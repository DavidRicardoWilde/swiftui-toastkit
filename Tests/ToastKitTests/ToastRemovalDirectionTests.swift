import CoreGraphics
import XCTest
@testable import ToastKit

/// Which way departing cards go, and how far they must travel to clear the stack's
/// region — pinned on plain values, with no view host.
final class ToastRemovalDirectionTests: XCTestCase {

    private func assertVector(
        _ vector: CGVector?,
        _ dx: CGFloat,
        _ dy: CGFloat,
        accuracy: CGFloat = 0.000_001,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let vector else { return XCTFail("expected a vector", file: file, line: line) }
        XCTAssertEqual(vector.dx, dx, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(vector.dy, dy, accuracy: accuracy, file: file, line: line)
    }

    private func unit(
        _ direction: ToastRemovalDirection,
        anchor: ToastPlacement.Anchor = .bottom,
        rightToLeft: Bool = false
    ) -> CGVector? {
        direction.unitVector(anchor: anchor, isRightToLeft: rightToLeft)
    }

    // MARK: - Fixed directions

    func testInPlaceDoesNotTravel() {
        XCTAssertNil(unit(.inPlace))
    }

    func testTopAndBottomAreTheSameInEitherLayoutDirection() {
        for rightToLeft in [false, true] {
            assertVector(unit(.top, rightToLeft: rightToLeft), 0, -1)
            assertVector(unit(.bottom, rightToLeft: rightToLeft), 0, 1)
        }
    }

    func testLeadingAndTrailingFlipInRightToLeftLayout() {
        assertVector(unit(.leading), -1, 0)
        assertVector(unit(.trailing), 1, 0)
        assertVector(unit(.leading, rightToLeft: true), 1, 0)
        assertVector(unit(.trailing, rightToLeft: true), -1, 0)
    }

    func testTowardAndAwayFromTheAnchorFollowTheEdgeTheStackHangsFrom() {
        assertVector(unit(.towardAnchor, anchor: .bottom), 0, 1)
        assertVector(unit(.awayFromAnchor, anchor: .bottom), 0, -1)
        assertVector(unit(.towardAnchor, anchor: .top), 0, -1)
        assertVector(unit(.awayFromAnchor, anchor: .top), 0, 1)
    }

    // MARK: - Angles

    func testDegreesZeroPointsRightAndAnglesGrowClockwise() {
        assertVector(unit(.degrees(0)), 1, 0, accuracy: 0)
        assertVector(unit(.degrees(90)), 0, 1, accuracy: 0)
        assertVector(unit(.degrees(180)), -1, 0, accuracy: 0)
        assertVector(unit(.degrees(-90)), 0, -1, accuracy: 0)
        assertVector(unit(.degrees(45)), CGFloat(0.5.squareRoot()), CGFloat(0.5.squareRoot()))
    }

    func testAnglesAndVectorsAreNotMirroredInRightToLeftLayout() {
        assertVector(unit(.degrees(0), rightToLeft: true), 1, 0)
        assertVector(unit(.degrees(180), rightToLeft: true), -1, 0)
        assertVector(unit(.vector(dx: 3, dy: 4), rightToLeft: true), 0.6, 0.8)
    }

    // MARK: - Vectors

    func testAVectorIsNormalised() {
        assertVector(unit(.vector(dx: 3, dy: 4)), 0.6, 0.8)
        assertVector(unit(.vector(dx: 0, dy: -250)), 0, -1)
    }

    func testAZeroVectorDoesNotTravel() {
        XCTAssertNil(unit(.vector(dx: 0, dy: 0)))
    }

    func testValuesThatAreNotFiniteMeanInPlace() {
        XCTAssertEqual(ToastRemovalDirection.degrees(.nan), .inPlace)
        XCTAssertEqual(ToastRemovalDirection.degrees(.infinity), .inPlace)
        XCTAssertEqual(ToastRemovalDirection.vector(dx: .nan, dy: 1), .inPlace)
        XCTAssertEqual(ToastRemovalDirection.vector(dx: 1, dy: -.infinity), .inPlace)
        XCTAssertNil(unit(.degrees(.nan)))
    }

    // MARK: - Distance

    private let region = CGRect(x: 0, y: 0, width: 400, height: 800)
    private let card = CGRect(x: 100, y: 700, width: 200, height: 60)

    func testTheDistanceFollowsTheNearestEdgeAlongAnAxis() {
        // Down: the card's top edge must pass the region's bottom, plus the margin.
        XCTAssertEqual(ToastDeparturePath.distance(card: card, region: region, along: CGVector(dx: 0, dy: 1)), 140)
        XCTAssertEqual(ToastDeparturePath.distance(card: card, region: region, along: CGVector(dx: 1, dy: 0)), 340)
        XCTAssertEqual(ToastDeparturePath.distance(card: card, region: region, along: CGVector(dx: -1, dy: 0)), 340)
        XCTAssertEqual(ToastDeparturePath.distance(card: card, region: region, along: CGVector(dx: 0, dy: -1)), 800)
    }

    func testADiagonalTravelsUntilTheFirstEdgeIsCleared() {
        let side = CGFloat(0.5.squareRoot())
        let vector = CGVector(dx: side, dy: side)

        let distance = ToastDeparturePath.distance(card: card, region: region, along: vector)

        XCTAssertEqual(distance, 100 / side + 40, accuracy: 0.001)
    }

    func testTheCardIsOutsideTheRegionAfterTravellingTheDistance() {
        for vector in [CGVector(dx: 0, dy: 1), CGVector(dx: 0.6, dy: 0.8), CGVector(dx: -1, dy: 0)] {
            let distance = ToastDeparturePath.distance(card: card, region: region, along: vector)
            let moved = card.offsetBy(dx: vector.dx * distance, dy: vector.dy * distance)
            XCTAssertFalse(moved.intersects(region), "\(vector)")
        }
    }

    func testNoTravelHasNoDistance() {
        XCTAssertEqual(ToastDeparturePath.distance(card: card, region: region, along: nil), 0)
    }

    func testAnUnmeasuredRegionFallsBackToTheSwipesExitDistance() {
        XCTAssertEqual(
            ToastDeparturePath.distance(card: card, region: .zero, along: CGVector(dx: 0, dy: 1)),
            1_400
        )
    }
}
