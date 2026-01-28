// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftFindRefs",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0"),
        .package(url: "https://github.com/MobileNativeFoundation/swift-index-store", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "SwiftFindRefs",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "IndexStore", package: "swift-index-store"),
            ]
        ),
        .testTarget(
            name: "SwiftFindRefsTests",
            dependencies: ["SwiftFindRefs"]
        )
    ]
)
