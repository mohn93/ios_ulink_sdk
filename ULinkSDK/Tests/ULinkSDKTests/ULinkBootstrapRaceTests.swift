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

    var resolveURLs: [String] {
        lock.lock(); defer { lock.unlock() }
        return _resolveURLs
    }

    var bootstrapStarted: Bool {
        lock.lock(); defer { lock.unlock() }
        return _bootstrapStarted
    }

    func failBootstrap() {
        lock.lock(); _failBootstrap = true; lock.unlock()
    }

    func releaseBootstrap() {
        lock.lock(); _released = true; lock.unlock()
    }

    private func markBootstrapStarted() {
        lock.lock(); _bootstrapStarted = true; lock.unlock()
    }

    private func gateState() -> (released: Bool, shouldFail: Bool) {
        lock.lock(); defer { lock.unlock() }
        return (_released, _failBootstrap)
    }

    private func recordResolve(_ url: String) {
        lock.lock(); _resolveURLs.append(url); lock.unlock()
    }

    override func post<T: Codable>(
        url: String,
        body: [String: Any],
        headers: [String: String] = [:]
    ) async throws -> T {
        markBootstrapStarted()

        while true {
            let state = gateState()
            if state.released { break }
            if state.shouldFail { throw ULinkError.invalidURL }
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

    private func makeConfig() -> ULinkConfig {
        ULinkConfig(
            apiKey: "test-key",
            baseUrl: "https://api.test.com",
            debug: false,
            enableDeepLinkIntegration: true,
            persistLastLinkData: false,
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
}
