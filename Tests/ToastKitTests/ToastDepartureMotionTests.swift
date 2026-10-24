import XCTest
@testable import ToastKit

/// The trail's timing and keyframes, and the pile's depth look, pinned without a view host.
final class ToastDepartureMotionTests: XCTestCase {

    private let ios = ToastDepartureMotion.profile(for: .iOS)

    // MARK: - Stagger

    func testAloneACardWaitsForNothing() {
        XCTAssertEqual(ios.stagger(count: 1), 0)
        XCTAssertEqual(ios.stagger(count: 0), 0)
        XCTAssertEqual(ios.delay(order: 0, count: 1), 0)
    }

    func testThreeCardsOnIOSAreStaggeredByTheMaximum() {
        XCTAssertEqual(ios.stagger(count: 3), 0.055, accuracy: 0.000_001)
        XCTAssertEqual(ios.cardDuration + 2 * ios.stagger(count: 3), 0.43, accuracy: 0.000_001)
    }

    func testABatchNeverTakesLongerThanTheCapOnAnyPlatform() {
        for platform in ToastPlatform.allCases {
            let motion = ToastDepartureMotion.profile(for: platform)
            for count in 1...12 {
                let total = motion.cardDuration + Double(count - 1) * motion.stagger(count: count)
                XCTAssertLessThanOrEqual(total, motion.cap + 0.000_001, "\(platform) \(count)")
            }
        }
    }

    func testDelaysIncreaseWithOrder() {
        let delays = (0..<4).map { ios.delay(order: $0, count: 4) }
        XCTAssertEqual(delays.first, 0)
        XCTAssertEqual(delays, delays.sorted())
        XCTAssertEqual(Set(delays).count, 4)
    }

    func testWatchAndVisionProfiles() {
        let watch = ToastDepartureMotion.profile(for: .watchOS)
        XCTAssertEqual(watch.cap, 0.45)
        XCTAssertEqual(watch.maxStagger, 0.04)
        XCTAssertFalse(watch.blurRamp)
        XCTAssertFalse(ToastDepartureMotion.profile(for: .visionOS).blurRamp)
        XCTAssertTrue(ToastDepartureMotion.profile(for: .iOS).blurRamp)
        XCTAssertTrue(ToastDepartureMotion.profile(for: .macOS).blurRamp)
    }

    // MARK: - Plans

    func testTheDefaultFadeStartsAtOnceOnTheStackCurve() {
        let plan = ios.plan(removal: .fade, order: 2, count: 3, reduceMotion: false)
        XCTAssertEqual(plan.delay, 0)
        XCTAssertEqual(plan.curve, .stack)
        XCTAssertEqual(plan.frames, .fade)
    }

    func testASlideMovesAllCardsTogetherOnTheTrailCurve() {
        let plan = ios.plan(removal: .slide(), order: 2, count: 3, reduceMotion: false)
        XCTAssertEqual(plan.delay, 0)
        XCTAssertEqual(plan.curve, .trail)
        XCTAssertEqual(plan.frames, .slide)
    }

    func testATrailDelaysEachCardByItsOrder() {
        let plan = ios.plan(removal: .trail(), order: 2, count: 3, reduceMotion: false)
        XCTAssertEqual(plan.delay, 0.11, accuracy: 0.000_001)
        XCTAssertEqual(plan.curve, .trail)
        XCTAssertEqual(plan.frames, .trail)
    }

    func testReduceMotionFadesEveryRemovalTogetherWithNoTravel() {
        let removals: [ToastRemoval] = [
            .fade, .slide(), .slide(.trailing), .trail(), .trail(.degrees(30)), .trail(.vector(dx: 1, dy: 1))
        ]
        for platform in ToastPlatform.allCases {
            let motion = ToastDepartureMotion.profile(for: platform)
            for removal in removals {
                let plan = motion.plan(removal: removal, order: 3, count: 5, reduceMotion: true)
                XCTAssertEqual(plan.delay, 0)
                XCTAssertEqual(plan.curve, .stack)
                XCTAssertEqual(plan.frames, .reduced)
                XCTAssertFalse(plan.frames.travels)
            }
        }
        for progress in stride(from: 0.0, through: 1.0, by: 0.1) {
            let frame = ToastDepartureFrame.sample(.reduced, progress: progress, blurRamp: true)
            XCTAssertEqual(frame.travelFraction, 0)
            XCTAssertEqual(frame.extraPoints, 0)
            XCTAssertEqual(frame.scaleFactor, 1)
            XCTAssertEqual(frame.blurDelta, 0)
        }
    }

    // MARK: - Keyframes

    func testTheFirstFrameIsTheCardAsItWas() {
        for kind in [ToastDepartureFrame.Kind.fade, .reduced, .slide, .trail] {
            let frame = ToastDepartureFrame.sample(kind, progress: 0, blurRamp: true)
            XCTAssertEqual(frame.travelFraction, 0)
            XCTAssertEqual(frame.extraPoints, 0)
            XCTAssertEqual(frame.opacityFactor, 1)
            XCTAssertEqual(frame.scaleFactor, 1)
            XCTAssertEqual(frame.blurDelta, 0)
        }
    }

