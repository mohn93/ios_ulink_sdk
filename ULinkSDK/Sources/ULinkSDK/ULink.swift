//
//  ULink.swift
//  ULinkSDK
//
//  Created by ULink SDK
//  Copyright © 2024 ULink. All rights reserved.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif
import Combine

/**
 * Main class for the ULink iOS SDK
 *
 * This class provides functionality for:
 * - Creating dynamic and unified links
 * - Handling deep links and universal links
 * - Session management with automatic lifecycle handling
 * - Installation tracking
 * - Link resolution and processing
 */
@available(macOS 10.15, iOS 13.0, *)
@objc public class ULink: NSObject {
    
    // MARK: - Constants
    
    private static let sdkVersion = "1.0.0"
    private static let prefsName = "ulink_prefs"
    private static let keyInstallationId = "installation_id"
    private static let keyInstallationToken = "installation_token"
    private static let keyLastLinkData = "last_link_data"
    private static let keyLastLinkSavedAt = "last_link_saved_at"
    
    // MARK: - Singleton
    
    @objc public static var shared: ULink {
        guard let instance = _instance else {
            fatalError("ULink SDK not initialized. Call ULink.initialize() first.")
        }
        return instance
    }
    
    private static var _instance: ULink?
    
    // MARK: - Properties
    
    private let config: ULinkConfig
    private let httpClient: HTTPClient
    private let userDefaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()
    
    // Installation and session management
    private var installationId: String?
    private var installationToken: String?
    private var currentSessionId: String?
    private var sessionState: SessionState = .idle
    private var sessionTask: Task<Void, Never>?
    private var sessionContinuation: CheckedContinuation<Void, Never>?
    
    // Streams for deep link handling
    private let _dynamicLinkSubject = PassthroughSubject<ULinkResolvedData, Never>()
    private let _unifiedLinkSubject = PassthroughSubject<ULinkResolvedData, Never>()
    
    public var dynamicLinkStream: AnyPublisher<ULinkResolvedData, Never> {
        return _dynamicLinkSubject.eraseToAnyPublisher()
    }
    
    public var unifiedLinkStream: AnyPublisher<ULinkResolvedData, Never> {
        return _unifiedLinkSubject.eraseToAnyPublisher()
    }
    
    // Legacy compatibility
    public var onLink: AnyPublisher<ULinkResolvedData, Never> {
        return dynamicLinkStream
    }
    
    public var onUnifiedLink: AnyPublisher<ULinkResolvedData, Never> {
        return unifiedLinkStream
    }
    
    // Deep link handling
    private var initialUrl: URL?
    private var lastLinkData: ULinkResolvedData?
    
    // MARK: - Initialization
    
    /**
     * Initialize the ULink SDK
     *
     * This method initializes the ULink SDK and performs the following actions:
     * 1. Creates a singleton instance with the provided configuration
     * 2. Retrieves or generates a unique installation ID
     * 3. Tracks the installation with the server
     * 4. Registers lifecycle observer for automatic session management
     *
     * Sessions must be started manually by calling startSession() when needed.
     *
     * It should be called when your app starts, typically in your AppDelegate's
     * application(_:didFinishLaunchingWithOptions:) method.
     *
     * Example:
     * ```swift
     *
     * 
     * func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
     *     ULink.initialize(
     *         config: ULinkConfig(
     *             apiKey: "your_api_key",
     *             baseUrl: "https://api.ulink.ly",
     *             debug: true
     *         )
     *     )
     *     return true
     * }
     * ```
     */
    public static func initialize(config: ULinkConfig) async -> ULink {
        if _instance == nil {
            _instance = ULink(config: config)
            await _instance?.setup()
        }
        return _instance!
    }
    
    public static func createInstance(config: ULinkConfig, httpClient: HTTPClient) -> ULink {
        return ULink(config: config, httpClient: httpClient)
    }
    
