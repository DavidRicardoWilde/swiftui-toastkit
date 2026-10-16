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

    // MARK: - Letting go of a card a swipe lifted onto the track

    func testTheArmedEndRunsWhenLetGo() {
        XCTAssertEqual(ToastSwipe.release(armed: .leading, travel: -64, projected: -64, leading: true, trailing: true), .leading)
        XCTAssertEqual(ToastSwipe.release(armed: .trailing, travel: 70, projected: 70, leading: true, trailing: true), .trailing)
    }

    func testTheArmedEndWinsOverAFlickBack() {
        XCTAssertEqual(ToastSwipe.release(armed: .trailing, travel: 70, projected: -300, leading: true, trailing: true), .trailing)
    }

    func testAFlickShortOfTheArmPointStillRunsThatSide() {
        XCTAssertEqual(ToastSwipe.release(armed: nil, travel: -30, projected: -240, leading: true, trailing: true), .leading)
    }

    func testLettingGoShortWithoutAFlickPutsTheCardBack() {
        XCTAssertNil(ToastSwipe.release(armed: nil, travel: 40, projected: 90, leading: true, trailing: true))
    }

    func testAFlickTowardASideWithoutAnActionPutsTheCardBack() {
        XCTAssertNil(ToastSwipe.release(armed: nil, travel: 30, projected: 400, leading: true, trailing: false))
    }
}
