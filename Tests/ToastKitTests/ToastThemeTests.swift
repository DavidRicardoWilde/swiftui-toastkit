import SwiftUI
import XCTest
@testable import ToastKit

final class ToastThemeTests: XCTestCase {

    // MARK: - Status tints

    func testStatusTintMapsEachStatusToItsColour() {
        let tint = ToastTheme.statusTint(normal: .gray, warning: .yellow, error: .pink, notification: .teal)

        XCTAssertEqual(tint(.normal), .gray)
        XCTAssertEqual(tint(.warning), .yellow)
        XCTAssertEqual(tint(.error), .pink)
        XCTAssertEqual(tint(.notification), .teal)
    }

    func testStatusTintKeepsTheStandardColourForStatusesLeftOut() {
        let tint = ToastTheme.statusTint(error: .pink)

        XCTAssertEqual(tint(.error), .pink)
        for status in ToastMessage.Status.allCases where status != .error {
            XCTAssertEqual(tint(status), ToastTheme.standardTint(status), "\(status)")
        }
    }

    func testStandardTintUsesSystemStatusColours() {
        XCTAssertEqual(ToastTheme.standardTint(.normal), .secondary)
        XCTAssertEqual(ToastTheme.standardTint(.warning), .orange)
        XCTAssertEqual(ToastTheme.standardTint(.error), .red)
        XCTAssertEqual(ToastTheme.standardTint(.notification), .accentColor)
    }

    func testThemeReadsItsTintFromStatusTint() {
        let theme = ToastTheme(tint: ToastTheme.statusTint(warning: .yellow))

        XCTAssertEqual(ToastMessage.Status.warning.tint(in: theme), .yellow)
        XCTAssertEqual(ToastMessage.Status.error.tint(in: theme), .red)
    }
}
