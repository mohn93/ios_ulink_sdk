//
//  ULinkInstallationInfo.swift
//  ULinkSDK
//
//  Created by ULink SDK
//  Copyright © 2024 ULink. All rights reserved.
//

import Foundation

/**
 * Contains information about the current installation, including reinstall detection data.
 *
 * This data is returned from the bootstrap process and indicates whether the current
 * installation was detected as a reinstall of a previous installation.
 */
public struct ULinkInstallationInfo: Codable, Equatable {
    
    /**
     * The unique identifier for this installation (client-generated UUID)
     */
    public let installationId: String
    
    /**
     * Whether this installation was detected as a reinstall
     */
    public let isReinstall: Bool
    
    /**
     * The ID of the previous installation if this is a reinstall.
     * Nil if this is a fresh install or reinstall detection is not available.
     */
    public let previousInstallationId: String?
    
    /**
     * Timestamp when the reinstall was detected (ISO 8601 format)
     */
    public let reinstallDetectedAt: String?
    
    /**
     * The persistent device ID used for reinstall detection
     */
    public let persistentDeviceId: String?
    
    /**
     * Creates a ULinkInstallationInfo instance
     */
    public init(
        installationId: String,
        isReinstall: Bool = false,
        previousInstallationId: String? = nil,
        reinstallDetectedAt: String? = nil,
        persistentDeviceId: String? = nil
    ) {
        self.installationId = installationId
        self.isReinstall = isReinstall
        self.previousInstallationId = previousInstallationId
        self.reinstallDetectedAt = reinstallDetectedAt
        self.persistentDeviceId = persistentDeviceId
    }
    
    /**
     * Creates a ULinkInstallationInfo from a JSON dictionary response
     */
    public static func fromDictionary(_ dict: [String: Any], installationId: String) -> ULinkInstallationInfo {
        return ULinkInstallationInfo(
            installationId: installationId,
            isReinstall: dict["isReinstall"] as? Bool ?? false,
            previousInstallationId: dict["previousInstallationId"] as? String,
            reinstallDetectedAt: dict["reinstallDetectedAt"] as? String,
            persistentDeviceId: dict["persistentDeviceId"] as? String
        )
    }
    
    /**
     * Creates a fresh installation info (not a reinstall)
     */
    public static func freshInstall(installationId: String, persistentDeviceId: String? = nil) -> ULinkInstallationInfo {
        return ULinkInstallationInfo(
            installationId: installationId,
            isReinstall: false,
            persistentDeviceId: persistentDeviceId
        )
    }
}
