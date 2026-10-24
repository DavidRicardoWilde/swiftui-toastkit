import CoreGraphics
import XCTest
@testable import ToastKit

/// The quick swipe's thresholds, pinned without a view host.
final class ToastSwipeTests: XCTestCase {

    // MARK: - Following the finger

    func testTheCardFollowsTowardASideWithAnAction() {
        XCTAssertEqual(ToastSwipe.follow(-60, leading: true, trailing: true), -60)
        XCTAssertEqual(ToastSwipe.follow(60, leading: true, trailing: true), 60)
    }

    func testTheCardBarelyMovesTowardASideWithoutOne() {
        XCTAssertEqual(ToastSwipe.follow(50, leading: true, trailing: false), 9, accuracy: 0.0001)
        XCTAssertEqual(ToastSwipe.follow(500, leading: true, trailing: false), ToastSwipe.maxResisted)
        XCTAssertEqual(ToastSwipe.follow(-500, leading: false, trailing: true), -ToastSwipe.maxResisted)
    }

    // MARK: - Letting go

    func testASwipePastTheThresholdRunsThatSide() {
        XCTAssertEqual(ToastSwipe.commit(travel: -88, projected: -88, leading: true, trailing: true), .leading)
        XCTAssertEqual(ToastSwipe.commit(travel: 88, projected: 88, leading: true, trailing: true), .trailing)
    }

    func testAShortSlowSwipeSpringsBack() {
        XCTAssertNil(ToastSwipe.commit(travel: 87, projected: 120, leading: true, trailing: true))
    }

    func testAFlickCommitsEvenWhenShort() {
        XCTAssertEqual(ToastSwipe.commit(travel: 30, projected: 220, leading: true, trailing: true), .trailing)
    }

    func testAFlickGoesTheWayItWasThrownEvenIfItReverses() {
        XCTAssertEqual(ToastSwipe.commit(travel: -40, projected: 260, leading: true, trailing: true), .leading)
    }

    func testASwipeTowardASideWithoutAnActionSpringsBack() {
        XCTAssertNil(ToastSwipe.commit(travel: 200, projected: 400, leading: true, trailing: false))
        XCTAssertNil(ToastSwipe.commit(travel: -200, projected: -400, leading: false, trailing: true))
    }

    // MARK: - The drag pose

    func testThePoseSagsTowardTheStacksEdgeAndCapsAt160() {
        XCTAssertEqual(ToastDragPose(dragX: 90, curve: 1, reduceMotion: false).sag, 4.5, accuracy: 0.0001)
        XCTAssertEqual(ToastDragPose(dragX: -90, curve: -1, reduceMotion: false).sag, -4.5, accuracy: 0.0001)
        XCTAssertEqual(ToastDragPose(dragX: 1_400, curve: 1, reduceMotion: false).sag, 160)
    }

    func testThePoseFadesWithTravelDownToAFloorOf35Percent() {
        XCTAssertEqual(ToastDragPose(dragX: 0, curve: 1, reduceMotion: false).opacity, 1)
        XCTAssertEqual(ToastDragPose(dragX: 120, curve: 1, reduceMotion: false).opacity, 0.5, accuracy: 0.0001)
        XCTAssertEqual(ToastDragPose(dragX: -120, curve: 1, reduceMotion: false).opacity, 0.5, accuracy: 0.0001)
        XCTAssertEqual(ToastDragPose(dragX: 1_000, curve: 1, reduceMotion: false).opacity, 0.35, accuracy: 0.0001)
    }

    func testThePoseTiltsByOneDegreePer36Points() {
        XCTAssertEqual(ToastDragPose(dragX: 72, curve: 1, reduceMotion: false).rotationDegrees, 2, accuracy: 0.0001)
        XCTAssertEqual(ToastDragPose(dragX: 72, curve: 1, reduceMotion: false).x, 72)
    }

    func testReduceMotionRemovesTheTiltAndTheSag() {
        let pose = ToastDragPose(dragX: 200, curve: 1, reduceMotion: true)
        XCTAssertEqual(pose.sag, 0)
        XCTAssertEqual(pose.rotationDegrees, 0)
        XCTAssertEqual(pose.x, 200)
    }

    @MainActor
    func testTheRegistryHandsBackWhatWasWrittenAndRestOtherwise() {
        let registry = ToastDragPoseRegistry()
        let id = UUID()
        XCTAssertEqual(registry.pose(for: id), .rest)

        let pose = ToastDragPose(dragX: 50, curve: 1, reduceMotion: false)
        registry.set(pose, for: id)
        XCTAssertEqual(registry.pose(for: id), pose)

        registry.clear(id)
        XCTAssertEqual(registry.pose(for: id), .rest)
    }
}
