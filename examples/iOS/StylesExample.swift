import SwiftUI
import ToastKit

/// The same toast drawn three ways: the default glass with a theme of your own, the bare
/// `.plain` style, and a `ToastStyle` written from scratch.
struct StylesExample: View {
    enum Look: String, CaseIterable, Identifiable {
        case themedGlass
        case plain
        case banner

        var id: Self { self }

        var title: String {
            switch self {
            case .themedGlass: "Themed glass"
            case .plain: "Plain"
            case .banner: "Banner"
            }
        }
    }

    @State private var look: Look = .themedGlass
    @State private var toasts = ToastCenter()

    var body: some View {
        NavigationStack {
            Form {
                Picker("Style", selection: $look) {
                    ForEach(Look.allCases) { look in
                        Text(look.title).tag(look)
                    }
                }
                .pickerStyle(.inline)

                Button("Show toast") {
                    toasts.present(
                        .notification,
                        title: "Drawn by \(look.title.lowercased())",
                        message: "Swipe or hold it: the gestures are the same in every style."
                    )
                }
            }
            .navigationTitle("Styles")
        }
        .modifier(StyledToasts(look: look, toasts: toasts))
    }
}

/// Attaches the stack in the chosen look. The kit's views draw nothing; the style in
/// effect draws every card.
private struct StyledToasts: ViewModifier {
    let look: StylesExample.Look
    let toasts: ToastCenter

    func body(content: Content) -> some View {
        switch look {
        case .themedGlass:
            content
                .toasts(toasts)
                .toastTheme(ToastTheme(
                    titleFont: .headline,
                    tint: { status in status == .notification ? .pink : ToastTheme.standardTint(status) },
                    cornerRadius: 14
                ))
        case .plain:
            content
                .toasts(toasts)
                .toastStyle(.plain)
        case .banner:
            content
                .toasts(toasts)
                .toastStyle(BannerToastStyle())
        }
    }
}

/// A style written from scratch: white on indigo, laid out from the configuration's parts.
private struct BannerToastStyle: ToastStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            configuration.icon
            VStack(alignment: .leading, spacing: 2) {
                configuration.title.bold()
                configuration.message?.font(.footnote)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(14)
        .background(.indigo, in: .rect(cornerRadius: 14))
        .opacity(configuration.isLifted ? 0.85 : 1)
    }
}
