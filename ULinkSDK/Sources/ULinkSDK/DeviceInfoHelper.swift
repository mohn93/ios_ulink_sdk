//
//  DeviceInfoHelper.swift
//  ULinkSDK
//
//  Created by ULink SDK
//  Copyright © 2024 ULink. All rights reserved.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

#if canImport(Network)
import Network
#endif

#if canImport(CoreTelephony)
import CoreTelephony
#endif

/**
 * Helper class for gathering device information
 */
@objc public class DeviceInfoHelper: NSObject {
    
    /**
     * Gathers comprehensive device information
     */
    @objc public static func getDeviceInfo() -> [String: Any] {
        var deviceInfo: [String: Any] = [:]
        
        #if canImport(UIKit)
        // Basic device information
        let device = UIDevice.current
        deviceInfo["platform"] = "ios"
        deviceInfo["osName"] = device.systemName
        deviceInfo["osVersion"] = device.systemVersion
        deviceInfo["deviceModel"] = getDeviceModel()
        deviceInfo["deviceName"] = device.name
        deviceInfo["deviceId"] = device.identifierForVendor?.uuidString
        #else
        // Fallback for non-iOS platforms
        deviceInfo["platform"] = "unknown"
        deviceInfo["osName"] = "unknown"
        deviceInfo["osVersion"] = "unknown"
        deviceInfo["deviceModel"] = "unknown"
        deviceInfo["deviceName"] = "unknown"
        deviceInfo["deviceId"] = UUID().uuidString
        #endif
        
        // App information
        if let appInfo = getAppInfo() {
            deviceInfo.merge(appInfo) { (_, new) in new }
        }
        
        // Screen information
        if let screenInfo = getScreenInfo() {
            deviceInfo.merge(screenInfo) { (_, new) in new }
        }
        
        // Locale and timezone
        deviceInfo["locale"] = Locale.current.identifier
        deviceInfo["timezone"] = TimeZone.current.identifier
        deviceInfo["language"] = Locale.current.languageCode
        deviceInfo["region"] = Locale.current.regionCode
        
        // Memory information
        deviceInfo["totalMemory"] = ProcessInfo.processInfo.physicalMemory
        
        // Battery information (if available)
        if let batteryInfo = getBatteryInfo() {
            deviceInfo.merge(batteryInfo) { (_, new) in new }
        }
        
        // Network information
        if let networkInfo = getNetworkInfo() {
            deviceInfo.merge(networkInfo) { (_, new) in new }
        }
        
        return deviceInfo
    }
    
