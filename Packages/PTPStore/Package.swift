// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PTPStore",
    platforms: [.iOS("18.4"), .macOS(.v15)],
    products: [
        .library(name: "PTPStore", targets: ["PTPStore"])
    ],
    targets: [
        .target(name: "PTPStore"),
        .testTarget(name: "PTPStoreTests", dependencies: ["PTPStore"])
    ]
)
