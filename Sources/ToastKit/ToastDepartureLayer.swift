import SwiftUI

/// A stand-in for a card the model has already removed, drawn while it animates out.
///
/// The live card is gone the moment the model drops it, so the way out is played by this
/// copy instead. It draws the card through the style in effect, with no gestures, and
/// animates one `progress` value from 0 to 1; `ToastDepartureFrame` turns that number
/// into travel, scale, opacity and blur, and `ToastDepartureEffect` applies them.
struct ToastDepartureGhost: View {
    let center: ToastCenter
    let departure: ToastDeparture
    let placement: ToastPlacement
    /// The stack's default, for a departure that did not ask for a removal of its own.
    let defaultRemoval: ToastRemoval
    /// The region the stack was given, in global coordinates.
    let region: CGRect
    let cardWidth: CGFloat
    let isTappable: Bool

    @Environment(\.toastStyle) private var style
    @Environment(\.toastTheme) private var theme
    @Environment(\.toastMetrics) private var metrics
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection

    @State private var progress: Double = 0
    @State private var startPose: ToastDragPose
    /// Measured once, at the first value `onGeometryChange` reports.
    @State private var cardFrame: CGRect?
    @State private var hasStarted = false

    /// - Parameter startPose: Where the card was being dragged, if it was removed mid-drag.
    ///   Read when the stand-in is created and never again.
    init(
        center: ToastCenter,
        departure: ToastDeparture,
        placement: ToastPlacement,
        defaultRemoval: ToastRemoval,
        region: CGRect,
        cardWidth: CGFloat,
        isTappable: Bool,
        startPose: ToastDragPose
    ) {
        self.center = center
        self.departure = departure
        self.placement = placement
        self.defaultRemoval = defaultRemoval
        self.region = region
        self.cardWidth = cardWidth
        self.isTappable = isTappable
        _startPose = State(initialValue: startPose)
    }

    var body: some View {
        style.makeBody(configuration: ToastStyleConfiguration(
            toast: departure.toast,
            isLifted: false,
            isTappable: isTappable,
            metrics: metrics.resolved(in: theme)
        ))
        .frame(width: cardWidth)
        .dynamicTypeSize(...metrics.maximumDynamicTypeSize)
        // Measured before the effect moves it, and only the first value is kept.
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { frame in
            if cardFrame == nil { cardFrame = frame }
        }
        .modifier(ToastDepartureEffect(
            progress: progress,
            kind: plan.frames,
            blurRamp: motion.blurRamp,
            depth: ToastDepthStyle(depth: departure.depth),
            start: startPose,
            unit: unit,
            distance: distance,
            peek: placement.peekSign * metrics.stackPeek * CGFloat(departure.depth),
            anchor: placement.unitPoint
        ))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear(perform: start)
    }

    // MARK: - Plan

    private var removal: ToastRemoval { departure.removal ?? defaultRemoval }

    private var motion: ToastDepartureMotion {
        ToastDepartureMotion.profile(for: .current)
    }

    private var plan: ToastDeparturePlan {
        motion.plan(
            removal: removal,
            order: departure.order,
            count: departure.batchCount,
            reduceMotion: reduceMotion
        )
    }

    /// The direction of travel, or `nil` when the removal stays where it is.
    private var unit: CGVector? {
        guard plan.frames.travels else { return nil }
        return removal.direction.unitVector(anchor: placement.anchor, isRightToLeft: layoutDirection == .rightToLeft)
    }

    /// How far a full journey is. The offsets are proportional to it, so a measurement
    /// that arrives a frame after the animation starts is not visible.
    private var distance: CGFloat {
        guard let cardFrame else { return unit == nil ? 0 : ToastDeparturePath.fallbackDistance }
        return ToastDeparturePath.distance(card: cardFrame, region: region, along: unit)
    }

    private var animation: Animation {
        switch plan.curve {
        case .stack:
            return theme.stackMotion.animation(reduceMotion: reduceMotion)
        case .trail:
            return Animation.timingCurve(0.45, 0, 0.85, 0.4, duration: plan.duration)
        }
    }

    private func start() {
        guard !hasStarted else { return }
        hasStarted = true
        let token = departure.token
        let center = center
        withAnimation(animation.delay(plan.delay)) {
            progress = 1
        } completion: {
            Task { @MainActor in center.finishDeparture(token: token) }
        }
    }
}

/// Applies a departing card's frame, in the same order the live card is dressed: the
/// drag it was in, the pile's scale, its peek, then the journey.
///
/// `Animatable` over `progress` alone: the offsets and the rest are fixed for the
/// departure, so SwiftUI interpolates one number and this recomputes the frame from it.
struct ToastDepartureEffect: ViewModifier, Animatable {
    var progress: Double
    let kind: ToastDepartureFrame.Kind
    let blurRamp: Bool
    let depth: ToastDepthStyle
    let start: ToastDragPose
    let unit: CGVector?
    let distance: CGFloat
    let peek: CGFloat
    let anchor: UnitPoint

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let frame = ToastDepartureFrame.sample(kind, progress: progress, blurRamp: blurRamp)
        let travel = CGFloat(frame.travelFraction) * distance + CGFloat(frame.extraPoints)
        return content
            .offset(x: start.x, y: start.sag)
            .rotationEffect(.degrees(start.rotationDegrees), anchor: .bottom)
            .opacity(start.opacity)
            .scaleEffect(depth.scale * CGFloat(frame.scaleFactor), anchor: anchor)
            .offset(y: peek)
            .offset(x: (unit?.dx ?? 0) * travel, y: (unit?.dy ?? 0) * travel)
            .opacity(depth.opacity * frame.opacityFactor)
            .blur(radius: depth.blur + CGFloat(frame.blurDelta))
    }
}