    private init(config: ULinkConfig, httpClient: HTTPClient? = nil) {
        self.config = config
        self.httpClient = httpClient ?? HTTPClient(debug: config.debug)
        self.userDefaults = UserDefaults.standard
        super.init()
    }
    
    // MARK: - Setup
    
    private func setup() async {
        // Generate or load installation ID
        if installationId == nil {
            generateInstallationId()
        }
        
        // Load installation token
        loadInstallationToken()
        
        // Load last link data
        loadLastLinkData()
        
        // Register for app lifecycle notifications
        registerForLifecycleNotifications()
        
        // Bootstrap (track installation and start session)
        await bootstrap()
        
        // Handle initial URL if set
        if let initialUrl = initialUrl {
            handleDeepLink(url: initialUrl)
        }
    }
    
    // MARK: - Installation Management
    
    @objc public func getInstallationId() -> String? {
        return installationId
    }
    
    private func generateInstallationId() {
        if let existingId = userDefaults.string(forKey: Self.keyInstallationId) {
            installationId = existingId
        } else {
            let newId = UUID().uuidString
            installationId = newId
            userDefaults.set(newId, forKey: Self.keyInstallationId)
        }
    }
    
    private func loadInstallationToken() {
        installationToken = userDefaults.string(forKey: Self.keyInstallationToken)
    }
    
    private func saveInstallationToken(_ token: String) {
        installationToken = token
        userDefaults.set(token, forKey: Self.keyInstallationToken)
    }
    
    private func getInstallationToken() -> String? {
        return installationToken
    }
    
    // MARK: - Bootstrap
    
    private func bootstrap() async {
        do {
            let response = try await trackInstallation()
            if response.success {
                if let token = response.installationToken {
                    saveInstallationToken(token)
                }
                
                // Save session ID if returned from bootstrap
                if let sessionId = response.sessionId {
                    currentSessionId = sessionId
                    sessionState = .active
                    
                    if config.debug {
                        print("[ULink] Bootstrap session started: \(sessionId)")
                    }
                }
                
                if config.debug {
                    print("[ULink] Bootstrap completed successfully. Installation token saved.")
                }
            } else {
                if config.debug {
                    print("[ULink] Bootstrap failed with status code: \(response.statusCode)")
                }
            }
        } catch {
            if config.debug {
                print("[ULink] Bootstrap error: \(error)")
            }
        }
    }
    
    private func buildBootstrapBody() async -> [String: Any] {
        // Use basic device info to match Flutter SDK structure
        let deviceInfo = await DeviceInfoUtils.getCompleteDeviceInfo()
        
        var bootstrapData: [String: Any] = [
            "installationId": installationId ?? ""
        ]
        
        // Add core device fields (matching Flutter SDK)
        if let deviceId = deviceInfo["deviceId"] as? String {
            bootstrapData["deviceId"] = deviceId
        }
        if let deviceModel = deviceInfo["deviceModel"] as? String {
            bootstrapData["deviceModel"] = deviceModel
        }
        if let deviceManufacturer = deviceInfo["deviceManufacturer"] as? String {
            bootstrapData["deviceManufacturer"] = deviceManufacturer
        }
        if let osName = deviceInfo["osName"] as? String {
            bootstrapData["osName"] = osName
        }
        if let osVersion = deviceInfo["osVersion"] as? String {
            bootstrapData["osVersion"] = osVersion
        }
        if let appVersion = deviceInfo["appVersion"] as? String {
            bootstrapData["appVersion"] = appVersion
        }
        if let appBuild = deviceInfo["appBuild"] as? String {
            bootstrapData["appBuild"] = appBuild
        }
        if let language = deviceInfo["language"] as? String {
            bootstrapData["language"] = language
        }
        if let timezone = deviceInfo["timezone"] as? String {
            bootstrapData["timezone"] = timezone
        }
        
        // Add session-specific fields that match startSession
        if let networkType = deviceInfo["networkType"] as? String {
            bootstrapData["networkType"] = networkType
        }
        if let deviceOrientation = deviceInfo["deviceOrientation"] as? String {
            bootstrapData["deviceOrientation"] = deviceOrientation
        }
        if let batteryLevel = deviceInfo["batteryLevel"] as? Int {
            bootstrapData["batteryLevel"] = batteryLevel
        }
        if let isCharging = deviceInfo["isCharging"] as? Bool {
            bootstrapData["isCharging"] = isCharging
        }
        
        // Include metadata with client info (matching Flutter SDK structure)
        let metadata: [String: Any] = [
            "client": [
                "type": "sdk-ios",
                "version": Self.sdkVersion,
                "platform": "ios"
            ]
        ]
        
        bootstrapData["metadata"] = metadata
        
        return bootstrapData
    }
    
