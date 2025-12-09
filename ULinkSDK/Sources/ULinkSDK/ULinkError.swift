//
//  ULinkError.swift
//  ULinkSDK
//
//  Created by ULink SDK
//  Copyright © 2024 ULink. All rights reserved.
//

import Foundation

/**
 * Detailed HTTP error information
 */
public struct ULinkHTTPError: Error {
    public let statusCode: Int
    public let responseBody: String?
    public let responseJSON: [String: Any]?
    public let originalError: Error?
    
    public init(statusCode: Int, responseBody: String? = nil, responseJSON: [String: Any]? = nil, originalError: Error? = nil) {
        self.statusCode = statusCode
        self.responseBody = responseBody
        self.responseJSON = responseJSON
        self.originalError = originalError
    }
    
    public var localizedDescription: String {
        var description = "HTTP error occurred (status: \(statusCode))"
        if let responseBody = responseBody, !responseBody.isEmpty {
            description += ". Response: \(responseBody)"
        }
        return description
    }
}

/**
 * Detailed SDK initialization and operation errors (Swift-only, supports associated values)
 */
public enum ULinkInitializationError: Error, LocalizedError {
    /// Bootstrap failed during SDK initialization
    case bootstrapFailed(statusCode: Int, message: String)
    
    /// Deep link resolution failed
    case deepLinkResolutionFailed(message: String)
    
    /// Deferred link check failed
    case deferredLinkFailed(message: String)
    
    /// Last link data loading failed
    case lastLinkDataLoadFailed(message: String)
    
    public var errorDescription: String? {
        switch self {
        case .bootstrapFailed(let statusCode, let message):
            return "Bootstrap failed (status: \(statusCode)): \(message)"
        case .deepLinkResolutionFailed(let message):
            return "Deep link resolution failed: \(message)"
        case .deferredLinkFailed(let message):
            return "Deferred link check failed: \(message)"
        case .lastLinkDataLoadFailed(let message):
            return "Failed to load last link data: \(message)"
        }
    }
    
    public var failureReason: String? {
        return errorDescription
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .bootstrapFailed:
            return "Check your API key, network connection, and server availability. This is essential for SDK operation."
        case .deepLinkResolutionFailed:
            return "Verify the deep link URL is valid and the server is accessible."
        case .deferredLinkFailed:
            return "Check network connectivity. Deferred link matching requires server communication."
        case .lastLinkDataLoadFailed:
            return "Clear app data or check storage permissions. This may indicate corrupted persisted data."
        }
    }
}

// MARK: - ULinkError Convenience Extensions

extension ULinkError {
    /// Creates a bootstrap failed error
    static func bootstrapFailed(statusCode: Int, message: String) -> ULinkInitializationError {
        return .bootstrapFailed(statusCode: statusCode, message: message)
    }
    
    /// Creates a deep link resolution failed error
    static func deepLinkResolutionFailed(message: String) -> ULinkInitializationError {
        return .deepLinkResolutionFailed(message: message)
    }
    
    /// Creates a deferred link failed error
    static func deferredLinkFailed(message: String) -> ULinkInitializationError {
        return .deferredLinkFailed(message: message)
    }
    
    /// Creates a last link data load failed error
    static func lastLinkDataLoadFailed(message: String) -> ULinkInitializationError {
        return .lastLinkDataLoadFailed(message: message)
    }
}

/**
 * Error types for the ULink SDK
 */
@objc public enum ULinkError: Int, Error, CaseIterable {
    /**
     * SDK has not been initialized
     */
    case notInitialized = 1000
    
    /**
     * Invalid configuration provided
     */
    case invalidConfiguration = 1001
    
    /**
     * Network error occurred
     */
    case networkError = 1002
    
    /**
     * Invalid URL provided
     */
    case invalidURL = 1003
    
    /**
     * Invalid response received
     */
    case invalidResponse = 1004
    
    /**
     * HTTP error with status code
     */
    case httpError = 1005
    
    /**
     * Invalid parameters provided
     */
    case invalidParameters = 1006
    
    /**
     * Session error
     */
    case sessionError = 1007
    
    /**
     * Installation tracking error
     */
    case installationError = 1008
    
    /**
     * Link creation error
     */
    case linkCreationError = 1009
    
    /**
     * Link resolution error
     */
    case linkResolutionError = 1010
    
    /**
     * Persistence error
     */
    case persistenceError = 1011
    
    /**
     * Unknown error
     */
    case unknown = 9999
}

// MARK: - ULinkError Extensions

extension ULinkError {
    
    /**
     * Human-readable description of the error
     */
    public var localizedDescription: String {
        switch self {
        case .notInitialized:
            return "ULink SDK has not been initialized. Call ULink.initialize() first."
        case .invalidConfiguration:
            return "Invalid configuration provided to ULink SDK."
        case .networkError:
            return "Network error occurred while communicating with ULink service."
        case .invalidURL:
            return "Invalid URL provided."
        case .invalidResponse:
            return "Invalid response received from ULink service."
        case .httpError:
            return "HTTP error occurred."
        case .invalidParameters:
            return "Invalid parameters provided."
        case .sessionError:
            return "Session management error occurred."
        case .installationError:
            return "Installation tracking error occurred."
        case .linkCreationError:
            return "Error occurred while creating link."
        case .linkResolutionError:
            return "Error occurred while resolving link."
        case .persistenceError:
            return "Data persistence error occurred."
        case .unknown:
            return "An unknown error occurred."
        }
    }
    
    /**
     * Error code as string
     */
    public var code: String {
        return "ULINK_ERROR_\(self.rawValue)"
    }
    
    /**
     * Creates an HTTP error with status code
     */
    public static func httpError(_ statusCode: Int) -> ULinkError {
        return .httpError
    }
}

// MARK: - NSError Bridging

extension ULinkError: LocalizedError {
    public var errorDescription: String? {
        return localizedDescription
    }
    
    public var failureReason: String? {
        return localizedDescription
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .notInitialized:
            return "Initialize the ULink SDK by calling ULink.initialize() with a valid configuration."
        case .invalidConfiguration:
            return "Check your API key and configuration parameters."
        case .networkError:
            return "Check your internet connection and try again."
        case .invalidURL:
            return "Ensure the URL is properly formatted."
        case .invalidResponse:
            return "Contact ULink support if the issue persists."
        case .httpError:
            return "Check the HTTP status code and try again."
        case .invalidParameters:
            return "Review the parameters and ensure they meet the required format."
        case .sessionError:
            return "Restart the session or reinitialize the SDK."
        case .installationError:
            return "Check your configuration and network connection."
        case .linkCreationError:
            return "Review the link parameters and try again."
        case .linkResolutionError:
            return "Ensure the link is valid and accessible."
        case .persistenceError:
            return "Check app permissions and available storage."
        case .unknown:
            return "Contact ULink support with error details."
        }
    }
}