// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SpeakerStatusPrototype",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "upnp-status", targets: ["UPnPStatus"]),
        .executable(name: "cloud-status", targets: ["CloudStatus"]),
    ],
    targets: [
        .target(name: "PrototypeSupport"),
        .executableTarget(name: "UPnPStatus", dependencies: ["PrototypeSupport"]),
        .executableTarget(name: "CloudStatus", dependencies: ["PrototypeSupport"]),
        .testTarget(name: "PrototypeSupportTests", dependencies: ["PrototypeSupport"]),
    ]
)
