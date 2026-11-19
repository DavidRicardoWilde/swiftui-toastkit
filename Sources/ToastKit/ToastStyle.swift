import SwiftUI

// MARK: - Protocol

/// How a toast card is drawn.
///
/// The kit's views own behaviour only — stacking, timing, gestures, the long-press
/// track, accessibility — and draw nothing of their own. Every pixel of a card comes
/// from the style in effect, the way a `ButtonStyle` draws a `Button`.
///
/// Two styles ship with the kit:
///
/// - ``GlassToastStyle`` (`.glass`) — frosted glass tinted by status, with a glyph chip.
///   The default, tuned through ``ToastTheme``.
/// - ``PlainToastStyle`` (`.plain`) — icon, title and message with no surface at all:
///   the unstyled starting point for your own.
///
/// Write your own by laying out the configuration's parts:
///
/// ```swift
/// struct BannerToastStyle: ToastStyle {
///     func makeBody(configuration: Configuration) -> some View {
///         HStack(spacing: 12) {
///             configuration.icon
///                 .foregroundStyle(.white)
///             VStack(alignment: .leading, spacing: 2) {
///                 configuration.title.bold()
///                 configuration.message?.font(.footnote)
///             }
///             Spacer(minLength: 0)
///         }
///         .foregroundStyle(.white)
///         .padding(14)
///         .background(.indigo, in: .rect(cornerRadius: 14))
///         .opacity(configuration.isLifted ? 0.85 : 1)
///     }
/// }
///
/// MyScreen()
///     .toasts(toasts)
///     .toastStyle(BannerToastStyle())
/// ```
///
/// A style draws the card at rest and while it rides the long-press track
/// (``ToastStyleConfiguration/isLifted``); the kit scales, moves and turns whatever the
/// style returns. Fill the width you are given: the stack sets each card's width.
public protocol ToastStyle {
    associatedtype Body: View

    /// The card for one toast.
    @ViewBuilder @MainActor
    func makeBody(configuration: Configuration) -> Body

    typealias Configuration = ToastStyleConfiguration

    /// Whether the style lays out ``ToastStyleConfiguration/progress`` itself. When it does
    /// not, which is the default, the kit adds a bar and a button under what the style
    /// draws, so a progress toast is never left without them.
    static var drawsProgress: Bool { get }
}

public extension ToastStyle {
    /// False: the kit adds the bar and button.
    static var drawsProgress: Bool { false }
}

/// What a ``ToastStyle`` draws a card from.
public struct ToastStyleConfiguration {

    /// The toast being drawn, for anything the ready-made parts below do not cover.
    public let toast: ToastMessage

    /// The toast's icon: its own, or its status's symbol.
    public let icon: Image

    /// The title as text, unstyled.
    public let title: Text

    /// The message as text, unstyled. `nil` when the toast has none.
    public let message: Text?

    /// True while a long press has lifted the card onto its action track. The kit
    /// shrinks the card to half size; a style may also thin its surface so the track
    /// shows through, as ``GlassToastStyle`` does.
    public let isLifted: Bool

    /// True when tapping the card runs an action, so a style can hint at it.
    public let isTappable: Bool

    /// The sizes in effect, as set with `toastMetrics(_:)`, with any title font, message
    /// font, corner radius or content padding the ``ToastTheme`` sets explicitly laid over
    /// them. ``GlassToastStyle`` draws from them; a custom style may do the same, or
    /// ignore them.
    public let metrics: ToastMetrics

    /// The bar, the detail line and the buttons of a progress toast. `nil` for any other
    /// toast, and for a progress toast that has finished, except a failure that offers
    /// Retry. Draw it only if the style sets ``ToastStyle/drawsProgress``; otherwise the
    /// kit adds a bar and a button under the card.
    public let progress: ToastProgressConfiguration?

    public var status: ToastMessage.Status { toast.status }

