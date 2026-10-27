import SwiftUI

/// How big toast cards are drawn.
///
/// Metrics own *size*: width, padding, type, the glyph chip, corner radius, line limits
/// and the scale of the long-press track. A ``ToastTheme`` owns identity and a
/// ``ToastStyle`` owns drawing, so the three combine freely — a brand theme in a compact
/// size, say. Three presets ship, each tuned per platform:
///
/// ```swift
/// MyScreen()
///     .toasts(toasts)
///     .toastMetrics(.compact)
/// ```
///
/// ``regular`` is the default and matches what the kit drew before, except on watchOS,
/// where it is the width of the screen, and that Dynamic Type is now capped at
/// `.accessibility1`. ``compact`` and ``large`` shrink and grow
/// the card; on watchOS they are always full width, so ``large`` means bigger type rather
/// than a wider card.
///
/// Build your own with the initializer; every parameter defaults to its ``regular`` value.
///
/// ```swift
/// ToastMetrics(width: .fraction(0.8), cornerRadius: 12, messageLineLimit: 3)
/// ```
///
/// Where each setting wins:
///
/// - **Width:** an explicit `width:` given to `.toasts(_:width:)` or ``ToastStack`` beats
///   ``width``, which beats the platform default (60% of the safe area, full width on
///   watchOS).
/// - **Fonts, padding and corner radius:** a value set explicitly on a ``ToastTheme``
///   beats the metrics'.
/// - **Stack offset:** each buried card peeks out by the average of the preset's top and
///   bottom ``contentPadding``; a theme's padding does not change it.
///
/// Every style gets the width, the stack offset, ``actionTrackScale``, the track label
/// fonts and ``maximumDynamicTypeSize``. Only ``GlassToastStyle`` draws the padding, fonts,
/// glyph chip, corner radius and line limits. A custom ``ToastStyle`` can read all of them
/// from ``ToastStyleConfiguration/metrics``, which has the theme's explicit fonts, radius
/// and padding already laid over them.
public struct ToastMetrics: Equatable, Sendable {

    /// How wide cards are drawn. `nil` uses the platform default: 60% of the safe-area
    /// width, or the full width on watchOS. An explicit `width:` given to the stack wins.
    public var width: ToastWidth?

    /// Space between the card's edge and its content.
    public var contentPadding: EdgeInsets

    public var titleFont: Font
    public var messageFont: Font

    /// Side of the glyph chip before Dynamic Type scales it, relative to `.callout`.
    public var glyphSide: CGFloat
    /// Gap between the glyph chip and the text.
    public var glyphSpacing: CGFloat
    /// Gap between the title and the message.
    public var textSpacing: CGFloat

    public var cornerRadius: CGFloat

    /// The most lines the title takes. `nil` for no limit.
    public var titleLineLimit: Int?
    /// The most lines the message takes. `nil` for no limit.
    public var messageLineLimit: Int?

    /// Scales the long-press track — its band, its height and how far the card rises on
    /// it — so a larger card still fits. 1 is the regular size. The distance a finger
    /// travels to arm an action does not scale.
    public var actionTrackScale: CGFloat
    /// Type of an action's title on the track.
    public var actionTitleFont: Font
    /// Type of an action's subtitle on the track.
    public var actionSubtitleFont: Font

    /// The largest Dynamic Type size toast content grows to. Larger sizes draw as this
    /// one, so a card stays a toast rather than filling the screen.
    public var maximumDynamicTypeSize: DynamicTypeSize

    /// Height of the progress bar.
    public var progressBarHeight: CGFloat
    /// Gap between the progress card's text and its bar.
    public var progressSpacing: CGFloat
    /// The most lines a progress card's title takes while the work runs. `nil` for no limit.
    public var progressTitleLineLimit: Int?
    /// The most lines a progress card's detail line takes. 0 hides the line, leaving the
    /// percentage alone. `nil` for no limit.
    public var progressDetailLineLimit: Int?
    /// Side of the Cancel and Retry buttons before the minimum hit target is applied.
    public var progressButtonSide: CGFloat

