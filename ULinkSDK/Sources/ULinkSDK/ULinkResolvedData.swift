//
//  ULinkResolvedData.swift
//  ULinkSDK
//
//  Created by ULink SDK
//  Copyright © 2024 ULink. All rights reserved.
//

import Foundation

/**
 * Data structure for resolved ULink deep links
 */
@objc public class ULinkResolvedData: NSObject, Codable {
    
    /**
     * The slug of the link
     */
    @objc public let slug: String?
    
    /**
     * iOS fallback URL
     */
    @objc public let iosFallbackUrl: String?
    
    /**
     * Android fallback URL
     */
    @objc public let androidFallbackUrl: String?
    
    /**
     * General fallback URL
     */
    @objc public let fallbackUrl: String?
    
    /**
     * iOS URL for unified links
     */
    @objc public let iosUrl: String?
    
    /**
     * Android URL for unified links
     */
    @objc public let androidUrl: String?
    
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
     * The type of the link (dynamic or unified)
     */
    @objc public let type: String?
    

    
    /**
     * Timestamp when the link was resolved
     */
    @objc public let resolvedAt: Date?
    
    /**
     * Raw data from the server response
     */
    public let rawData: [String: Any]?
    
    /**
     * Creates a new ULinkResolvedData instance
     */
    @objc public init(
        slug: String? = nil,
        iosFallbackUrl: String? = nil,
        androidFallbackUrl: String? = nil,
        fallbackUrl: String? = nil,
        iosUrl: String? = nil,
        androidUrl: String? = nil,
        parameters: [String: Any]? = nil,
        socialMediaTags: SocialMediaTags? = nil,
        metadata: [String: Any]? = nil,
        type: String? = nil,

        resolvedAt: Date? = nil,
        rawData: [String: Any]? = nil
    ) {
        self.slug = slug
        self.iosFallbackUrl = iosFallbackUrl
        self.androidFallbackUrl = androidFallbackUrl
        self.fallbackUrl = fallbackUrl
        self.iosUrl = iosUrl
        self.androidUrl = androidUrl
        self.parameters = parameters
        self.socialMediaTags = socialMediaTags
        self.metadata = metadata
        self.type = type

        self.resolvedAt = resolvedAt
        self.rawData = rawData
        super.init()
    }
    
    /**
     * Creates ULinkResolvedData from JSON dictionary
     */
    @objc public static func fromJson(_ json: [String: Any]) -> ULinkResolvedData? {
        // Extract social media tags from metadata if it exists (matching Flutter SDK logic)
        var socialMediaTags: SocialMediaTags?
        let metadata = json["metadata"] as? [String: Any]
        let parameters = json["parameters"] as? [String: Any]
        
        // Try to extract social media tags from metadata first
        if let metadata = metadata {
            let ogTitle = metadata["ogTitle"] as? String
            let ogDescription = metadata["ogDescription"] as? String
            let ogImage = metadata["ogImage"] as? String
            
            if ogTitle != nil || ogDescription != nil || ogImage != nil {
                socialMediaTags = SocialMediaTags(
                    ogTitle: ogTitle,
                    ogDescription: ogDescription,
                    ogImage: ogImage
                )
            }
        }
        
        // Fallback: check parameters for backward compatibility (matching Flutter SDK)
        if socialMediaTags == nil, let parameters = parameters {
            let ogTitle = parameters["ogTitle"] as? String
            let ogDescription = parameters["ogDescription"] as? String
            let ogImage = parameters["ogImage"] as? String
            
            if ogTitle != nil || ogDescription != nil || ogImage != nil {
                socialMediaTags = SocialMediaTags(
                    ogTitle: ogTitle,
                    ogDescription: ogDescription,
                    ogImage: ogImage
                )
            }
        }
        
        // Also check direct socialMediaTags field for backward compatibility
        if socialMediaTags == nil, let socialMediaData = json["socialMediaTags"] as? [String: Any] {
            socialMediaTags = SocialMediaTags(
                ogTitle: socialMediaData["ogTitle"] as? String,
                ogDescription: socialMediaData["ogDescription"] as? String,
                ogImage: socialMediaData["ogImage"] as? String
            )
        }
        
        var resolvedAt: Date?
        if let resolvedAtString = json["resolvedAt"] as? String {
            let formatter = ISO8601DateFormatter()
            resolvedAt = formatter.date(from: resolvedAtString)
        }
        
        return ULinkResolvedData(
            slug: json["slug"] as? String,
            iosFallbackUrl: json["iosFallbackUrl"] as? String,
            androidFallbackUrl: json["androidFallbackUrl"] as? String,
            fallbackUrl: json["fallbackUrl"] as? String,
            iosUrl: json["iosUrl"] as? String,
            androidUrl: json["androidUrl"] as? String,
            parameters: parameters,
            socialMediaTags: socialMediaTags,
            metadata: metadata,
            type: json["type"] as? String,

            resolvedAt: resolvedAt,
            rawData: json  // Fix: Include rawData assignment that was missing
        )
    }
    
