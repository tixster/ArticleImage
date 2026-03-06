// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ArticleParser",
    platforms: [
        .iOS(.v15),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "VKParser",
            targets: ["VKParser"]),
        .library(
            name: "BoostyParser",
            targets: ["BoostyParser"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/vapor-community/Zip",
            .upToNextMinor(from: "2.2.3")
        ),
        .package(
            url: "https://github.com/apple/swift-argument-parser",
            from: "1.2.3"
        ),
        .package(
            url: "https://github.com/crossroadlabs/Regex",
            from: "1.2.0"
        ),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/groue/Semaphore.git", from: "0.1.0"),
    ],
    targets: [
        .target(
            name: "Parser",
            dependencies: [
                .product(name: "Zip", package: "Zip"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Semaphore", package: "Semaphore"),
                .target(name: "Common")
            ],
            swiftSettings: [
                .unsafeFlags(
                    ["-cross-module-optimization"],
                    .when(configuration: .release)
                )
            ]
        ),
        .target(
            name: "Common",
            swiftSettings: [
                .unsafeFlags(
                    ["-cross-module-optimization"],
                    .when(configuration: .release)
                )
            ]
        ),
        .target(
            name: "VKParser",
            dependencies: [
                .product(name: "Zip", package: "Zip"),
                .product(name: "Regex", package: "Regex"),
                .product(name: "Semaphore", package: "Semaphore"),
                .target(name: "Parser"),
                .target(name: "Common"),
            ],
            swiftSettings: [
                .unsafeFlags(
                    ["-cross-module-optimization"],
                    .when(configuration: .release)
                )
            ]
        ),
        .target(
            name: "BoostyParser",
            dependencies: [
                .product(name: "Zip", package: "Zip"),
                .product(name: "Semaphore", package: "Semaphore"),
                .target(name: "Parser"),
                .target(name: "Common"),
            ],
            swiftSettings: [
                .unsafeFlags(
                    ["-cross-module-optimization"],
                    .when(configuration: .release)
                )
            ]
        ),
        .executableTarget(
            name: "parse",
            dependencies: [
                .product(
                    name: "ArgumentParser",
                    package: "swift-argument-parser"
                ),
                .target(name: "VKParser"),
                .target(name: "BoostyParser")
            ]
        ),
        .testTarget(
            name: "ParserTests",
            dependencies: ["Parser"]),
    ]
)
