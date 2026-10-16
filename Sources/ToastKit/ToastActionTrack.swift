import SwiftUI

// MARK: - Observing actions

/// Observes every action run on a toast. Set with `onToastAction(perform:)`.
struct ToastActionHandler {
    let perform: (ToastMessage, ToastAction) -> Void
}

public extension View {

    /// Runs `handler` for every action chosen on a toast below this point — taps, swipes,
    /// long-press choices and VoiceOver actions alike.
    ///
    /// Use it to handle actions in one place by ``ToastAction/id``, instead of, or as well
    /// as, giving each action its own handler. It runs after the action's own handler
    /// and before the toast is dismissed or postponed.
    ///
    /// ```swift
    /// MyScreen()
    ///     .toasts(toasts)
    ///     .onToastAction { toast, action in
    ///         switch action.id {
    ///         case ToastAction.deleteID: analytics.log("toast.deleted")
    ///         case "archive": store.archive(toast.id)
    ///         default: break
    ///         }
    ///     }
    /// ```
    func onToastAction(perform handler: @escaping (ToastMessage, ToastAction) -> Void) -> some View {
        environment(\.toastActionHandler, ToastActionHandler(perform: handler))
    }
}

// MARK: - What the stack tells its cards

/// The widths a card needs to lay out its track: its own, and the stack's.
struct ToastTrackLayout: Equatable {
    let cardWidth: CGFloat
    let availableWidth: CGFloat
}

private struct ToastActionHandlerKey: EnvironmentKey {
    static let defaultValue: ToastActionHandler? = nil
}

private struct ToastPlacementKey: EnvironmentKey {
    static let defaultValue: ToastPlacement = .bottom
}

private struct ToastTrackLayoutKey: EnvironmentKey {
    static let defaultValue: ToastTrackLayout? = nil
}

extension EnvironmentValues {
    var toastActionHandler: ToastActionHandler? {
        get { self[ToastActionHandlerKey.self] }
        set { self[ToastActionHandlerKey.self] = newValue }
    }

    /// Where the stack a card belongs to sits, so its swipe and track bend toward it.
    var toastPlacement: ToastPlacement {
        get { self[ToastPlacementKey.self] }
        set { self[ToastPlacementKey.self] = newValue }
    }

    /// `nil` outside a stack, which leaves a card without room for its track.
    var toastTrackLayout: ToastTrackLayout? {
        get { self[ToastTrackLayoutKey.self] }
        set { self[ToastTrackLayoutKey.self] = newValue }
    }
}

/// The id of the card lifted onto its track, if any. The stack reads it to dim the
/// screen and fade the cards behind.
struct ToastLiftPreferenceKey: PreferenceKey {
    static let defaultValue: UUID? = nil

    static func reduce(value: inout UUID?, nextValue: () -> UUID?) {
        value = value ?? nextValue()
    }
}

// MARK: - The card's long-press state

/// Where a card is on the long-press path.
enum ToastLift: Equatable {
    case resting
    /// Riding the track, following the finger.
    case lifted
    /// Dropping into the action it was let go on.
    case committing
}

/// Shrinks, moves and turns the card body for the long press. Split out so the card's
/// body chain reads the same whether or not the toast has actions.
struct ToastLiftEffect: ViewModifier {
    let lift: ToastLift
    /// A finger is down and still: the card eases in slightly so the hold is felt.
    let isPressing: Bool
    let offset: CGSize
    let tilt: Double
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressing && !reduceMotion ? 0.97 : 1)
            .animation(.easeOut(duration: 0.45), value: isPressing)
            .scaleEffect(scale)
            .opacity(lift == .committing ? 0 : 1)
            .rotationEffect(.radians(reduceMotion || lift == .resting ? 0 : tilt))
            .offset(lift == .resting ? .zero : offset)
    }

    private var scale: CGFloat {
        switch lift {
        case .resting:    1
        case .lifted:     ToastTrackGeometry.liftScale
        case .committing: ToastTrackGeometry.commitScale
        }
    }
}

/// The haptic for the latest long-press event. The serial makes each event a change,
/// so arming the same end twice still ticks twice.
struct ToastLiftHaptic: Equatable {
    enum Event: Equatable {
        case none
        case lifted
        case armed
        case chosen(destructive: Bool)
    }

    private(set) var event: Event = .none
    private(set) var serial = 0

    mutating func fire(_ event: Event) {
        self.event = event
        serial += 1
    }
}

/// Plays `ToastLiftHaptic`. Compiled out on visionOS, like the arrival haptic.
struct ToastLiftFeedback: ViewModifier {
    let trigger: ToastLiftHaptic

