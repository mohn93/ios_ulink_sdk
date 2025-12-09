//
//  ULinkLogEntry.swift
//  ULinkSDK
//
//  Created by ULink SDK
//  Copyright © 2024 ULink. All rights reserved.
//

import Foundation

/**
 * Represents a log entry from the ULink SDK
 * Mirrors the functionality of Android SDK's ULinkLogEntry
 */
@objc public class ULinkLogEntry: NSObject, Codable {
    
    // MARK: - Log Levels
    
    @objc public static let LEVEL_DEBUG = "debug"
    @objc public static let LEVEL_INFO = "info"
    @objc public static let LEVEL_WARNING = "warning"
    @objc public static let LEVEL_ERROR = "error"
    
    // MARK: - Properties
    
    /// Log level: "debug", "info", "warning", "error"
    @objc public let level: String
    
    /// Log tag/source
    @objc public let tag: String
    
    /// Log message
    @objc public let message: String
    
    /// Timestamp in milliseconds since epoch
    @objc public let timestamp: Int64
    
    // MARK: - Initialization
    
    /// Initialize with all parameters (Objective-C compatible)
    @objc public init(level: String, tag: String, message: String, timestamp: Int64) {
        self.level = level
        self.tag = tag
        self.message = message
        self.timestamp = timestamp
        super.init()
    }
    
    /// Initialize with automatic timestamp (Swift only)
    public convenience init(level: String, tag: String, message: String) {
        self.init(level: level, tag: tag, message: message, timestamp: Int64(Date().timeIntervalSince1970 * 1000))
    }
    
    // MARK: - Convenience Methods
    
    /// Convert to dictionary for Flutter bridge
    @objc public func toDictionary() -> [String: Any] {
        return [
            "level": level,
            "tag": tag,
            "message": message,
            "timestamp": timestamp
        ]
    }
    
    /// Create a debug log entry
    @objc public static func debug(tag: String, message: String) -> ULinkLogEntry {
        return ULinkLogEntry(level: LEVEL_DEBUG, tag: tag, message: message)
    }
    
    /// Create an info log entry
    @objc public static func info(tag: String, message: String) -> ULinkLogEntry {
        return ULinkLogEntry(level: LEVEL_INFO, tag: tag, message: message)
    }
    
    /// Create a warning log entry
    @objc public static func warning(tag: String, message: String) -> ULinkLogEntry {
        return ULinkLogEntry(level: LEVEL_WARNING, tag: tag, message: message)
    }
    
    /// Create an error log entry
    @objc public static func error(tag: String, message: String) -> ULinkLogEntry {
        return ULinkLogEntry(level: LEVEL_ERROR, tag: tag, message: message)
    }
}
