// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-nexus",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "Nexus", targets: ["Nexus"]),
        .library(name: "NexusRouter", targets: ["NexusRouter"]),
        .library(name: "NexusHummingbird", targets: ["NexusHummingbird"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-http-types.git",
            from: "1.0.0"
        ),
        .package(
            url: "https://github.com/hummingbird-project/hummingbird.git",
            from: "2.0.0"
        ),
    ],
    targets: [
        // MARK: Core

        .target(
            name: "Nexus",
            dependencies: [
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ]
        ),

        // MARK: Router DSL

        .target(
            name: "NexusRouter",
            dependencies: [
                "Nexus",
            ]
        ),

        // MARK: Hummingbird Adapter

        .target(
            name: "NexusHummingbird",
            dependencies: [
                "Nexus",
                .product(name: "Hummingbird", package: "hummingbird"),
            ]
        ),

        // MARK: Tests

        .testTarget(
            name: "NexusTests",
            dependencies: [
                "Nexus",
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ]
        ),
        .testTarget(
            name: "NexusRouterTests",
            dependencies: [
                "Nexus",
                "NexusRouter",
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ]
        ),
    ]
)
