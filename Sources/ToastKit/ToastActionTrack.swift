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

// MARK: - The track

/// The band a long-pressed card rides, with an action at each end.
///
/// One translucent band across the stack, bent gently toward its edge. Each end carries
/// its action's colour, solid near the end and fading to nothing at the centre so the
/// two meet without a seam. The labels sit on the band beside the lifted card.
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
        ZStack {
            // Draws out from under the card toward both ends.
            ToastTrackBand(geometry: geometry)
                .trim(from: isShown ? 0 : 0.5, to: isShown ? 1 : 0.5)
                .stroke(bandStyle, style: stroke)
            ToastTrackBand(geometry: geometry)
                .stroke(LinearGradient(stops: washStops, startPoint: .leading, endPoint: .trailing), style: stroke)
                .opacity(isShown ? 1 : 0)
            label(for: .leading)
            label(for: .trailing)
        }
        .frame(width: geometry.bandWidth, height: ToastTrackGeometry.height)
        .allowsHitTesting(false)
        // VoiceOver reaches the actions as named actions on the card instead.
        .accessibilityHidden(true)
    }

    /// Translucent white, or the theme's opaque surface under Reduce Transparency, where
    /// the washes over it then come out opaque too.
    private var bandStyle: AnyShapeStyle {
        reduceTransparency ? theme.opaqueSurfaceFill : AnyShapeStyle(Color.white.opacity(0.34))
    }

    private var washStops: [Gradient.Stop] {
        let stops = ToastTrackWash.leadingStops(fadeStart: theme.actionFadeStart)
        let leadingTint = tint(for: .leading)
        let trailingTint = tint(for: .trailing)
        let leadingStrength = strength(for: .leading)
        let trailingStrength = strength(for: .trailing)
        let leading = stops.map {
            Gradient.Stop(color: leadingTint.opacity(leadingStrength * $0.strength), location: CGFloat($0.location))
        }
        let trailing = stops.reversed().map {
            Gradient.Stop(color: trailingTint.opacity(trailingStrength * $0.strength), location: CGFloat(1 - $0.location))
        }
        return leading + trailing
    }

    private func tint(for side: ToastTrackSide) -> Color {
        actions.action(for: side).map { theme.actionTint($0.role) } ?? .clear
    }

    private func isLit(_ side: ToastTrackSide) -> Bool {
        armed == side || chosen == side
    }

    private func isDimmed(_ side: ToastTrackSide) -> Bool {
        let other: ToastTrackSide = side == .leading ? .trailing : .leading
        return !isLit(side) && isLit(other)
    }

    private func strength(for side: ToastTrackSide) -> Double {
        guard actions.action(for: side) != nil else { return 0 }
        if isLit(side) { return ToastTrackWash.armedStrength }
        if isDimmed(side) { return ToastTrackWash.dimmedStrength }
        return ToastTrackWash.restingStrength
    }

    /// The action's icon and title, with its subtitle beneath, on the band. A dark shade
    /// of the action's hue on the translucent band; white once that end is lit, with a
    /// faint shadow so it holds up where the colour fades. Once chosen, the confirmation
    /// replaces the title and the subtitle steps aside.
    @ViewBuilder
    private func label(for side: ToastTrackSide) -> some View {
        if let action = actions.action(for: side) {
            let x = geometry.labelX(for: side)
            let lit = isLit(side)
            let isChosen = chosen == side
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
            .foregroundStyle(lit ? Color.white : theme.actionTint(action.role))
            .brightness(lit ? 0 : -0.35)
            .shadow(color: .black.opacity(lit ? 0.35 : 0), radius: 2)
            .opacity(isDimmed(side) ? 0.5 : 1)
            .frame(width: max(0, geometry.labelWidth))
            .rotationEffect(.radians(geometry.tilt(at: x)))
            .position(x: geometry.bandWidth / 2 + x, y: geometry.bandY(at: x))
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
