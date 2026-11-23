// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SkipperCore",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SkipperCore", targets: ["SkipperCore"])
    ],
    targets: [
        .target(name: "SkipperCore"),
        .testTarget(name: "SkipperCoreTests", dependencies: ["SkipperCore"])
    ]
)