    public init(
        width: ToastWidth? = nil,
        contentPadding: EdgeInsets = EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16),
        titleFont: Font = .callout.weight(.medium),
        messageFont: Font = .footnote,
        glyphSide: CGFloat = 30,
        glyphSpacing: CGFloat = 12,
        textSpacing: CGFloat = 3,
        cornerRadius: CGFloat = 22,
        titleLineLimit: Int? = 2,
        messageLineLimit: Int? = 2,
        actionTrackScale: CGFloat = 1,
        actionTitleFont: Font = .caption.weight(.bold),
        actionSubtitleFont: Font = .caption2.weight(.medium),
        maximumDynamicTypeSize: DynamicTypeSize = .accessibility1,
        progressBarHeight: CGFloat = ToastMetrics.regularProgressBarHeight,
        progressSpacing: CGFloat = 8,
        progressTitleLineLimit: Int? = 1,
        progressDetailLineLimit: Int? = 1,
        progressButtonSide: CGFloat = ToastMetrics.regularProgressButtonSide
    ) {
        self.width = width
        self.contentPadding = contentPadding
        self.titleFont = titleFont
        self.messageFont = messageFont
        self.glyphSide = glyphSide
        self.glyphSpacing = glyphSpacing
        self.textSpacing = textSpacing
        self.cornerRadius = cornerRadius
        self.titleLineLimit = titleLineLimit
        self.messageLineLimit = messageLineLimit
        self.actionTrackScale = actionTrackScale
        self.actionTitleFont = actionTitleFont
        self.actionSubtitleFont = actionSubtitleFont
        self.maximumDynamicTypeSize = maximumDynamicTypeSize
        self.progressBarHeight = progressBarHeight
        self.progressSpacing = progressSpacing
        self.progressTitleLineLimit = progressTitleLineLimit
        self.progressDetailLineLimit = progressDetailLineLimit
        self.progressButtonSide = progressButtonSide
    }

    // A public default argument can't name the internal `ToastPlatform`, so the regular
    // values the initializer defaults to are read through these.
    @usableFromInline static let regularProgressBarHeight: CGFloat = ToastPlatform.current.regularProgressBarHeight
    @usableFromInline static let regularProgressButtonSide: CGFloat = ToastPlatform.current.regularProgressButtonSide

    // MARK: Presets

    /// Smaller type, tighter padding and a narrower card.
    public static let compact = compactTable(on: .current)

    /// The kit's standard size, and the default. The same on iOS, macOS and visionOS as it
    /// has always been; full width on watchOS.
    public static let regular = ToastMetrics()

    /// Larger type, roomier padding and a wider card.
    public static let large = largeTable(on: .current)

    // MARK: Derived values

    /// How far each buried card peeks past the one in front: the average of the top and
    /// bottom padding, so a roomier card shows a deeper stack. 14 pt for ``regular``. Read
    /// from the preset itself, never theme-resolved.
    var stackPeek: CGFloat {
        (contentPadding.top + contentPadding.bottom) / 2
    }

    /// The width to draw cards at: the explicit `width:` if there is one, else this
    /// metrics' width, else the platform default.
    func resolvedWidth(explicit: ToastWidth?, on platform: ToastPlatform = .current) -> ToastWidth {
        explicit ?? width ?? platform.defaultWidth
    }

    /// These metrics with the values `theme` sets explicitly laid over them.
    func resolved(in theme: ToastTheme) -> ToastMetrics {
        var metrics = self
        if let titleFont = theme.explicitTitleFont { metrics.titleFont = titleFont }
        if let messageFont = theme.explicitMessageFont { metrics.messageFont = messageFont }
        if let cornerRadius = theme.explicitCornerRadius { metrics.cornerRadius = cornerRadius }
        if let contentPadding = theme.explicitContentPadding { metrics.contentPadding = contentPadding }
        return metrics
    }
}

// MARK: - Platforms

/// The platforms whose presets differ. A value rather than `#if` in the tables, so a test
/// on any host can check all four.
enum ToastPlatform: CaseIterable {
    case iOS
    case macOS
    case watchOS
    case visionOS

    static var current: ToastPlatform {
        #if os(macOS)
        .macOS
        #elseif os(watchOS)
        .watchOS
        #elseif os(visionOS)
        .visionOS
        #else
        .iOS
        #endif
    }

    /// What a card is as wide as when nothing says otherwise.
    var defaultWidth: ToastWidth {
        self == .watchOS ? .fraction(1) : .default
    }

    /// The regular progress bar's height.
    var regularProgressBarHeight: CGFloat {
        switch self {
        case .iOS, .macOS, .watchOS: 4
        case .visionOS: 5
        }
    }

    /// The regular Cancel and Retry button's visual side.
    var regularProgressButtonSide: CGFloat {
        switch self {
        case .iOS: 28
        case .macOS: 22
        case .watchOS, .visionOS: 32
        }
    }
}

// MARK: - Preset tables

extension ToastMetrics {

    private static func insets(_ vertical: CGFloat, _ horizontal: CGFloat) -> EdgeInsets {
        EdgeInsets(top: vertical, leading: horizontal, bottom: vertical, trailing: horizontal)
    }

