import Foundation
import SwiftUI
import ToastKit

enum DemoTab: Hashable, CaseIterable {
    case playground
    case styles
    case sizes
    case dismissal
    case progress

    var title: LocalizedStringKey {
        switch self {
        case .playground: "Playground"
        case .styles:     "Styles"
        case .sizes:      "Sizes"
        case .dismissal:  "Dismissal"
        case .progress:   "Progress"
        }
    }

    var systemImage: String {
        switch self {
        case .playground: "rectangle.stack"
        case .styles:     "paintpalette"
        case .sizes:      "textformat.size"
        case .dismissal:  "xmark.bin"
        case .progress:   "arrow.up.circle"
        }
    }
}

/// The demo's root: five screens in the platform's native tab bar.
struct ContentView: View {
    @State private var toasts = ToastCenter()
    @State private var settings = DemoSettings()
    @State private var selectedTab = DemoTab.playground

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                PlaygroundView(toasts: toasts, settings: settings)
                    .demoToasts(toasts, settings: settings)
            }
            .tabItem { Label(DemoTab.playground.title, systemImage: DemoTab.playground.systemImage) }
            .tag(DemoTab.playground)

            NavigationStack {
                StylesView(toasts: toasts, settings: settings)
                    .demoToasts(toasts, settings: settings)
            }
            .tabItem { Label(DemoTab.styles.title, systemImage: DemoTab.styles.systemImage) }
            .tag(DemoTab.styles)

            NavigationStack {
                // The panes own their centers, so this page's stack stays empty.
                SizesView(settings: settings)
                    .demoToasts(toasts, settings: settings)
            }
            .tabItem { Label(DemoTab.sizes.title, systemImage: DemoTab.sizes.systemImage) }
            .tag(DemoTab.sizes)

            NavigationStack {
                DismissalView(toasts: toasts, settings: settings)
                    .demoToasts(toasts, settings: settings)
            }
            .tabItem { Label(DemoTab.dismissal.title, systemImage: DemoTab.dismissal.systemImage) }
            .tag(DemoTab.dismissal)

            NavigationStack {
                ProgressDemoView(toasts: toasts, settings: settings)
                    .demoToasts(toasts, settings: settings)
            }
            .tabItem { Label(DemoTab.progress.title, systemImage: DemoTab.progress.systemImage) }
            .tag(DemoTab.progress)
        }
    }
}

private extension View {
    /// Hosts the shared toast center on a page, with the demo's style, theme, size and
    /// action log.
    func demoToasts(_ toasts: ToastCenter, settings: DemoSettings) -> some View {
        self
            .toasts(toasts, placement: settings.placement)
            // Style, theme and the action observer are read from the environment by the
            // stack, so they go outside `.toasts(_:)`.
            .demoToastStyle(settings.style)
            .toastTheme(settings.theme == .brand ? .brand : .standard)
            .toastMetrics(settings.size.metrics)
            .toastSwipeHints(settings.immediateSwipeHints ? .immediate : .afterHold)
            .toastRemoval(settings.removal.removal(settings.direction.direction))
            .onToastAction { toast, action in
                settings.recentActions.append("\(action.title) — \(toast.title)")
            }
    }
}

#Preview {
    ContentView()
}
