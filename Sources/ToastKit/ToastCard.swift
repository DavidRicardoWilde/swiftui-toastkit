import SwiftUI

/// A single toast card: the owner of its tap, swipe and long-press gestures.
///
/// The card draws nothing itself — its body comes from the ``ToastStyle`` in effect —
/// and is deliberately dumb about the stack. It knows whether it is the one the user can
/// touch (`isInteractive`) and reports back through closures; ordering and timing stay
/// in ``ToastCenter``, and running an action belongs to whoever owns the card.
/// ``ToastStack`` builds these for you; use one directly for a preview or a static
/// layout.
///
/// Gestures, on the front card:
///
/// - **Tap** runs the tap action, if there is one.
/// - **Swipe** toward a side runs that side's swipe action. Past 88 pt, or on a flick,
///   the card flies off that way first; short of it, the card springs back. Toward a
///   side with no action it barely moves.
/// - **Press and hold** lifts the card onto a track with each swipe action drawn at its
///   end. Carrying it 64 pt toward an end arms that action; letting go there runs it,
///   anywhere else puts the card back. See `ToastActionTrack`.
///
/// The exit is animated here rather than left to a SwiftUI removal transition, because
/// a transition cannot know which way the finger went. The card flings itself past the
/// screen edge, fading as it goes, and only then reports the action — by which point it
/// is invisible, so the plain opacity removal underneath is never seen.
public struct ToastCard: View {

    let toast: ToastMessage
    /// Only the topmost card takes touches; the ones behind are peeks.
    let isInteractive: Bool
    /// What a tap runs: the toast's own tap action, or the stack's fallback.
    let tapAction: ToastAction?
    /// Raised while a finger is down or a fling is in flight, so the countdown pauses.
    let onInteractionChange: (Bool) -> Void
    /// Runs the chosen action — tap, swipe or track. The owner applies its effect.
    let onAction: (ToastAction) -> Void
    /// Removes the toast with no action, for VoiceOver's "Dismiss".
    let onDismiss: () -> Void
    /// Told when the card starts an exit of its own — a fling or a track action's drop —
    /// at least 220 ms before it is removed, so the stack draws no stand-in for it.
    let onOwnExit: () -> Void

    /// - Parameters:
    ///   - toast: What to draw, and the actions it offers.
    ///   - isInteractive: Whether the card takes touches. Only a stack's front card does.
    ///   - onInteractionChange: Told `true` when a gesture starts and `false` when it
    ///     settles, so a countdown can pause in between.
    ///   - onAction: Runs the tap or swipe action the user chose. Applying its handler
    ///     and effect is up to you; ``ToastStack`` does both.
    ///   - onDismiss: Removes the toast without running an action.
    public init(
        toast: ToastMessage,
        isInteractive: Bool = true,
        onInteractionChange: @escaping (Bool) -> Void = { _ in },
        onAction: @escaping (ToastAction) -> Void = { _ in },
        onDismiss: @escaping () -> Void = {}
    ) {
        self.init(
            toast: toast,
            isInteractive: isInteractive,
            tapAction: toast.tapAction,
            onInteractionChange: onInteractionChange,
            onAction: onAction,
            onDismiss: onDismiss,
            onOwnExit: {}
        )
    }

    init(
        toast: ToastMessage,
        isInteractive: Bool,
        tapAction: ToastAction?,
        onInteractionChange: @escaping (Bool) -> Void,
        onAction: @escaping (ToastAction) -> Void,
        onDismiss: @escaping () -> Void,
        onOwnExit: @escaping () -> Void
    ) {
        self.toast = toast
        self.isInteractive = isInteractive
        self.tapAction = tapAction
        self.onInteractionChange = onInteractionChange
        self.onAction = onAction
        self.onDismiss = onDismiss
        self.onOwnExit = onOwnExit
    }

