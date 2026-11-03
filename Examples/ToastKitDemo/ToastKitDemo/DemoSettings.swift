import Foundation
import Observation
import SwiftUI
import ToastKit

/// Which ``ToastStyle`` the demo draws its cards with.
enum StyleChoice: String, CaseIterable, Identifiable {
    case glass = "Glass"
    case plain = "Plain"
    case custom = "Custom"

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .glass:  String(localized: "Glass")
        case .plain:  String(localized: "Plain")
        case .custom: String(localized: "Custom")
        }
    }
}

/// Which ``ToastTheme`` the demo applies.
enum ThemeChoice: String, CaseIterable, Identifiable {
    case standard = "Standard"
    case brand = "Brand"

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .standard: String(localized: "Standard")
        case .brand:    String(localized: "Brand")
        }
    }
}

/// Which ``ToastMetrics`` preset the demo applies.
enum SizeChoice: String, CaseIterable, Identifiable {
    case compact = "Compact"
    case regular = "Regular"
    case large = "Large"

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .compact: String(localized: "Compact")
        case .regular: String(localized: "Regular")
        case .large:   String(localized: "Large")
        }
    }

    var metrics: ToastMetrics {
        switch self {
        case .compact: .compact
        case .regular: .regular
        case .large:   .large
        }
    }
}

/// Which ``ToastRemoval`` style the demo uses by default.
enum RemovalChoice: String, CaseIterable, Identifiable {
    case fade = "Fade"
    case slide = "Slide"
    case trail = "Trail"

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .fade:  String(localized: "Fade")
        case .slide: String(localized: "Slide")
        case .trail: String(localized: "Trail")
        }
    }

    func removal(_ direction: ToastRemovalDirection) -> ToastRemoval {
        switch self {
        case .fade:  .fade
        case .slide: .slide(direction)
        case .trail: .trail(direction)
        }
    }
}

/// Which ``ToastRemovalDirection`` slides and trails travel in.
enum DirectionChoice: String, CaseIterable, Identifiable {
    case towardAnchor = "Toward edge"
    case awayFromAnchor = "Away from edge"
    case top = "Up"
    case bottom = "Down"
    case leading = "Leading"
    case trailing = "Trailing"
    case upRight = "Up and right"

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .towardAnchor:   String(localized: "Toward edge")
        case .awayFromAnchor: String(localized: "Away from edge")
        case .top:            String(localized: "Up")
        case .bottom:         String(localized: "Down")
        case .leading:        String(localized: "Leading")
        case .trailing:       String(localized: "Trailing")
        case .upRight:        String(localized: "Up and right")
        }
    }

    var direction: ToastRemovalDirection {
        switch self {
        case .towardAnchor:   .towardAnchor
        case .awayFromAnchor: .awayFromAnchor
        case .top:            .top
        case .bottom:         .bottom
        case .leading:        .leading
        case .trailing:       .trailing
        case .upRight:        .degrees(-45)
        }
    }
}

/// Everything the demo's controls change, shared by both tabs.
@Observable
final class DemoSettings {
    var style: StyleChoice = .glass
    var theme: ThemeChoice = .standard
    var size: SizeChoice = .regular
    var placement: ToastPlacement = .bottom
    var removal: RemovalChoice = .fade
    var direction: DirectionChoice = .towardAnchor
    /// Grows the custom tab bar, to show the stack following an obstruction's height.
    var tallTabBar = false
    /// Every action run on a toast, newest last, as reported by `onToastAction`.
    var recentActions: [String] = []
}
