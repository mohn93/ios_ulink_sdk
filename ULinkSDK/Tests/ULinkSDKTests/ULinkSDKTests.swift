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
    
    func testULinkConfigInitialization() throws {
        let config = ULinkConfig(apiKey: "test-api-key", baseUrl: "https://api.ulink.example.com")
        
        XCTAssertEqual(config.apiKey, "test-api-key")
        XCTAssertEqual(config.baseUrl, "https://api.ulink.example.com")
        XCTAssertTrue(config.enableDebugLogging)
        XCTAssertEqual(config.sessionTimeoutMinutes, 30)
    }
    
    func testULinkParametersInitialization() throws {
        let params = ULinkParameters()
        params.setParameter("key1", value: "value1")
        params.setParameter("key2", value: 123)
        
        XCTAssertEqual(params.getParameter("key1") as? String, "value1")
        XCTAssertEqual(params.getParameter("key2") as? Int, 123)
    }
    
    func testULinkResolvedDataInitialization() throws {
        let resolvedData = ULinkResolvedData()
        resolvedData.url = "https://example.com/deep-link"
        resolvedData.isULink = true
        resolvedData.clickId = "test-click-id"
        
        XCTAssertEqual(resolvedData.url, "https://example.com/deep-link")
        XCTAssertTrue(resolvedData.isULink)
        XCTAssertEqual(resolvedData.clickId, "test-click-id")
    }
    
    func testDeviceInfoUtils() throws {
        let deviceInfo = DeviceInfoUtils.getBasicDeviceInfoSync()
        
        XCTAssertNotNil(deviceInfo["platform"])
        XCTAssertEqual(deviceInfo["platform"] as? String, "ios")
        XCTAssertNotNil(deviceInfo["deviceModel"])
        XCTAssertNotNil(deviceInfo["osName"])
    }
    
    func testULinkInstallationInitialization() throws {
        let installation = ULinkInstallation()
        installation.installationId = "test-installation-id"
        installation.installationToken = "test-token"
        installation.isFirstLaunch = true
        
        XCTAssertEqual(installation.installationId, "test-installation-id")
        XCTAssertEqual(installation.installationToken, "test-token")
        XCTAssertTrue(installation.isFirstLaunch)
    }
    
    func testULinkSessionInitialization() throws {
        let session = ULinkSession()
        session.sessionId = "test-session-id"
        session.installationId = "test-installation-id"
        session.startedAt = Date()
        
        XCTAssertEqual(session.sessionId, "test-session-id")
        XCTAssertEqual(session.installationId, "test-installation-id")
        XCTAssertNotNil(session.startedAt)
    }
    
    func testULinkResponseInitialization() throws {
        let response = ULinkResponse()
        response.success = true
        response.url = "https://ulink.example.com/abc123"
        response.shortUrl = "https://u.link/abc123"
        
        XCTAssertTrue(response.success)
        XCTAssertEqual(response.url, "https://ulink.example.com/abc123")
        XCTAssertEqual(response.shortUrl, "https://u.link/abc123")
    }
    
    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
            let _ = DeviceInfoUtils.getBasicDeviceInfoSync()
        }
    }
}