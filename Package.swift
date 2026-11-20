// swift-tools-version: 5.10
import PackageDescription

/// Stacked toast notifications for iOS.
let package = Package(
    name: "ToastKit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "ToastKit", targets: ["ToastKit"])
    ],
    targets: [
        .target(name: "ToastKit", resources: [.process("Resources")]),
        .testTarget(name: "ToastKitTests", dependencies: ["ToastKit"])
    ]
)
