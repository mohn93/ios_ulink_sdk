//
//  ULinkBootstrapRaceTests.swift
//  ULinkSDKTests
//
//  Regression tests for deep links lost to the cold-start bootstrap race.
//
//  A host launched by a universal link calls handleDeepLink from
//  application(_:continue:) moments after didFinishLaunching kicks off the
//  async initialize. resolveLink guarded with ensureBootstrapCompleted(), which
//  throws while bootstrap is still in flight, and handleDeepLink swallows that
//  error into a log line — so the launch link, the most common deep link there
//  is, was dropped.
//
//  The Android SDK had the identical defect; fixed there in 1.2.0.
//

import XCTest
@testable import ULinkSDK

/// HTTP client that holds the bootstrap POST open until released, and records
/// every resolve GET so the test can see whether resolution was attempted.
private final class GatedHTTPClient: HTTPClient {

    private let lock = NSLock()
    private var _resolveURLs: [String] = []
    private var _bootstrapStarted = false
    private var _released = false
    private var _failBootstrap = false
    private var _bootstrapAttempts = 0
    private var _failError: Error = ULinkError.invalidURL

    var resolveURLs: [String] {
        lock.lock(); defer { lock.unlock() }
        return _resolveURLs
    }

    var bootstrapStarted: Bool {
        lock.lock(); defer { lock.unlock() }
        return _bootstrapStarted
    }

    /// How many times /sdk/bootstrap was called — one per bootstrap attempt.
    var bootstrapAttempts: Int {
        lock.lock(); defer { lock.unlock() }
        return _bootstrapAttempts
    }

    func failBootstrap(with error: Error = ULinkError.invalidURL) {
        lock.lock(); _failBootstrap = true; _failError = error; lock.unlock()
    }

    func releaseBootstrap() {
        lock.lock(); _released = true; lock.unlock()
    }

    /// Simulates the network coming back: subsequent bootstrap attempts succeed.
    func recoverBootstrap() {
        lock.lock(); _failBootstrap = false; _released = true; lock.unlock()
    }

    private func markBootstrapStarted(_ url: String) {
        lock.lock()
        _bootstrapStarted = true
        if url.hasSuffix("/sdk/bootstrap") { _bootstrapAttempts += 1 }
        lock.unlock()
    }

    private func gateState() -> (released: Bool, shouldFail: Bool, error: Error) {
        lock.lock(); defer { lock.unlock() }
        return (_released, _failBootstrap, _failError)
    }

    private func recordResolve(_ url: String) {
        lock.lock(); _resolveURLs.append(url); lock.unlock()
    }

    override func post<T: Codable>(
        url: String,
        body: [String: Any],
        headers: [String: String] = [:]
    ) async throws -> T {
        markBootstrapStarted(url)

        while true {
            let state = gateState()
            if state.released { break }
            if state.shouldFail { throw state.error }
            try await Task.sleep(nanoseconds: 5_000_000)
        }

        let json = """
        {"success": true, "statusCode": 200, "installationId": "i-1", \
        "sessionId": "s-1", "installationToken": "tok", "isReinstall": false}
        """.data(using: .utf8)!
        return try JSONDecoder().decode(T.self, from: json)
    }

    override func getJson(
        url: String,
        headers: [String: String] = [:]
    ) async throws -> [String: Any] {
        recordResolve(url)
        return [
            "success": true,
            "data": ["slug": "abc", "type": "dynamic"] as [String: Any]
        ]
    }
}

final class ULinkBootstrapRaceTests: XCTestCase {

    private let link = URL(string: "https://links.shared.ly/abc")!

    private func makeConfig(persistLastLinkData: Bool = false) -> ULinkConfig {
        ULinkConfig(
            apiKey: "test-key",
            baseUrl: "https://api.test.com",
            debug: false,
            enableDeepLinkIntegration: true,
            persistLastLinkData: persistLastLinkData,
            autoCheckDeferredLink: false
        )
    }

