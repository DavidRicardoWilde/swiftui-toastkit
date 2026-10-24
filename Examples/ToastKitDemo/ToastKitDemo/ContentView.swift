import SwiftUI
import ToastKit

enum DemoTab: Hashable {
    case playground
    case styles
}

/// The demo's root: two screens behind a custom tab bar drawn in a `ZStack`.
///
/// The tab bar is not a system `TabView`, so the safe area knows nothing about it. It is
/// marked with `toastObstruction()`, and the stack lifts itself clear of it.
struct ContentView: View {
    @State private var toasts = ToastCenter()
    @State private var settings = DemoSettings()
    @State private var selectedTab = DemoTab.playground

    var body: some View {
        ZStack(alignment: .bottom) {
            NavigationStack {
                // Each page hosts its own stack, so top toasts sit below the navigation
                // bar instead of over the title.
                switch selectedTab {
                case .playground:
                    PlaygroundView(toasts: toasts, settings: settings)
                        .demoToasts(toasts, settings: settings)
                case .styles:
                    StylesView(toasts: toasts, settings: settings)
                        .demoToasts(toasts, settings: settings)
                }
            }
            // Keep the last rows of each form scrollable above the floating tab bar.
            .contentMargins(.bottom, settings.tallTabBar ? 120 : 80, for: .scrollContent)

            CustomTabBar(selection: $selectedTab, isTall: settings.tallTabBar)
                .toastObstruction()
        }
        // The tab bar is beside the pages' stacks rather than inside them, so the
        // nearest common container opens a scope that lets the stacks see it.
        .toastObstructionScope()
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
            .onToastAction { toast, action in
                settings.recentActions.append("\(action.title) — \(toast.title)")
            }
    }
}

/// A floating tab bar of plain buttons, standing in for an app's own design.
struct CustomTabBar: View {
    @Binding var selection: DemoTab
    var isTall: Bool

    var body: some View {
        HStack(spacing: 0) {
            TabButton(title: "Playground", systemImage: "rectangle.stack", isSelected: selection == .playground) {
                selection = .playground
            }
            TabButton(title: "Styles", systemImage: "paintpalette", isSelected: selection == .styles) {
                selection = .styles
            }
        }
        .padding(.horizontal, 8)
        .frame(height: isTall ? 96 : 56)
        .background(.regularMaterial, in: .rect(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .animation(.snappy, value: isTall)
    }
}

struct TabButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
}
