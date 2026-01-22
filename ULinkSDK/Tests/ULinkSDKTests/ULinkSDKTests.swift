//
//  ULinkSDKTests.swift
//  ULinkSDKTests
//
//  Created by ULink SDK
//  Copyright © 2024 ULink. All rights reserved.
//

import XCTest
@testable import ULinkSDK

final class ULinkSDKTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    // MARK: - ULinkConfig Tests

    func testULinkConfigInitialization() throws {
        let config = ULinkConfig(apiKey: "test-api-key", baseUrl: "https://api.ulink.example.com")

        XCTAssertEqual(config.apiKey, "test-api-key")
        XCTAssertEqual(config.baseUrl, "https://api.ulink.example.com")
        XCTAssertFalse(config.debug) // Default is false
        XCTAssertTrue(config.enableDeepLinkIntegration) // Default is true
    }

    func testULinkConfigWithDebugEnabled() throws {
        let config = ULinkConfig(
            apiKey: "test-api-key",
            baseUrl: "https://api.ulink.example.com",
            debug: true
        )

        XCTAssertTrue(config.debug)
    }

    func testULinkConfigDefaultBaseUrl() throws {
        let config = ULinkConfig(apiKey: "test-api-key")

        XCTAssertEqual(config.baseUrl, "https://api.ulink.ly")
    }

    // MARK: - ULinkParameters Tests

    func testULinkParametersDynamicLink() throws {
        let params = ULinkParameters.dynamic(
            domain: "example.shared.ly",
            slug: "test-slug",
            iosFallbackUrl: "https://apps.apple.com/app/test",
            androidFallbackUrl: "https://play.google.com/store/apps/details?id=test",
            fallbackUrl: "https://example.com",
            parameters: ["key1": "value1", "key2": 123]
        )

        XCTAssertEqual(params.domain, "example.shared.ly")
        XCTAssertEqual(params.slug, "test-slug")
        XCTAssertEqual(params.type, "dynamic")
        XCTAssertEqual(params.iosFallbackUrl, "https://apps.apple.com/app/test")
        XCTAssertEqual(params.androidFallbackUrl, "https://play.google.com/store/apps/details?id=test")
        XCTAssertEqual(params.fallbackUrl, "https://example.com")
        XCTAssertEqual(params.parameters?["key1"] as? String, "value1")
        XCTAssertEqual(params.parameters?["key2"] as? Int, 123)
    }

    func testULinkParametersUnifiedLink() throws {
        let params = ULinkParameters.unified(
            domain: "example.shared.ly",
            slug: "test-unified",
            iosUrl: "https://apps.apple.com/app/test",
            androidUrl: "https://play.google.com/store/apps/details?id=test",
            fallbackUrl: "https://example.com"
        )

        XCTAssertEqual(params.domain, "example.shared.ly")
        XCTAssertEqual(params.slug, "test-unified")
        XCTAssertEqual(params.type, "unified")
        XCTAssertEqual(params.iosUrl, "https://apps.apple.com/app/test")
        XCTAssertEqual(params.androidUrl, "https://play.google.com/store/apps/details?id=test")
        XCTAssertEqual(params.fallbackUrl, "https://example.com")
    }

    func testULinkParametersToJson() throws {
        let params = ULinkParameters.dynamic(
            domain: "example.shared.ly",
            slug: "test-slug",
            parameters: ["utm_source": "test"]
        )

        let json = params.toJson()

        XCTAssertEqual(json["domain"] as? String, "example.shared.ly")
        XCTAssertEqual(json["slug"] as? String, "test-slug")
        XCTAssertEqual(json["type"] as? String, "dynamic")
    }

    // MARK: - ULinkResolvedData Tests

    func testULinkResolvedDataInitialization() throws {
        let resolvedData = ULinkResolvedData(
            slug: "test-slug",
            iosFallbackUrl: "https://apps.apple.com/app/test",
            fallbackUrl: "https://example.com",
            parameters: ["key": "value"],
            type: "dynamic",
            isDeferred: false,
            matchType: nil
        )

        XCTAssertEqual(resolvedData.slug, "test-slug")
        XCTAssertEqual(resolvedData.iosFallbackUrl, "https://apps.apple.com/app/test")
        XCTAssertEqual(resolvedData.fallbackUrl, "https://example.com")
        XCTAssertEqual(resolvedData.parameters?["key"] as? String, "value")
        XCTAssertEqual(resolvedData.type, "dynamic")
        XCTAssertFalse(resolvedData.isDeferred)
    }

    func testULinkResolvedDataDeferredLink() throws {
        let resolvedData = ULinkResolvedData(
            slug: "deferred-test",
            isDeferred: true,
            matchType: "fingerprint"
        )

        XCTAssertEqual(resolvedData.slug, "deferred-test")
        XCTAssertTrue(resolvedData.isDeferred)
        XCTAssertEqual(resolvedData.matchType, "fingerprint")
    }

    func testULinkResolvedDataFromJson() throws {
        let json: [String: Any] = [
            "slug": "test-slug",
            "iosFallbackUrl": "https://apps.apple.com/app/test",
            "fallbackUrl": "https://example.com",
            "parameters": ["utm_source": "test"],
            "type": "dynamic",
            "isDeferred": false
        ]

        let resolvedData = ULinkResolvedData.fromJson(json)

        XCTAssertNotNil(resolvedData)
        XCTAssertEqual(resolvedData?.slug, "test-slug")
        XCTAssertEqual(resolvedData?.iosFallbackUrl, "https://apps.apple.com/app/test")
        XCTAssertEqual(resolvedData?.type, "dynamic")
        XCTAssertFalse(resolvedData?.isDeferred ?? true)
    }

    // MARK: - DeviceInfoHelper Tests

    func testDeviceInfoHelper() throws {
        let deviceInfo = DeviceInfoHelper.getDeviceInfo()

        XCTAssertNotNil(deviceInfo["platform"])
        // Platform is "ios" on iOS devices, "unknown" on macOS command line
        let platform = deviceInfo["platform"] as? String
        XCTAssertTrue(platform == "ios" || platform == "unknown")
        XCTAssertNotNil(deviceInfo["osName"])
        XCTAssertNotNil(deviceInfo["osVersion"])
    }

    func testDeviceInfoHelperSDKVersion() throws {
        let sdkVersion = DeviceInfoHelper.getSDKVersion()

        XCTAssertFalse(sdkVersion.isEmpty)
    }

    func testDeviceInfoHelperUserAgent() throws {
        let userAgent = DeviceInfoHelper.getUserAgent()

        XCTAssertFalse(userAgent.isEmpty)
        // User agent format varies by platform - just ensure it's not empty
    }

    // MARK: - ULinkInstallation Tests

    func testULinkInstallationInitialization() throws {
        let installation = ULinkInstallation(
            installationId: "test-installation-id",
            installationToken: "test-token"
        )

        XCTAssertEqual(installation.installationId, "test-installation-id")
        XCTAssertEqual(installation.installationToken, "test-token")
        XCTAssertNotNil(installation.createdAt)
        XCTAssertNotNil(installation.updatedAt)
    }

    func testULinkInstallationFromJson() throws {
        let json: [String: Any] = [
            "installationId": "test-installation-id",
            "installationToken": "test-token",
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "updatedAt": ISO8601DateFormatter().string(from: Date())
        ]

        let installation = ULinkInstallation.fromJson(json)

        XCTAssertNotNil(installation)
        XCTAssertEqual(installation?.installationId, "test-installation-id")
        XCTAssertEqual(installation?.installationToken, "test-token")
    }

    func testULinkInstallationToJson() throws {
        let installation = ULinkInstallation(
            installationId: "test-id",
            installationToken: "test-token"
        )

        let json = installation.toJson()

        XCTAssertEqual(json["installationId"] as? String, "test-id")
        XCTAssertEqual(json["installationToken"] as? String, "test-token")
    }

    // MARK: - ULinkSession Tests

    func testULinkSessionInitialization() throws {
        let session = ULinkSession(
            sessionId: "test-session-id",
            installationId: "test-installation-id"
        )

        XCTAssertEqual(session.sessionId, "test-session-id")
        XCTAssertEqual(session.installationId, "test-installation-id")
        XCTAssertNotNil(session.startedAt)
        XCTAssertTrue(session.isActive)
    }

    func testULinkSessionEndSession() throws {
        let session = ULinkSession(
            sessionId: "test-session-id",
            installationId: "test-installation-id"
        )

        // Wait a tiny bit to ensure duration > 0
        Thread.sleep(forTimeInterval: 0.01)

        let endedSession = session.endSession()

        XCTAssertEqual(endedSession.sessionId, "test-session-id")
        XCTAssertNotNil(endedSession.endedAt)
        XCTAssertNotNil(endedSession.duration)
        XCTAssertFalse(endedSession.isActive)
    }

    func testULinkSessionFromJson() throws {
        let json: [String: Any] = [
            "sessionId": "test-session-id",
            "installationId": "test-installation-id",
            "startedAt": ISO8601DateFormatter().string(from: Date())
        ]

        let session = ULinkSession.fromJson(json)

        XCTAssertNotNil(session)
        XCTAssertEqual(session?.sessionId, "test-session-id")
        XCTAssertEqual(session?.installationId, "test-installation-id")
    }

    // MARK: - ULinkResponse Tests

    func testULinkResponseSuccessInitialization() throws {
        let response = ULinkResponse(
            success: true,
            url: "https://ulink.example.com/abc123"
        )

        XCTAssertTrue(response.success)
        XCTAssertEqual(response.url, "https://ulink.example.com/abc123")
        XCTAssertNil(response.error)
    }

    func testULinkResponseErrorInitialization() throws {
        let response = ULinkResponse(
            success: false,
            error: "Something went wrong"
        )

        XCTAssertFalse(response.success)
        XCTAssertNil(response.url)
        XCTAssertEqual(response.error, "Something went wrong")
    }

    func testULinkResponseFactoryMethods() throws {
        let successResponse = ULinkResponse.success(url: "https://u.link/abc123")
        let errorResponse = ULinkResponse.error(message: "Failed to create link")

        XCTAssertTrue(successResponse.success)
        XCTAssertEqual(successResponse.url, "https://u.link/abc123")

        XCTAssertFalse(errorResponse.success)
        XCTAssertEqual(errorResponse.error, "Failed to create link")
    }

    func testULinkResponseFromJson() throws {
        let json: [String: Any] = [
            "success": true,
            "shortUrl": "https://u.link/abc123"
        ]

        let response = ULinkResponse.fromJson(json)

        XCTAssertTrue(response.success)
        XCTAssertEqual(response.url, "https://u.link/abc123")
    }

    func testULinkResponseFromJsonWithError() throws {
        let json: [String: Any] = [
            "error": "Invalid API key"
        ]

        let response = ULinkResponse.fromJson(json)

        XCTAssertFalse(response.success)
        XCTAssertEqual(response.error, "Invalid API key")
    }

    // MARK: - SocialMediaTags Tests

    func testSocialMediaTagsInitialization() throws {
        let tags = SocialMediaTags(
            ogTitle: "Test Title",
            ogDescription: "Test Description",
            ogImage: "https://example.com/image.png"
        )

        XCTAssertEqual(tags.ogTitle, "Test Title")
        XCTAssertEqual(tags.ogDescription, "Test Description")
        XCTAssertEqual(tags.ogImage, "https://example.com/image.png")
    }

    func testSocialMediaTagsToJson() throws {
        let tags = SocialMediaTags(
            ogTitle: "Test Title",
            ogDescription: "Test Description"
        )

        let json = tags.toJson()

        XCTAssertEqual(json["ogTitle"] as? String, "Test Title")
        XCTAssertEqual(json["ogDescription"] as? String, "Test Description")
        XCTAssertNil(json["ogImage"])
    }

    // MARK: - Performance Tests

    func testPerformanceDeviceInfo() throws {
        self.measure {
            let _ = DeviceInfoHelper.getDeviceInfo()
        }
    }
}