    /// Polls until `condition` holds or the timeout elapses. The deep-link path
    /// is fire-and-forget, so there is no handle to await.
    private func waitUntil(
        timeout: TimeInterval = 5.0,
        _ condition: () -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return condition()
    }

    /// A link handed to the SDK while bootstrap is still in flight must be
    /// resolved once bootstrap lands, rather than rejected and forgotten.
    func testLinkArrivingDuringBootstrapIsResolvedOnceBootstrapFinishes() async throws {
        let client = GatedHTTPClient()
        let ulink = ULink.createInstance(config: makeConfig(), httpClient: client)

        let setupTask = Task { try await ulink.setup() }
        let started = await waitUntil { client.bootstrapStarted }
        XCTAssertTrue(started, "bootstrap should be in flight")

        // The launch link arrives while bootstrap is still pending.
        ulink.handleDeepLink(url: link)

        // Give the fire-and-forget task a chance to run and fail, if it is going to.
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertTrue(
            client.resolveURLs.isEmpty,
            "resolve must not be attempted before bootstrap completes"
        )

        client.releaseBootstrap()
        _ = try? await setupTask.value

        let resolved = await waitUntil {
            client.resolveURLs.contains { $0.contains("links.shared.ly") }
        }
        XCTAssertTrue(
            resolved,
            "the link that arrived during bootstrap must be resolved once bootstrap completes, not dropped"
        )
    }

    /// Waiting on bootstrap is only safe if bootstrap always reaches a terminal
    /// state. bootstrap() throws out of setup() on a network failure without
    /// marking itself completed, so without a guarantee at the setup boundary a
    /// failed cold start would park every later link for the life of the process.
    func testLinkDoesNotHangForeverWhenBootstrapFails() async throws {
        let client = GatedHTTPClient()
        let ulink = ULink.createInstance(config: makeConfig(), httpClient: client)

        client.failBootstrap()
        let setupTask = Task { try await ulink.setupOrMarkFailed() }
        _ = try? await setupTask.value

        // The link must reach a terminal outcome. It will fail — bootstrap did
        // not succeed — but it must not park forever waiting for a state that
        // will never arrive.
        var finished = false
        let deepLinkTask = Task {
            _ = try? await ulink.handleDeepLinkAsync(url: link)
            finished = true
        }

        let reachedTerminal = await waitUntil(timeout: 3.0) { finished }
        deepLinkTask.cancel()

        XCTAssertTrue(
            reachedTerminal,
            "a link handled after a failed bootstrap must fail fast, not park forever"
        )
    }

    /// A bootstrap failure is usually transient — a momentary network blip, or
    /// the first-launch "allow network access" dialog answered a beat too late.
    /// Bootstrap then sits in a completed-but-failed state, and because
    /// awaitBootstrap only waits for *completion*, every later link sailed past
    /// it into ensureBootstrapCompleted, which rejected it. handleDeepLink
    /// swallows that error into a log line, so the link was lost for the rest of
    /// the process even though the network had long since recovered.
    func testLinkArrivingAfterTransientBootstrapFailureRetriesAndResolves() async throws {
        let client = GatedHTTPClient()
        let ulink = ULink.createInstance(config: makeConfig(), httpClient: client)

        // Cold start during a blip: bootstrap reaches a terminal, failed state.
        client.failBootstrap()
        _ = try? await Task { try await ulink.setupOrMarkFailed() }.value
        XCTAssertEqual(client.bootstrapAttempts, 1, "cold-start bootstrap should have been attempted once")

        // By the time the user taps a link, the network is back.
        client.recoverBootstrap()
        ulink.handleDeepLink(url: link)

        let resolved = await waitUntil {
            client.resolveURLs.contains { $0.contains("links.shared.ly") }
        }
        XCTAssertTrue(
            resolved,
            "a link arriving after a transient bootstrap failure must retry bootstrap and resolve, not be dropped"
        )
        XCTAssertGreaterThanOrEqual(
            client.bootstrapAttempts, 2,
            "the failed bootstrap should have been retried before resolving"
        )
    }

