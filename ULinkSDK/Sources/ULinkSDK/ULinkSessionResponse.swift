//
//  ULinkSessionResponse.swift
//  ULinkSDK
//
//  Created by ULink SDK
//  Copyright © 2024 ULink. All rights reserved.
//

import Foundation

/**
 * Response structure for session management API calls
 * Mirrors the functionality of Android and Flutter SDKs
 */
@objc public class ULinkSessionResponse: NSObject, Codable {
    
    // MARK: - Properties
    
    /// Whether the session operation was successful
    @objc public let success: Bool
    
    /// Session ID returned from the server
    @objc public let sessionId: String?
    
    /// Installation ID associated with the session
    @objc public let installationId: String?
    
    /// Session start timestamp
    @objc public let startedAt: Date?
    
    /// Session end timestamp (for end session responses)
    @objc public let endedAt: Date?
    
    /// Session duration in seconds (for end session responses)
    @objc public let duration: TimeInterval
    
    /// Error message if the request failed
    @objc public let error: String?
    
    /// Additional session data returned from the server
    public let data: [String: Any]?
    
    /// HTTP status code of the response
    @objc public let statusCode: Int
    
    /// Timestamp when the response was received
    @objc public let timestamp: Date
    
    // MARK: - Coding Keys
    
    private enum CodingKeys: String, CodingKey {
        case success
        case sessionId = "sessionId"
        case installationId = "installation_id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case duration
        case error
        case data
        case statusCode = "status_code"
        case timestamp
    }
    
    // MARK: - Initialization
    
    public init(
        success: Bool,
        sessionId: String? = nil,
        installationId: String? = nil,
        startedAt: Date? = nil,
        endedAt: Date? = nil,
        duration: TimeInterval = 0,
        error: String? = nil,
        data: [String: Any]? = nil,
        statusCode: Int = 200
    ) {
        self.success = success
        self.sessionId = sessionId
        self.installationId = installationId
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.duration = duration
        self.error = error
        self.data = data
        self.statusCode = statusCode
        self.timestamp = Date()
        super.init()
    }
    
