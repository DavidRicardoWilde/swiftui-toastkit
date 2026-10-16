import CoreGraphics
import XCTest
@testable import ToastKit

/// The quick swipe's axis and thresholds, pinned without a view host.
final class ToastSwipeTests: XCTestCase {

    private let sideways = ToastSwipeActions()
    private let leadingOnly = ToastSwipeActions(leading: .delete, trailing: nil)
    private let trailingOnly = ToastSwipeActions(leading: nil, trailing: .later)
    private let upDown = ToastSwipeActions.vertical(up: .later, down: .delete)
    private let fourWays = ToastSwipeActions(up: .later, down: .delete)

    // MARK: - Picking the axis

    func testASwipeMovesAlongTheOnlyAxisWithActions() {
        XCTAssertEqual(ToastSwipe.axis(for: CGSize(width: 2, height: 40), actions: sideways), .horizontal)
        XCTAssertEqual(ToastSwipe.axis(for: CGSize(width: 40, height: 2), actions: upDown), .vertical)
    }

    func testWithActionsBothWaysTheFirstMovementPicksTheAxis() {
        XCTAssertEqual(ToastSwipe.axis(for: CGSize(width: 9, height: 4), actions: fourWays), .horizontal)
        XCTAssertEqual(ToastSwipe.axis(for: CGSize(width: -4, height: -9), actions: fourWays), .vertical)
    }

    func testAToastWithNoActionsSwipesSideways() {
        XCTAssertEqual(ToastSwipe.axis(for: CGSize(width: 0, height: 40), actions: .disabled), .horizontal)
    }

    // MARK: - Following the finger

    func testTheCardFollowsTowardASideWithAnAction() {
        XCTAssertEqual(ToastSwipe.follow(-60, along: .horizontal, actions: sideways), -60)
        XCTAssertEqual(ToastSwipe.follow(60, along: .horizontal, actions: sideways), 60)
        XCTAssertEqual(ToastSwipe.follow(-60, along: .vertical, actions: upDown), -60)
        XCTAssertEqual(ToastSwipe.follow(60, along: .vertical, actions: upDown), 60)
    }

    func testTheCardBarelyMovesTowardASideWithoutOne() {
        XCTAssertEqual(ToastSwipe.follow(50, along: .horizontal, actions: leadingOnly), 9, accuracy: 0.0001)
        XCTAssertEqual(ToastSwipe.follow(500, along: .horizontal, actions: leadingOnly), ToastSwipe.maxResisted)
        XCTAssertEqual(ToastSwipe.follow(-500, along: .horizontal, actions: trailingOnly), -ToastSwipe.maxResisted)
        XCTAssertEqual(ToastSwipe.follow(-500, along: .vertical, actions: sideways), -ToastSwipe.maxResisted)
    }

    // MARK: - Letting go

    func testASwipePastTheThresholdRunsThatSide() {
        XCTAssertEqual(ToastSwipe.commit(travel: -88, projected: -88, along: .horizontal, actions: sideways), .leading)
        XCTAssertEqual(ToastSwipe.commit(travel: 88, projected: 88, along: .horizontal, actions: sideways), .trailing)
        XCTAssertEqual(ToastSwipe.commit(travel: -88, projected: -88, along: .vertical, actions: upDown), .up)
        XCTAssertEqual(ToastSwipe.commit(travel: 88, projected: 88, along: .vertical, actions: upDown), .down)
    }

    func testAShortSlowSwipeSpringsBack() {
        XCTAssertNil(ToastSwipe.commit(travel: 87, projected: 120, along: .horizontal, actions: sideways))
        XCTAssertNil(ToastSwipe.commit(travel: -87, projected: -120, along: .vertical, actions: upDown))
    }

    func testAFlickCommitsEvenWhenShort() {
        XCTAssertEqual(ToastSwipe.commit(travel: 30, projected: 220, along: .horizontal, actions: sideways), .trailing)
        XCTAssertEqual(ToastSwipe.commit(travel: -30, projected: -220, along: .vertical, actions: upDown), .up)
    }

    func testAFlickGoesTheWayItWasThrownEvenIfItReverses() {
        XCTAssertEqual(ToastSwipe.commit(travel: -40, projected: 260, along: .horizontal, actions: sideways), .leading)
        XCTAssertEqual(ToastSwipe.commit(travel: 40, projected: -260, along: .vertical, actions: upDown), .down)
    }

    func testASwipeTowardASideWithoutAnActionSpringsBack() {
        XCTAssertNil(ToastSwipe.commit(travel: 200, projected: 400, along: .horizontal, actions: leadingOnly))
        XCTAssertNil(ToastSwipe.commit(travel: -200, projected: -400, along: .horizontal, actions: trailingOnly))
        XCTAssertNil(ToastSwipe.commit(travel: 200, projected: 400, along: .vertical, actions: sideways))
    }

    // MARK: - Letting go of a card a swipe lifted onto the track

    func testTheArmedEndRunsWhenLetGo() {
        XCTAssertEqual(
            ToastSwipe.release(armed: .leading, travel: -64, projected: -64, along: .horizontal, actions: sideways),
            .leading
        )
        XCTAssertEqual(
            ToastSwipe.release(armed: .down, travel: 70, projected: 70, along: .vertical, actions: upDown),
            .down
        )
    }

    func testTheArmedEndWinsOverAFlickBack() {
        XCTAssertEqual(
            ToastSwipe.release(armed: .trailing, travel: 70, projected: -300, along: .horizontal, actions: sideways),
            .trailing
        )
    }

    func testAFlickShortOfTheArmPointStillRunsThatSide() {
        XCTAssertEqual(
            ToastSwipe.release(armed: nil, travel: -30, projected: -240, along: .horizontal, actions: sideways),
            .leading
        )
        XCTAssertEqual(
            ToastSwipe.release(armed: nil, travel: -30, projected: -240, along: .vertical, actions: fourWays),
            .up
        )
    }

    func testLettingGoShortWithoutAFlickPutsTheCardBack() {
        XCTAssertNil(ToastSwipe.release(armed: nil, travel: 40, projected: 90, along: .horizontal, actions: sideways))
    }

    func testAFlickTowardASideWithoutAnActionPutsTheCardBack() {
        XCTAssertNil(ToastSwipe.release(armed: nil, travel: 30, projected: 400, along: .horizontal, actions: leadingOnly))
    }
}