    /**
     * Gets the device model identifier
     */
    private static func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            let scalar = UnicodeScalar(UInt8(value))
            return identifier + String(Character(scalar))
            return identifier
        }
        return identifier
    }
    
    /**
     * Gets app-specific information
     */
    private static func getAppInfo() -> [String: Any]? {
        guard let infoDictionary = Bundle.main.infoDictionary else {
            return nil
        }
        
        var appInfo: [String: Any] = [:]
        
        appInfo["appName"] = infoDictionary["CFBundleDisplayName"] as? String ?? infoDictionary["CFBundleName"] as? String
        appInfo["appVersion"] = infoDictionary["CFBundleShortVersionString"] as? String
        appInfo["buildNumber"] = infoDictionary["CFBundleVersion"] as? String
        appInfo["bundleId"] = Bundle.main.bundleIdentifier
        
        return appInfo
    }
    
    /**
     * Gets screen information
     */
    private static func getScreenInfo() -> [String: Any]? {
        #if canImport(UIKit)
        let screen = UIScreen.main
        let bounds = screen.bounds
        let scale = screen.scale
        
        var screenInfo: [String: Any] = [:]
        screenInfo["screenWidth"] = bounds.width * scale
        screenInfo["screenHeight"] = bounds.height * scale
        screenInfo["screenScale"] = scale
        screenInfo["screenBrightness"] = screen.brightness
        
        return screenInfo
        #else
        return nil
        #endif
    }
    
    /**
     * Gets battery information
     */
    private static func getBatteryInfo() -> [String: Any]? {
        #if canImport(UIKit)
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        
        guard device.batteryState != .unknown else {
            device.isBatteryMonitoringEnabled = false
            return nil
        }
        
        var batteryInfo: [String: Any] = [:]
        batteryInfo["batteryLevel"] = device.batteryLevel
        
        switch device.batteryState {
        case .unplugged:
            batteryInfo["batteryState"] = "unplugged"
        case .charging:
            batteryInfo["batteryState"] = "charging"
        case .full:
            batteryInfo["batteryState"] = "full"
        default:
            batteryInfo["batteryState"] = "unknown"
        }
        
        device.isBatteryMonitoringEnabled = false
        return batteryInfo
        #else
        return nil
        #endif
    }
    
    /**
     * Gets network information
     */
    private static func getNetworkInfo() -> [String: Any]? {
        var networkInfo: [String: Any] = [:]
        
        // Check if device is connected to internet
        networkInfo["isConnected"] = isConnectedToNetwork()
        
        // Get network type (this is a simplified version)
        networkInfo["networkType"] = getSimpleNetworkType()
        
        return networkInfo
    }
    
    /**
     * Checks if device is connected to network
     */
    private static func isConnectedToNetwork() -> Bool {
        // This is a simplified check. In a real implementation,
        // you might want to use Reachability or similar library
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        guard let defaultRouteReachability = withUnsafePointer(to: &zeroAddress, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                SCNetworkReachabilityCreateWithAddress(nil, $0)
            }
        }) else {
            return false
        }
        
        var flags: SCNetworkReachabilityFlags = []
        if !SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) {
            return false
        }
        
        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)
        
        return isReachable && !needsConnection
    }
    
    /**
     * Gets the network type
     */
    private static func getSimpleNetworkType() -> String {
        // This is a simplified implementation
        // In a real app, you might want to use more sophisticated network detection
        if isConnectedToNetwork() {
            return "wifi" // iOS apps typically use WiFi or cellular, defaulting to wifi
        } else {
            return "none"
        }
    }
    
    /**
     * Gets the device orientation
     */
    @objc public static func getDeviceOrientation() -> String {
        guard Thread.isMainThread else {
            return DispatchQueue.main.sync {
                return getDeviceOrientation()
            }
        }
        
        #if canImport(UIKit)
        switch UIDevice.current.orientation {
        case .portrait:
            return "portrait"
        case .portraitUpsideDown:
            return "portraitUpsideDown"
        case .landscapeLeft:
            return "landscapeLeft"
        case .landscapeRight:
            return "landscapeRight"
        case .faceUp:
            return "faceUp"
        case .faceDown:
            return "faceDown"
        default:
            return "unknown"
        }
        #else
        return "unknown"
        #endif
    }
    
    /**
      * Gets the network type (WiFi, Cellular, etc.)
      */
     @available(macOS 10.14, iOS 12.0, *)
     @objc public static func getNetworkType() -> String {
          #if canImport(Network)
          let monitor = NWPathMonitor()
         let queue = DispatchQueue(label: "NetworkMonitor")
         var networkType = "unknown"
         
         let semaphore = DispatchSemaphore(value: 0)
         
         monitor.pathUpdateHandler = { path in
             if path.status == .satisfied {
                 if path.usesInterfaceType(.wifi) {
                     networkType = "wifi"
                 } else if path.usesInterfaceType(.cellular) {
                     networkType = "cellular"
                 } else if path.usesInterfaceType(.wiredEthernet) {
                     networkType = "ethernet"
                 } else {
                     networkType = "other"
                 }
             } else {
                 networkType = "none"
             }
             semaphore.signal()
         }
         
         monitor.start(queue: queue)
         _ = semaphore.wait(timeout: .now() + 1.0)
         monitor.cancel()
         
         return networkType
         #else
         return "unknown"
         #endif
     }
     
     /**
      * Gets the carrier name
      */
     @objc public static func getCarrierName() -> String {
          #if canImport(CoreTelephony) && !os(macOS)
          let networkInfo = CTTelephonyNetworkInfo()
         if let carrier = networkInfo.subscriberCellularProvider {
             return carrier.carrierName ?? "unknown"
         }
         return "unknown"
         #else
         return "unknown"
         #endif
     }
    
    /**
     * Gets the battery level (0-100)
     */
    public static func getBatteryLevel() -> Int? {
        #if canImport(UIKit)
        UIDevice.current.isBatteryMonitoringEnabled = true
        let batteryLevel = UIDevice.current.batteryLevel
        
        if batteryLevel < 0 {
            return nil // Battery level unknown
        }
        
        return Int(batteryLevel * 100)
        #else
        return nil
        #endif
    }
    
    /**
     * Checks if the device is charging
     */
    @objc public static func isCharging() -> Bool {
        #if canImport(UIKit)
        UIDevice.current.isBatteryMonitoringEnabled = true
        let batteryState = UIDevice.current.batteryState
        
        return batteryState == .charging || batteryState == .full
        #else
        return false
        #endif
    }
    
    /**
     * Checks if this is a physical device (not simulator)
     */
    @objc public static func isPhysicalDevice() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return true
        #endif
    }
    
    /**
     * Gets the SDK version
     */
    @objc public static func getSDKVersion() -> String {
        return "1.0.8" // This should match your SDK version
    }
    
    /**
     * Gets the user agent string
     */
    @objc public static func getUserAgent() -> String {
        let deviceInfo = getDeviceInfo()
        let osName = deviceInfo["osName"] as? String ?? "iOS"
        let osVersion = deviceInfo["osVersion"] as? String ?? "unknown"
        let deviceModel = deviceInfo["deviceModel"] as? String ?? "unknown"
        let appVersion = deviceInfo["appVersion"] as? String ?? "unknown"
        let bundleId = deviceInfo["bundleId"] as? String ?? "unknown"
        
        return "\(bundleId)/\(appVersion) (\(deviceModel); \(osName) \(osVersion))"
    }
    
    /**
     * Gets the persistent device ID that survives app reinstalls.
     * 
     * This uses iOS Keychain storage which:
     * - Persists across app reinstalls
     * - Is cleared on device reset or if user explicitly clears Keychain data
     * - Is unique per device
     * 
     * Used for reinstall detection - when the same persistentDeviceId
     * appears with a different installationId, it indicates a reinstall.
     * 
     * - Returns: The persistent device ID, or nil if Keychain is unavailable
     */
    @objc public static func getPersistentDeviceId() -> String? {
        return KeychainHelper.getPersistentDeviceId()
    }
    
    /**
     * Generates a unique device fingerprint
     */
    @objc public static func generateDeviceFingerprint() -> String {
        let deviceInfo = getDeviceInfo()
        
        // Create a fingerprint based on device characteristics
        var fingerprintComponents: [String] = []
        
        if let deviceModel = deviceInfo["deviceModel"] as? String {
            fingerprintComponents.append(deviceModel)
        }
        if let osVersion = deviceInfo["osVersion"] as? String {
            fingerprintComponents.append(osVersion)
        }
        if let screenWidth = deviceInfo["screenWidth"] as? Double {
            fingerprintComponents.append(String(screenWidth))
        }
        if let screenHeight = deviceInfo["screenHeight"] as? Double {
            fingerprintComponents.append(String(screenHeight))
        }
        if let timezone = deviceInfo["timezone"] as? String {
            fingerprintComponents.append(timezone)
        }
        
        let fingerprintString = fingerprintComponents.joined(separator: "|")
        
        // Generate SHA256 hash
        return fingerprintString.sha256()
    }
}

