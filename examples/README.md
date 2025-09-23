# ULink iOS SDK Examples

This directory contains example projects demonstrating how to integrate and use the ULink iOS SDK.

## Available Examples

### ULinkSDKExample_Fresh
A modern SwiftUI-based example application that demonstrates:
- SDK initialization and configuration
- Creating dynamic and unified links
- Handling deep link resolution
- Session management
- Real-time link event handling

**Location:** `ULinkSDKExample_Fresh/`
**Framework:** SwiftUI
**Requirements:** iOS 13.0+

### ULinkSDKExample.xcworkspace
A workspace configuration for running examples with the SDK.

**Location:** `ULinkSDKExample.xcworkspace/`

## Getting Started

1. **Open the example project:**
   ```bash
   cd ULinkSDKExample_Fresh
   open ULinkSDKExample.xcodeproj
   ```

2. **Install dependencies:**
   - The example projects are configured to use the local ULink SDK
   - No additional setup required for basic functionality

3. **Configure your app:**
   - Update the bundle identifier in the project settings
   - Configure your ULink API credentials in the example code
   - Set up URL schemes and universal links as needed

4. **Run the example:**
   - Select your target device or simulator
   - Build and run the project

## Example Features Demonstrated

- **Initialization:** How to properly initialize the ULink SDK
- **Link Creation:** Creating both dynamic and unified links
- **Deep Link Handling:** Processing incoming deep links
- **Session Management:** Starting, managing, and ending user sessions
- **Event Handling:** Listening to link resolution events
- **Error Handling:** Proper error handling and user feedback

## Integration Notes

These examples show best practices for:
- SDK lifecycle management
- Async/await patterns with the SDK
- Combine framework integration
- SwiftUI reactive patterns
- Error handling and user experience

## Support

For questions about the examples or SDK integration, please refer to the main [README](../README.md) or check the SDK documentation.