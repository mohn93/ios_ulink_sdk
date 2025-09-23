//
//  ULinkError.swift
//  ULinkSDK
//
//  Created by ULink SDK
//  Copyright © 2024 ULink. All rights reserved.
//

import Foundation

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