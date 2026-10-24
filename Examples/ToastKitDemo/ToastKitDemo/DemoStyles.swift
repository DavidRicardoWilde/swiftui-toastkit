import SwiftUI
import ToastKit

/// A style written from scratch: a solid banner coloured by status, ignoring the theme's
/// surfaces entirely.
struct BannerToastStyle: ToastStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            configuration.icon
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                configuration.title
                    .bold()
                if let message = configuration.message {
                    message
                        .font(.footnote)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            if configuration.isTappable {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
            }
        }
        .foregroundStyle(.white)
        .padding(14)
        .background(Self.color(for: configuration.status), in: .rect(cornerRadius: 14))
        .opacity(configuration.isLifted ? 0.85 : 1)
    }

    private static func color(for status: ToastMessage.Status) -> Color {
        switch status {
        case .normal:       .indigo
        case .warning:      .orange
        case .error:        .red
        case .notification: .teal
        }
    }
}

extension ToastTheme {
    /// An app palette adopted through `statusTint`, plus a few type and shape tokens.
    static let brand = ToastTheme(
        titleFont: .headline,
        tint: ToastTheme.statusTint(
            normal: .teal,
            warning: .yellow,
            error: .pink,
            notification: .purple
        ),
        cornerRadius: 14
    )
}

private struct DemoToastStyleModifier: ViewModifier {
    let choice: StyleChoice

    @ViewBuilder
    func body(content: Content) -> some View {
        // `toastStyle(_:)` is generic, so each choice is its own branch.
        switch choice {
        case .glass:
            content.toastStyle(.glass)
        case .plain:
            content.toastStyle(.plain)
        case .custom:
            content.toastStyle(BannerToastStyle())
        }
    }
}

extension View {
    func demoToastStyle(_ choice: StyleChoice) -> some View {
        modifier(DemoToastStyleModifier(choice: choice))
    }
}

extension ToastMessage.Status {
    var displayName: String { rawValue.capitalized }

    var symbolName: String {
        switch self {
        case .normal:       "checkmark.circle"
        case .warning:      "exclamationmark.triangle"
        case .error:        "xmark.octagon"
        case .notification: "bell"
        }
    }
}
