// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NearMeCore",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "NearMeCore", targets: ["NearMeCore"])
    ],
    targets: [
        .target(name: "NearMeCore"),
        .testTarget(name: "NearMeCoreTests", dependencies: ["NearMeCore"])
    ]
)