    init(
        toast: ToastMessage,
        isLifted: Bool,
        isTappable: Bool,
        metrics: ToastMetrics = .regular,
        progress: ToastProgressConfiguration? = nil
    ) {
        self.toast = toast
        self.icon = toast.icon?.image ?? Image(systemName: toast.status.symbolName)
        self.title = Text(toast.title)
        if let message = toast.message, !message.isEmpty {
            self.message = Text(message)
        } else {
            self.message = nil
        }
        self.isLifted = isLifted
        self.isTappable = isTappable
        self.metrics = metrics
        self.progress = progress
    }
}

// MARK: - Applying a style

public extension View {
    /// Draws every toast below this point with `style`.
    ///
    /// ```swift
    /// MyScreen()
    ///     .toasts(toasts)
    ///     .toastStyle(.plain)
    /// ```
    func toastStyle<S: ToastStyle>(_ style: S) -> some View {
        environment(\.toastStyle, AnyToastStyle(style))
    }
}

/// A type-erased style, so the environment can hold any of them.
struct AnyToastStyle {
    private let body: @MainActor (ToastStyleConfiguration) -> AnyView
    /// Whether the style lays out the progress parts itself.
    let drawsProgress: Bool

    init<S: ToastStyle>(_ style: S) {
        drawsProgress = S.drawsProgress
        body = { configuration in AnyView(style.makeBody(configuration: configuration)) }
    }

    @MainActor
    func makeBody(configuration: ToastStyleConfiguration) -> AnyView {
        body(configuration)
    }
}

private struct ToastStyleKey: EnvironmentKey {
    static let defaultValue = AnyToastStyle(GlassToastStyle())
}

extension EnvironmentValues {
    var toastStyle: AnyToastStyle {
        get { self[ToastStyleKey.self] }
        set { self[ToastStyleKey.self] = newValue }
    }
}

// MARK: - Icons

extension ToastIcon {
    var image: Image {
        switch self {
        case .system(let name):
            Image(systemName: name)
        case .asset(let name, let bundle):
            Image(name, bundle: bundle)
        }
    }
}

// MARK: - Glass

/// Frosted glass tinted by the toast's status, with a glyph chip beside the text. The
/// default style.
///
/// Its colours, type, metrics and elevation come from ``ToastTheme`` — set one with
/// `.toastTheme(_:)` to adopt a design system without writing a style. Under Reduce
/// Transparency the glass turns opaque; under Increase Contrast its gradient edge turns
/// solid. While lifted onto the action track it thins, so the track shows through.
public struct GlassToastStyle: ToastStyle {
    public init() {}

    public static var drawsProgress: Bool { true }

    public func makeBody(configuration: Configuration) -> some View {
        GlassToastCard(configuration: configuration)
    }
}

public extension ToastStyle where Self == GlassToastStyle {
    /// Frosted glass tinted by status. The default.
    static var glass: GlassToastStyle { GlassToastStyle() }
}

private struct GlassToastCard: View {
    let configuration: ToastStyleConfiguration

    @Environment(\.toastTheme) private var theme

    var body: some View {
        // Sizes from the metrics, except where the theme sets one explicitly.
        let metrics = configuration.metrics.resolved(in: theme)
        HStack(alignment: configuration.progress == nil ? .top : .center, spacing: metrics.glyphSpacing) {
            ToastGlyph(status: configuration.status, icon: configuration.icon, side: metrics.glyphSide)

            VStack(alignment: .leading, spacing: metrics.textSpacing) {
                if let progress = configuration.progress {
                    progressText(progress, metrics: metrics)
                } else {
                    text(metrics: metrics)
                }
            }
            // A card that finishes in place fades from one wording to the next, without
            // scaling, so there is nothing for Reduce Motion to take away.
            .contentTransition(.opacity)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.25), value: configuration.toast.progressPhase)

            Spacer(minLength: 0)