    public  func trackInstallation() async throws -> ULinkInstallationResponse {
        let body = await buildBootstrapBody()
        
        var headers = [
            "X-App-Key": config.apiKey,
            "Content-Type": "application/json",
            "X-ULink-Client": "sdk-ios",
            "X-ULink-Client-Version": ULink.sdkVersion,
            "X-ULink-Client-Platform": "ios"
        ]
        
        // Add installation token if available (like Flutter SDK)
        if let installationToken = getInstallationToken(), !installationToken.isEmpty {
            headers["X-Installation-Token"] = installationToken
        }
        
        // Add installation ID if available
        if let installationId = getInstallationId(), !installationId.isEmpty {
            headers["X-Installation-Id"] = installationId
        }
        
        // Add device ID if available (like Flutter SDK)
        let deviceInfo = await DeviceInfoUtils.getCompleteDeviceInfo()
        if let deviceId = deviceInfo["deviceId"] as? String, !deviceId.isEmpty {
            headers["X-Device-Id"] = deviceId
        }
        
        return try await httpClient.post(
            url: "\(config.baseUrl)/sdk/bootstrap",
            body: body,
            headers: headers
        )
    }
    
    // MARK: - Deep Link Handling
    
    @objc public func handleDeepLink(url: URL) {
        if config.debug {
            print("[ULink] Handling deep link: \(url.absoluteString)")
        }
        
        Task {
            if let resolvedData = await processULinkUrl(url) {
                // Determine link type and emit to appropriate stream
                if resolvedData.type == "unified" {
                    _unifiedLinkSubject.send(resolvedData)
                } else {
                    _dynamicLinkSubject.send(resolvedData)
                }
                
                // Save last link data if persistence is enabled
                if config.persistLastLinkData {
                    saveLastLinkData(resolvedData)
                }
            }
        }
    }
    
    @objc public func setInitialUrl(_ url: URL?) {
        initialUrl = url
        if let url = url {
            if config.debug {
                print("[ULink] Initial URL set: \(url.absoluteString)")
            }
        }
    }
    
    @objc public func getInitialUrl() -> URL? {
        return initialUrl
    }
    
    @objc public func handleIncomingURL(_ url: URL) -> Bool {
        if config.debug {
            print("[ULink] Handling incoming URL: \(url.absoluteString)")
        }
        
        // Check if this is a ULink URL
        guard isULinkUrl(url) else {
            if config.debug {
                print("[ULink] URL is not a ULink URL")
            }
            return false
        }
        
        // Handle the deep link
        handleDeepLink(url: url)
        return true
    }
    
    private func isULinkUrl(_ url: URL) -> Bool {
        // Always return true and let processULinkUrl handle server-side validation
        // This aligns with the Flutter SDK approach for consistency
        return true
    }
    
    public func processULinkUrl(_ url: URL) async -> ULinkResolvedData? {
        do {
            if config.debug {
                print("[ULink] Processing URL: \(url.absoluteString)")
            }
            
            // Always try to resolve the URL with the server to determine if it's a ULink
            if config.debug {
                print("[ULink] Querying server to resolve URL...")
            }
            
            let resolveResponse = try await resolveLink(url: url.absoluteString)
            
            if let responseData = resolveResponse.data,
               let resolvedData = ULinkResolvedData.fromDictionary(responseData) {
                if config.debug {
                    print("[ULink] Successfully resolved ULink data: \(resolvedData.rawData ?? [:])")
                }
                return resolvedData
            } else {
                // URL is not a ULink or resolution failed
                if config.debug {
                    print("[ULink] URL is not a ULink or resolution failed")
                }
                return nil
            }
        } catch {
            if config.debug {
                print("[ULink] Error processing ULink URL: \(error)")
            }
            return nil
        }
    }
    