    // MARK: - Codable Implementation
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        success = try container.decode(Bool.self, forKey: .success)
        sessionId = try container.decodeIfPresent(String.self, forKey: .sessionId)
        installationId = try container.decodeIfPresent(String.self, forKey: .installationId)
        duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration) ?? 0
        error = try container.decodeIfPresent(String.self, forKey: .error)
        statusCode = try container.decodeIfPresent(Int.self, forKey: .statusCode) ?? 200
        timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp) ?? Date()
        
        // Handle date decoding
        if let startedAtString = try container.decodeIfPresent(String.self, forKey: .startedAt) {
            startedAt = ISO8601DateFormatter().date(from: startedAtString)
        } else {
            startedAt = nil
        }
        
        if let endedAtString = try container.decodeIfPresent(String.self, forKey: .endedAt) {
            endedAt = ISO8601DateFormatter().date(from: endedAtString)
        } else {
            endedAt = nil
        }
        
        // Handle data as optional dictionary
        if let dataContainer = try? container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: .data) {
            var dataDict: [String: Any] = [:]
            for key in dataContainer.allKeys {
                if let value = try? dataContainer.decode(String.self, forKey: key) {
                    dataDict[key.stringValue] = value
                } else if let value = try? dataContainer.decode(Int.self, forKey: key) {
                    dataDict[key.stringValue] = value
                } else if let value = try? dataContainer.decode(Double.self, forKey: key) {
                    dataDict[key.stringValue] = value
                } else if let value = try? dataContainer.decode(Bool.self, forKey: key) {
                    dataDict[key.stringValue] = value
                }
            }
            data = dataDict.isEmpty ? nil : dataDict
        } else {
            data = nil
        }
        
        super.init()
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(success, forKey: .success)
        try container.encodeIfPresent(sessionId, forKey: .sessionId)
        try container.encodeIfPresent(installationId, forKey: .installationId)
        try container.encode(duration, forKey: .duration)
        try container.encodeIfPresent(error, forKey: .error)
        try container.encode(statusCode, forKey: .statusCode)
        try container.encode(timestamp, forKey: .timestamp)
        
        // Handle date encoding
        if let startedAt = startedAt {
            try container.encode(ISO8601DateFormatter().string(from: startedAt), forKey: .startedAt)
        }
        
        if let endedAt = endedAt {
            try container.encode(ISO8601DateFormatter().string(from: endedAt), forKey: .endedAt)
        }
        
        // Handle data encoding
        if let data = data {
            var dataContainer = container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: .data)
            for (key, value) in data {
                let codingKey = DynamicCodingKey(stringValue: key)!
                if let stringValue = value as? String {
                    try dataContainer.encode(stringValue, forKey: codingKey)
                } else if let intValue = value as? Int {
                    try dataContainer.encode(intValue, forKey: codingKey)
                } else if let doubleValue = value as? Double {
                    try dataContainer.encode(doubleValue, forKey: codingKey)
                } else if let boolValue = value as? Bool {
                    try dataContainer.encode(boolValue, forKey: codingKey)
                }
            }
        }
    }
    
    // MARK: - Convenience Methods
    
    /// Convert to dictionary representation
    @objc public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "success": success,
            "duration": duration,
            "statusCode": statusCode,
            "timestamp": timestamp.timeIntervalSince1970
        ]
        
        if let sessionId = sessionId {
            dict["sessionId"] = sessionId
        }
        
        if let installationId = installationId {
            dict["installationId"] = installationId
        }
        
        if let startedAt = startedAt {
            dict["startedAt"] = startedAt.timeIntervalSince1970
        }
        
        if let endedAt = endedAt {
            dict["endedAt"] = endedAt.timeIntervalSince1970
        }
        
        if let error = error {
            dict["error"] = error
        }
        
        if let data = data {
            dict["data"] = data
        }
        
        return dict
    }
    
    /// Create from dictionary
    @objc public static func fromDictionary(_ dict: [String: Any]) -> ULinkSessionResponse? {
        guard let success = dict["success"] as? Bool else { return nil }
        
        let sessionId = dict["sessionId"] as? String
        let installationId = dict["installationId"] as? String
        let duration = dict["duration"] as? TimeInterval ?? 0
        let error = dict["error"] as? String
        let data = dict["data"] as? [String: Any]
        let statusCode = dict["statusCode"] as? Int ?? 200
        
        var startedAt: Date?
        if let startedAtTimestamp = dict["startedAt"] as? TimeInterval {
            startedAt = Date(timeIntervalSince1970: startedAtTimestamp)
        }
        
        var endedAt: Date?
        if let endedAtTimestamp = dict["endedAt"] as? TimeInterval {
            endedAt = Date(timeIntervalSince1970: endedAtTimestamp)
        }
        
        return ULinkSessionResponse(
            success: success,
            sessionId: sessionId,
            installationId: installationId,
            startedAt: startedAt,
            endedAt: endedAt,
            duration: duration,
            error: error,
            data: data,
            statusCode: statusCode
        )
    }
    
    // MARK: - Factory Methods
    
    /// Creates a successful session response
    /// - Parameter sessionId: The session ID returned from the server
    /// - Returns: A successful ULinkSessionResponse instance
    @objc public static func success(_ sessionId: String) -> ULinkSessionResponse {
        return ULinkSessionResponse(
            success: true,
            sessionId: sessionId,
            startedAt: Date(),
            statusCode: 200
        )
    }
    
    /// Creates an error session response
    /// - Parameter errorMessage: The error message describing what went wrong
    /// - Returns: A failed ULinkSessionResponse instance
    @objc public static func error(_ errorMessage: String) -> ULinkSessionResponse {
        return ULinkSessionResponse(
            success: false,
            error: errorMessage,
            statusCode: 400
        )
    }
}

// MARK: - Dynamic Coding Key

private struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}