    /// Several links can land at once (a tap plus a pending launch URL). They
    /// must share one retry rather than each firing their own bootstrap.
    func testConcurrentLinksAfterFailedBootstrapShareASingleRetry() async throws {
        let client = GatedHTTPClient()
        let ulink = ULink.createInstance(config: makeConfig(), httpClient: client)

        client.failBootstrap()
        _ = try? await Task { try await ulink.setupOrMarkFailed() }.value
        client.recoverBootstrap()

        ulink.handleDeepLink(url: link)
        ulink.handleDeepLink(url: link)
        ulink.handleDeepLink(url: link)

        let resolved = await waitUntil {
            client.resolveURLs.contains { $0.contains("links.shared.ly") }
        }
        XCTAssertTrue(resolved, "links should resolve after the shared retry")

        // Let any duplicate retries land before counting.
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(
            client.bootstrapAttempts, 2,
            "three concurrent links must trigger exactly one bootstrap retry, not three"
        )
    }

    /// The plugins resolve links through resolveLink/processULinkUrl directly,
    /// not handleDeepLinkAsync. Those used to reject outright after a failed
    /// bootstrap, so a degraded SDK lost every link until the next foreground.
    func testResolveLinkAfterFailedBootstrapRetriesAndSucceeds() async throws {
        let client = GatedHTTPClient()
        let ulink = ULink.createInstance(config: makeConfig(), httpClient: client)

        client.failBootstrap()
        _ = try? await Task { try await ulink.setupOrMarkFailed() }.value
        client.recoverBootstrap()

        let response = try await ulink.resolveLink(url: link.absoluteString)

        XCTAssertTrue(response.success, "resolveLink must retry the failed bootstrap and then resolve")
        XCTAssertEqual(client.bootstrapAttempts, 2, "exactly one bootstrap retry before resolving")
    }

    /// A 503 from load shedding carries Retry-After. Retrying sooner only adds
    /// load to a backend that is already shedding it.
    func testBootstrapRetryWaitsForRetryAfter() async throws {
        let client = GatedHTTPClient()
        let ulink = ULink.createInstance(config: makeConfig(), httpClient: client)

        client.failBootstrap(with: ULinkHTTPError(statusCode: 503, retryAfter: 0.5))
        _ = try? await Task { try await ulink.setupOrMarkFailed() }.value
        client.recoverBootstrap()

        let start = Date()
        let response = try await ulink.resolveLink(url: link.absoluteString)
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertTrue(response.success)
        XCTAssertGreaterThanOrEqual(elapsed, 0.5, "the retry must not be sent before Retry-After elapses")
        XCTAssertLessThan(elapsed, 2.0, "jitter is bounded to 50% of Retry-After")
        XCTAssertEqual(client.bootstrapAttempts, 2)
    }

    /// A long Retry-After is not waited out inside a single call: the call
    /// fails fast and leaves the retry to a later call or foreground.
    func testLongRetryAfterFailsFastWithoutRetrying() async throws {
        let client = GatedHTTPClient()
        let ulink = ULink.createInstance(config: makeConfig(), httpClient: client)

        client.failBootstrap(with: ULinkHTTPError(statusCode: 503, retryAfter: 600))
        _ = try? await Task { try await ulink.setupOrMarkFailed() }.value
        client.recoverBootstrap()

        let start = Date()
        do {
            _ = try await ulink.resolveLink(url: link.absoluteString)
            XCTFail("resolveLink must fail while the server's Retry-After is pending")
        } catch {}

        XCTAssertLessThan(Date().timeIntervalSince(start), 2.0, "must fail fast, not wait 10 minutes")
        XCTAssertEqual(client.bootstrapAttempts, 1, "no retry may be sent before Retry-After")
    }