            if let progress = configuration.progress {
                trailingButton(progress)
            }
        }
        .padding(metrics.contentPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .toastGlassSurface(status: configuration.status, lifted: configuration.isLifted)
    }

    @ViewBuilder
    private func text(metrics: ToastMetrics) -> some View {
        configuration.title
            .font(metrics.titleFont)
            .foregroundStyle(theme.textPrimary)
            .lineLimit(metrics.titleLineLimit)

        if let message = configuration.message {
            message
                .font(metrics.messageFont)
                .foregroundStyle(theme.textSecondary)
                .lineLimit(metrics.messageLineLimit)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The text of a card with work behind it: the title and percent on one row, the
    /// message, the detail line and the bar. Line limits are fixed and digits are
    /// monospaced, so a tick never changes the card's height.
    @ViewBuilder
    private func progressText(_ progress: ToastProgressConfiguration, metrics: ToastMetrics) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            configuration.title
                .font(metrics.titleFont)
                .foregroundStyle(theme.textPrimary)
                .lineLimit(progress.phase.isActive ? metrics.progressTitleLineLimit : metrics.titleLineLimit)
            Spacer(minLength: 0)
            if progress.phase.isActive, let percent = progress.percent {
                percent
                    .font(metrics.messageFont)
                    .monospacedDigit()
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
            }
        }

        if let message = configuration.message {
            message
                .font(metrics.messageFont)
                .foregroundStyle(theme.textSecondary)
                .lineLimit(metrics.messageLineLimit)
                .fixedSize(horizontal: false, vertical: true)
        }

        if metrics.progressDetailLineLimit != 0, progress.phase.isActive {
            // The slot is always reserved while the work runs, so the first words of a
            // detail line do not push the bar down.
            (progress.detail ?? Text(" "))
                .font(metrics.messageFont)
                .monospacedDigit()
                .foregroundStyle(theme.textSecondary)
                .lineLimit(metrics.progressDetailLineLimit)
                .opacity(progress.detail == nil ? 0 : 1)
        }

        if progress.phase.isActive {
            progress.bar
                .padding(.top, metrics.progressSpacing - metrics.textSpacing)
        }
    }

    @ViewBuilder
    private func trailingButton(_ progress: ToastProgressConfiguration) -> some View {
        progress.cancelButton
        progress.retryButton
    }
}

/// The status glyph on a tinted chip.
private struct ToastGlyph: View {
    let status: ToastMessage.Status
    let icon: Image

    @Environment(\.toastTheme) private var theme
    @ScaledMetric private var side: CGFloat

    init(status: ToastMessage.Status, icon: Image, side: CGFloat) {
        self.status = status
        self.icon = icon
        _side = ScaledMetric(wrappedValue: side, relativeTo: .callout)
    }

    var body: some View {
        let tint = status.tint(in: theme)
        return icon
            // Already scaled by `side`; scaling the glyph again would compound it.
            .font(.system(size: side * 0.52, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: side, height: side)
            .background { Circle().fill(tint.opacity(0.18)) }
            .overlay { Circle().strokeBorder(tint.opacity(0.30), lineWidth: 0.8) }
            .accessibilityHidden(true)
    }
}

// MARK: - Plain

/// Icon, title and message, and nothing else: no surface, no colour, no fixed type.
///
/// The unstyled baseline. Use it as the starting point for your own look, wrapping it in
/// whatever surface your design system uses:
///
/// ```swift
/// struct CardToastStyle: ToastStyle {
///     func makeBody(configuration: Configuration) -> some View {
///         PlainToastStyle().makeBody(configuration: configuration)
///             .padding()
///             .background(.background, in: .rect(cornerRadius: 12))
///             .shadow(radius: 8, y: 4)
///     }
/// }
/// ```
public struct PlainToastStyle: ToastStyle {
    public init() {}

    public static var drawsProgress: Bool { true }

    public func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: configuration.metrics.progressSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                configuration.icon
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    configuration.title
                    if let message = configuration.message {
                        message
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let progress = configuration.progress {
                HStack(spacing: 8) {
                    if progress.phase.isActive {
                        progress.bar
                    } else {
                        Spacer(minLength: 0)
                    }
                    progress.cancelButton
                    progress.retryButton
                }
            }
        }
    }
}

public extension ToastStyle where Self == PlainToastStyle {
    /// No surface at all: the unstyled starting point.
    static var plain: PlainToastStyle { PlainToastStyle() }
}
