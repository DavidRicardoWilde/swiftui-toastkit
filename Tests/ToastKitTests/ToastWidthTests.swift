import XCTest
@testable import ToastKit

final class ToastWidthTests: XCTestCase {

    private let available: CGFloat = 400

    // MARK: - Fractions

    func testDefaultIsSixtyPercent() {
        XCTAssertEqual(ToastWidth.default, .fraction(0.6))
        XCTAssertEqual(ToastWidth.default.resolved(in: available), 240)
    }

    func testFractionScalesWithTheAvailableWidth() {
        XCTAssertEqual(ToastWidth.fraction(0.5).resolved(in: 320), 160)
        XCTAssertEqual(ToastWidth.fraction(0.5).resolved(in: 1024), 512)
    }

    func testFullFractionIsTheWholeAvailableWidth() {
        XCTAssertEqual(ToastWidth.fraction(1).resolved(in: available), available)
    }

    func testFractionAboveOneClampsToTheAvailableWidth() {
        XCTAssertEqual(ToastWidth.fraction(2.5).resolved(in: available), available)
    }

    func testNegativeFractionClampsToZero() {
        XCTAssertEqual(ToastWidth.fraction(-1).resolved(in: available), 0)
    }

    // MARK: - Fixed points

    func testPointsPassThroughWhenTheyFit() {
        XCTAssertEqual(ToastWidth.points(320).resolved(in: available), 320)
    }

    func testPointsWiderThanTheSafeAreaClampDown() {
        XCTAssertEqual(ToastWidth.points(9_999).resolved(in: available), available)
    }

    func testNegativePointsClampToZero() {
        XCTAssertEqual(ToastWidth.points(-40).resolved(in: available), 0)
    }

    // MARK: - Degenerate containers

    func testUnmeasuredContainerResolvesToZero() {
        // SwiftUI hands out a zero frame before its first layout pass.
        XCTAssertEqual(ToastWidth.fraction(0.6).resolved(in: 0), 0)
        XCTAssertEqual(ToastWidth.points(320).resolved(in: 0), 0)
    }

    func testNegativeContainerResolvesToZero() {
        XCTAssertEqual(ToastWidth.fraction(0.6).resolved(in: -100), 0)
    }

    func testNonFiniteValuesFallBackToTheAvailableWidth() {
        XCTAssertEqual(ToastWidth.fraction(.nan).resolved(in: available), available)
        XCTAssertEqual(ToastWidth.fraction(.infinity).resolved(in: available), available)
        XCTAssertEqual(ToastWidth.points(.infinity).resolved(in: available), available)
    }
}