// MARK: - String Extension for SHA256

extension String {
    func sha256() -> String {
        guard let data = self.data(using: .utf8) else { return "" }
        
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// Import CommonCrypto for SHA256
import CommonCrypto
import SystemConfiguration
import Security

// MARK: - Keychain Helper for Persistent Device ID

/**
 * Helper class for storing and retrieving data from the iOS Keychain.
 * The Keychain persists across app reinstalls, making it ideal for
 * storing a persistent device identifier for reinstall detection.
 */
class KeychainHelper {
    
    private static let serviceName = "ly.ulink.sdk"
    private static let persistentDeviceIdKey = "persistentDeviceId"
    
    /**
     * Retrieves or creates a persistent device ID stored in the Keychain.
     * 
     * This ID survives app reinstalls (unless user explicitly clears Keychain
     * or resets their device). It's used to detect when an app has been
     * reinstalled on the same device.
     * 
     * - Returns: The persistent device ID string, or nil if Keychain is unavailable
     */
    static func getPersistentDeviceId() -> String? {
        // First, try to read existing ID from Keychain
        if let existingId = readFromKeychain(key: persistentDeviceIdKey) {
            return existingId
        }
        
        // If no existing ID, generate a new UUID and save it
        let newId = UUID().uuidString
        if saveToKeychain(key: persistentDeviceIdKey, value: newId) {
            return newId
        }
        
        // If Keychain save failed, return the new ID anyway
        // (it won't persist across reinstalls but app will still work)
        return newId
    }
    
    /**
     * Saves a string value to the Keychain
     */
    private static func saveToKeychain(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        
        // First, try to delete any existing item
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Now add the new item
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /**
     * Reads a string value from the Keychain
     */
    private static func readFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return string
    }
    
    /**
     * Deletes a value from the Keychain (for testing/debugging)
     */
    static func deleteFromKeychain(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}