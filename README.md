# ULink iOS SDK

The ULink iOS SDK provides a comprehensive solution for creating, managing, and handling deep links in iOS applications.

## Features

- **Dynamic Link Creation**: Create dynamic links with customizable parameters
- **Unified Link Creation**: Create unified links with platform-specific URLs
- **Deep Link Resolution**: Resolve and handle incoming deep links
- **Session Management**: Automatic session tracking with app lifecycle handling
- **Installation Tracking**: Track app installations and user analytics
- **Universal Link Support**: Handle both custom URL schemes and universal links
- **Persistence**: Optional persistence of last resolved link data
- **Combine Integration**: Reactive streams for link resolution events

## Requirements

- iOS 13.0+
- Swift 5.0+
- Xcode 12.0+

## Installation

### CocoaPods

Add the following line to your `Podfile`:

```ruby
pod 'ULinkSDK', '~> 1.0.7'
```

Then run:

```bash
pod install
```

### Swift Package Manager

Add the following dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/mohn93/ios_ulink_sdk.git", from: "1.0.7")
]
```

Or add it through Xcode:
1. File → Add Package Dependencies
2. Enter the repository URL: `https://github.com/mohn93/ios_ulink_sdk.git`
3. Select version `1.0.7` or later

## Quick Start

### 1. Initialize the SDK

In your `AppDelegate.swift`:

```swift
import ULinkSDK

func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    let config = ULinkConfig(
        apiKey: "your-api-key-here",
        debug: true,
        enableDeepLinkIntegration: true
    )

    Task {
        do {
            let ulink = try await ULink.initialize(config: config)

            // Handle link resolution
            ulink.dynamicLinkStream.sink { resolvedData in
                print("Resolved link: \(resolvedData.slug ?? "unknown")")
                // Handle the resolved link data
            }.store(in: &cancellables)
        } catch {
            print("Failed to initialize ULink: \(error)")
        }
    }

    return true
}
```

### 2. Handle Incoming URLs

Add URL handling in your `AppDelegate.swift`:

```swift
func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    return ULink.shared.handleIncomingURL(url)
}

func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
          let url = userActivity.webpageURL else {
        return false
    }
    return ULink.shared.handleIncomingURL(url)
}
```

### 3. Create Links

#### Dynamic Links

```swift
let parameters = ULinkParameters.dynamic(
    domain: "links.shared.ly",
    slug: "my-dynamic-link",
    iosFallbackUrl: "https://apps.apple.com/app/myapp",
    androidFallbackUrl: "https://play.google.com/store/apps/details?id=com.myapp",
    fallbackUrl: "https://myapp.com",
    parameters: ["userId": "12345", "campaign": "summer2024"],
    socialMediaTags: SocialMediaTags(
        ogTitle: "Check out this awesome app!",
        ogDescription: "Download our app for the best experience",
        ogImage: "https://myapp.com/share-image.png"
    )
)

Task {
    do {
        let response = try await ULink.shared.createLink(parameters: parameters)
        print("Created link: \(response.url ?? "No URL")")
    } catch {
        print("Error creating link: \(error.localizedDescription)")
    }
}
```

#### Unified Links

```swift
let parameters = ULinkParameters.unified(
    domain: "links.shared.ly",
    slug: "my-unified-link",
    iosUrl: "myapp://content/123",
    androidUrl: "myapp://content/123",
    fallbackUrl: "https://myapp.com/content/123"
)

Task {
    do {
        let response = try await ULink.shared.createLink(parameters: parameters)
        print("Created unified link: \(response.url ?? "No URL")")
    } catch {
        print("Error creating unified link: \(error.localizedDescription)")
    }
}
```

### 4. Handle Resolved Links

```swift
// Using Combine
ULink.shared.dynamicLinkStream.sink { resolvedData in
    // Handle dynamic links
    if let slug = resolvedData.slug {
        navigateToContent(slug: slug, parameters: resolvedData.parameters)
    }
}.store(in: &cancellables)

ULink.shared.unifiedLinkStream.sink { resolvedData in
    // Handle unified links
    if let iosUrl = resolvedData.iosUrl {
        handleDeepLink(url: iosUrl)
    }
}.store(in: &cancellables)

// Get last resolved link
if let lastLink = ULink.shared.getLastLinkData() {
    print("Last resolved link: \(lastLink.slug ?? "unknown")")
}
```

