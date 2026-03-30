//
//  ULinkConfig.swift
//  ULinkSDK
//
//  Created by ULink SDK
//  Copyright © 2024 ULink. All rights reserved.
//

import Foundation

/**
 * Configuration for the ULink SDK
 */
@objc public class ULinkConfig: NSObject {
    
    /**
     * The API key for the ULink service
     */
    @objc public let apiKey: String
    
    /**
     * Internal use only. Defaults to the production ULink API.
     * You do not need to set this — it is used for local development and testing.
     */
    @objc public let baseUrl: String
    
    /**
     * Whether to use debug mode
     */
    @objc public let debug: Bool
    
    /**
     * Whether to enable automatic deep link integration
     * When enabled, the SDK will automatically handle incoming URLs and process deep links
     */
    @objc public let enableDeepLinkIntegration: Bool
    
    /**
     * Whether to persist the last resolved link for later retrieval
     */
    @objc public let persistLastLinkData: Bool
    
    /**
     * Time-to-live for persisted last link (nil to disable TTL)
     */
    public let lastLinkTimeToLive: TimeInterval?
    
    /**
     * If true, clears the persisted last link after it is read the first time
     */
    @objc public let clearLastLinkOnRead: Bool
    
    /**
     * If true, do not persist parameters/metadata for the last link
     */
    @objc public let redactAllParametersInLastLink: Bool
    
    /**
     * Keys to redact from parameters/metadata when persisting the last link
     */
    public let redactedParameterKeysInLastLink: [String]
    
    /**
     * If true, automatically checks for deferred deep links on first app launch
     * If false, developers must manually call checkDeferredLink() when ready
     */
    @objc public let autoCheckDeferredLink: Bool
    
    /**
     * Creates a new ULink configuration
     *
     * - Parameters:
     *   - apiKey: The API key for the ULink service
     *   - baseUrl: Internal use only. Defaults to the production API. You do not need to set this.
     *   - debug: Whether to use debug mode (defaults to false)
     *   - enableDeepLinkIntegration: Whether to enable automatic deep link integration (defaults to true)
     *   - persistLastLinkData: Whether to persist the last resolved link (defaults to true)
     *   - lastLinkTimeToLive: Time-to-live for persisted last link in seconds (defaults to 24 hours, nil to disable)
     *   - clearLastLinkOnRead: If true, clears the persisted last link after reading (defaults to false)
     *   - redactAllParametersInLastLink: If true, do not persist parameters/metadata (defaults to false)
     *   - redactedParameterKeysInLastLink: Keys to redact from parameters/metadata (defaults to empty array)
     */
    public init(
        apiKey: String,
        baseUrl: String = "https://api.ulink.ly",
        debug: Bool = false,
        enableDeepLinkIntegration: Bool = true,
        persistLastLinkData: Bool = true,
        lastLinkTimeToLive: TimeInterval? = 24 * 60 * 60, // 24 hours
        clearLastLinkOnRead: Bool = false,
        redactAllParametersInLastLink: Bool = false,
        redactedParameterKeysInLastLink: [String] = [],
        autoCheckDeferredLink: Bool = true
    ) {
        self.apiKey = apiKey
        self.baseUrl = baseUrl
        self.debug = debug
        self.enableDeepLinkIntegration = enableDeepLinkIntegration
        self.persistLastLinkData = persistLastLinkData
        self.lastLinkTimeToLive = lastLinkTimeToLive
        self.clearLastLinkOnRead = clearLastLinkOnRead
        self.redactAllParametersInLastLink = redactAllParametersInLastLink
        self.redactedParameterKeysInLastLink = redactedParameterKeysInLastLink
        self.autoCheckDeferredLink = autoCheckDeferredLink
        super.init()
    }
}