    func body(content: Content) -> some View {
        #if os(visionOS)
        content
        #else
        content.sensoryFeedback(trigger: trigger) { _, new -> SensoryFeedback? in
            switch new.event {
            case .none:
                return nil
            case .lifted:
                return .impact(weight: .medium)
            case .armed:
                return .selection
            case .chosen(let destructive):
                return destructive ? SensoryFeedback.impact(weight: .heavy) : SensoryFeedback.success
            }
        }
        #endif
    }
}

// MARK: - Shared by both tracks

/// Which ends are lit — armed, or chosen — and which step back while another is.
struct ToastTrackHighlight {
    let armed: ToastTrackSide?
    let chosen: ToastTrackSide?

    func isLit(_ side: ToastTrackSide) -> Bool {
        armed == side || chosen == side
    }

    /// Another end is lit.
    func isDimmed(_ side: ToastTrackSide) -> Bool {
        !isLit(side) && (armed != nil || chosen != nil)
    }
}

/// The colours both tracks are drawn in, worked out once per drawing.
struct ToastTrackPalette {
    let theme: ToastTheme
    let actions: ToastSwipeActions
    let highlight: ToastTrackHighlight
    let reduceTransparency: Bool

    /// Translucent white, or the theme's opaque surface under Reduce Transparency, where
    /// the washes over it then come out opaque too.
    var band: AnyShapeStyle {
        reduceTransparency ? theme.opaqueSurfaceFill : AnyShapeStyle(Color.white.opacity(0.34))
    }

    func tint(for side: ToastTrackSide) -> Color {
        actions.action(for: side).map { theme.actionTint($0.role) } ?? .clear
    }

    func strength(for side: ToastTrackSide) -> Double {
        guard actions.action(for: side) != nil else { return 0 }
        if highlight.isLit(side) { return ToastTrackWash.armedStrength }
        if highlight.isDimmed(side) { return ToastTrackWash.dimmedStrength }
        return ToastTrackWash.restingStrength
    }

    /// A band's colour from `start`'s end (location 0) to `end`'s (location 1), each
    /// fading to nothing at the centre.
    func washStops(from start: ToastTrackSide, to end: ToastTrackSide) -> [Gradient.Stop] {
        let stops = ToastTrackWash.leadingStops(fadeStart: theme.actionFadeStart)
        let startTint = tint(for: start)
        let endTint = tint(for: end)
        let startStrength = strength(for: start)
        let endStrength = strength(for: end)
        let first = stops.map {
            Gradient.Stop(color: startTint.opacity(startStrength * $0.strength), location: CGFloat($0.location))
        }
        let second = stops.reversed().map {
            Gradient.Stop(color: endTint.opacity(endStrength * $0.strength), location: CGFloat(1 - $0.location))
        }
        return first + second
    }
}

/// An action's icon and title, with its subtitle beneath. A dark shade of the action's
/// hue; white once its end is lit, with a faint shadow so it holds up where the colour
/// fades. Once chosen, the confirmation replaces the title and the subtitle steps aside.
struct ToastTrackLabel: View {
    let action: ToastAction
    let isLit: Bool
    let isChosen: Bool
    let isDimmed: Bool

    @Environment(\.toastTheme) private var theme

