//
//  DeviceInfoUtils.swift
//  ULinkSDK
//
//  Created by ULink SDK
//  Copyright © 2024 ULink. All rights reserved.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/**
 * Utility class for gathering device information
 * Provides async methods for device info collection
 */
@objc public class DeviceInfoUtils: NSObject {
    
    /**
     * Gets basic device information asynchronously
     * Returns essential device info needed for API calls
     */
    @available(macOS 10.15, iOS 13.0, *)
    public static func getBasicDeviceInfo() async -> [String: Any] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let deviceInfo = DeviceInfoHelper.getDeviceInfo()
                
                // Extract basic info needed for API calls
                var basicInfo: [String: Any] = [:]
                
                // Device identification
                basicInfo["deviceId"] = deviceInfo["deviceId"] ?? ""
                basicInfo["deviceModel"] = deviceInfo["deviceModel"] ?? ""
                basicInfo["deviceManufacturer"] = "Apple"
                
                // OS information
                basicInfo["osName"] = deviceInfo["osName"] ?? "iOS"
                basicInfo["osVersion"] = deviceInfo["osVersion"] ?? ""
                
                // App information
                basicInfo["appVersion"] = deviceInfo["appVersion"] ?? ""
                basicInfo["appBuild"] = deviceInfo["buildNumber"] ?? ""
                basicInfo["bundleId"] = deviceInfo["bundleId"] ?? ""
                
                // Locale information
                basicInfo["language"] = deviceInfo["language"] ?? ""
                basicInfo["timezone"] = deviceInfo["timezone"] ?? ""
                basicInfo["locale"] = deviceInfo["locale"] ?? ""
                basicInfo["region"] = deviceInfo["region"] ?? ""
                
                // Screen information
            basicInfo["screenWidth"] = deviceInfo["screenWidth"] ?? 0
            basicInfo["screenHeight"] = deviceInfo["screenHeight"] ?? 0
            basicInfo["screenScale"] = deviceInfo["screenScale"] ?? 1.0
            
            // Platform
            basicInfo["platform"] = "ios"
            
            continuation.resume(returning: basicInfo)
            }
        }
    }
    
    /**
     * Gets comprehensive device information to match Android SDK functionality
     * Returns complete device info including network, battery, and device state
     */
    @available(macOS 10.15, iOS 13.0, *)
    public static func getCompleteDeviceInfo() async -> [String: Any] {
    return await withCheckedContinuation { continuation in
        DispatchQueue.global(qos: .utility).async {
            let deviceInfo = DeviceInfoHelper.getDeviceInfo()
            var completeInfo: [String: Any] = [:]
            
            // Basic device information
            completeInfo["osName"] = deviceInfo["osName"] ?? "iOS"
            completeInfo["osVersion"] = deviceInfo["osVersion"] ?? ""
            completeInfo["deviceModel"] = deviceInfo["deviceModel"] ?? ""
            completeInfo["deviceManufacturer"] = "Apple"
            completeInfo["brand"] = "Apple"
            completeInfo["device"] = deviceInfo["deviceModel"] ?? ""
            completeInfo["isPhysicalDevice"] = DeviceInfoHelper.isPhysicalDevice()
            completeInfo["sdkVersion"] = DeviceInfoHelper.getSDKVersion()
            
            // App information
            completeInfo["appVersion"] = deviceInfo["appVersion"] ?? ""
            completeInfo["appBuild"] = deviceInfo["buildNumber"] ?? ""
            completeInfo["bundleId"] = deviceInfo["bundleId"] ?? ""
            
            // Device identifiers
            completeInfo["deviceId"] = deviceInfo["deviceId"] ?? ""
            
            // Locale and timezone
            completeInfo["language"] = deviceInfo["language"] ?? ""
            completeInfo["timezone"] = deviceInfo["timezone"] ?? ""
            completeInfo["locale"] = deviceInfo["locale"] ?? ""
            completeInfo["region"] = deviceInfo["region"] ?? ""
            
            // Network and connectivity
            completeInfo["networkType"] = DeviceInfoHelper.getNetworkType()
            completeInfo["carrierName"] = DeviceInfoHelper.getCarrierName()
            completeInfo["countryCode"] = deviceInfo["region"] ?? ""
            
            // Device state
            completeInfo["deviceOrientation"] = DeviceInfoHelper.getDeviceOrientation()
            completeInfo["batteryLevel"] = DeviceInfoHelper.getBatteryLevel()
            completeInfo["isCharging"] = DeviceInfoHelper.isCharging()
            
            // Platform specific
            completeInfo["platform"] = "ios"
            completeInfo["userAgent"] = DeviceInfoHelper.getUserAgent()
            
            continuation.resume(returning: completeInfo)
            }
        }
    }
    
    /**
     * Gets comprehensive device information asynchronously
     * Returns all available device info
     */
    @available(macOS 10.15, iOS 13.0, *)
    public static func getFullDeviceInfo() async -> [String: Any] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let deviceInfo = DeviceInfoHelper.getDeviceInfo()
                continuation.resume(returning: deviceInfo)
            }
        }
    }
    
    /**
     * Generates device fingerprint asynchronously
     */
    @available(macOS 10.15, iOS 13.0, *)
    public static func generateDeviceFingerprint() async -> String {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let fingerprint = DeviceInfoHelper.generateDeviceFingerprint()
                continuation.resume(returning: fingerprint)
            }
        }
    }
    
    /**
     * Gets device info formatted for API requests
     */
    @available(macOS 10.15, iOS 13.0, *)
    public static func getApiFormattedDeviceInfo() async -> [String: Any] {
        let basicInfo = await getBasicDeviceInfo()
        
        // Format for API compatibility
        var apiInfo: [String: Any] = [:]
        
        // Required fields for API
        apiInfo["device_id"] = basicInfo["deviceId"]
        apiInfo["device_model"] = basicInfo["deviceModel"]
        apiInfo["device_manufacturer"] = basicInfo["deviceManufacturer"]
        apiInfo["os_name"] = basicInfo["osName"]
        apiInfo["os_version"] = basicInfo["osVersion"]
        apiInfo["app_version"] = basicInfo["appVersion"]
        apiInfo["app_build"] = basicInfo["appBuild"]
        apiInfo["bundle_id"] = basicInfo["bundleId"]
        apiInfo["language"] = basicInfo["language"]
        apiInfo["timezone"] = basicInfo["timezone"]
        apiInfo["locale"] = basicInfo["locale"]
        apiInfo["region"] = basicInfo["region"]
        apiInfo["screen_width"] = basicInfo["screenWidth"]
        apiInfo["screen_height"] = basicInfo["screenHeight"]
        apiInfo["screen_scale"] = basicInfo["screenScale"]
        apiInfo["platform"] = basicInfo["platform"]
        
        return apiInfo
    }
    

}