## Configuration

The `ULinkConfig` class provides various configuration options:

```swift
let config = ULinkConfig(
    apiKey: "your-api-key",                    // Required: Your ULink API key
    baseUrl: "https://api.ulink.ly",           // API base URL
    debug: true,                               // Enable debug logging
    enableDeepLinkIntegration: true,           // Enable automatic deep link handling
    autoCheckDeferredLink: true,               // Automatically check for deferred links on first launch
    persistLastLinkData: true,                 // Persist last resolved link
    lastLinkTimeToLive: 3600,                  // TTL for persisted link (seconds)
    clearLastLinkOnRead: false,                // Clear link data after reading
    redactAllParametersInLastLink: false,      // Redact all parameters in persisted link
    redactedParameterKeysInLastLink: ["token"] // Specific keys to redact
)
```

## URL Scheme Configuration

Add URL schemes to your app's `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.yourapp.deeplink</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>yourapp</string>
            <string>ulink</string>
        </array>
    </dict>
</array>
```

## Universal Links

For universal links, add associated domains to your app's entitlements:

```xml
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:yourdomain.com</string>
    <string>applinks:*.yourdomain.com</string>
</array>
```

## Session Management

The SDK automatically manages sessions based on app lifecycle:

```swift
// Check current session
if ULink.shared.hasActiveSession() {
    print("Session ID: \(ULink.shared.getCurrentSessionId() ?? "none")")
}

// Get session state
let state = ULink.shared.getSessionState()
print("Session state: \(state)")
```

## Error Handling

The SDK provides specific error types:

```swift
do {
    let response = try await ULink.shared.createLink(parameters: parameters)
} catch ULinkError.notInitialized {
    print("SDK not initialized")
} catch ULinkError.invalidConfiguration {
    print("Invalid configuration")
} catch ULinkError.networkError {
    print("Network error")
} catch {
    print("Other error: \(error.localizedDescription)")
}
```

## Testing

The SDK includes a test app demonstrating all features. To run the test app:

1. Open the project in Xcode
2. Select the `ULinkSDKExample` target
3. Update the API key in `AppDelegate.swift`
4. Build and run

## API Reference

### ULink

Main SDK class providing all functionality.

#### Methods

- `initialize(config:)` - Initialize the SDK (async throws)
- `createLink(parameters:)` - Create a dynamic or unified link
- `resolveLink(url:)` - Resolve a ULink URL
- `handleIncomingURL(_:)` - Handle incoming URLs
- `getLastLinkData()` - Get last resolved link data
- `getInitialDeepLink()` - Get initial deep link that launched the app
- `getInstallationId()` - Get the installation ID
- `getInstallationInfo()` - Get installation info including reinstall detection
- `isReinstall()` - Check if current installation is a reinstall
- `hasActiveSession()` - Check if there's an active session
- `getCurrentSessionId()` - Get the current session ID
- `getSessionState()` - Get the current session state

#### Properties

- `dynamicLinkStream` - Publisher for dynamic link resolution events
- `unifiedLinkStream` - Publisher for unified link resolution events
- `onReinstallDetected` - Publisher that emits when a reinstall is detected
- `logStream` - Publisher for SDK log entries (debug mode only)

> **Note:** `onLink` and `onUnifiedLink` are deprecated aliases for `dynamicLinkStream` and `unifiedLinkStream` respectively. They are retained for backward compatibility but new code should use the newer names.

### ULinkConfig

Configuration class for SDK initialization.

### ULinkParameters

Parameters for link creation with factory methods:

- `dynamic(...)` - Create dynamic link parameters
- `unified(...)` - Create unified link parameters

### ULinkResolvedData

Data structure for resolved link information.

## License

MIT License. See LICENSE file for details.

## Support

For support, please contact support@ulink.ly or visit our documentation at https://docs.ulink.ly