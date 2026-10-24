import SwiftUI

/// A LIFO stack of toasts, drawn over the content it is applied to.
///
/// Prefer the `.toasts(_:placement:width:onTap:)` modifier over building this directly:
///
/// ```swift
/// @State private var toasts = ToastCenter()
///
/// var body: some View {
///     MyScreen()
///         .toasts(toasts)                 // bottom of the safe area
/// }
/// ```
///
/// Only `center.visibleDepth` cards are drawn; anything deeper is held in the model and
/// surfaces as the ones in front leave. The card at depth 0 is the newest, is the only
/// one that takes touches, and is the only one being timed — see ``ToastCenter`` for why
/// those three are the same card.
///
/// The stack runs every action the user chooses: the action's own handler, then any
/// `onToastAction` observer, then its effect — dismissing or postponing the toast. Each
/// time the stack appears it brings back the toasts postponed while it was away.
///
/// It sits inside the safe area of the view it is applied to, so a `TabView`'s tab bar
/// and bottom accessory are already clear, in whatever placement the system gives them.
/// Anything else covering the screen — a custom tab bar, a floating player — is cleared
/// by marking it with `toastObstruction()`.
public struct ToastStack: View {

    let center: ToastCenter
    let placement: ToastPlacement
    /// How wide the cards are drawn, against the safe-area width. See ``ToastWidth``.
    /// `nil` defers to the ``ToastMetrics`` in effect.
    let width: ToastWidth?
    /// Runs when a card with no tap action of its own is tapped.
    let onTap: ((ToastMessage) -> Void)?
    /// Obstruction scopes the `.toasts(_:)` modifier hands over, beyond the one in this
    /// view's own environment.
    var obstructionScopes: [ToastObstructionRegistry] = []

    /// - Parameters:
    ///   - center: The model the stack draws and times.
    ///   - placement: The edge the stack hangs from. Bottom by default.
    ///   - width: How wide cards are drawn. Omit it to use the ``ToastMetrics`` width: 60%
    ///     of the safe-area width by default, the full width on watchOS. An explicit width
    ///     always wins.
    ///   - onTap: Runs for a tapped toast that has no ``ToastMessage/tapAction`` of its
    ///     own, then the toast is dismissed. Omit it to leave such toasts inert to taps.
    public init(
        center: ToastCenter,
        placement: ToastPlacement = .bottom,
        width: ToastWidth? = nil,
        onTap: ((ToastMessage) -> Void)? = nil
    ) {
        self.center = center
        self.placement = placement
        self.width = width
        self.onTap = onTap
    }

