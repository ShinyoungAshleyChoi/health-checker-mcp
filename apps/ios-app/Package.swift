// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HealthCheckerApp",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .executable(name: "HealthCheckerApp", targets: ["HealthCheckerApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0")
    ],
    targets: [
        .executableTarget(
            name: "HealthCheckerApp",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/HealthCheckerApp"
        ),
        .testTarget(
            name: "HealthCheckerAppTests",
            dependencies: ["HealthCheckerApp"],
            path: "Tests/HealthCheckerAppTests"
        )
    ]
)
