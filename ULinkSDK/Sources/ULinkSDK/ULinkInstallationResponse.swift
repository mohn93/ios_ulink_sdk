//
//  ULinkInstallationResponse.swift
//  ULinkSDK
//
//  Created by ULink SDK
//  Copyright © 2024 ULink. All rights reserved.
//

import Foundation

/**
 * Response structure for installation tracking API calls
 * Mirrors the functionality of Android and Flutter SDKs
 */
@objc public class ULinkInstallationResponse: NSObject, Codable {
    
    // MARK: - Properties
    
    /// Installation token returned from the server
    @objc public let installationToken: String?
    
    /// Session ID returned from the server
    @objc public let sessionId: String?
    
    /// Installation ID that was tracked
    @objc public let installationId: String?
    
    /// Whether this installation was detected as a reinstall
    @objc public let isReinstall: Bool
    
    /// The ID of the previous installation if this is a reinstall
    @objc public let previousInstallationId: String?
    
    /// Timestamp when the reinstall was detected (ISO 8601 format)
    @objc public let reinstallDetectedAt: String?
    
    /// Additional data returned from the server
    @objc public let data: [String: Any]?
    
    /// HTTP status code of the response
    @objc public let statusCode: Int
    
    /// Timestamp when the response was received
    @objc public let timestamp: Date
    
    /// Whether the installation tracking was successful (derived from HTTP status)
    @objc public var success: Bool {
        return statusCode >= 200 && statusCode < 300
    }
    
    // MARK: - Coding Keys
    
    private enum CodingKeys: String, CodingKey {
        case installationToken = "installationToken"
        case sessionId = "sessionId"
        case installationId = "installationId"
        case isReinstall = "isReinstall"
        case previousInstallationId = "previousInstallationId"
        case reinstallDetectedAt = "reinstallDetectedAt"
        case data
        case statusCode = "status_code"
        case timestamp
    }
    
    // MARK: - Initialization
    
    @objc public init(
        installationToken: String? = nil,
        sessionId: String? = nil,
        installationId: String? = nil,
        isReinstall: Bool = false,
        previousInstallationId: String? = nil,
        reinstallDetectedAt: String? = nil,
        data: [String: Any]? = nil,
        statusCode: Int = 200
    ) {
        self.installationToken = installationToken
        self.sessionId = sessionId
        self.installationId = installationId
        self.isReinstall = isReinstall
        self.previousInstallationId = previousInstallationId
        self.reinstallDetectedAt = reinstallDetectedAt
        self.data = data
        self.statusCode = statusCode
        self.timestamp = Date()
        super.init()
    }
    
    // MARK: - Codable Implementation
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        installationToken = try container.decodeIfPresent(String.self, forKey: .installationToken)
        sessionId = try container.decodeIfPresent(String.self, forKey: .sessionId)
        installationId = try container.decodeIfPresent(String.self, forKey: .installationId)
        isReinstall = try container.decodeIfPresent(Bool.self, forKey: .isReinstall) ?? false
        previousInstallationId = try container.decodeIfPresent(String.self, forKey: .previousInstallationId)
        reinstallDetectedAt = try container.decodeIfPresent(String.self, forKey: .reinstallDetectedAt)
        statusCode = try container.decodeIfPresent(Int.self, forKey: .statusCode) ?? 200
        timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp) ?? Date()
        
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
        
        try container.encodeIfPresent(installationToken, forKey: .installationToken)
        try container.encodeIfPresent(sessionId, forKey: .sessionId)
        try container.encodeIfPresent(installationId, forKey: .installationId)
        try container.encode(isReinstall, forKey: .isReinstall)
        try container.encodeIfPresent(previousInstallationId, forKey: .previousInstallationId)
        try container.encodeIfPresent(reinstallDetectedAt, forKey: .reinstallDetectedAt)
        try container.encode(statusCode, forKey: .statusCode)
        try container.encode(timestamp, forKey: .timestamp)
        
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
            "statusCode": statusCode,
            "timestamp": timestamp.timeIntervalSince1970,
            "isReinstall": isReinstall
        ]
        
        if let installationToken = installationToken {
            dict["installationToken"] = installationToken
        }
        
        if let sessionId = sessionId {
            dict["sessionId"] = sessionId
        }
        
        if let installationId = installationId {
            dict["installationId"] = installationId
        }
        
        if let previousInstallationId = previousInstallationId {
            dict["previousInstallationId"] = previousInstallationId
        }
        
        if let reinstallDetectedAt = reinstallDetectedAt {
            dict["reinstallDetectedAt"] = reinstallDetectedAt
        }
        
        if let data = data {
            dict["data"] = data
        }
        
        return dict
    }
    
    /// Create from dictionary
    @objc public static func fromDictionary(_ dict: [String: Any]) -> ULinkInstallationResponse? {
        let installationToken = dict["installationToken"] as? String
        let sessionId = dict["sessionId"] as? String
        let installationId = dict["installationId"] as? String
        let isReinstall = dict["isReinstall"] as? Bool ?? false
        let previousInstallationId = dict["previousInstallationId"] as? String
        let reinstallDetectedAt = dict["reinstallDetectedAt"] as? String
        let data = dict["data"] as? [String: Any]
        let statusCode = dict["statusCode"] as? Int ?? 200
        
        return ULinkInstallationResponse(
            installationToken: installationToken,
            sessionId: sessionId,
            installationId: installationId,
            isReinstall: isReinstall,
            previousInstallationId: previousInstallationId,
            reinstallDetectedAt: reinstallDetectedAt,
            data: data,
            statusCode: statusCode
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