    var body: some View {
        VStack(spacing: 1) {
            HStack(spacing: 4) {
                if let icon = action.icon {
                    icon.image
                        .imageScale(.small)
                }
                Text(isChosen ? (action.confirmation ?? action.title) : action.title)
            }
            .font(.caption.weight(.bold))
            if let subtitle = action.subtitle, !isChosen {
                Text(subtitle)
                    .font(.caption2.weight(.medium))
                    .opacity(0.8)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .foregroundStyle(isLit ? Color.white : theme.actionTint(action.role))
        .brightness(isLit ? 0 : -0.35)
        .shadow(color: .black.opacity(isLit ? 0.35 : 0), radius: 2)
        .opacity(isDimmed ? 0.5 : 1)
    }
}

// MARK: - The horizontal track

/// The band a long-pressed card rides left and right, with an action at each end.
///
/// One translucent band across the stack, bent gently toward its edge. Each end carries
/// its action's colour, solid near the end and fading to nothing at the centre so the
/// two meet without a seam. The labels sit beside the lifted card, in the half of the
/// band away from the stack's edge, clear of the finger.
struct ToastActionTrack: View {
    let geometry: ToastTrackGeometry
    let actions: ToastSwipeActions
    let armed: ToastTrackSide?
    let chosen: ToastTrackSide?
    let isShown: Bool

    @Environment(\.toastTheme) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let stroke = StrokeStyle(lineWidth: ToastTrackGeometry.bandThickness, lineJoin: .round)
        let palette = ToastTrackPalette(
            theme: theme,
            actions: actions,
            highlight: ToastTrackHighlight(armed: armed, chosen: chosen),
            reduceTransparency: reduceTransparency
        )
        ZStack {
            // Draws out from under the card toward both ends.
            ToastTrackBand(geometry: geometry)
                .trim(from: isShown ? 0 : 0.5, to: isShown ? 1 : 0.5)
                .stroke(palette.band, style: stroke)
            ToastTrackBand(geometry: geometry)
                .stroke(
                    LinearGradient(
                        stops: palette.washStops(from: .leading, to: .trailing),
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: stroke
                )
                .opacity(isShown ? 1 : 0)
            label(for: .leading, palette: palette)
            label(for: .trailing, palette: palette)
        }
        .frame(width: geometry.bandWidth, height: ToastTrackGeometry.height)
        .allowsHitTesting(false)
        // VoiceOver reaches the actions as named actions on the card instead.
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func label(for side: ToastTrackSide, palette: ToastTrackPalette) -> some View {
        if let action = actions.action(for: side) {
            let x = geometry.labelX(for: side)
            ToastTrackLabel(
                action: action,
                isLit: palette.highlight.isLit(side),
                isChosen: chosen == side,
                isDimmed: palette.highlight.isDimmed(side)
            )
            .frame(width: max(0, geometry.labelWidth))
            .rotationEffect(.radians(geometry.tilt(at: x)))
            .position(x: geometry.bandWidth / 2 + x, y: geometry.labelY(at: x))
            .opacity(isShown ? 1 : 0)
        }
    }
}

/// The band's centre line, edge to edge, as a polyline fine enough to read as an arc.
/// A shape rather than a path so `trim` can animate it drawing out from the centre.
struct ToastTrackBand: Shape {
    let geometry: ToastTrackGeometry

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let segments = 48
        let half = geometry.bandWidth / 2
        for step in 0...segments {
            let x = -half + geometry.bandWidth * CGFloat(step) / CGFloat(segments)
            let point = CGPoint(x: rect.midX + x, y: rect.minY + geometry.bandY(at: x))
            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }
}

// MARK: - The vertical track

/// The band a long-pressed card rides up and down, with an action at each end.
///
/// A straight translucent band through the lifted card, coloured at each end like the
/// horizontal one. The finger carrying the card is below it, so a label at the bottom
/// end would be under the finger on the way down. The labels sit beside the ends
/// instead, on the leading side, each on a small piece of band of its own.
struct ToastVerticalActionTrack: View {
    let geometry: ToastTrackGeometry
    let actions: ToastSwipeActions
    let armed: ToastTrackSide?
    let chosen: ToastTrackSide?
    let isShown: Bool

    @Environment(\.toastTheme) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var length: CGFloat { 2 * ToastTrackGeometry.verticalReach }

    var body: some View {
        let stroke = StrokeStyle(lineWidth: ToastTrackGeometry.bandThickness)
        let palette = ToastTrackPalette(
            theme: theme,
            actions: actions,
            highlight: ToastTrackHighlight(armed: armed, chosen: chosen),
            reduceTransparency: reduceTransparency
        )
        ZStack {
            ToastVerticalBand()
                .trim(from: isShown ? 0 : 0.5, to: isShown ? 1 : 0.5)
                .stroke(palette.band, style: stroke)
            ToastVerticalBand()
                .stroke(
                    LinearGradient(
                        stops: palette.washStops(from: .up, to: .down),
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: stroke
                )
                .opacity(isShown ? 1 : 0)
            label(for: .up, palette: palette)
            label(for: .down, palette: palette)
        }
        .frame(width: geometry.bandWidth, height: length)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func label(for side: ToastTrackSide, palette: ToastTrackPalette) -> some View {
        if let action = actions.action(for: side) {
            ToastTrackLabel(
                action: action,
                isLit: palette.highlight.isLit(side),
                isChosen: chosen == side,
                isDimmed: palette.highlight.isDimmed(side)
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                Capsule().fill(palette.band)
                Capsule().fill(palette.tint(for: side).opacity(palette.strength(for: side)))
            }
            .frame(width: max(0, geometry.labelWidth), alignment: .trailing)
            .position(
                x: geometry.bandWidth / 2 + geometry.verticalLabelX,
                y: length / 2 + geometry.verticalLabelY(for: side)
            )
            .opacity(isShown ? 1 : 0)
        }
    }
}

/// The vertical band's centre line, top to bottom. A shape so `trim` can draw it out
/// from the middle.
struct ToastVerticalBand: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}