    static func compactTable(on platform: ToastPlatform) -> ToastMetrics {
        var metrics = ToastMetrics(
            titleLineLimit: 2,
            messageLineLimit: 2,
            actionTrackScale: 0.8,
            actionTitleFont: .caption2.weight(.bold),
            actionSubtitleFont: .caption2.weight(.medium)
        )
        metrics.progressButtonSide = platform.regularProgressButtonSide
        switch platform {
        case .iOS:
            metrics.width = .fraction(0.5)
            metrics.contentPadding = insets(10, 12)
            metrics.titleFont = .footnote.weight(.medium)
            metrics.messageFont = .caption
            metrics.glyphSide = 24
            metrics.glyphSpacing = 8
            metrics.textSpacing = 2
            metrics.cornerRadius = 16
            metrics.progressBarHeight = 3
            metrics.progressTitleLineLimit = 1
            metrics.progressDetailLineLimit = 1
        case .macOS:
            metrics.width = .points(280)
            metrics.contentPadding = insets(8, 10)
            metrics.titleFont = .callout.weight(.medium)
            metrics.messageFont = .caption
            metrics.glyphSide = 20
            metrics.glyphSpacing = 8
            metrics.textSpacing = 2
            metrics.cornerRadius = 12
            metrics.progressBarHeight = 3
            metrics.progressTitleLineLimit = 1
            metrics.progressDetailLineLimit = 1
        case .watchOS:
            metrics.width = .fraction(1)
            metrics.contentPadding = insets(8, 10)
            metrics.titleFont = .footnote.weight(.medium)
            metrics.messageFont = .caption2
            metrics.glyphSide = 20
            metrics.glyphSpacing = 6
            metrics.textSpacing = 1
            metrics.cornerRadius = 14
            metrics.progressBarHeight = 3
            metrics.progressTitleLineLimit = 1
            metrics.progressDetailLineLimit = 0
        case .visionOS:
            metrics.width = .fraction(0.5)
            metrics.contentPadding = insets(12, 14)
            metrics.titleFont = .callout.weight(.medium)
            metrics.messageFont = .footnote
            metrics.glyphSide = 28
            metrics.glyphSpacing = 10
            metrics.textSpacing = 2
            metrics.cornerRadius = 20
            metrics.progressBarHeight = 4
            metrics.progressTitleLineLimit = 1
            metrics.progressDetailLineLimit = 1
        }
        return metrics
    }

    static func largeTable(on platform: ToastPlatform) -> ToastMetrics {
        var metrics = ToastMetrics(
            titleLineLimit: 3,
            messageLineLimit: 4,
            actionTrackScale: 1.35,
            actionTitleFont: .footnote.weight(.bold),
            actionSubtitleFont: .caption.weight(.medium)
        )
        metrics.progressButtonSide = platform.regularProgressButtonSide
        switch platform {
        case .iOS:
            metrics.width = .fraction(0.8)
            metrics.contentPadding = insets(18, 20)
            metrics.titleFont = .body.weight(.semibold)
            metrics.messageFont = .subheadline
            metrics.glyphSide = 38
            metrics.glyphSpacing = 14
            metrics.textSpacing = 4
            metrics.cornerRadius = 28
            metrics.progressBarHeight = 6
            metrics.progressTitleLineLimit = 2
            metrics.progressDetailLineLimit = 1
        case .macOS:
            metrics.width = .points(480)
            metrics.contentPadding = insets(16, 18)
            metrics.titleFont = .body.weight(.semibold)
            metrics.messageFont = .callout
            metrics.glyphSide = 34
            metrics.glyphSpacing = 14
            metrics.textSpacing = 4
            metrics.cornerRadius = 22
            metrics.progressBarHeight = 5
            metrics.progressTitleLineLimit = 2
            metrics.progressDetailLineLimit = 1
        case .watchOS:
            metrics.width = .fraction(1)
            metrics.contentPadding = insets(12, 14)
            metrics.titleFont = .headline
            metrics.messageFont = .footnote
            metrics.glyphSide = 32
            metrics.glyphSpacing = 10
            metrics.textSpacing = 2
            metrics.cornerRadius = 24
            metrics.progressBarHeight = 5
            metrics.progressTitleLineLimit = 2
            metrics.progressDetailLineLimit = 1
        case .visionOS:
            metrics.width = .fraction(0.7)
            metrics.contentPadding = insets(20, 24)
            metrics.titleFont = .title3.weight(.semibold)
            metrics.messageFont = .body
            metrics.glyphSide = 44
            metrics.glyphSpacing = 16
            metrics.textSpacing = 4
            metrics.cornerRadius = 32
            metrics.progressBarHeight = 7
            metrics.progressTitleLineLimit = 2
            metrics.progressDetailLineLimit = 1
        }
        return metrics
    }
}

// MARK: - Environment

private struct ToastMetricsKey: EnvironmentKey {
    static let defaultValue = ToastMetrics.regular
}

public extension EnvironmentValues {
    /// The sizes toasts below this point are drawn with. ``ToastMetrics/regular`` by default.
    var toastMetrics: ToastMetrics {
        get { self[ToastMetricsKey.self] }
        set { self[ToastMetricsKey.self] = newValue }
    }
}

public extension View {
    /// Draws every toast below this point at `metrics`' size.
    ///
    /// ```swift
    /// MyScreen()
    ///     .toasts(toasts)
    ///     .toastMetrics(.large)
    /// ```
    ///
    /// Like the style and the theme, it is read from the environment by the stack, so it
    /// goes outside `.toasts(_:)`. A `width:` passed to `.toasts(_:width:)` still wins over
    /// the metrics' width.
    func toastMetrics(_ metrics: ToastMetrics) -> some View {
        environment(\.toastMetrics, metrics)
    }
}
