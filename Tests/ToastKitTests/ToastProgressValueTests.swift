import XCTest
@testable import ToastKit

/// `ToastProgress` and the options around it: plain values, no center and no view host.
final class ToastProgressValueTests: XCTestCase {

    private let english = Locale(identifier: "en_US")

    // MARK: - Fractions

    func testTheFractionIsClamped() {
        XCTAssertEqual(ToastProgress(fraction: 1.5).fraction, 1)
        XCTAssertEqual(ToastProgress(fraction: -2).fraction, 0)
        XCTAssertEqual(ToastProgress(fraction: 0.4).fraction, 0.4)
        XCTAssertEqual(ToastProgress.fraction(7).fraction, 1)
    }

    func testANonFiniteFractionIsIndeterminate() {
        XCTAssertNil(ToastProgress(fraction: .nan).fraction)
        XCTAssertNil(ToastProgress(fraction: .infinity).fraction)
        XCTAssertTrue(ToastProgress(fraction: .nan).isIndeterminate)
    }

    func testIndeterminateHasNoFraction() {
        XCTAssertTrue(ToastProgress.indeterminate.isIndeterminate)
        XCTAssertNil(ToastProgress.indeterminate.detailText(locale: english))
        XCTAssertFalse(ToastProgress.fraction(0).isIndeterminate)
    }

    // MARK: - Counts

    func testBytesDeriveTheFraction() {
        let progress = ToastProgress.bytes(25, of: 100)

        XCTAssertEqual(progress.fraction, 0.25)
        XCTAssertEqual(progress.completedUnitCount, 25)
        XCTAssertEqual(progress.totalUnitCount, 100)
        XCTAssertEqual(progress.unit, .bytes)
    }

    func testAnUnknownTotalIsIndeterminate() {
        for progress in [ToastProgress.bytes(25, of: nil), .bytes(25, of: 0), .items(3, of: nil), .items(3, of: -1)] {
            XCTAssertTrue(progress.isIndeterminate, "\(progress)")
            XCTAssertNil(progress.totalUnitCount)
        }
        XCTAssertEqual(ToastProgress.bytes(25, of: nil).completedUnitCount, 25)
    }

    func testCountsNeverGoNegativeOrPastTheWhole() {
        XCTAssertEqual(ToastProgress.bytes(-5, of: 100).completedUnitCount, 0)
        XCTAssertEqual(ToastProgress.bytes(500, of: 100).fraction, 1)
    }

    func testItemsDeriveTheFraction() {
        let progress = ToastProgress.items(3, of: 10)

        XCTAssertEqual(progress.fraction, 0.3)
        XCTAssertEqual(progress.unit, .items)
    }

    // MARK: - Text

    func testBytesReadAsSizes() throws {
        let text = try XCTUnwrap(ToastProgress.bytes(12_000_000, of: 30_000_000).detailText(locale: english))

        XCTAssertTrue(text.contains("12 MB"), text)
        XCTAssertTrue(text.contains("30 MB"), text)
        XCTAssertFalse(text.contains("toast.progress"), "the string table must resolve: \(text)")
    }

    func testBytesWithoutATotalShowOnlyWhatIsDone() {
        XCTAssertEqual(ToastProgress.bytes(12_000_000, of: nil).detailText(locale: english), "12 MB")
    }

    func testItemsReadAsCounts() throws {
        let text = try XCTUnwrap(ToastProgress.items(3, of: 10).detailText(locale: english))

        XCTAssertTrue(text.contains("3"), text)
        XCTAssertTrue(text.contains("10"), text)
        XCTAssertFalse(text.contains("toast.progress"), "the string table must resolve: \(text)")
        XCTAssertEqual(ToastProgress.items(3, of: nil).detailText(locale: english), "3")
    }

    func testASubtitleReplacesTheGeneratedLine() {
        var progress = ToastProgress.bytes(12_000_000, of: 30_000_000)
        progress.subtitle = "2 minutes left"

        XCTAssertEqual(progress.detailText(locale: english), "2 minutes left")
        XCTAssertEqual(ToastProgress.fraction(0.5, subtitle: "Halfway").detailText(locale: english), "Halfway")
    }

    func testAnEmptySubtitleKeepsTheGeneratedLine() {
        var progress = ToastProgress.bytes(12_000_000, of: nil)
        progress.subtitle = ""

        XCTAssertEqual(progress.detailText(locale: english), "12 MB")
    }

    func testAPlainFractionHasNoDetailLine() {
        XCTAssertNil(ToastProgress.fraction(0.5).detailText(locale: english))
    }

    func testPercentIsWrittenInTheLocale() {
        XCTAssertEqual(ToastProgress.fraction(0.424).percentText(locale: english), "42%")
        XCTAssertNil(ToastProgress.indeterminate.percentText(locale: english))
    }

    func testOnlyAFullBarReadsOneHundredPercent() {
        XCTAssertEqual(ToastProgress.fraction(0.999).percentValue, 99)
        XCTAssertEqual(ToastProgress.fraction(1).percentValue, 100)
        XCTAssertEqual(ToastProgress.fraction(0.004).percentValue, 0)
        XCTAssertNil(ToastProgress.indeterminate.percentValue)
    }

    // MARK: - Phase

    func testOnlyRunningAndCancellingAreActive() {
        XCTAssertTrue(ToastProgressPhase.running(.indeterminate).isActive)
        XCTAssertTrue(ToastProgressPhase.cancelling.isActive)
        XCTAssertFalse(ToastProgressPhase.succeeded.isActive)
        XCTAssertFalse(ToastProgressPhase.failed.isActive)
        XCTAssertFalse(ToastProgressPhase.cancelled.isActive)
    }

    // MARK: - Options

    func testTheDefaultOptionsAreTheRecommendedOnes() {
        let options = ToastProgressOptions.default

        XCTAssertEqual(options, ToastProgressOptions())
        XCTAssertEqual(options.successDuration, .automatic)
        XCTAssertEqual(options.failureDuration, .seconds(8))
        XCTAssertEqual(options.resultWhenHidden, .failureOnly)
        XCTAssertEqual(options.announcements, .milestones(step: 0.25, minimumInterval: 5))
        XCTAssertEqual(options.cancellationGrace, 10)
        XCTAssertFalse(options.showsCancelledResult)
        XCTAssertFalse(options.confirmsCancel)
        XCTAssertEqual(options.swipeActions, .progress)
    }

    func testTheResultDefaultsToNothing() {
        let result = ToastProgressResult()

        XCTAssertNil(result.title)
        XCTAssertNil(result.message)
        XCTAssertNil(result.icon)
        XCTAssertNil(result.duration)
        XCTAssertNil(result.tapAction)
    }

    func testARunningCardIsHiddenEitherWayBySwiping() {
        XCTAssertEqual(ToastSwipeActions.progress.leading?.effect, .dismiss)
        XCTAssertEqual(ToastSwipeActions.progress.trailing?.effect, .dismiss)
        XCTAssertNotEqual(ToastSwipeActions.progress, .standard)
    }
}
