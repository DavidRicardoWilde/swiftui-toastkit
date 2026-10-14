import SwiftUI

/// Design tokens for the default ``GlassToastStyle``, and the motion every style shares.
///
/// This is the seam for adopting a design system without writing a style. The kit owns
/// *proportion* — how far a buried card peeks, how much of the tint becomes a wash, how
/// the edge gradient falls off — and the host owns *identity*: which colours, which
/// type, which curves. A macOS or visionOS app adopts the same component by supplying a
/// different `ToastTheme`, not by forking the views.
///
/// ```swift
/// MyScreen()
///     .toasts(toasts)
///     .toastTheme(ToastTheme(
///         titleFont: .headline,
///         tint: { status in status == .notification ? .pink : ToastTheme.standardTint(status) },
///         cornerRadius: 16
///     ))
/// ```
///
/// Surfaces, content and metrics are read by ``GlassToastStyle`` only; a custom
/// ``ToastStyle`` is free to ignore them. `edgeInset`, the motions, `actionTint`,
/// `actionFadeStart` and `feedback` apply whatever the style.
///
/// Note what is deliberately *not* here: Reduce Motion, Reduce Transparency and
/// Increase Contrast. Those are read straight from the SwiftUI environment inside the
/// views, because SwiftUI already resolves them correctly on every platform. Routing
/// them through the theme would make each host reimplement `UIAccessibility` /
/// `NSWorkspace` lookups that SwiftUI does for free.
public struct ToastTheme {

    // MARK: Nested tokens

    /// A spring, described by numbers rather than by an `Animation`, so the kit can
    /// both build the curve *and* know how long it runs — the swipe-out has to defer
    /// removal until the card has actually left the screen.
    public struct Motion {
        public var duration: TimeInterval
        public var bounce: Double

        public init(duration: TimeInterval, bounce: Double = 0) {
            self.duration = duration
            self.bounce = bounce
        }

        /// Per Apple's HIG, Reduce Motion replaces the spring with a cross-fade of the
        /// same duration rather than removing the animation outright.
        public func animation(reduceMotion: Bool) -> Animation {
            if reduceMotion || bounce == 0 {
                return .easeInOut(duration: duration)
            }
            return .spring(duration: duration, bounce: bounce)
        }
    }

    public struct Shadow {
        public var color: Color
        public var radius: CGFloat
        public var y: CGFloat

        public init(color: Color, radius: CGFloat, y: CGFloat) {
            self.color = color
            self.radius = radius
            self.y = y
        }
    }

    // MARK: Surfaces

    /// The blurred layer at the back of the card.
    public var material: AnyShapeStyle
    /// Neutral fill between the material and the status wash.
    public var surfaceFill: AnyShapeStyle
    /// Substituted for both of the above under Reduce Transparency.
    public var opaqueSurfaceFill: AnyShapeStyle
    /// Border colour when Increase Contrast rules out the gradient edge.
    public var borderSubtle: Color

    // MARK: Content

    public var textPrimary: Color
    public var textSecondary: Color
    public var titleFont: Font
    public var messageFont: Font

    /// The hue for a status. One colour per status — the kit derives the wash, the edge,
    /// the glyph chip and the glow from it at fixed opacities, so a host retunes a
    /// status by changing one value rather than four.
    public var tint: (ToastMessage.Status) -> Color

    // MARK: Metrics

    public var cornerRadius: CGFloat
    public var contentPadding: EdgeInsets
    /// Gap between the stack and the edge it hangs from.
    public var edgeInset: CGFloat

    // MARK: Elevation and motion

    public var shadow: Shadow
    /// Cards entering, leaving and re-stacking.
    public var stackMotion: Motion
    /// The swipe-out flight. Its `duration` also times the deferred removal.
    public var flingMotion: Motion
    /// Snap-back when a drag does not cross the dismiss threshold.
    public var snapBackMotion: Motion

    // MARK: Long-press actions

    /// The hue of an action's end of the track. One colour per role: the wash, its
    /// strengths and the label's shade are all derived from it.
    public var actionTint: (ToastAction.Role) -> Color
    /// The thinner glass a card turns to while it rides the action track, so the band and
    /// its colours show through it.
    public var liftedMaterial: AnyShapeStyle
    /// How far in from each end an action's colour stays solid before fading to nothing
    /// at the centre, as a share of the way from that end to the centre. ½, ⅓ and ¼ all
    /// read well.
    public var actionFadeStart: Double

