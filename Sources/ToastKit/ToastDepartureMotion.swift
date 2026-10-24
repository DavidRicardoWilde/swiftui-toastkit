import CoreGraphics
import Foundation

/// The timing and shape of a removal animation, with no SwiftUI in it.
///
/// The stand-in cards animate a single `progress` from 0 to 1; everything about how that
/// number becomes travel, opacity, scale and blur is decided here, so it is unit-tested.
struct ToastDepartureMotion: Equatable {
    /// Seconds one card takes to leave.
    var cardDuration: TimeInterval
    /// Most seconds a whole batch may take, first card to last.
    var cap: TimeInterval
    /// Longest gap between one card starting and the next.
    var maxStagger: TimeInterval
    /// Whether the departing card blurs as it goes.
    var blurRamp: Bool

    static func profile(for platform: ToastPlatform) -> ToastDepartureMotion {
        switch platform {
        case .iOS, .macOS:
            ToastDepartureMotion(cardDuration: 0.32, cap: 0.6, maxStagger: 0.055, blurRamp: true)
        case .watchOS:
            ToastDepartureMotion(cardDuration: 0.32, cap: 0.45, maxStagger: 0.04, blurRamp: false)
        case .visionOS:
            ToastDepartureMotion(cardDuration: 0.32, cap: 0.6, maxStagger: 0.055, blurRamp: false)
        }
    }

    /// Gap between one card starting and the next, for `count` cards leaving together.
    /// Shrinks so that `cardDuration + (count - 1) * stagger` never passes `cap`.
    func stagger(count: Int) -> TimeInterval {
        guard count > 1 else { return 0 }
        return max(0, min(maxStagger, (cap - cardDuration) / Double(count - 1)))
    }

    /// Seconds card number `order` (0 is the front) waits before it starts.
    func delay(order: Int, count: Int) -> TimeInterval {
        Double(max(0, order)) * stagger(count: count)
    }

    func plan(removal: ToastRemoval, order: Int, count: Int, reduceMotion: Bool) -> ToastDeparturePlan {
        if reduceMotion {
            return ToastDeparturePlan(delay: 0, duration: cardDuration, curve: .stack, frames: .reduced)
        }
        switch removal.kind {
        case .fade:
            return ToastDeparturePlan(delay: 0, duration: cardDuration, curve: .stack, frames: .fade)
        case .slide:
            return ToastDeparturePlan(delay: 0, duration: cardDuration, curve: .trail, frames: .slide)
        case .trail:
            return ToastDeparturePlan(
                delay: delay(order: order, count: count),
                duration: cardDuration,
                curve: .trail,
                frames: .trail
            )
        }
    }
}

/// When one stand-in card starts, which curve drives it and what shape it follows.
struct ToastDeparturePlan: Equatable {

    /// The easing of the progress value. The view maps each to an `Animation`.
    enum Curve: Equatable {
        /// The theme's stack motion, so a default removal feels like it always did.
        case stack
        /// A fixed ease-in curve: slow to start, quick to leave.
        case trail
    }

    let delay: TimeInterval
    /// Used by the ``Curve/trail`` curve; the stack curve takes the theme's own duration.
    let duration: TimeInterval
    let curve: Curve
    let frames: ToastDepartureFrame.Kind
}

/// One sample of a departing card's keyframe table.
struct ToastDepartureFrame: Equatable {

    enum Kind: Equatable {
        /// Opacity only: the default removal.
        case fade
        /// Opacity only, under Reduce Motion. Nothing moves, scales or blurs.
        case reduced
        /// Travel, scale and opacity, with no wind-up and no blur.
        case slide
        /// Wind-up, travel, scale, opacity and blur.
        case trail

        /// Whether the card travels along a direction.
        var travels: Bool { self == .slide || self == .trail }
    }

    /// Share of the full travel distance covered so far, 0…1.
    var travelFraction: Double
    /// Points added on top of the travel: the trail's small step back before it leaves.
    var extraPoints: Double
    var opacityFactor: Double
    var scaleFactor: Double
    /// Radius added to the card's own blur. Zero unless `blurRamp` is on.
    var blurDelta: Double

    private static let times: [Double] = [0, 0.15, 0.45, 0.75, 1]
    private static let travel: [Double] = [0, 0, 0.3, 0.7, 1]
    private static let wind: [Double] = [0, -8, 0, 0, 0]
    private static let opacity: [Double] = [1, 1, 0.85, 0.4, 0]
    private static let scale: [Double] = [1, 1.02, 0.96, 0.90, 0.85]
    private static let blur: [Double] = [0, 0, 2, 6, 10]

    /// The frame at `progress`, linearly interpolated between the table's keys.
    /// `progress` is clamped to 0…1, so a spring that overshoots cannot bring a fading
    /// card back.
    static func sample(_ kind: Kind, progress: Double, blurRamp: Bool) -> ToastDepartureFrame {
        let t = progress.isFinite ? min(max(progress, 0), 1) : 0
        switch kind {
        case .fade, .reduced:
            return ToastDepartureFrame(
                travelFraction: 0, extraPoints: 0, opacityFactor: 1 - t, scaleFactor: 1, blurDelta: 0
            )
        case .slide, .trail:
            let isTrail = kind == .trail
            return ToastDepartureFrame(
                travelFraction: interpolate(travel, at: t),
                extraPoints: isTrail ? interpolate(wind, at: t) : 0,
                opacityFactor: interpolate(opacity, at: t),
                scaleFactor: interpolate(scale, at: t),
                blurDelta: isTrail && blurRamp ? interpolate(blur, at: t) : 0
            )
        }
    }

    private static func interpolate(_ values: [Double], at t: Double) -> Double {
        for index in 1..<times.count where t <= times[index] {
            let span = times[index] - times[index - 1]
            let fraction = (t - times[index - 1]) / span
            return values[index - 1] + (values[index] - values[index - 1]) * fraction
        }
        return values[values.count - 1]
    }
}
