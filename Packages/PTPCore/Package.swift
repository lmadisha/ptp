// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PTPCore",
    platforms: [.iOS("18.4"), .watchOS(.v11), .macOS(.v15)],
    products: [
        .library(name: "PTPCore", targets: ["PTPCore"])
    ],
    targets: [
        .target(name: "PTPCore"),
        .testTarget(name: "PTPCoreTests", dependencies: ["PTPCore"])
    ]
)