    public func getInitialDeepLink() async -> ULinkResolvedData? {
        guard let initialUrl = initialUrl else { return nil }
        return await processULinkUrl(initialUrl)
    }
    
    @objc public func getLastLinkData() -> ULinkResolvedData? {
        let data = lastLinkData
        if data != nil && config.clearLastLinkOnRead {
            clearPersistedLastLink()
            lastLinkData = nil
        }
        return data
    }
    
    /**
     * Clears the last resolved link data
     */
    @objc public func clearLastResolvedLink() {
        clearPersistedLastLink()
        lastLinkData = nil
    }
    
    // MARK: - Link Creation
    
    public func createLink(parameters: ULinkParameters) async throws -> ULinkResponse {
        let body = parameters.toJson()
        
        var headers = [
            "X-App-Key": config.apiKey,
            "Content-Type": "application/json",
            "X-ULink-Client": "sdk-ios",
            "X-ULink-Client-Version": ULink.sdkVersion,
            "X-ULink-Client-Platform": "ios"
        ]
        
        // Add installation token if available, otherwise use installation ID
        if let installationToken = getInstallationToken() {
            headers["X-Installation-Token"] = installationToken
        } else if let installationId = installationId {
            headers["X-Installation-Id"] = installationId
        }
        
        // Add device ID if available
        let deviceInfo = DeviceInfoHelper.getDeviceInfo()
        if let deviceId = deviceInfo["deviceId"] as? String {
            headers["X-Device-Id"] = deviceId
        }
        
        do {
            let responseData = try await httpClient.postJson(
                url: "\(config.baseUrl)/sdk/links",
                body: body,
                headers: headers
            )
            
            let response = ULinkResponse.fromJson(responseData)
            
            if response.success {
                // Update session if sessionId is provided in response
                if let sessionId = responseData["sessionId"] as? String {
                    currentSessionId = sessionId
                    sessionState = .active
                }
                return response
            } else {
                let errorMessage = response.error ?? "Unknown error occurred"
                return ULinkResponse.error(message: errorMessage, data: responseData)
            }
        } catch {
            return ULinkResponse.error(message: "Network error: \(error.localizedDescription)")
        }
    }
    
    public func resolveLink(url: String) async throws -> ULinkResponse {
        guard let encodedUrl = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw ULinkError.invalidURL
        }
        
        let resolveUrl = "\(config.baseUrl)/sdk/resolve?url=\(encodedUrl)"
        
        var headers = [
            "X-App-Key": config.apiKey,
            "X-ULink-Client": "sdk-ios",
            "X-ULink-Client-Version": ULink.sdkVersion,
            "X-ULink-Client-Platform": "ios",
            "Content-Type": "application/json"
        ]
        
        // Add installation token if available, otherwise use installation ID
        if let installationToken = getInstallationToken() {
            headers["X-Installation-Token"] = installationToken
        } else if let installationId = installationId {
            headers["X-Installation-Id"] = installationId
        }
        
        // Add device ID if available
        let deviceInfo = DeviceInfoHelper.getDeviceInfo()
        if let deviceId = deviceInfo["deviceId"] as? String {
            headers["X-Device-Id"] = deviceId
        }
        
