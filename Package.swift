// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "openai-realtime-api-connector",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "OpenAIRealtimeAPI",
            targets: ["OpenAIRealtimeAPI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/stasel/WebRTC.git", from: "125.0.0")
    ],
    targets: [
        .target(
            name: "OpenAIRealtimeAPI",
            dependencies: [
                .product(name: "WebRTC", package: "WebRTC")
            ],
            path: "Sources/OpenAIRealtimeAPI"
        ),
        .testTarget(
            name: "OpenAIRealtimeAPITests",
            dependencies: ["OpenAIRealtimeAPI"],
            path: "Tests/OpenAIRealtimeAPITests"
        ),
    ]
)