    @Environment(\.toastTheme) private var theme
    @Environment(\.toastMetrics) private var metrics
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.toastActionHandler) private var actionObserver
    @Environment(\.toastObstructions) private var environmentObstructions

    /// The card lifted onto its action track by a long press, if any.
    @State private var liftedToastID: UUID?
    /// The region the stack was given, in global coordinates, before keeping clear of
    /// anything.
    @State private var region: CGRect = .zero

    /// Width the pile loses per layer of depth.
    private let scaleStep: CGFloat = 0.05
    /// How far each buried card peeks past the one in front of it: derived from the
    /// preset's padding. The theme's padding does not change it: the kit owns the stack.
    private var peekStep: CGFloat { metrics.stackPeek }

    public var body: some View {
        // The reader measures the region the stack was handed; `availableWidth` then
        // subtracts any safe area still inside it. There is deliberately no horizontal
        // padding — the card's own width *is* the layout, so `fraction(1)` can mean the
        // full safe-area width rather than that minus a margin nobody asked for.
        GeometryReader { proxy in
            let available = availableWidth(in: proxy)
            cards(width: metrics.resolvedWidth(explicit: width).resolved(in: available), available: available)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: placement.alignment)
        }
        .padding(placement.paddingEdge, theme.edgeInset + obstructionLift)
        // Measured outside the padding, so keeping clear never moves what is measured.
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { frame in
            region = frame
        }
        // Outside the padding, so the dimming reaches the edge the stack hangs from.
        .background { liftScrim }
        .onPreferenceChange(ToastLiftPreferenceKey.self) { liftedToastID = $0 }
        .animation(.easeInOut(duration: 0.3), value: liftedToastID)
        .animation(theme.stackMotion.animation(reduceMotion: reduceMotion), value: center.toasts)
        .animation(theme.stackMotion.animation(reduceMotion: reduceMotion), value: obstructionLift)
        .modifier(ToastArrivalFeedback(center: center))
        // Hold the countdown while the app is out of the foreground — inactive covers
        // Control Center and the app switcher too — so a toast never expires unseen.
        .onChange(of: scenePhase, initial: true) { _, phase in
            center.setSuspended(phase != .active)
        }
        // The page is being opened again: bring back what was put off until now.
        .onAppear { center.restorePostponed() }
    }

    private func cards(width cardWidth: CGFloat, available: CGFloat) -> some View {
        ZStack(alignment: placement.alignment) {
            ForEach(visibleToasts) { toast in
                let depth = center.depth(of: toast) ?? 0

                ToastCard(
                    toast: toast,
                    isInteractive: depth == 0,
                    tapAction: tapAction(for: toast),
                    onInteractionChange: { center.setInteracting($0) },
                    onAction: { perform($0, on: toast) },
                    onDismiss: { center.dismiss(id: toast.id) }
                )
                .frame(width: cardWidth)
                // What a card needs to bend its swipe and lay out its long-press track.
                .environment(\.toastPlacement, placement)
                .environment(\.toastTrackLayout, ToastTrackLayout(cardWidth: cardWidth, availableWidth: available))
                .scaleEffect(1 - scaleStep * CGFloat(depth), anchor: placement.unitPoint)
                .offset(y: placement.peekSign * peekStep * CGFloat(depth))
                // While a card rides its track, the ones behind step out of the way.
                .opacity(depth != 0 && liftedToastID != nil ? 0 : 1 - 0.16 * Double(depth))
                // A hair of defocus on the buried cards: cheap depth cue, and it stops
                // their text competing for attention through the translucent front card.
                .blur(radius: depth == 0 ? 0 : 1.4)
                .zIndex(Double(center.capacity - depth))
                .accessibilityHidden(depth != 0)
                .transition(transition)
            }
        }
    }

    // MARK: - Actions

    /// The toast's own tap action, or one wrapping the stack's `onTap`.
    private func tapAction(for toast: ToastMessage) -> ToastAction? {
        if let own = toast.tapAction { return own }
        guard let onTap else { return nil }
        return ToastAction(
            id: ToastAction.tapID,
            title: String(localized: "toast.action.open", bundle: .module),
            handler: { onTap($0) }
        )
    }

    /// The action's own work, then the observer's, then what happens to the toast.
    private func perform(_ action: ToastAction, on toast: ToastMessage) {
        action.handler?(toast)
        actionObserver?.perform(toast, action)
        switch action.effect {
        case .dismiss:
            center.dismiss(id: toast.id)
        case .postpone:
            center.postpone(id: toast.id)
        }
    }

    // MARK: - Keeping clear

    /// How far the stack moves off its edge to clear the views marked with
    /// `toastObstruction()` that it can see.
    private var obstructionLift: CGFloat {
        let scopes = obstructionScopes + [environmentObstructions].compactMap { $0 }
        let frames = scopes.flatMap { $0.frames.values }
        return ToastObstructionLayout.lift(for: region, anchor: placement.anchor, obstructions: frames)
    }

    // MARK: - Drawing

    /// Dims what is behind the stack while a card rides its action track, so the track
    /// and the card read clearly over any content. Never takes touches.
    private var liftScrim: some View {
        Color.black
            .opacity(liftedToastID == nil ? 0 : 0.16)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }

    /// The stack's own width minus whatever safe area is still inside it.
    ///
    /// Attached to a view that already excludes the safe area — the usual case — the
    /// insets are zero and this is just the width. Attached to one that ignores it,
    /// this is what keeps a full-width card clear of the notch and home indicator.
    private func availableWidth(in proxy: GeometryProxy) -> CGFloat {
        let insets = proxy.safeAreaInsets
        return max(0, proxy.size.width - insets.leading - insets.trailing)
    }

    /// Newest last, so `ForEach` order matches the model and `zIndex` does the layering.
    private var visibleToasts: [ToastMessage] {
        Array(center.toasts.suffix(center.visibleDepth))
    }

    /// Insertion drops in from the anchored edge and settles; removal is a plain fade,
    /// because a swiped card has already flung itself off-screen by the time it is
    /// removed and an expired one should simply dissolve.
    private var transition: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(
            insertion: .move(edge: placement.transitionEdge)
                .combined(with: .scale(scale: 0.92, anchor: placement.unitPoint))
                .combined(with: .opacity),
            removal: .opacity
        )
    }
}

// MARK: - Arrival feedback

