// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "ULinkSDK",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "ULinkSDK",
            targets: ["ULinkSDK"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ULinkSDK",
            dependencies: [],
            path: "ULinkSDK/Sources/ULinkSDK"
        ),
        .testTarget(
            name: "ULinkSDKTests",
            dependencies: ["ULinkSDK"],
            path: "ULinkSDK/Tests/ULinkSDKTests"
        ),
    ]
)
