// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SleeperKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SleeperKit", targets: ["SleeperKit"]),
        .library(name: "SleeperKitMocks", targets: ["SleeperKitMocks"]),
    ],
    targets: [
        .target(
            name: "SleeperKit",
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .target(
            name: "SleeperKitMocks",
            dependencies: ["SleeperKit"],
            resources: [.process("Fixtures")],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .testTarget(
            name: "SleeperKitTests",
            dependencies: ["SleeperKit", "SleeperKitMocks"]
        ),
    ]
)
