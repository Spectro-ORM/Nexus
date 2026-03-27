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
        .library(name: "NexusTest", targets: ["NexusTest"]),
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
        .package(
            url: "https://github.com/apple/swift-crypto.git",
            from: "3.0.0"
        ),
    ],
    targets: [
        // MARK: Core

        .target(
            name: "Nexus",
            dependencies: [
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(
                    name: "Crypto",
                    package: "swift-crypto",
                    condition: .when(platforms: [.linux])
                ),
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

        // MARK: Test Helpers

        .target(
            name: "NexusTest",
            dependencies: [
                "Nexus",
                .product(name: "HTTPTypes", package: "swift-http-types"),
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
        .testTarget(
            name: "NexusHummingbirdTests",
            dependencies: [
                "Nexus",
                "NexusHummingbird",
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdTesting", package: "hummingbird"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ]
        ),
    ]
)