    /// Unreadable persisted last-link data used to throw out of setup() before
    /// bootstrap, on every launch, because nothing cleared it.
    func testUnreadablePersistedLastLinkDataDoesNotFailSetup() async throws {
        let key = "last_link_data"
        UserDefaults.standard.set(Data("not json".utf8), forKey: key)
        defer { UserDefaults.standard.removeObject(forKey: key) }

        let client = GatedHTTPClient()
        client.releaseBootstrap()
        let ulink = ULink.createInstance(config: makeConfig(persistLastLinkData: true), httpClient: client)

        try await ulink.setupOrMarkFailed()

        XCTAssertEqual(client.bootstrapAttempts, 1, "bootstrap must still run")
        XCTAssertNil(UserDefaults.standard.data(forKey: key), "the unreadable data must be discarded")
        let response = try await ulink.resolveLink(url: link.absoluteString)
        XCTAssertTrue(response.success)
    }

    func testRetryAfterHeaderIsParsedCaseInsensitively() {
        let url = URL(string: "https://api.test.com/sdk/bootstrap")!
        let lower = HTTPURLResponse(url: url, statusCode: 503, httpVersion: nil, headerFields: ["retry-after": "10"])!
        let missing = HTTPURLResponse(url: url, statusCode: 503, httpVersion: nil, headerFields: [:])!
        let date = HTTPURLResponse(url: url, statusCode: 503, httpVersion: nil,
                                   headerFields: ["Retry-After": "Wed, 21 Oct 2026 07:28:00 GMT"])!
        XCTAssertEqual(HTTPClient.retryAfterSeconds(lower), 10)
        XCTAssertNil(HTTPClient.retryAfterSeconds(missing))
        XCTAssertNil(HTTPClient.retryAfterSeconds(date), "the HTTP-date form is not used by the API and is ignored")
    }

    /// Wrappers forward `error.localizedDescription` from an `any Error`. Without
    /// LocalizedError that was "The operation couldn't be completed.
    /// (ULinkSDK.ULinkHTTPError error 1.)", hiding the status and the reason.
    func testHTTPErrorDescribesStatusAndServerDetailThroughAnyError() {
        let error: Error = ULinkHTTPError(
            statusCode: 403,
            responseBody: #"{"type":"about:blank","status":403,"detail":"Free plan MAU limit reached (10000/10000)."}"#
        )

        XCTAssertEqual(
            error.localizedDescription,
            "HTTP error occurred (status: 403): Free plan MAU limit reached (10000/10000)."
        )
        XCTAssertEqual((error as NSError).localizedDescription, error.localizedDescription)
    }

    func testHTTPErrorFallsBackToTruncatedRawBody() {
        let error: Error = ULinkHTTPError(statusCode: 502, responseBody: String(repeating: "x", count: 1000))

        XCTAssertTrue(error.localizedDescription.hasPrefix("HTTP error occurred (status: 502). Response: xxx"))
        XCTAssertLessThan(error.localizedDescription.count, 400)
    }

    /// While degraded, API calls used to report "Bootstrap failed (status: 0)"
    /// whatever the server had said.
    func testCallsWhileDegradedReportTheLastBootstrapStatus() async throws {
        let client = GatedHTTPClient()
        let ulink = ULink.createInstance(config: makeConfig(), httpClient: client)

        client.failBootstrap(with: ULinkHTTPError(statusCode: 401, responseBody: #"{"detail":"Invalid API key"}"#))
        _ = try? await Task { try await ulink.setupOrMarkFailed() }.value

        do {
            _ = try await ulink.resolveLink(url: link.absoluteString)
            XCTFail("resolveLink must fail while bootstrap keeps failing")
        } catch ULinkInitializationError.bootstrapFailed(let statusCode, let message) {
            XCTAssertEqual(statusCode, 401)
            XCTAssertTrue(message.contains("Invalid API key"), message)
        }
    }

    func testRecoveredBootstrapClearsTheRecordedFailure() async throws {
        let client = GatedHTTPClient()
        let ulink = ULink.createInstance(config: makeConfig(), httpClient: client)

        client.failBootstrap(with: ULinkHTTPError(statusCode: 503))
        _ = try? await Task { try await ulink.setupOrMarkFailed() }.value
        client.recoverBootstrap()

        let response = try await ulink.resolveLink(url: link.absoluteString)
        XCTAssertTrue(response.success)
    }
}