/// Plays the theme's haptic when a new toast becomes topmost.
///
/// Split into a modifier so the whole feature can be compiled out on visionOS, where
/// `SensoryFeedback` is 26+ and there is no haptic engine, without `#if` scattered
/// through the stack's body.
private struct ToastArrivalFeedback: ViewModifier {
    let center: ToastCenter

    @Environment(\.toastTheme) private var theme

    func body(content: Content) -> some View {
        #if os(visionOS)
        content
        #else
        content.sensoryFeedback(trigger: center.topmost?.id) { previous, current in
            guard let current, current != previous else { return nil }
            return center.topmost.map { theme.feedback($0.status) } ?? nil
        }
        #endif
    }
}

// MARK: - Presentation

public extension View {

    /// Draws `center`'s toasts over this view.
    ///
    /// Apply it to the view whose safe area the toasts should respect. Inside a
    /// `TabView`, apply it to the tab's content: the tab bar and its bottom accessory are
    /// in that safe area, so the stack sits above them however they are laid out. Over a
    /// custom tab bar, mark the bar with `toastObstruction()` and the stack lifts itself
    /// clear of it.
    ///
    /// ```swift
    /// @State private var toasts = ToastCenter()
    ///
    /// ContentView()
    ///     .toasts(toasts)                                   // bottom, 60% wide
    ///     .toasts(toasts, placement: .top)                  // from the top
    ///     .toasts(toasts, width: .fraction(0.9))            // 90% of the safe area
    ///     .toasts(toasts) { toast in open(toast) }          // tap to open
    ///     .toasts(toasts).toastMetrics(.compact)            // a smaller card
    /// ```
    ///
    /// Cards are drawn by the ``ToastStyle`` in effect — `.glass` unless you set another
    /// with `toastStyle(_:)` — and observed with `onToastAction(perform:)`.
    ///
    /// - Parameters:
    ///   - center: The model to draw. Keep it in `@State`.
    ///   - placement: The edge the stack hangs from. Bottom by default.
    ///   - width: How wide cards are drawn, against the safe-area width. Omit it for the
    ///     width of the ``ToastMetrics`` in effect: 60% by default, the full width on
    ///     watchOS. An explicit width always wins. `.fraction(1)` is the maximum and
    ///     `.points(_:)` is clamped to it.
    ///   - onTap: Runs for a tapped toast that has no tap action of its own, then the
    ///     toast is dismissed.
    func toasts(
        _ center: ToastCenter,
        placement: ToastPlacement = .bottom,
        width: ToastWidth? = nil,
        onTap: ((ToastMessage) -> Void)? = nil
    ) -> some View {
        modifier(ToastStackModifier(center: center, placement: placement, width: width, onTap: onTap))
    }
}

/// Lays the stack over the content, and gives the content an obstruction scope of its
/// own so a marked view inside it — a custom tab bar beside the screens — is seen
/// without any further setup.
private struct ToastStackModifier: ViewModifier {
    let center: ToastCenter
    let placement: ToastPlacement
    let width: ToastWidth?
    let onTap: ((ToastMessage) -> Void)?

    @State private var contentObstructions = ToastObstructionRegistry()
    @Environment(\.toastObstructions) private var enclosingObstructions

    func body(content: Content) -> some View {
        content
            .environment(\.toastObstructions, contentObstructions)
            .overlay(alignment: placement.alignment) {
                stack
            }
    }

    private var stack: ToastStack {
        var stack = ToastStack(center: center, placement: placement, width: width, onTap: onTap)
        stack.obstructionScopes = [contentObstructions] + [enclosingObstructions].compactMap { $0 }
        return stack
    }
}

// MARK: - Preview

/// A playground for Xcode previews: `#Preview { ToastStackPreview() }`.
struct ToastStackPreview: View {
    @State private var center = ToastCenter()
    @State private var counter = 0
    @State private var placement = ToastPlacement.bottom

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.blue, .purple, .indigo],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Spacer()
                Button("Add toast") { addToast() }
                    .buttonStyle(.borderedProminent)
                Button("Add persistent toast") {
                    center.present(.error, title: "Sync failed", message: "Swipe to dismiss.", duration: .indefinite)
                }
                Button("Dismiss all") { center.dismissAll() }
                Button(placement == .bottom ? "Move to top" : "Move to bottom") {
                    placement = placement == .bottom ? .top : .bottom
                }
                Spacer()
            }
        }
        .toasts(center, placement: placement)
    }

    private func addToast() {
        counter += 1
        let statuses = ToastMessage.Status.allCases
        center.present(
            statuses[counter % statuses.count],
            title: "Notification #\(counter)",
            message: "Swipe left to delete, right for later, or hold to see both."
        )
    }
}
