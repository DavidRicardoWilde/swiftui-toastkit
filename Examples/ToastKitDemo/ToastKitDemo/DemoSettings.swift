import Observation
import SwiftUI
import ToastKit

/// Which ``ToastStyle`` the demo draws its cards with.
enum StyleChoice: String, CaseIterable, Identifiable {
    case glass = "Glass"
    case plain = "Plain"
    case custom = "Custom"

    var id: String { rawValue }
}

/// Which ``ToastTheme`` the demo applies.
enum ThemeChoice: String, CaseIterable, Identifiable {
    case standard = "Standard"
    case brand = "Brand"

    var id: String { rawValue }
}

/// Which ``ToastMetrics`` preset the demo applies.
enum SizeChoice: String, CaseIterable, Identifiable {
    case compact = "Compact"
    case regular = "Regular"
    case large = "Large"

    var id: String { rawValue }

    var metrics: ToastMetrics {
        switch self {
        case .compact: .compact
        case .regular: .regular
        case .large:   .large
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
    /// Grows the custom tab bar, to show the stack following an obstruction's height.
    var tallTabBar = false
    /// Every action run on a toast, newest last, as reported by `onToastAction`.
    var recentActions: [String] = []
}
