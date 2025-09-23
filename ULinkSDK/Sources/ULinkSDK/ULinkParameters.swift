//
//  ULinkParameters.swift
//  ULinkSDK
//
//  Created by ULink SDK
//  Copyright © 2024 ULink. All rights reserved.
//

import Foundation

/**
 * Enumeration for different types of links
 */
@objc public enum ULinkType: Int, CaseIterable {
    /**
     * Dynamic links designed for app deep linking with parameters, fallback URLs, and smart app store redirects
     */
    case dynamic
    
    /**
     * Simple platform-based redirects (iOS URL, Android URL, fallback URL) intended for browser handling
     */
    case unified
    
    public var stringValue: String {
        switch self {
        case .dynamic:
            return "dynamic"
        case .unified:
            return "unified"
        }
    }
}

/**
 * Social media tags for Open Graph metadata
 */
@objc public class SocialMediaTags: NSObject, Codable {
    
    /**
     * The title to be displayed when shared on social media
     */
    @objc public let ogTitle: String?
    
    /**
     * The description to be displayed when shared on social media
     */
    @objc public let ogDescription: String?
    
    /**
     * The image URL to be displayed when shared on social media
     */
    @objc public let ogImage: String?
    
    /**
     * Creates a new set of social media tags
     *
     * - Parameters:
     *   - ogTitle: The title to be displayed when shared on social media
     *   - ogDescription: The description to be displayed when shared on social media
     *   - ogImage: The image URL to be displayed when shared on social media
     */
    @objc public init(
        ogTitle: String? = nil,
        ogDescription: String? = nil,
        ogImage: String? = nil
    ) {
        self.ogTitle = ogTitle
        self.ogDescription = ogDescription
        self.ogImage = ogImage
        super.init()
    }
    
    /**
     * Converts the social media tags to a JSON dictionary
     */
    @objc public func toJson() -> [String: Any] {
        var data: [String: Any] = [:]
        
        if let ogTitle = ogTitle {
            data["ogTitle"] = ogTitle
        }
        if let ogDescription = ogDescription {
            data["ogDescription"] = ogDescription
        }
        if let ogImage = ogImage {
            data["ogImage"] = ogImage
        }
        
        return data
    }
}

/**
 * Parameters for creating ULinks
 */
@objc public class ULinkParameters: NSObject {
    
    /**
     * Link type: "unified" or "dynamic"
     */
    @objc public let type: String
    
    /**
     * Optional custom slug for the link
     */
    @objc public let slug: String?
    
    /**
     * iOS URL for unified links (direct iOS app store or web URL)
     */
    @objc public let iosUrl: String?
    
    /**
     * Android URL for unified links (direct Google Play or web URL)
     */
    @objc public let androidUrl: String?
    
    /**
     * iOS fallback URL for dynamic links
     */
    @objc public let iosFallbackUrl: String?
    
    /**
     * Android fallback URL for dynamic links
     */
    @objc public let androidFallbackUrl: String?
    
    /**
     * General fallback URL
     */
    @objc public let fallbackUrl: String?
    
    /**
     * Additional parameters from the link
     */
    @objc public let parameters: [String: Any]?
    
    /**
     * Social media tags
     */
    @objc public let socialMediaTags: SocialMediaTags?
    
    /**
     * Metadata from the link
     */
    @objc public let metadata: [String: Any]?
    
    /**
     * Domain host to use for the link (e.g., "example.com" or "subdomain.shared.ly")
     * Required to ensure consistent link generation and prevent app breakage
     * when projects have multiple domains configured.
     */
    @objc public let domain: String
    
    /**
     * Private initializer for ULinkParameters
     */
    private init(
        type: String,
        domain: String,
        slug: String? = nil,
        iosUrl: String? = nil,
        androidUrl: String? = nil,
        iosFallbackUrl: String? = nil,
        androidFallbackUrl: String? = nil,
        fallbackUrl: String? = nil,
        parameters: [String: Any]? = nil,
        socialMediaTags: SocialMediaTags? = nil,
        metadata: [String: Any]? = nil
    ) {
        self.type = type
        self.domain = domain
        self.slug = slug
        self.iosUrl = iosUrl
        self.androidUrl = androidUrl
        self.iosFallbackUrl = iosFallbackUrl
        self.androidFallbackUrl = androidFallbackUrl
        self.fallbackUrl = fallbackUrl
        self.parameters = parameters
        self.socialMediaTags = socialMediaTags
        self.metadata = metadata
        super.init()
    }
    
