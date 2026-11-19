import SwiftUI
import XCTest
@testable import ToastKit

/// When a toast shows its swipe actions, as the environment carries it.
@MainActor
final class ToastSwipeHintsTests: XCTestCase {

    func testHintsWaitForAHoldUnlessToldOtherwise() {
        XCTAssertEqual(EnvironmentValues().toastSwipeHints, .afterHold)
    }

    func testTheEnvironmentCarriesImmediateHints() {
        var values = EnvironmentValues()
        values.toastSwipeHints = .immediate
        XCTAssertEqual(values.toastSwipeHints, .immediate)
    }
}
