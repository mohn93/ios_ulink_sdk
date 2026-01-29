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
    
    private static let sdkVersion = "1.0.7"
    
    // MARK: - Error Handling Utility
    
    private func handleHTTPError(_ error: Error) -> ULinkResponse {
        if let httpError = error as? ULinkHTTPError {
            // Extract detailed HTTP error information
            var errorData: [String: Any] = [
                "statusCode": httpError.statusCode
            ]
            
            // Use responseJSON if available, otherwise fall back to responseBody
            if let responseJSON = httpError.responseJSON {
                errorData["parsedResponse"] = responseJSON
            } else if let responseBody = httpError.responseBody {
                errorData["responseBody"] = responseBody
                
                // Try to parse JSON response for additional error details
                if let data = responseBody.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    errorData["parsedResponse"] = json
                }
            }
            
            let errorMessage = "HTTP error occurred (status: \(httpError.statusCode))"
            return ULinkResponse.error(message: errorMessage, data: errorData)
        } else {
            return ULinkResponse.error(message: "Network error: \(error.localizedDescription)")
        }
    }
    
    private func handleSessionHTTPError(_ error: Error) -> ULinkSessionResponse {
         if let httpError = error as? ULinkHTTPError {
             logError("Failed to start session: HTTP \(httpError.statusCode)")
             
             // Extract detailed HTTP error information
             var errorMessage = "HTTP error occurred (status: \(httpError.statusCode))"
             
             // Use responseJSON if available, otherwise fall back to responseBody
             var json: [String: Any]? = nil
             if let responseJSON = httpError.responseJSON {
                 json = responseJSON
             } else if let responseBody = httpError.responseBody,
                       let data = responseBody.data(using: .utf8) {
                 json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
             }
             
             if let json = json {
                 // Try to extract backend error message
                 if let backendMessage = json["message"] as? String {
                     errorMessage = "\(backendMessage) (status: \(httpError.statusCode))"
                 } else if let backendError = json["error"] as? String {
                     errorMessage = "\(backendError) (status: \(httpError.statusCode))"
                 }
             }
             
             return ULinkSessionResponse.error(errorMessage)
         } else {
             logError("Failed to start session", error: error)
             return ULinkSessionResponse.error("Network error: \(error.localizedDescription)")
         }
     }
     
     private func handleInstallationHTTPError(_ error: Error) -> ULinkInstallationResponse {
         if let httpError = error as? ULinkHTTPError {
             logError("Failed to track installation: HTTP \(httpError.statusCode)")
             
             // Extract detailed HTTP error information
             var errorData: [String: Any] = [
                 "statusCode": httpError.statusCode
             ]
             
             // Use responseJSON if available, otherwise fall back to responseBody
             var json: [String: Any]? = nil
             if let responseJSON = httpError.responseJSON {
                 json = responseJSON
                 errorData["parsedResponse"] = responseJSON
             } else if let responseBody = httpError.responseBody,
                       let data = responseBody.data(using: .utf8) {
                 errorData["responseBody"] = responseBody
                 json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                 if let json = json {
                     errorData["parsedResponse"] = json
                 }
             }
             
             if let json = json {
                 // Try to extract backend error message
                 if let backendMessage = json["message"] as? String {
                     errorData["errorMessage"] = "\(backendMessage) (status: \(httpError.statusCode))"
                 } else if let backendError = json["error"] as? String {
                     errorData["errorMessage"] = "\(backendError) (status: \(httpError.statusCode))"
                 } else {
                     errorData["errorMessage"] = "HTTP error occurred (status: \(httpError.statusCode))"
                 }
             } else {
                 errorData["errorMessage"] = "HTTP error occurred (status: \(httpError.statusCode))"
             }
             
             return ULinkInstallationResponse(
                 installationToken: nil,
                 sessionId: nil,
                 installationId: nil,
                 data: errorData,
                 statusCode: httpError.statusCode
             )
         } else {
             logError("Failed to track installation", error: error)
             
             let errorData: [String: Any] = [
                 "errorMessage": "Network error: \(error.localizedDescription)",
                 "statusCode": 500
             ]
             
             return ULinkInstallationResponse(
                 installationToken: nil,
                 sessionId: nil,
                 installationId: nil,
                 data: errorData,
                 statusCode: 500
             )
         }
      }
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
    private static var isInitializing = false
    
    /// Actor for thread-safe initialization
    private actor InitializationGuard {
        private var isInitializing = false
        
        func startInitializing() -> Bool {
            if isInitializing { return false }
            isInitializing = true
            return true
        }
        
        func finishInitializing() {
            isInitializing = false
        }
    }
    
    private static let initGuard = InitializationGuard()
    
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
    private var bootstrapCompleted: Bool = false
    private var bootstrapSucceeded: Bool = false
    
    // Reinstall detection
    private var _installationInfo: ULinkInstallationInfo?
    private let _reinstallDetectedSubject = PassthroughSubject<ULinkInstallationInfo, Never>()
    
    /**
     * Publisher that emits when a reinstall is detected during bootstrap.
     * The emitted ULinkInstallationInfo contains details about the reinstall,
     * including the previous installation ID.
     */
    public var onReinstallDetected: AnyPublisher<ULinkInstallationInfo, Never> {
        return _reinstallDetectedSubject.eraseToAnyPublisher()
    }
    
    // Streams for deep link handling
    // Use CurrentValueSubject with replay support to match Android's SharedFlow behavior
    // This ensures events sent before listeners subscribe are not lost
    // The nil value is used to clear the buffer after emitting, allowing only the latest event to be replayed
    private let _dynamicLinkSubject = CurrentValueSubject<ULinkResolvedData?, Never>(nil)
    private let _unifiedLinkSubject = CurrentValueSubject<ULinkResolvedData?, Never>(nil)
    
    public var dynamicLinkStream: AnyPublisher<ULinkResolvedData, Never> {
        return _dynamicLinkSubject
            .compactMap { $0 } // Filter out nil values, only emit actual events
            .eraseToAnyPublisher()
    }
    
    public var unifiedLinkStream: AnyPublisher<ULinkResolvedData, Never> {
        return _unifiedLinkSubject
            .compactMap { $0 } // Filter out nil values, only emit actual events
            .eraseToAnyPublisher()
    }
    
    // Log stream for debugging
    private let _logSubject = PassthroughSubject<ULinkLogEntry, Never>()
    private static let LOG_TAG = "ULink"
    
    /**
     * Publisher that emits log entries from the SDK.
     * Only emits when debug mode is enabled.
     * Use this to capture SDK logs in your app for debugging.
     */
    public var logStream: AnyPublisher<ULinkLogEntry, Never> {
        return _logSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Logging Methods
    
    /**
     * Logs a debug message to both console and the log stream
     */
    private func logDebug(_ message: String, tag: String? = nil) {
        guard config.debug else { return }
        let logTag = tag ?? Self.LOG_TAG
        print("[\(logTag)] DEBUG: \(message)")
        _logSubject.send(ULinkLogEntry.debug(tag: logTag, message: message))
    }
    
    /**
     * Logs an info message to both console and the log stream
     */
    private func logInfo(_ message: String, tag: String? = nil) {
        guard config.debug else { return }
        let logTag = tag ?? Self.LOG_TAG
        print("[\(logTag)] INFO: \(message)")
        _logSubject.send(ULinkLogEntry.info(tag: logTag, message: message))
    }
    
    /**
     * Logs a warning message to both console and the log stream
     */
    private func logWarning(_ message: String, tag: String? = nil) {
        let logTag = tag ?? Self.LOG_TAG
        print("[\(logTag)] WARNING: \(message)")
        if config.debug {
            _logSubject.send(ULinkLogEntry.warning(tag: logTag, message: message))
        }
    }
    
    /**
     * Logs an error message to both console and the log stream
     */
    private func logError(_ message: String, error: Error? = nil, tag: String? = nil) {
        let logTag = tag ?? Self.LOG_TAG
        let fullMessage = error != nil ? "\(message): \(error!.localizedDescription)" : message
        print("[\(logTag)] ERROR: \(fullMessage)")
        if config.debug {
            _logSubject.send(ULinkLogEntry.error(tag: logTag, message: fullMessage))
        }
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
     * 3. Tracks the installation with the server (essential - throws on failure)
     * 4. Registers lifecycle observer for automatic session management
     * 5. Handles initial deep link if `enableDeepLinkIntegration` is enabled (throws on failure)
     * 6. Checks deferred links if `autoCheckDeferredLink` is enabled (throws on failure)
     *
     * Sessions are started automatically during bootstrap.
     *
     * It should be called when your app starts, typically in your AppDelegate's
     * application(_:didFinishLaunchingWithOptions:) method.
     *
     * Example:
     * ```swift
     * func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
     *     Task {
     *         do {
     *             try await ULink.initialize(
     *                 config: ULinkConfig(
     *                     apiKey: "your_api_key",
     *                     baseUrl: "https://api.ulink.ly",
     *                     debug: true
     *                 )
     *             )
     *         } catch {
     *             print("ULink SDK initialization failed: \(error)")
     *         }
     *     }
     *     return true
     * }
     * ```
     *
     * - Parameter config: The SDK configuration
     * - Returns: The initialized ULink instance
     * - Throws: ULinkError if any essential operation fails based on configuration
     */
    public static func initialize(config: ULinkConfig) async throws -> ULink {
        // Fast path: already initialized successfully
        if let instance = _instance, instance.bootstrapSucceeded {
            return instance
        }
        
        // Check if another initialization is in progress
        guard await initGuard.startInitializing() else {
            // Another call is already initializing - wait and return existing instance
            // Poll until initialization completes
            while isInitializing {
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
            if let instance = _instance {
                return instance
            }
            throw ULinkInitializationError.bootstrapFailed(statusCode: 0, message: "Initialization failed")
        }
        
        defer {
            Task { await initGuard.finishInitializing() }
            isInitializing = false
        }
        isInitializing = true
        
        // Double-check after acquiring initialization rights
        if let instance = _instance {
            if instance.bootstrapSucceeded {
                return instance
            }
            
            // Bootstrap failed or didn't complete - retry
            instance.bootstrapCompleted = false
            instance.bootstrapSucceeded = false
            try await instance.setup()
            return instance
        }
        
        // Create new instance
        _instance = ULink(config: config)
        try await _instance?.setup()
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
    
    /// Sets up the SDK with error propagation for essential operations
    /// - Throws: ULinkError for failures in essential operations based on configuration
    private func setup() async throws {
        // Generate or load installation ID
        if installationId == nil {
            generateInstallationId()
        }
        
        // Load installation token
        loadInstallationToken()
        
        // Load last link data - throw if persistence is enabled and loading fails
        if config.persistLastLinkData {
            try loadLastLinkDataThrowing()
        } else {
            loadLastLinkData()
        }
        
        // Log initialization
        logInfo("ULink SDK initialized with API key: \(config.apiKey.prefix(20))...")
        logDebug("Installation ID: \(installationId ?? "nil")")
        logDebug("Installation Token: \(installationToken != nil ? "[LOADED]" : "[NOT FOUND]")")
        logDebug("SDK Version: \(Self.sdkVersion)")
        
        // Register for app lifecycle notifications
        registerForLifecycleNotifications()
        
        // Bootstrap (track installation and start session) - always essential
        try await bootstrap()
        
        // Handle initial URL if automatic deep link integration is enabled
        if config.enableDeepLinkIntegration {
            if let initialUrl = initialUrl {
                // Await and throw if deep link integration is enabled
                try await handleDeepLinkAsync(url: initialUrl)
            }
        } else if initialUrl != nil {
            logDebug("Deep link integration disabled - initial URL will be ignored until handled manually")
        }
        
        // Check for deferred links after bootstrap completes (if enabled in config)
        // Launch in background Task (don't await) to match Android behavior
        // This ensures listeners can be set up before deferred link is processed
        if config.autoCheckDeferredLink {
            Task {
                do {
            try await checkDeferredLinkAsync()
                } catch {
                    logError("Deferred link check failed", error: error)
                    // Don't throw - deferred link check is not critical for initialization
                }
            }
        }
    }
    
    // MARK: - Installation Management
    
    @objc public func getInstallationId() -> String? {
        return installationId
    }
    
    /**
     * Gets the current installation info including reinstall detection data.
     *
     * If this is a reinstall, the returned object will have isReinstall=true
     * and previousInstallationId will contain the ID of the previous installation.
     *
     * - Returns: ULinkInstallationInfo or nil if bootstrap hasn't completed
     */
    public func getInstallationInfo() -> ULinkInstallationInfo? {
        return _installationInfo
    }
    
    /**
     * Checks if the current installation is a reinstall.
     *
     * - Returns: true if this installation was detected as a reinstall
     */
    @objc public func isReinstall() -> Bool {
        return _installationInfo?.isReinstall ?? false
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
    
    /// Bootstrap the SDK by tracking installation and starting a session.
    /// - Throws: ULinkError if bootstrap fails (essential for SDK operation)
    private func bootstrap() async throws {
        logDebug("Starting bootstrap...")
        
        let response = try await trackInstallationThrowing()
        
        logDebug("Bootstrap response received - success: \(response.success), statusCode: \(response.statusCode)")
        logDebug("Bootstrap response - installationToken: \(response.installationToken != nil ? "[RECEIVED]" : "nil")")
        logDebug("Bootstrap response - sessionId: \(response.sessionId ?? "nil")")
        logDebug("Bootstrap response - isReinstall: \(response.isReinstall)")
        
        guard response.success else {
            let errorMessage = "Bootstrap failed with status code: \(response.statusCode)"
            logError(errorMessage)
            bootstrapSucceeded = false
            bootstrapCompleted = true
            throw ULinkInitializationError.bootstrapFailed(statusCode: response.statusCode, message: errorMessage)
        }
        
            if let token = response.installationToken {
                saveInstallationToken(token)
                logDebug("Installation token saved")
            }
            
            // Save session ID if returned from bootstrap
            if let sessionId = response.sessionId {
                currentSessionId = sessionId
                sessionState = .active
                logInfo("Bootstrap session started: \(sessionId)")
            } else {
                logWarning("Bootstrap succeeded but no sessionId returned - session state remains idle")
            }
            
            // Parse and store installation info (including reinstall detection)
            if let currentInstallationId = installationId {
                let persistentDeviceId = DeviceInfoHelper.getPersistentDeviceId()
                
                // Create installation info from the response
                let info = ULinkInstallationInfo(
                    installationId: currentInstallationId,
                    isReinstall: response.isReinstall,
                    previousInstallationId: response.previousInstallationId,
                    reinstallDetectedAt: response.reinstallDetectedAt,
                    persistentDeviceId: persistentDeviceId
                )
                
                _installationInfo = info
                
                // Emit reinstall event if detected
                if info.isReinstall {
                    logInfo("Reinstall detected! Previous installation: \(info.previousInstallationId ?? "unknown")")
                    _reinstallDetectedSubject.send(info)
                    logDebug("Installation info: isReinstall=true, previousInstallationId=\(info.previousInstallationId ?? "nil")")
                }
            }
            
            logInfo("Bootstrap completed successfully")
            bootstrapSucceeded = true
        bootstrapCompleted = true
        logDebug("Bootstrap completed - sessionState: \(sessionState), bootstrapSucceeded: \(bootstrapSucceeded)")
    }
    
    /// Non-throwing version of bootstrap for lifecycle retry scenarios
    private func bootstrapSilent() async {
        do {
            try await bootstrap()
        } catch {
            logError("Bootstrap error (silent)", error: error)
            bootstrapSucceeded = false
            bootstrapCompleted = true
        }
    }
    
    // MARK: - Bootstrap Guard
    
    /// Ensures bootstrap has completed successfully before allowing SDK operations.
    /// Call this at the start of any method that requires the SDK to be fully initialized.
    /// - Throws: ULinkInitializationError if bootstrap hasn't completed or failed
    private func ensureBootstrapCompleted() throws {
        guard bootstrapCompleted else {
            logError("SDK method called before initialization complete")
            throw ULinkInitializationError.bootstrapFailed(
                statusCode: 0,
                message: "SDK initialization not complete. Ensure initialize() completes successfully before calling SDK methods."
            )
        }
        
        guard bootstrapSucceeded else {
            logError("SDK method called after initialization failed")
            throw ULinkInitializationError.bootstrapFailed(
                statusCode: 0,
                message: "SDK initialization failed. Check the error from initialize() method and retry initialization."
            )
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
        
        // Persistent device ID for reinstall detection (survives app reinstalls via Keychain)
        if let persistentDeviceId = DeviceInfoHelper.getPersistentDeviceId() {
            bootstrapData["persistentDeviceId"] = persistentDeviceId
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
    
    /// Tracks installation with error propagation for essential bootstrap flow
    /// - Throws: Error if the HTTP request fails or returns non-success status
    private func trackInstallationThrowing() async throws -> ULinkInstallationResponse {
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
        
        let response: ULinkInstallationResponse = try await httpClient.post(
            url: "\(config.baseUrl)/sdk/bootstrap",
            body: body,
            headers: headers
        )
        
            return response
    }
    
    private func trackInstallation() async -> ULinkInstallationResponse {
        do {
            return try await trackInstallationThrowing()
        } catch {
            return handleInstallationHTTPError(error)
        }
    }
    
    // MARK: - Deep Link Handling
    
    /// Handles a deep link (fire-and-forget version for backward compatibility)
    @objc public func handleDeepLink(url: URL, isDeferred: Bool = false, matchType: String? = nil) {
        Task {
            do {
                try await handleDeepLinkAsync(url: url, isDeferred: isDeferred, matchType: matchType)
            } catch {
                logError("Failed to handle deep link", error: error)
            }
        }
    }
    
    /// Handles a deep link with async/await support
    /// - Parameters:
    ///   - url: The deep link URL to handle
    ///   - isDeferred: Whether this is a deferred deep link
    ///   - matchType: The match type for deferred links
    /// - Throws: ULinkError if the deep link resolution fails
    public func handleDeepLinkAsync(url: URL, isDeferred: Bool = false, matchType: String? = nil) async throws {
        logDebug("Handling deep link: \(url.absoluteString) (isDeferred: \(isDeferred), matchType: \(matchType ?? "nil"))")
        
        guard var resolvedData = try await processULinkUrlThrowing(url) else {
            logDebug("URL is not a ULink or resolution returned nil")
            return
        }
        
        // Inject isDeferred and matchType if this came from deferred deep linking
        if isDeferred {
            resolvedData = ULinkResolvedData(
                slug: resolvedData.slug,
                iosFallbackUrl: resolvedData.iosFallbackUrl,
                androidFallbackUrl: resolvedData.androidFallbackUrl,
                fallbackUrl: resolvedData.fallbackUrl,
                iosUrl: resolvedData.iosUrl,
                androidUrl: resolvedData.androidUrl,
                parameters: resolvedData.parameters,
                socialMediaTags: resolvedData.socialMediaTags,
                metadata: resolvedData.metadata,
                type: resolvedData.type,
                isDeferred: true,
                matchType: matchType,
                resolvedAt: resolvedData.resolvedAt,
                rawData: resolvedData.rawData
            )
        }
        
        // Determine link type and emit to appropriate stream
        // CurrentValueSubject stores the value, allowing new subscribers to receive it
        // The value is kept until the next event overwrites it (replay of latest event)
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
    
    @objc public func setInitialUrl(_ url: URL?) {
        initialUrl = url
        if let url = url {
            logDebug("Initial URL set: \(url.absoluteString)")
        }
    }
    
    @objc public func getInitialUrl() -> URL? {
        return initialUrl
    }
    
    @objc public func handleIncomingURL(_ url: URL) -> Bool {
        logDebug("Handling incoming URL: \(url.absoluteString)")
        
        // Handle the deep link
        handleDeepLink(url: url)
        return true
    }
    
  
    
    public func processULinkUrl(_ url: URL) async -> ULinkResolvedData? {
        do {
            return try await processULinkUrlThrowing(url)
        } catch {
            logError("Error processing ULink URL", error: error)
            return nil
        }
    }
    
    /// Processes a ULink URL with error propagation
    /// - Parameter url: The URL to process
    /// - Returns: Resolved data if successful, nil if URL is not a ULink
    /// - Throws: Error if the resolution request fails
    public func processULinkUrlThrowing(_ url: URL) async throws -> ULinkResolvedData? {
            logDebug("Processing URL: \(url.absoluteString)")
            logDebug("Querying server to resolve URL...")
            
            let resolveResponse = try await resolveLink(url: url.absoluteString)
            
            // Check if the response was successful before processing data
            if !resolveResponse.success {
            let errorMessage = resolveResponse.error ?? "Unknown error"
            logWarning("Server returned error: \(errorMessage)")
            throw ULinkInitializationError.deepLinkResolutionFailed(message: errorMessage)
            }
            
            if let responseData = resolveResponse.data,
               let resolvedData = ULinkResolvedData.fromDictionary(responseData) {
                logInfo("Successfully resolved ULink data")
                logDebug("Resolved data: \(resolvedData.rawData ?? [:])")
                return resolvedData
            } else {
                logDebug("URL is not a ULink or resolution failed")
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
    
    // MARK: - Link Creation
    
    public func createLink(parameters: ULinkParameters) async throws -> ULinkResponse {
        // Ensure SDK is fully initialized before creating links
        try ensureBootstrapCompleted()
        
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
                // Return error response with detailed information
                return response
            }
        } catch let httpError as ULinkHTTPError {
            // Extract detailed HTTP error information
            var errorData: [String: Any] = [
                "statusCode": httpError.statusCode
            ]
            
            // Use responseJSON if available, otherwise fall back to responseBody
            if let responseJSON = httpError.responseJSON {
                errorData.merge(responseJSON) { (_, new) in new }
            } else if let responseBody = httpError.responseBody {
                errorData["responseBody"] = responseBody
                
                // Try to parse JSON response for additional error details
                if let data = responseBody.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    errorData.merge(json) { (_, new) in new }
                }
            }
            
            // Build error message similar to Android format: "HTTP 400: {json_response}"
            var errorMessage = "HTTP \(httpError.statusCode)"
            if let responseBody = httpError.responseBody {
                // Use raw response body if available (matches Android format)
                errorMessage += ": \(responseBody)"
            } else if let responseJSON = httpError.responseJSON {
                // Serialize JSON back to string to match Android format
                if let jsonData = try? JSONSerialization.data(withJSONObject: responseJSON, options: []),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    errorMessage += ": \(jsonString)"
                } else {
                    // Fallback: try to extract message or error field
                    if let message = responseJSON["message"] as? String {
                        errorMessage += ": \(message)"
                    } else if let error = responseJSON["error"] as? String {
                        errorMessage += ": \(error)"
                    }
                }
            }
            
            return ULinkResponse.error(message: errorMessage, data: errorData)
        } catch let ulinkError as ULinkError {
            // For other ULinkError instances, return error response
            return ULinkResponse.error(message: ulinkError.localizedDescription, data: nil)
        } catch {
            // Handle other errors
            return ULinkResponse.error(message: "Network error: \(error.localizedDescription)", data: nil)
        }
    }
    
    public func resolveLink(url: String) async throws -> ULinkResponse {
        // Ensure SDK is fully initialized before resolving links
        try ensureBootstrapCompleted()
        
        guard let encodedUrl = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return ULinkResponse.error(message: "Invalid URL provided", data: nil)
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
            
            // If the response indicates failure, return error response with details
            if !response.success {
                return response
            }
            
            return response
        } catch let httpError as ULinkHTTPError {
            // Extract detailed HTTP error information
            var errorData: [String: Any] = [
                "statusCode": httpError.statusCode
            ]
            
            // Use responseJSON if available, otherwise fall back to responseBody
            if let responseJSON = httpError.responseJSON {
                errorData.merge(responseJSON) { (_, new) in new }
            } else if let responseBody = httpError.responseBody {
                errorData["responseBody"] = responseBody
                
                // Try to parse JSON response for additional error details
                if let data = responseBody.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    errorData.merge(json) { (_, new) in new }
                }
            }
            
            // Build error message similar to Android format: "HTTP 400: {json_response}"
            var errorMessage = "HTTP \(httpError.statusCode)"
            if let responseBody = httpError.responseBody {
                // Use raw response body if available (matches Android format)
                errorMessage += ": \(responseBody)"
            } else if let responseJSON = httpError.responseJSON {
                // Serialize JSON back to string to match Android format
                if let jsonData = try? JSONSerialization.data(withJSONObject: responseJSON, options: []),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    errorMessage += ": \(jsonString)"
                } else {
                    // Fallback: try to extract message or error field
                    if let message = responseJSON["message"] as? String {
                        errorMessage += ": \(message)"
                    } else if let error = responseJSON["error"] as? String {
                        errorMessage += ": \(error)"
                    }
                }
            }
            
            return ULinkResponse.error(message: errorMessage, data: errorData)
        } catch let ulinkError as ULinkError {
            // For other ULinkError instances, return error response
            return ULinkResponse.error(message: ulinkError.localizedDescription, data: nil)
        } catch {
            // Handle other errors
            return ULinkResponse.error(message: "Network error: \(error.localizedDescription)", data: nil)
        }
    }
    
    // MARK: - Session Management
    
    private func startSession(metadata: [String: Any]? = nil) async throws -> ULinkSessionResponse {
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
                let filteredDeviceInfo = deviceInfo
            
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
                logInfo("Session started: \(sessionId)")
                
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
            
            return handleSessionHTTPError(error)
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
            logInfo("Session ended: \(sessionId)")
            
            return true
        } catch {
            sessionState = .failed
            logError("Failed to end session", error: error)
            
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
    
    /// Waits for the current session to complete initialization
    /// - Returns: True if session is active, false if failed or timed out
    private func waitForSession(timeout: TimeInterval = 30.0) async -> Bool {
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
        logDebug("App became active - sessionState: \(sessionState), bootstrapCompleted: \(bootstrapCompleted), bootstrapSucceeded: \(bootstrapSucceeded)")
        
        // If bootstrap hasn't completed yet, skip (it will finish on its own)
        guard bootstrapCompleted else {
            logDebug("App became active but bootstrap not yet completed - skipping")
            return
        }
        
        // If session is already active, nothing to do
        if sessionState == .active {
            logDebug("App became active with active session - nothing to do")
            return
        }
        
        // If bootstrap failed previously (e.g., due to network permission dialog), retry it
        // Bootstrap returns a sessionId, so we don't need a separate startSession call
        // Use silent version for lifecycle retry to avoid crashing the app
        if !bootstrapSucceeded || sessionState == .idle || sessionState == .failed {
            logInfo("App became active - retrying bootstrap (previous bootstrapSucceeded: \(bootstrapSucceeded), sessionState: \(sessionState))")
            Task {
                // Reset state before retrying
                sessionState = .idle
                bootstrapSucceeded = false
                
                // Use silent version for lifecycle retry (errors are logged but not thrown)
                await bootstrapSilent()
                
                    logDebug("Bootstrap retry completed - sessionState: \(sessionState), bootstrapSucceeded: \(bootstrapSucceeded)")
            }
        }
        
        // Process any pending deep links when automatic integration is enabled
        if config.enableDeepLinkIntegration {
            if let initialUrl = initialUrl {
                handleDeepLink(url: initialUrl)
                self.initialUrl = nil // Clear after processing
            }
        } else if initialUrl != nil {
            logDebug("Deep link integration disabled - pending initial URL will not be processed automatically")
        }
    }
    
    private func handleAppDidEnterBackground() {
        if hasActiveSession() {
            logDebug("App entered background - ending session")
            Task {
                let success = await endSession()
                if success {
                    logInfo("Session ended on app background")
                } else {
                    logWarning("Failed to end session on app background")
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
            logError("Error saving last link data", error: error)
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
    
    /// Loads persisted last link data (non-throwing version for backward compatibility)
    private func loadLastLinkData() {
        do {
            try loadLastLinkDataThrowing()
        } catch {
            logError("Error loading last link data", error: error)
        }
    }
    
    /// Loads persisted last link data with error propagation
    /// - Throws: ULinkError if loading fails and persistLastLinkData is enabled
    private func loadLastLinkDataThrowing() throws {
        guard let jsonData = userDefaults.data(forKey: Self.keyLastLinkData) else { return }
        
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
    }
    
    private func clearPersistedLastLink() {
        userDefaults.removeObject(forKey: Self.keyLastLinkData)
        userDefaults.removeObject(forKey: Self.keyLastLinkSavedAt)
        logDebug("Cleared persisted last link data")
    }
    
    // MARK: - Cleanup
    
    @objc public func dispose() {
        cancellables.removeAll()
        Task {
            _ = await endSession()
        }
    }
    /// Checks for deferred deep links (fire-and-forget version for backward compatibility)
    @objc public func checkDeferredLink() {
        Task {
            do {
                try await checkDeferredLinkAsync()
            } catch {
                logError("Deferred link check failed", error: error)
            }
        }
    }
    
    /// Checks for deferred deep links with async/await support
    /// - Throws: ULinkError if the deferred link check fails when autoCheckDeferredLink is enabled
    public func checkDeferredLinkAsync() async throws {
        // Ensure SDK is fully initialized before checking deferred links
        try ensureBootstrapCompleted()
        
        #if canImport(UIKit)
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "ulink_deferred_checked") {
            logDebug("Deferred link check skipped: already checked")
            return
        }
        
        logDebug("Checking for deferred link...")
        
        // Collect fingerprint (must be done on main actor for UIKit access)
        let fingerprint: [String: Any] = await MainActor.run {
            var fp: [String: Any] = [
            "os": "ios",
            "model": UIDevice.current.model,
            "name": UIDevice.current.name,
            "systemName": UIDevice.current.systemName,
            "systemVersion": UIDevice.current.systemVersion
        ]
        
        if let identifier = UIDevice.current.identifierForVendor?.uuidString {
                fp["identifierForVendor"] = identifier
        }
        
        // Screen Resolution
        let screen = UIScreen.main
        let width = Int(screen.bounds.width)
        let height = Int(screen.bounds.height)
            fp["screenResolution"] = "\(width)x\(height)"
        
        // Timezone
            fp["timezone"] = TimeZone.current.identifier
        
        // Language
        if let language = Locale.preferredLanguages.first {
                fp["language"] = language.replacingOccurrences(of: "_", with: "-")
        } else {
                fp["language"] = Locale.current.identifier.replacingOccurrences(of: "_", with: "-")
            }
            
            return fp
        }
        
        logDebug("Deferred link fingerprint: \(fingerprint)")
        
        // Call API using async/await
        let urlString = "\(config.baseUrl)/sdk/deferred/match"
        guard let url = URL(string: urlString) else {
            throw ULinkInitializationError.deferredLinkFailed(message: "Invalid deferred link URL: \(urlString)")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.apiKey, forHTTPHeaderField: "X-App-Key")
        
        var body: [String: Any] = ["fingerprint": fingerprint]
        
        // Include installation ID for attribution
        if let installationId = self.installationId {
            body["installationId"] = installationId
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ULinkInitializationError.deferredLinkFailed(message: "Invalid response from deferred link API")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ULinkInitializationError.deferredLinkFailed(message: "Deferred link API returned status \(httpResponse.statusCode)")
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ULinkInitializationError.deferredLinkFailed(message: "Failed to parse deferred link response")
        }
        
        logDebug("Deferred link response: \(json)")
        
        // Check success flag
        let isSuccess = json["success"] as? Bool ?? false
        
        if isSuccess,
           let dataDict = json["data"] as? [String: Any] {
            
            let matchType = json["matchType"] as? String
            
            if let deepLink = dataDict["deepLink"] as? String {
                // Handle the deep link
                logInfo("Matched deferred link: \(deepLink) (matchType: \(matchType ?? "nil"))")
                
                // If we have a deep link, we should process it with deferred flag
                if let linkUrl = URL(string: deepLink) {
                    try await handleDeepLinkAsync(url: linkUrl, isDeferred: true, matchType: matchType)
                }
            } else {
                logDebug("Deferred link matched but no deepLink found in data")
            }
        } else {
            logDebug("No deferred link matched")
        }
        
        defaults.set(true, forKey: "ulink_deferred_checked")
        #else
        logDebug("Deferred link check skipped: UIKit not available")
        #endif
    }
}
