Pod::Spec.new do |spec|
  spec.name         = "ULinkSDK"
  spec.version      = "1.0.0"
  spec.summary      = "ULink iOS SDK for creating and managing deep links"
  spec.description  = <<-DESC
                      ULink iOS SDK provides a comprehensive solution for creating, managing, and handling deep links in iOS applications.
                      Features include:
                      - Dynamic and unified link creation
                      - Deep link resolution and handling
                      - Session management with automatic lifecycle handling
                      - Installation tracking and analytics
                      - Universal link support
                      - Customizable configuration options
                      DESC

  spec.homepage     = "https://github.com/ulink/ios-sdk"
  spec.license      = { :type => "MIT", :file => "LICENSE" }
  spec.author       = { "ULink" => "support@ulink.com" }
  spec.source       = { :path => "." }

  spec.ios.deployment_target = "13.0"
  spec.swift_version = "5.0"

  spec.source_files = "ULinkSDK/Sources/ULinkSDK/**/*.swift"

  spec.frameworks = "Foundation", "UIKit", "Combine"

  spec.pod_target_xcconfig = {
    "SWIFT_VERSION" => "5.0"
  }
end