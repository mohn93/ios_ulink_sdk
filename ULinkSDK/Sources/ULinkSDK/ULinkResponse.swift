//
//  ULinkResponse.swift
//  ULinkSDK
//
//  Created by ULink SDK
//  Copyright © 2024 ULink. All rights reserved.
//

import Foundation

/**
 * Response from ULink API for link creation
 */
@objc public class ULinkResponse: NSObject {
    
    /**
     * Whether the request was successful
     */
    @objc public let success: Bool
    
    /**
     * The generated short URL (if successful)
     */
    @objc public let url: String?
    
    /**
     * Error message (if unsuccessful)
     */
    @objc public let error: String?
    
    /**
     * Additional data from the response
     */
    @objc public let data: [String: Any]?
    
    /**
     * Creates a new ULinkResponse instance
     */
    @objc public init(
        success: Bool,
        url: String? = nil,
        error: String? = nil,
        data: [String: Any]? = nil
    ) {
        self.success = success
        self.url = url
        self.error = error
        self.data = data
        super.init()
    }
    
    /**
     * Creates a successful response
     */
    @objc public static func success(url: String, data: [String: Any]? = nil) -> ULinkResponse {
        return ULinkResponse(
            success: true,
            url: url,
            data: data
        )
    }
    
    /**
     * Creates an error response
     */
    @objc public static func error(message: String, data: [String: Any]? = nil) -> ULinkResponse {
        return ULinkResponse(
            success: false,
            error: message,
            data: data
        )
    }
    
    /**
     * Creates ULinkResponse from JSON dictionary
     */
    @objc public static func fromJson(_ json: [String: Any]) -> ULinkResponse {
        // Check for explicit success field first
        if let explicitSuccess = json["success"] as? Bool {
            let url = json["url"] as? String
            let error = json["error"] as? String
            
            return ULinkResponse(
                success: explicitSuccess,
                url: url,
                error: error,
                data: json
            )
        }
        
        // If no explicit success field, determine success based on response content
        let error = json["error"] as? String
        if error != nil {
            // Has error field, treat as failure
            return ULinkResponse(
                success: false,
                url: nil,
                error: error,
                data: json
            )
        }
        
        // Check for successful link creation indicators
        let shortUrl = json["shortUrl"] as? String
        let id = json["id"] as? String
        
        if shortUrl != nil || id != nil {
            // Has shortUrl or id, treat as successful link creation
            return ULinkResponse(
                success: true,
                url: shortUrl,
                error: nil,
                data: json
            )
        }
        
        // Default to failure if we can't determine success
        return ULinkResponse(
            success: false,
            url: nil,
            error: "Unknown error occurred",
            data: json
        )
    }
    
    /**
     * Converts the response to a JSON dictionary
     */
    @objc public func toJson() -> [String: Any] {
        var json: [String: Any] = [
            "success": success
        ]
        
        if let url = url {
            json["url"] = url
        }
        
        if let error = error {
            json["error"] = error
        }
        
        if let data = data {
            json["data"] = data
        }
        
        return json
    }
    
    /**
     * Returns a string representation of the response
     */
    public override var description: String {
        return "ULinkResponse(success: \(success), url: \(url ?? "nil"), error: \(error ?? "nil"))"
    }
    

}