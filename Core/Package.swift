// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LidPilotCore",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "LidPilotCore",
            targets: ["LidPilotCore"]
        )
    ],
    targets: [
        .target(name: "LidPilotCore"),
        .testTarget(
            name: "LidPilotCoreTests",
            dependencies: ["LidPilotCore"]
        )
    ],
    swiftLanguageModes: [.v6]
)