    func testTheLastFrameIsInvisible() {
        for kind in [ToastDepartureFrame.Kind.fade, .reduced, .slide, .trail] {
            let frame = ToastDepartureFrame.sample(kind, progress: 1, blurRamp: true)
            XCTAssertEqual(frame.opacityFactor, 0, accuracy: 0.000_001)
        }
        let trail = ToastDepartureFrame.sample(.trail, progress: 1, blurRamp: true)
        XCTAssertEqual(trail.travelFraction, 1, accuracy: 0.000_001)
        XCTAssertEqual(trail.scaleFactor, 0.85, accuracy: 0.000_001)
        XCTAssertEqual(trail.blurDelta, 10, accuracy: 0.000_001)
    }

    func testTheTableIsInterpolatedAtItsKeys() {
        let mid = ToastDepartureFrame.sample(.trail, progress: 0.45, blurRamp: true)
        XCTAssertEqual(mid.travelFraction, 0.3, accuracy: 0.000_001)
        XCTAssertEqual(mid.opacityFactor, 0.85, accuracy: 0.000_001)
        XCTAssertEqual(mid.scaleFactor, 0.96, accuracy: 0.000_001)
        XCTAssertEqual(mid.blurDelta, 2, accuracy: 0.000_001)

        let late = ToastDepartureFrame.sample(.slide, progress: 0.75, blurRamp: true)
        XCTAssertEqual(late.travelFraction, 0.7, accuracy: 0.000_001)
        XCTAssertEqual(late.opacityFactor, 0.4, accuracy: 0.000_001)
        XCTAssertEqual(late.scaleFactor, 0.90, accuracy: 0.000_001)
    }

    func testAfterTheWindUpOpacityNeverRisesAndTravelNeverFalls() {
        var previous = ToastDepartureFrame.sample(.trail, progress: 0.15, blurRamp: true)
        for step in 16...100 {
            let frame = ToastDepartureFrame.sample(.trail, progress: Double(step) / 100, blurRamp: true)
            XCTAssertLessThanOrEqual(frame.opacityFactor, previous.opacityFactor + 0.000_001)
            XCTAssertGreaterThanOrEqual(frame.travelFraction, previous.travelFraction - 0.000_001)
            previous = frame
        }
    }

    func testOnlyATrailWindsUpBeforeLeaving() {
        XCTAssertEqual(ToastDepartureFrame.sample(.trail, progress: 0.15, blurRamp: true).extraPoints, -8)
        XCTAssertEqual(ToastDepartureFrame.sample(.slide, progress: 0.15, blurRamp: true).extraPoints, 0)
        XCTAssertEqual(ToastDepartureFrame.sample(.fade, progress: 0.15, blurRamp: true).extraPoints, 0)
    }

    func testProgressBeyondTheRangeIsClamped() {
        for kind in [ToastDepartureFrame.Kind.fade, .slide, .trail] {
            XCTAssertEqual(
                ToastDepartureFrame.sample(kind, progress: 1.4, blurRamp: true),
                ToastDepartureFrame.sample(kind, progress: 1, blurRamp: true)
            )
            XCTAssertEqual(
                ToastDepartureFrame.sample(kind, progress: -0.3, blurRamp: true),
                ToastDepartureFrame.sample(kind, progress: 0, blurRamp: true)
            )
        }
    }

    func testBlurOnlyRampsWhenTheProfileAllowsIt() {
        XCTAssertEqual(ToastDepartureFrame.sample(.trail, progress: 0.75, blurRamp: false).blurDelta, 0)
        XCTAssertEqual(ToastDepartureFrame.sample(.trail, progress: 0.75, blurRamp: true).blurDelta, 6, accuracy: 0.000_001)
        XCTAssertEqual(ToastDepartureFrame.sample(.slide, progress: 0.75, blurRamp: true).blurDelta, 0)
    }

    func testAPlainFadeChangesOnlyOpacity() {
        let frame = ToastDepartureFrame.sample(.fade, progress: 0.5, blurRamp: true)
        XCTAssertEqual(frame.opacityFactor, 0.5, accuracy: 0.000_001)
        XCTAssertEqual(frame.travelFraction, 0)
        XCTAssertEqual(frame.scaleFactor, 1)
        XCTAssertEqual(frame.blurDelta, 0)
    }

    // MARK: - The pile

    func testDepthStyleKeepsTheStacksConstants() {
        let front = ToastDepthStyle(depth: 0)
        XCTAssertEqual(front.scale, 1)
        XCTAssertEqual(front.opacity, 1)
        XCTAssertEqual(front.blur, 0)

        let second = ToastDepthStyle(depth: 2)
        XCTAssertEqual(second.scale, 0.9, accuracy: 0.000_001)
        XCTAssertEqual(second.opacity, 0.68, accuracy: 0.000_001)
        XCTAssertEqual(second.blur, 1.4, accuracy: 0.000_001)
    }

    // MARK: - Scopes

    func testScopesSayWhichSetsTheyReach() {
        XCTAssertTrue(ToastDismissalScope.onScreen.includesOnScreen)
        XCTAssertFalse(ToastDismissalScope.onScreen.includesPostponed)
        XCTAssertFalse(ToastDismissalScope.postponed.includesOnScreen)
        XCTAssertTrue(ToastDismissalScope.postponed.includesPostponed)
        XCTAssertTrue(ToastDismissalScope.everywhere.includesOnScreen)
        XCTAssertTrue(ToastDismissalScope.everywhere.includesPostponed)
    }
}
