// swift-tools-version: 5.10
import PackageDescription

/// Platform-agnostic stacked toast notifications.
///
/// Deliberately depends on nothing but SwiftUI: the host app injects its own colours,
/// metrics, type and motion through `ToastTheme`, so a macOS, tvOS or visionOS app can
/// adopt this without inheriting another platform's design tokens.
let package = Package(
    name: "ToastKit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10),
        .visionOS(.v1)
        // No tvOS: `DragGesture` is unavailable there, and swipe-to-dismiss is the
        // component's primary interaction. A tvOS toast needs a focus-driven dismissal,
        // which is a redesign rather than a port — see README.
    ],
    products: [
        .library(name: "ToastKit", targets: ["ToastKit"])
    ],
    targets: [
        .target(name: "ToastKit", resources: [.process("Resources")]),
        .testTarget(name: "ToastKitTests", dependencies: ["ToastKit"])
    ]
)