        do {
            let responseData = try await httpClient.getJson(
                url: resolveUrl,
                headers: headers
            )
            
            let response = ULinkResponse.fromJson(responseData)
            
            // Update session if sessionId is present
            if let sessionId = responseData["sessionId"] as? String {
                currentSessionId = sessionId
                sessionState = .active
            }
            
            return response
        } catch {
            throw error
        }
    }
    
    // MARK: - Session Management
    
    public func startSession(metadata: [String: Any]? = nil) async throws -> ULinkSessionResponse {
        sessionState = .initializing
        
        do {
            // Build session data to match Flutter SDK structure exactly
            let deviceInfo = await DeviceInfoUtils.getCompleteDeviceInfo()
            
            var sessionData: [String: Any] = [
                "installationId": installationId ?? ""
            ]
            
            // Add core device fields (matching bootstrap structure)
            if let deviceId = deviceInfo["deviceId"] as? String {
                sessionData["deviceId"] = deviceId
            }
            if let deviceModel = deviceInfo["deviceModel"] as? String {
                sessionData["deviceModel"] = deviceModel
            }
            if let deviceManufacturer = deviceInfo["deviceManufacturer"] as? String {
                sessionData["deviceManufacturer"] = deviceManufacturer
            }
            if let osName = deviceInfo["osName"] as? String {
                sessionData["osName"] = osName
            }
            if let osVersion = deviceInfo["osVersion"] as? String {
                sessionData["osVersion"] = osVersion
            }
            if let appVersion = deviceInfo["appVersion"] as? String {
                sessionData["appVersion"] = appVersion
            }
            if let appBuild = deviceInfo["appBuild"] as? String {
                sessionData["appBuild"] = appBuild
            }
            if let language = deviceInfo["language"] as? String {
                sessionData["language"] = language
            }
            if let timezone = deviceInfo["timezone"] as? String {
                sessionData["timezone"] = timezone
            }
            
            // Add session-specific fields
            if let networkType = deviceInfo["networkType"] as? String {
                sessionData["networkType"] = networkType
            }
            
            if let deviceOrientation = deviceInfo["deviceOrientation"] as? String {
                sessionData["deviceOrientation"] = deviceOrientation
            }
            
            if let batteryLevel = deviceInfo["batteryLevel"] as? Int {
                sessionData["batteryLevel"] = batteryLevel
            }
            
            if let isCharging = deviceInfo["isCharging"] as? Bool {
                sessionData["isCharging"] = isCharging
            }
            
            // Always include client metadata and device info like Flutter SDK does
            var sessionMetadata: [String: Any] = [
                "client": [
                    "type": "sdk-ios",
                    "version": Self.sdkVersion,
                    "platform": "ios"
                ]
            ]
            
            // Add device info to metadata if not explicitly provided
            if metadata == nil || metadata!["deviceInfo"] == nil {
                // Filter out properties that are already included in the session object
                var filteredDeviceInfo = deviceInfo
            
                if !filteredDeviceInfo.isEmpty {
                    sessionMetadata["deviceInfo"] = filteredDeviceInfo
                }
            }
            
            // Merge any provided metadata
            if let metadata = metadata {
                sessionMetadata.merge(metadata) { (_, new) in new }
            }
            
            sessionData["metadata"] = sessionMetadata
            
            let headers = [
                "Content-Type": "application/json",
                "X-App-Key": config.apiKey,
                "X-ULink-Client": "sdk-ios",
                "X-ULink-Client-Version": Self.sdkVersion,
                "X-ULink-Client-Platform": "ios"
            ]
            
            let response: ULinkSessionResponse = try await httpClient.post(
                url: "\(config.baseUrl)/sdk/sessions/start",
                body: sessionData,
                headers: headers
            )
            
            if response.success, let sessionId = response.sessionId {
                currentSessionId = sessionId
                sessionState = .active
                
                if config.debug {
                    print("[ULink] Session started: \(sessionId)")
                }
                
                // Complete any waiting session continuation
                sessionContinuation?.resume()
                sessionContinuation = nil
                
                return ULinkSessionResponse.success(sessionId)
            } else {
                sessionState = .failed
                sessionContinuation?.resume()
                sessionContinuation = nil
                return ULinkSessionResponse.error(response.error ?? "No session ID in response")
            }
        } catch {
            sessionState = .failed
            sessionContinuation?.resume()
            sessionContinuation = nil
            
            if config.debug {
                print("[ULink] Failed to start session: \(error)")
            }
            
            return ULinkSessionResponse.error(error.localizedDescription)
        }
    }
    
    public func endSession() async -> Bool {
        guard let sessionId = currentSessionId else { return false }
        
        // Set state to ending
        sessionState = .ending
        
        do {
            var headers = [
                "X-App-Key": config.apiKey,
                "Content-Type": "application/json",
                "X-ULink-Client": "sdk-ios",
                "X-ULink-Client-Version": ULink.sdkVersion,
                "X-ULink-Client-Platform": "ios"
            ]
            
            // Add installation ID if available
            if let installationId = installationId {
                headers["X-Installation-Id"] = installationId
            }
            
            // Add device ID if available
            let deviceInfo = DeviceInfoHelper.getDeviceInfo()
            if let deviceId = deviceInfo["deviceId"] as? String {
                headers["X-Device-Id"] = deviceId
            }
            
            let _: ULinkSessionResponse = try await httpClient.post(
                url: "\(config.baseUrl)/sdk/sessions/\(sessionId)/end",
                body: [:],
                headers: headers
            )
            
            currentSessionId = nil
            sessionState = .idle
            
            if config.debug {
                print("[ULink] Session ended: \(sessionId)")
            }
            
            return true
        } catch {
            sessionState = .failed
            
            if config.debug {
                print("[ULink] Failed to end session: \(error)")
            }
            
            return false
        }
    }
    
    @objc public func getCurrentSessionId() -> String? {
        return currentSessionId
    }
    
    @objc public func hasActiveSession() -> Bool {
        return currentSessionId != nil && sessionState == .active
    }
    
    public func getSessionState() -> SessionState {
        return sessionState
    }
    

    
    /// Checks if a session is currently active
    /// - Returns: True if a session is active, false otherwise
    @objc public func isSessionActive() -> Bool {
        return sessionState == .active && currentSessionId != nil
    }
    
    /// Waits for the current session to complete initialization
    /// - Returns: True if session is active, false if failed or timed out
    public func waitForSession(timeout: TimeInterval = 30.0) async -> Bool {
        // If already active, return immediately
        if sessionState == .active {
            return true
        }
        
        // If not initializing, return false
        guard sessionState == .initializing else {
            return false
        }
        
        await withCheckedContinuation { continuation in
            sessionContinuation = continuation
            
            // Set a timeout
            Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                if sessionContinuation != nil {
                    sessionContinuation?.resume()
                    sessionContinuation = nil
                }
            }
        }
        
        return sessionState == .active
    }
    
    @objc public func isSessionInitializing() -> Bool {
        return sessionState == .initializing
    }
    
    // MARK: - Lifecycle Management
    
    private func registerForLifecycleNotifications() {
        #if canImport(UIKit)
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppDidBecomeActive()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.handleAppDidEnterBackground()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)
            .sink { [weak self] _ in
                self?.handleAppWillTerminate()
            }
            .store(in: &cancellables)
        #endif
    }
    
    private func handleAppDidBecomeActive() {
        if sessionState == .idle {
            if config.debug {
                print("[ULink] App became active - starting new session")
            }
            Task {
                do {
                    let response = try await startSession()
                    if config.debug {
                        if response.success {
                            print("[ULink] New session started on app resume: \(currentSessionId ?? "unknown")")
                        } else {
                            print("[ULink] Failed to start session on app resume: \(response.error ?? "unknown error")")
                        }
                    }
                } catch {
                    if config.debug {
                        print("[ULink] Error starting session on app resume: \(error)")
                    }
                }
            }
        }
        
        // Process any pending deep links
        if let initialUrl = initialUrl {
            handleDeepLink(url: initialUrl)
            self.initialUrl = nil // Clear after processing
        }
    }
    
    private func handleAppDidEnterBackground() {
        if hasActiveSession() {
            if config.debug {
                print("[ULink] App entered background - ending session")
            }
            Task {
                let success = await endSession()
                if config.debug {
                    if success {
                        print("[ULink] Session ended on app background")
                    } else {
                        print("[ULink] Failed to end session on app background")
                    }
                }
            }
        }
    }
    
    private func handleAppWillTerminate() {
        // Ensure session is properly ended when app terminates
        if sessionState == .active {
            Task {
                _ = await endSession()
            }
        }
        dispose()
    }
    
    // MARK: - Last Link Data Persistence
    
    private func saveLastLinkData(_ data: ULinkResolvedData) {
        guard config.persistLastLinkData else { return }
        
        do {
            let sanitizedData = sanitizeLastLinkData(data)
            let jsonData = try JSONEncoder().encode(sanitizedData)
            userDefaults.set(jsonData, forKey: Self.keyLastLinkData)
            userDefaults.set(Date().timeIntervalSince1970, forKey: Self.keyLastLinkSavedAt)
            lastLinkData = data
        } catch {
            if config.debug {
                print("[ULink] Error saving last link data: \(error)")
            }
        }
    }
    
    private func sanitizeLastLinkData(_ data: ULinkResolvedData) -> ULinkResolvedData {
        let dropAll = config.redactAllParametersInLastLink
        
        // If dropping all parameters, create a copy without parameters and metadata
        if dropAll {
            return ULinkResolvedData(
                slug: data.slug,
                fallbackUrl: data.fallbackUrl,
                iosUrl: data.iosUrl,
                androidUrl: data.androidUrl,
                parameters: nil,
                metadata: nil,
                type: data.type,
                rawData: data.rawData
            )
        }
        
        // Redact specific keys from parameters and metadata
        let redactedKeys = config.redactedParameterKeysInLastLink
        guard !redactedKeys.isEmpty else { return data }
        
        var sanitizedParameters = data.parameters
        var sanitizedMetadata = data.metadata
        
        // Remove redacted keys from parameters
        if var params = sanitizedParameters {
            for key in redactedKeys {
                params.removeValue(forKey: key)
            }
            sanitizedParameters = params
        }
        
        // Remove redacted keys from metadata
        if var meta = sanitizedMetadata {
            for key in redactedKeys {
                meta.removeValue(forKey: key)
            }
            sanitizedMetadata = meta
        }
        
        return ULinkResolvedData(
            slug: data.slug,
            fallbackUrl: data.fallbackUrl,
            iosUrl: data.iosUrl,
            androidUrl: data.androidUrl,
            parameters: sanitizedParameters,
            metadata: sanitizedMetadata,
            type: data.type,
            rawData: data.rawData
        )
    }
    
    private func loadLastLinkData() {
        guard let jsonData = userDefaults.data(forKey: Self.keyLastLinkData) else { return }
        
        do {
            let data = try JSONDecoder().decode(ULinkResolvedData.self, from: jsonData)
            
            // Check TTL if configured
            if let ttl = config.lastLinkTimeToLive {
                let savedAt = userDefaults.double(forKey: Self.keyLastLinkSavedAt)
                let now = Date().timeIntervalSince1970
                if now - savedAt > ttl {
                    clearPersistedLastLink()
                    return
                }
            }
            
            lastLinkData = data
            
            // Clear on read if configured
            if config.clearLastLinkOnRead {
                clearPersistedLastLink()
            }
        } catch {
            if config.debug {
                print("[ULink] Error loading last link data: \(error)")
            }
        }
    }
    
    private func clearPersistedLastLink() {
        userDefaults.removeObject(forKey: Self.keyLastLinkData)
        userDefaults.removeObject(forKey: Self.keyLastLinkSavedAt)
        
        if config.debug {
            print("[ULink] Cleared persisted last link data")
        }
    }
    
    // MARK: - Cleanup
    
    @objc public func dispose() {
        cancellables.removeAll()
        Task {
            _ = await endSession()
        }
    }
}