    @Environment(\.toastStyle) private var style
    @Environment(\.toastTheme) private var theme
    @Environment(\.toastMetrics) private var metrics
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.toastPlacement) private var placement
    @Environment(\.toastTrackLayout) private var trackLayout
    @Environment(\.toastDragPoses) private var dragPoses

    @State private var dragX: CGFloat = 0
    @State private var isFlingingOut = false
    /// True from a drag's first change until it is resolved, by `onEnded` or by
    /// `releaseAbandonedDrag()`. It is what says this card raised the interaction.
    @State private var holdsInteraction = false
    /// True for as long as SwiftUI considers the drag alive. Unlike `onEnded`, which a
    /// cancelled gesture never reaches, a `@GestureState` is reset either way.
    @GestureState private var isDragging = false
    /// This touch is a swipe: set by the drag's first change, cleared by its end and by a
    /// lift. Kept apart from `holdsInteraction` so a cancelled drag's clean-up cannot
    /// swallow a real release, and a touch that lifted the card cannot fling it.
    @State private var swipeStarted = false

    @State private var lift: ToastLift = .resting
    /// Where the lifted card sits along the track, from its centre.
    @State private var carryX: CGFloat = 0
    @State private var armedSide: ToastTrackSide?
    /// The end chosen on letting go; its label switches to the confirmation.
    @State private var chosenSide: ToastTrackSide?
    @State private var liftHaptic = ToastLiftHaptic()
    /// Set when a long press lifts the card, so the tap that may follow the same touch
    /// does not also run the tap action. Cleared when the next touch begins.
    @State private var liftConsumedTouch = false
    /// A finger is down and has not moved yet: the hold is under way.
    @GestureState private var isPressing = false
    /// The long press or the carry that follows it is alive. Reset on cancellation too.
    @GestureState private var isLiftGestureActive = false

    /// Far enough to clear the widest phone or tablet in either orientation.
    private let exitDistance: CGFloat = 1_400
    /// How long a still finger must stay down to lift the card.
    private let holdDuration: Double = 0.45
    /// How long the chosen action's confirmation shows before the action runs.
    private let confirmationDelay: UInt64 = 200_000_000
    private let removalDelay: UInt64 = 700_000_000

    public var body: some View {
        cardBody
            .modifier(ToastLiftEffect(
                lift: lift,
                isPressing: isPressing && canLift,
                offset: liftOffset,
                tilt: trackGeometry?.tilt(at: carryX) ?? 0,
                reduceMotion: reduceMotion
            ))
            .offset(x: dragX, y: swipeSag)
            .modifier(ToastTiltEffect(degrees: dragPose.rotationDegrees))
            .opacity(dragOpacity)
            .background { actionTrack }
            // Past the limit toast content stops growing, track labels included.
            .dynamicTypeSize(...metrics.maximumDynamicTypeSize)
            .contentShape(Rectangle())
            .gesture(dragGesture, including: isInteractive ? .all : .subviews)
            .simultaneousGesture(liftGesture, including: canLift ? .all : .subviews)
            // Safe alongside the drag: `minimumDistance: 8` means a tap never starts
            // the drag, and a drag past 8pt never resolves as a tap.
            .modifier(ToastTapGesture(action: tapHandler))
            // A drag can end without `onEnded`: the system cancels it, a new arrival
            // buries this card, or the card is removed. Each would leave the countdown
            // paused for good, so each settles the drag here instead.
            .onChange(of: isDragging) { _, dragging in
                if !dragging { releaseAbandonedDrag() }
            }
            .onChange(of: isInteractive) { _, interactive in
                if !interactive {
                    releaseAbandonedDrag()
                    putBack()
                }
            }
            // The pose is only meaningful away from rest, whichever path brought it home.
            .onChange(of: dragX) { _, x in
                if x == 0 { dragPoses?.clear(toast.id) }
            }
            .onChange(of: isPressing) { _, pressing in
                if pressing { liftConsumedTouch = false }
            }
            // The same for a lift: a cancelled long press must not leave the card up.
            // Deferred a turn so that a normal release, handled in `onEnded`, wins.
            .onChange(of: isLiftGestureActive) { _, active in
                guard !active else { return }
                Task { @MainActor in putBack() }
            }
            .onDisappear {
                releaseAbandonedDrag()
                putBack()
                dragPoses?.clear(toast.id)
            }
            .preference(key: ToastLiftPreferenceKey.self, value: lift == .resting ? nil : toast.id)
            .modifier(ToastLiftFeedback(trigger: liftHaptic))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAddTraits(isTappable ? .isButton : [])
            .accessibilityHint(isInteractive ? Text(hintKey, bundle: .module) : Text(""))
            .accessibilityAction(named: Text("toast.a11y.dismiss", bundle: .module)) { onDismiss() }
            .modifier(ToastActionAccessibility(actions: offeredActions, perform: onAction))
    }

    private var isTappable: Bool { isInteractive && tapAction != nil }

    private var hintKey: LocalizedStringKey {
        isTappable ? "toast.a11y.hint.activate" : "toast.a11y.hint"
    }

    // MARK: - Content

    private var cardBody: some View {
        style.makeBody(configuration: ToastStyleConfiguration(
            toast: toast,
            isLifted: lift != .resting,
            isTappable: isTappable,
            metrics: metrics.resolved(in: theme)
        ))
    }

    private var accessibilityLabel: Text {
        guard let message = toast.message, !message.isEmpty else { return Text(toast.title) }
        return Text("\(toast.title), \(message)")
    }

    // MARK: - Tap

    /// Taps run the tap action, unless the touch was a long press that lifted the card.
    private var tapHandler: (() -> Void)? {
        guard isInteractive, let tapAction else { return nil }
        return {
            guard !liftConsumedTouch else {
                liftConsumedTouch = false
                return
            }
            onAction(tapAction)
        }
    }

    // MARK: - Swipe

    private var swipeActions: ToastSwipeActions { toast.swipeActions }

    /// Fades with travel in either direction, so the card is already ghosted by the
    /// time it clears the threshold — and fully gone once a fling starts.
    private var dragOpacity: Double {
        if isFlingingOut { return 0 }
        return dragPose.opacity
    }

    /// The swipe's path bends gently toward the stack's edge, so a throw reads as a swing
    /// rather than a slide. Flat under Reduce Motion. The numbers live in `ToastDragPose`.
    private var swipeSag: CGFloat { dragPose.sag }

    private var dragPose: ToastDragPose {
        ToastDragPose(dragX: dragX, curve: placement.curve, reduceMotion: reduceMotion)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($isDragging) { _, dragging, _ in dragging = true }
            .onChanged { value in
                guard !isFlingingOut, isInteractive, lift == .resting else { return }
                swipeStarted = true
                if !holdsInteraction {
                    holdsInteraction = true
                    onInteractionChange(true)
                }
                dragX = ToastSwipe.follow(
                    value.translation.width,
                    leading: swipeActions.leading != nil,
                    trailing: swipeActions.trailing != nil
                )
                // Read once, if a batch removes this card mid-drag, to start its stand-in
                // from here. A plain box, so the drag does not redraw the stack.
                dragPoses?.set(dragPose, for: toast.id)
            }
            .onEnded { value in
                guard !isFlingingOut, isInteractive, swipeStarted, lift == .resting else { return }
                swipeStarted = false
                holdsInteraction = false
                let side = ToastSwipe.commit(
                    travel: value.translation.width,
                    projected: value.predictedEndTranslation.width,
                    leading: swipeActions.leading != nil,
                    trailing: swipeActions.trailing != nil
                )
                if let side, let action = swipeActions.action(for: side) {
                    flingOut(towards: side == .leading ? -1 : 1, running: action)
                } else {
                    withAnimation(theme.snapBackMotion.animation(reduceMotion: reduceMotion)) {
                        dragX = 0
                    }
                    dragPoses?.clear(toast.id)
                    onInteractionChange(false)
                }
            }
    }

    /// Settles a drag that ended without `onEnded`: springs the card home and lowers the
    /// interaction it raised. A no-op once the drag has been resolved, and during a
    /// fling, whose deferred action lowers the interaction itself.
    private func releaseAbandonedDrag() {
        guard holdsInteraction, !isFlingingOut else { return }
        holdsInteraction = false
        withAnimation(theme.snapBackMotion.animation(reduceMotion: reduceMotion)) {
            dragX = 0
        }
        dragPoses?.clear(toast.id)
        onInteractionChange(false)
    }

    private func flingOut(towards direction: CGFloat, running action: ToastAction) {
        isFlingingOut = true
        onOwnExit()
        // Raised again rather than assumed: whichever way `onEnded` and the gesture
        // state's reset are ordered, the flight must hold the countdown. Idempotent.
        onInteractionChange(true)
        let motion = theme.flingMotion
        withAnimation(motion.animation(reduceMotion: reduceMotion)) {
            dragX = direction * exitDistance
        }
        // The action runs once the card has left the screen; `onInteractionChange`
        // stays raised across the fling so the toast underneath does not start its
        // countdown until it is actually the one on top.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(motion.duration * 1_000_000_000))
            onAction(action)
            onInteractionChange(false)
        }
    }

    // MARK: - Long press

    private var trackGeometry: ToastTrackGeometry? {
        guard let trackLayout else { return nil }
        return ToastTrackGeometry(
            cardWidth: trackLayout.cardWidth,
            availableWidth: trackLayout.availableWidth,
            curve: placement.curve,
            scale: metrics.actionTrackScale
        )
    }

    /// Only the front card of a stack, with something to swipe into.
    private var canLift: Bool {
        isInteractive && trackGeometry != nil && !swipeActions.isEmpty
    }

    private var liftOffset: CGSize {
        trackGeometry?.cardOffset(at: carryX) ?? .zero
    }

    /// Hidden at rest rather than absent, so it can draw out as the card lifts.
    @ViewBuilder
    private var actionTrack: some View {
        if let geometry = trackGeometry, !swipeActions.isEmpty {
            ToastActionTrack(
                geometry: geometry,
                actions: swipeActions,
                armed: armedSide,
                chosen: chosenSide,
                isShown: lift != .resting
            )
            .offset(y: geometry.trackOffset)
        }
    }

    /// Hold still for `holdDuration`, then carry. Runs alongside the swipe: moving 8 pt
    /// before the hold completes fails the long press, and the swipe takes over.
    private var liftGesture: some Gesture {
        LongPressGesture(minimumDuration: holdDuration, maximumDistance: 8)
            .updating($isPressing) { pressing, state, _ in state = pressing }
            .sequenced(before: DragGesture(minimumDistance: 0))
            .updating($isLiftGestureActive) { _, state, _ in state = true }
            .onChanged { value in
                guard case .second(true, let drag) = value else { return }
                if lift == .resting { liftUp() }
                if let drag { carry(drag.translation.width) }
            }
            .onEnded { value in
                guard case .second(true, _) = value else { return }
                release()
            }
    }

    private func liftUp() {
        guard lift == .resting, canLift, !isFlingingOut else { return }
        liftConsumedTouch = true
        swipeStarted = false
        withAnimation(theme.stackMotion.animation(reduceMotion: reduceMotion)) {
            lift = .lifted
            carryX = 0
            armedSide = nil
            chosenSide = nil
        }
        onInteractionChange(true)
        liftHaptic.fire(.lifted)
    }

    private func carry(_ translation: CGFloat) {
        guard lift == .lifted, let geometry = trackGeometry else { return }
        let x = geometry.carry(
            translation,
            leading: swipeActions.leading != nil,
            trailing: swipeActions.trailing != nil
        )
        if reduceMotion {
            carryX = x
        } else {
            withAnimation(.interactiveSpring(duration: 0.18, extraBounce: 0)) { carryX = x }
        }
        let side = geometry.armedSide(at: x)
        guard side != armedSide else { return }
        withAnimation(.easeOut(duration: 0.18)) { armedSide = side }
        if side != nil { liftHaptic.fire(.armed) }
    }

    /// Let go: into the armed action, or back down if none is armed.
    private func release() {
        guard lift == .lifted else { return }
        if let side = armedSide, let action = swipeActions.action(for: side) {
            choose(action, at: side)
        } else {
            putBack()
        }
    }

    /// Drops the card into the chosen end, confirms, then runs the action. The countdown
    /// stays held until the action has run.
    private func choose(_ action: ToastAction, at side: ToastTrackSide) {
        guard let geometry = trackGeometry else { return }
        onOwnExit()
        withAnimation(theme.flingMotion.animation(reduceMotion: reduceMotion)) {
            lift = .committing
            carryX = geometry.labelX(for: side)
        }
        liftHaptic.fire(.chosen(destructive: action.role == .destructive))
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: confirmationDelay)
            withAnimation(.easeOut(duration: 0.18)) { chosenSide = side }
            try? await Task.sleep(nanoseconds: removalDelay)
            onAction(action)
            onInteractionChange(false)
        }
    }

    /// Back down to full size with nothing chosen. A no-op unless the card is lifted.
    private func putBack() {
        guard lift == .lifted else { return }
        withAnimation(theme.stackMotion.animation(reduceMotion: reduceMotion)) {
            lift = .resting
            carryX = 0
            armedSide = nil
        }
        onInteractionChange(false)
    }

    /// The swipe actions VoiceOver offers by name, so a gesture is never the only way in.
    private var offeredActions: ToastSwipeActions? {
        isInteractive ? swipeActions : nil
    }
}

