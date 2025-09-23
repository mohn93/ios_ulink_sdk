//
//  ULinkInstallation.swift
//  ULinkSDK
//
//  Created by ULink SDK
//  Copyright © 2024 ULink. All rights reserved.
//

import Foundation

/**
 * Installation data for tracking app installations
 */
@objc public class ULinkInstallation: NSObject, Codable {
    
    /**
     * Unique installation ID
     */
    @objc public let installationId: String
    
    /**
     * Installation token for authentication
     */
    @objc public let installationToken: String
    
    /**
     * Timestamp when the installation was created
     */
    @objc public let createdAt: Date
    
    /**
     * Timestamp when the installation was last updated
     */
    @objc public let updatedAt: Date
    
    /**
     * Device information associated with this installation
     */
    @objc public let deviceInfo: [String: Any]?
    
    /**
     * App information associated with this installation
     */
    @objc public let appInfo: [String: Any]?
    
    /**
     * Creates a new ULinkInstallation instance
     */
    @objc public init(
        installationId: String,
        installationToken: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deviceInfo: [String: Any]? = nil,
        appInfo: [String: Any]? = nil
    ) {
        self.installationId = installationId
        self.installationToken = installationToken
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deviceInfo = deviceInfo
        self.appInfo = appInfo
        super.init()
    }
    
    /**
     * Creates ULinkInstallation from JSON dictionary
     */
    @objc public static func fromJson(_ json: [String: Any]) -> ULinkInstallation? {
        guard let installationId = json["installationId"] as? String,
              let installationToken = json["installationToken"] as? String else {
            return nil
        }
        
        let dateFormatter = ISO8601DateFormatter()
        
        var createdAt = Date()
        if let createdAtString = json["createdAt"] as? String {
            createdAt = dateFormatter.date(from: createdAtString) ?? Date()
        }
        
        var updatedAt = Date()
        if let updatedAtString = json["updatedAt"] as? String {
            updatedAt = dateFormatter.date(from: updatedAtString) ?? Date()
        }
        
        return ULinkInstallation(
            installationId: installationId,
            installationToken: installationToken,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deviceInfo: json["deviceInfo"] as? [String: Any],
            appInfo: json["appInfo"] as? [String: Any]
        )
    }
    
    /**
     * Converts the installation to a JSON dictionary
     */
    @objc public func toJson() -> [String: Any] {
        let dateFormatter = ISO8601DateFormatter()
        
        var json: [String: Any] = [
            "installationId": installationId,
            "installationToken": installationToken,
            "createdAt": dateFormatter.string(from: createdAt),
            "updatedAt": dateFormatter.string(from: updatedAt)
        ]
        
        if let deviceInfo = deviceInfo {
            json["deviceInfo"] = deviceInfo
        }
        
        if let appInfo = appInfo {
            json["appInfo"] = appInfo
        }
        
        return json
    }
    
    /**
     * Returns a string representation of the installation
     */
    public override var description: String {
        return "ULinkInstallation(installationId: \(installationId), createdAt: \(createdAt))"
    }
    
    // MARK: - Codable
    
    private enum CodingKeys: String, CodingKey {
        case installationId, installationToken, createdAt, updatedAt, deviceInfo, appInfo
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        installationId = try container.decode(String.self, forKey: .installationId)
        installationToken = try container.decode(String.self, forKey: .installationToken)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        
        // Handle deviceInfo as [String: Any]
        if let deviceInfoData = try container.decodeIfPresent(Data.self, forKey: .deviceInfo) {
            deviceInfo = try JSONSerialization.jsonObject(with: deviceInfoData) as? [String: Any]
        } else {
            deviceInfo = nil
        }
        
        // Handle appInfo as [String: Any]
        if let appInfoData = try container.decodeIfPresent(Data.self, forKey: .appInfo) {
            appInfo = try JSONSerialization.jsonObject(with: appInfoData) as? [String: Any]
        } else {
            appInfo = nil
        }
        
        super.init()
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(installationId, forKey: .installationId)
        try container.encode(installationToken, forKey: .installationToken)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        
        // Handle deviceInfo as [String: Any]
        if let deviceInfo = deviceInfo {
            let deviceInfoData = try JSONSerialization.data(withJSONObject: deviceInfo)
            try container.encode(deviceInfoData, forKey: .deviceInfo)
        }
        
        // Handle appInfo as [String: Any]
        if let appInfo = appInfo {
            let appInfoData = try JSONSerialization.data(withJSONObject: appInfo)
            try container.encode(appInfoData, forKey: .appInfo)
        }
    }
}