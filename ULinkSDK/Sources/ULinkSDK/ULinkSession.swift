//
//  ULinkSession.swift
//  ULinkSDK
//
//  Created by ULink SDK
//  Copyright © 2024 ULink. All rights reserved.
//

import Foundation

/**
 * Session data for tracking user sessions
 */
@objc public class ULinkSession: NSObject, Codable {
    
    /**
     * Unique session ID
     */
    @objc public let sessionId: String
    
    /**
     * Installation ID associated with this session
     */
    @objc public let installationId: String
    
    /**
     * Timestamp when the session started
     */
    @objc public let startedAt: Date
    
    /**
     * Timestamp when the session ended (nil if still active)
     */
    @objc public let endedAt: Date?
    
    /**
     * Duration of the session in seconds (nil if still active)
     */
    public let duration: TimeInterval?
    
    /**
     * Additional session data
     */
    @objc public let sessionData: [String: Any]?
    
    /**
     * Whether the session is currently active
     */
    @objc public var isActive: Bool {
        return endedAt == nil
    }
    
    /**
     * Creates a new ULinkSession instance
     */
    public init(
        sessionId: String,
        installationId: String,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        duration: TimeInterval? = nil,
        sessionData: [String: Any]? = nil
    ) {
        self.sessionId = sessionId
        self.installationId = installationId
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.duration = duration
        self.sessionData = sessionData
        super.init()
    }
    
    /**
     * Creates ULinkSession from JSON dictionary
     */
    @objc public static func fromJson(_ json: [String: Any]) -> ULinkSession? {
        guard let sessionId = json["sessionId"] as? String,
              let installationId = json["installationId"] as? String else {
            return nil
        }
        
        let dateFormatter = ISO8601DateFormatter()
        
        var startedAt = Date()
        if let startedAtString = json["startedAt"] as? String {
            startedAt = dateFormatter.date(from: startedAtString) ?? Date()
        }
        
        var endedAt: Date?
        if let endedAtString = json["endedAt"] as? String {
            endedAt = dateFormatter.date(from: endedAtString)
        }
        
        let duration = json["duration"] as? TimeInterval
        
        return ULinkSession(
            sessionId: sessionId,
            installationId: installationId,
            startedAt: startedAt,
            endedAt: endedAt,
            duration: duration,
            sessionData: json["sessionData"] as? [String: Any]
        )
    }
    
    /**
     * Converts the session to a JSON dictionary
     */
    @objc public func toJson() -> [String: Any] {
        let dateFormatter = ISO8601DateFormatter()
        
        var json: [String: Any] = [
            "sessionId": sessionId,
            "installationId": installationId,
            "startedAt": dateFormatter.string(from: startedAt)
        ]
        
        if let endedAt = endedAt {
            json["endedAt"] = dateFormatter.string(from: endedAt)
        }
        
        if let duration = duration {
            json["duration"] = duration
        }
        
        if let sessionData = sessionData {
            json["sessionData"] = sessionData
        }
        
        return json
    }
    
    /**
     * Ends the session and calculates duration
     */
    @objc public func endSession() -> ULinkSession {
        let endTime = Date()
        let sessionDuration = endTime.timeIntervalSince(startedAt)
        
        return ULinkSession(
            sessionId: sessionId,
            installationId: installationId,
            startedAt: startedAt,
            endedAt: endTime,
            duration: sessionDuration,
            sessionData: sessionData
        )
    }
    
    /**
     * Returns a string representation of the session
     */
    public override var description: String {
        let status = isActive ? "active" : "ended"
        return "ULinkSession(sessionId: \(sessionId), status: \(status), startedAt: \(startedAt))"
    }
    
    // MARK: - Codable
    
    private enum CodingKeys: String, CodingKey {
        case sessionId, installationId, startedAt, endedAt, duration, sessionData
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        sessionId = try container.decode(String.self, forKey: .sessionId)
        installationId = try container.decode(String.self, forKey: .installationId)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
        duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration)
        
        // Handle sessionData as [String: Any]
        if let sessionDataValue = try container.decodeIfPresent(Data.self, forKey: .sessionData) {
            sessionData = try JSONSerialization.jsonObject(with: sessionDataValue) as? [String: Any]
        } else {
            sessionData = nil
        }
        
        super.init()
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(sessionId, forKey: .sessionId)
        try container.encode(installationId, forKey: .installationId)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encodeIfPresent(endedAt, forKey: .endedAt)
        try container.encodeIfPresent(duration, forKey: .duration)
        
        // Handle sessionData as [String: Any]
        if let sessionData = sessionData {
            let sessionDataValue = try JSONSerialization.data(withJSONObject: sessionData)
            try container.encode(sessionDataValue, forKey: .sessionData)
        }
    }
}