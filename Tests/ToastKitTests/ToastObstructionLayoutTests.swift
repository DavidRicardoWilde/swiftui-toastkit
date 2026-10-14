import CoreGraphics
import XCTest
@testable import ToastKit

/// How far a stack moves to clear views marked with `toastObstruction()`.
///
/// The stack's region is the safe-area region of a 390 × 844 pt phone screen above a
/// 49 pt tab bar: everything the stack was given before keeping clear of anything.
final class ToastObstructionLayoutTests: XCTestCase {

    private let region = CGRect(x: 0, y: 59, width: 390, height: 702)

    private func lift(_ anchor: ToastPlacement.Anchor, _ obstructions: [CGRect]) -> CGFloat {
        ToastObstructionLayout.lift(for: region, anchor: anchor, obstructions: obstructions)
    }

    func testNothingMarkedMeansNoLift() {
        XCTAssertEqual(lift(.bottom, []), 0)
    }

    func testABarReachingIntoTheBottomLiftsTheStackByTheOverlap() {
        // A 56 pt mini player hosted above the tab bar, outside the page's safe area.
        let accessory = CGRect(x: 16, y: 705, width: 358, height: 48)
        XCTAssertEqual(lift(.bottom, [accessory]), 56)
    }

    func testTheTallestReachWins() {
        let bar = CGRect(x: 0, y: 741, width: 390, height: 103)
        let player = CGRect(x: 16, y: 680, width: 358, height: 56)
        XCTAssertEqual(lift(.bottom, [bar, player]), 81)
    }

    func testAViewAlreadyOutsideTheRegionNeedsNoLift() {
        // A custom tab bar installed with safeAreaInset: the region already ends above it.
        let tabBar = CGRect(x: 0, y: 761, width: 390, height: 83)
        XCTAssertEqual(lift(.bottom, [tabBar]), 0)
    }

    func testOnlyViewsOnTheStacksOwnSideCount() {
        let toolbar = CGRect(x: 0, y: 59, width: 390, height: 52)
        XCTAssertEqual(lift(.bottom, [toolbar]), 0, "a bar at the top is not in a bottom stack's way")
        XCTAssertEqual(lift(.top, [toolbar]), 52)
    }

    func testViewsBesideTheStackDoNotCount() {
        let sidebar = CGRect(x: 400, y: 600, width: 100, height: 200)
        XCTAssertEqual(lift(.bottom, [sidebar]), 0)
    }

    func testEmptyFramesAreIgnored() {
        XCTAssertEqual(lift(.bottom, [CGRect(x: 0, y: 700, width: 390, height: 0)]), 0)
        XCTAssertEqual(ToastObstructionLayout.lift(for: .zero, anchor: .bottom, obstructions: [region]), 0)
    }

    func testTheLiftNeverExceedsTheStacksHeight() {
        let sheet = CGRect(x: 0, y: -100, width: 390, height: 2000)
        XCTAssertLessThanOrEqual(lift(.bottom, [sheet]), region.height)
    }
}
