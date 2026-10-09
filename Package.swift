// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MultiroomKit",
    platforms: [.macOS(.v13), .iOS(.v16), .tvOS(.v16)],
    products: [.library(name: "MultiroomKit", targets: ["MultiroomKit"])],
    targets: [
        .target(name: "MultiroomKit"),
        .testTarget(name: "MultiroomKitTests", dependencies: ["MultiroomKit"]),
        .testTarget(name: "MultiroomKitIntegrationTests", dependencies: ["MultiroomKit"]),
        .testTarget(name: "MultiroomKitLiveTests", dependencies: ["MultiroomKit"]),
    ]
)