    /**
     * Creates a ULinkResolvedData instance from a dictionary
     * This is an alias for fromJson for consistency with Android SDK
     */
    @objc public static func fromDictionary(_ dictionary: [String: Any]) -> ULinkResolvedData? {
        return fromJson(dictionary)
    }
    
    /**
     * Converts the resolved data to a JSON dictionary
     */
    @objc public func toJson() -> [String: Any] {
        var data: [String: Any] = [:]
        
        if let slug = slug {
            data["slug"] = slug
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
        if let iosUrl = iosUrl {
            data["iosUrl"] = iosUrl
        }
        if let androidUrl = androidUrl {
            data["androidUrl"] = androidUrl
        }
        if let parameters = parameters {
            data["parameters"] = parameters
        }
        if let socialMediaTags = socialMediaTags {
            data["socialMediaTags"] = socialMediaTags.toJson()
        }
        if let metadata = metadata {
            data["metadata"] = metadata
        }
        if let type = type {
            data["type"] = type
        }

        if let resolvedAt = resolvedAt {
            let formatter = ISO8601DateFormatter()
            data["resolvedAt"] = formatter.string(from: resolvedAt)
        }
        
        return data
    }
    
    /**
     * Returns a string representation of the resolved data
     */
    public override var description: String {
        return "ULinkResolvedData(slug: \(slug ?? "nil"), type: \(type ?? "nil"))"
    }
    
    // MARK: - Codable
    
    private enum CodingKeys: String, CodingKey {
        case slug, iosFallbackUrl, androidFallbackUrl, fallbackUrl
        case iosUrl, androidUrl, parameters, socialMediaTags
        case metadata, type, resolvedAt
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        slug = try container.decodeIfPresent(String.self, forKey: .slug)
        iosFallbackUrl = try container.decodeIfPresent(String.self, forKey: .iosFallbackUrl)
        androidFallbackUrl = try container.decodeIfPresent(String.self, forKey: .androidFallbackUrl)
        fallbackUrl = try container.decodeIfPresent(String.self, forKey: .fallbackUrl)
        iosUrl = try container.decodeIfPresent(String.self, forKey: .iosUrl)
        androidUrl = try container.decodeIfPresent(String.self, forKey: .androidUrl)
        
        // Handle parameters as [String: Any]
        if let parametersData = try container.decodeIfPresent(Data.self, forKey: .parameters) {
            parameters = try JSONSerialization.jsonObject(with: parametersData) as? [String: Any]
        } else {
            parameters = nil
        }
        
        socialMediaTags = try container.decodeIfPresent(SocialMediaTags.self, forKey: .socialMediaTags)
        
        // Handle metadata as [String: Any]
        if let metadataData = try container.decodeIfPresent(Data.self, forKey: .metadata) {
            metadata = try JSONSerialization.jsonObject(with: metadataData) as? [String: Any]
        } else {
            metadata = nil
        }
        
        type = try container.decodeIfPresent(String.self, forKey: .type)
        resolvedAt = try container.decodeIfPresent(Date.self, forKey: .resolvedAt)
        rawData = nil
        
        super.init()
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(slug, forKey: .slug)
        try container.encodeIfPresent(iosFallbackUrl, forKey: .iosFallbackUrl)
        try container.encodeIfPresent(androidFallbackUrl, forKey: .androidFallbackUrl)
        try container.encodeIfPresent(fallbackUrl, forKey: .fallbackUrl)
        try container.encodeIfPresent(iosUrl, forKey: .iosUrl)
        try container.encodeIfPresent(androidUrl, forKey: .androidUrl)
        
        // Handle parameters as [String: Any]
        if let parameters = parameters {
            let parametersData = try JSONSerialization.data(withJSONObject: parameters)
            try container.encode(parametersData, forKey: .parameters)
        }
        
        try container.encodeIfPresent(socialMediaTags, forKey: .socialMediaTags)
        
        // Handle metadata as [String: Any]
        if let metadata = metadata {
            let metadataData = try JSONSerialization.data(withJSONObject: metadata)
            try container.encode(metadataData, forKey: .metadata)
        }
        
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(resolvedAt, forKey: .resolvedAt)
    }
}