// MARK: - Tap

/// Attaches the tap handler only when there is one, so a toast with no tap action stays
/// genuinely inert rather than swallowing taps meant for the content behind it.
private struct ToastTapGesture: ViewModifier {
    let action: (() -> Void)?

    func body(content: Content) -> some View {
        if let action {
            content.onTapGesture { action() }
        } else {
            content
        }
    }
}

// MARK: - Accessibility actions

/// Names each swipe action for VoiceOver and Switch Control.
private struct ToastActionAccessibility: ViewModifier {
    let actions: ToastSwipeActions?
    let perform: (ToastAction) -> Void

    func body(content: Content) -> some View {
        content.accessibilityActions {
            if let leading = actions?.leading {
                Button(leading.title) { perform(leading) }
            }
            if let trailing = actions?.trailing {
                Button(trailing.title) { perform(trailing) }
            }
        }
    }
}

// MARK: - Tilt

/// A few degrees of rotation following the drag, pivoting off the card's far edge. The
/// angle comes from `ToastDragPose`, which is zero under Reduce Motion; the modifier is
/// always applied, so the card's identity does not change as a drag begins.
private struct ToastTiltEffect: ViewModifier {
    let degrees: Double

    func body(content: Content) -> some View {
        content.rotationEffect(.degrees(degrees), anchor: .bottom)
    }
}
