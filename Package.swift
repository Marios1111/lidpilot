// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LidPilotRuntime",
    platforms: [.macOS(.v15)],
    products: [.library(name: "LidPilotRuntime", type: .static, targets: ["LidPilotRuntime"])],
    dependencies: [.package(path: "Core")],
    targets: [
        .target(name: "LidPilotRuntime", dependencies: [.product(name: "LidPilotCore", package: "Core")], path: "Runtime"),
        .testTarget(name: "LidPilotRuntimeTests", dependencies: ["LidPilotRuntime"], path: "Tests")
    ]
)