    /**
     * Creates parameters for a dynamic link
     *
     * - Parameters:
     *   - slug: Optional custom slug for the link
     *   - iosFallbackUrl: iOS fallback URL
     *   - androidFallbackUrl: Android fallback URL
     *   - fallbackUrl: General fallback URL
     *   - parameters: Additional parameters
     *   - socialMediaTags: Social media tags
     *   - metadata: Metadata
     * - Returns: ULinkParameters configured for dynamic links
     */
    @objc public static func dynamic(
        domain: String,
        slug: String? = nil,
        iosFallbackUrl: String? = nil,
        androidFallbackUrl: String? = nil,
        fallbackUrl: String? = nil,
        parameters: [String: Any]? = nil,
        socialMediaTags: SocialMediaTags? = nil,
        metadata: [String: Any]? = nil
    ) -> ULinkParameters {
        return ULinkParameters(
            type: ULinkType.dynamic.stringValue,
            domain: domain,
            slug: slug,
            iosFallbackUrl: iosFallbackUrl,
            androidFallbackUrl: androidFallbackUrl,
            fallbackUrl: fallbackUrl,
            parameters: parameters,
            socialMediaTags: socialMediaTags,
            metadata: metadata
        )
    }
    
    /**
     * Creates parameters for a unified link
     *
     * - Parameters:
     *   - slug: Optional custom slug for the link
     *   - iosUrl: iOS URL (required)
     *   - androidUrl: Android URL (required)
     *   - fallbackUrl: Fallback URL (required)
     *   - parameters: Additional parameters
     *   - socialMediaTags: Social media tags
     *   - metadata: Metadata
     * - Returns: ULinkParameters configured for unified links
     */
    @objc public static func unified(
        domain: String,
        slug: String? = nil,
        iosUrl: String,
        androidUrl: String,
        fallbackUrl: String,
        parameters: [String: Any]? = nil,
        socialMediaTags: SocialMediaTags? = nil,
        metadata: [String: Any]? = nil
    ) -> ULinkParameters {
        return ULinkParameters(
            type: ULinkType.unified.stringValue,
            domain: domain,
            slug: slug,
            iosUrl: iosUrl,
            androidUrl: androidUrl,
            fallbackUrl: fallbackUrl,
            parameters: parameters,
            socialMediaTags: socialMediaTags,
            metadata: metadata
        )
    }
    
    /**
     * Converts the parameters to a JSON dictionary
     */
    @objc public func toJson() -> [String: Any] {
        var data: [String: Any] = [
            "domain": domain
        ]
        
        data["type"] = type
        
        if let slug = slug {
            data["slug"] = slug
        }
        if let iosUrl = iosUrl {
            data["iosUrl"] = iosUrl
        }
        if let androidUrl = androidUrl {
            data["androidUrl"] = androidUrl
        }
        if let iosFallbackUrl = iosFallbackUrl {
            data["iosFallbackUrl"] = iosFallbackUrl
        }
        if let androidFallbackUrl = androidFallbackUrl {
            data["androidFallbackUrl"] = androidFallbackUrl
        }
        if let fallbackUrl = fallbackUrl {
            data["fallbackUrl"] = fallbackUrl
        }
        
        // Handle regular parameters (non-social media)
        if let parameters = parameters {
            var regularParameters: [String: Any] = [:]
            for (key, value) in parameters {
                if !key.hasPrefix("og") && !isSocialMediaParameter(key) {
                    regularParameters[key] = value
                }
            }
            if !regularParameters.isEmpty {
                data["parameters"] = regularParameters
            }
        }
        
        // Handle metadata (social media data)
        var metadataMap: [String: Any] = [:]
        
        // Add social media tags from socialMediaTags object
        if let socialMediaTags = socialMediaTags {
            let socialTags = socialMediaTags.toJson()
            for (key, value) in socialTags {
                metadataMap[key] = value
            }
        }
        
        // Add social media parameters from parameters map
        if let parameters = parameters {
            for (key, value) in parameters {
                if key.hasPrefix("og") || isSocialMediaParameter(key) {
                    metadataMap[key] = value
                }
            }
        }
        
        // Add explicit metadata
        if let metadata = metadata {
            for (key, value) in metadata {
                metadataMap[key] = value
            }
        }
        
        if !metadataMap.isEmpty {
            data["metadata"] = metadataMap
        }
        
        return data
    }
    
    private func isSocialMediaParameter(_ key: String) -> Bool {
        let socialMediaKeys = [
            "ogTitle",
            "ogDescription",
            "ogImage",
            "ogSiteName",
            "ogType",
            "ogUrl",
            "twitterCard",
            "twitterSite",
            "twitterCreator",
            "twitterTitle",
            "twitterDescription",
            "twitterImage"
        ]
        return socialMediaKeys.contains(key)
    }
}