    #if !os(visionOS)
    /// Haptic played when a toast becomes topmost. `nil` for silence.
    ///
    /// Absent on visionOS: `SensoryFeedback` is visionOS 26+, and a headset has nothing
    /// to vibrate, so there is nothing to fall back to.
    public var feedback: (ToastMessage.Status) -> SensoryFeedback?
    #endif

    // MARK: Init

    public init(
        material: AnyShapeStyle = AnyShapeStyle(.regularMaterial),
        surfaceFill: AnyShapeStyle = AnyShapeStyle(Color.primary.opacity(0.04)),
        opaqueSurfaceFill: AnyShapeStyle = AnyShapeStyle(.background),
        borderSubtle: Color = .primary.opacity(0.25),
        textPrimary: Color = .primary,
        textSecondary: Color = .secondary,
        titleFont: Font = .callout.weight(.medium),
        messageFont: Font = .footnote,
        tint: @escaping (ToastMessage.Status) -> Color = ToastTheme.standardTint,
        cornerRadius: CGFloat = 22,
        contentPadding: EdgeInsets = EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16),
        edgeInset: CGFloat = 8,
        shadow: Shadow = Shadow(color: .black.opacity(0.12), radius: 28, y: 12),
        stackMotion: Motion = Motion(duration: 0.38, bounce: 0.28),
        flingMotion: Motion = Motion(duration: 0.22, bounce: 0.10),
        snapBackMotion: Motion = Motion(duration: 0.25, bounce: 0.30),
        actionTint: @escaping (ToastAction.Role) -> Color = ToastTheme.standardActionTint,
        liftedMaterial: AnyShapeStyle = AnyShapeStyle(.ultraThinMaterial),
        actionFadeStart: Double = 1.0 / 3.0
    ) {
        self.material = material
        self.surfaceFill = surfaceFill
        self.opaqueSurfaceFill = opaqueSurfaceFill
        self.borderSubtle = borderSubtle
        self.textPrimary = textPrimary
        self.textSecondary = textSecondary
        self.titleFont = titleFont
        self.messageFont = messageFont
        self.tint = tint
        self.cornerRadius = cornerRadius
        self.contentPadding = contentPadding
        self.edgeInset = edgeInset
        self.shadow = shadow
        self.stackMotion = stackMotion
        self.flingMotion = flingMotion
        self.snapBackMotion = snapBackMotion
        self.actionTint = actionTint
        self.liftedMaterial = liftedMaterial
        self.actionFadeStart = actionFadeStart
        #if !os(visionOS)
        self.feedback = ToastTheme.standardFeedback
        #endif
    }

    // MARK: Defaults

    /// System semantic colours: they read as status everywhere, and each platform has
    /// already tuned the pair for its own appearances and contrast requirements.
    /// `normal` resolves to the secondary label colour, which is what makes its wash
    /// vanish — see `ToastMessage.Status.surfaceWash(in:)`.
    public static let standardTint: (ToastMessage.Status) -> Color = { status in
        switch status {
        case .normal:       .secondary
        case .warning:      .orange
        case .error:        .red
        case .notification: .accentColor
        }
    }

    /// Distinct in lightness as well as hue, so the two ends of the track still read
    /// apart without colour vision.
    public static let standardActionTint: (ToastAction.Role) -> Color = { role in
        switch role {
        case .destructive: .red
        case .standard:    .indigo
        case .subdued:     .gray
        }
    }

    #if !os(visionOS)
    public static let standardFeedback: (ToastMessage.Status) -> SensoryFeedback? = { status in
        switch status {
        case .normal:       .selection
        case .warning:      .warning
        case .error:        .error
        case .notification: .impact(weight: .medium)
        }
    }
    #endif

    /// Platform-neutral defaults, built entirely from system values. Usable as-is; a
    /// host with its own design system supplies a configured `ToastTheme` instead.
    public static let standard = ToastTheme()
}

// MARK: - Environment

private struct ToastThemeKey: EnvironmentKey {
    static let defaultValue = ToastTheme.standard
}

public extension EnvironmentValues {
    var toastTheme: ToastTheme {
        get { self[ToastThemeKey.self] }
        set { self[ToastThemeKey.self] = newValue }
    }
}

public extension View {
    /// Supplies the design tokens every toast below this point renders with.
    func toastTheme(_ theme: ToastTheme) -> some View {
        environment(\.toastTheme, theme)
    }
}
