import XCTest
@testable import ToastKit

/// The Foundation `Progress` bridge: the mapping to `ToastProgress` and the card following
/// a `Progress` through key-value observing. Needs Darwin's KVO, so it stays out of the
/// SwiftUI-free Linux check.
@MainActor
final class ToastProgressFoundationTests: XCTestCase {

    private func makeCenter() -> ToastCenter {
        ToastCenter(scheduler: FakeToastScheduler(), defaultDuration: 4, capacity: 5)
    }

    // MARK: - Mapping

    func testAFileProgressMapsToBytes() throws {
        let progress = Progress(totalUnitCount: 100)
        progress.kind = .file
        progress.completedUnitCount = 40

        let value = ToastProgress(progress)

        XCTAssertEqual(value.unit, .bytes)
        XCTAssertEqual(value.completedUnitCount, 40)
        XCTAssertEqual(value.totalUnitCount, 100)
        XCTAssertEqual(try XCTUnwrap(value.fraction), 0.4, accuracy: 0.0001)
    }

    func testAPlainProgressCountsItems() throws {
        let progress = Progress(totalUnitCount: 10)
        progress.completedUnitCount = 3

        let value = ToastProgress(progress)

        XCTAssertEqual(value.unit, .items)
        XCTAssertEqual(value.completedUnitCount, 3)
        XCTAssertEqual(value.totalUnitCount, 10)
        XCTAssertNil(value.subtitle, "only a file borrows the system's description")
        XCTAssertEqual(try XCTUnwrap(value.fraction), 0.3, accuracy: 0.0001)
    }

    func testAnIndeterminateProgressHasNoFraction() {
        let progress = Progress(totalUnitCount: -1)

        let value = ToastProgress(progress)

        XCTAssertNil(value.fraction)
        XCTAssertNil(value.totalUnitCount)
        XCTAssertTrue(value.isIndeterminate)
    }

    // MARK: - Following

    func testFoundationProgressCompletesAutomatically() async throws {
        let center = makeCenter()
        let progress = Progress(totalUnitCount: 100)
        let handle = center.track(progress, title: "Copying")
        // The record goes when the card finishes, so take the inbox first.
        let inbox = try XCTUnwrap(center.progressRecords[handle.id]?.inbox)

        progress.completedUnitCount = 100
        await inbox.lastHop?.value

        XCTAssertEqual(center.topmost?.progressPhase, .succeeded)
        XCTAssertEqual(center.timedToastID, handle.id, "a finished card is timed like any other")
        XCTAssertFalse(center.isTracking(id: handle.id))
    }

    func testAManualProgressDoesNotSucceedItself() async throws {
        let center = makeCenter()
        let progress = Progress(totalUnitCount: 100)
        let handle = center.track(progress, title: "Copying", completion: .manual)
        let inbox = try XCTUnwrap(center.progressRecords[handle.id]?.inbox)

        progress.completedUnitCount = 100
        await inbox.lastHop?.value

        XCTAssertTrue(center.topmost?.progressPhase?.isRunning == true, "the operation decides the outcome")
        XCTAssertTrue(center.isTracking(id: handle.id))
        handle.succeed()
        XCTAssertEqual(center.topmost?.progressPhase, .succeeded)
    }

    func testCancellingTheProgressFinishesTheCard() async throws {
        let center = makeCenter()
        let progress = Progress(totalUnitCount: 100)
        let handle = center.track(progress, title: "Copying")
        let inbox = try XCTUnwrap(center.progressRecords[handle.id]?.inbox)

        progress.cancel()
        await inbox.lastHop?.value

        XCTAssertTrue(center.toasts.isEmpty)
        XCTAssertFalse(center.isTracking(id: handle.id))
    }

    func testTheCancelButtonCancelsAManualProgress() async throws {
        let center = makeCenter()
        let progress = Progress(totalUnitCount: 100)
        let handle = center.track(progress, title: "Copying", completion: .manual)
        let inbox = try XCTUnwrap(center.progressRecords[handle.id]?.inbox)
        XCTAssertEqual(center.progressStore.cells[handle.id]?.canCancel, true)

        XCTAssertTrue(center.requestCancel(id: handle.id))
        XCTAssertEqual(handle.phase, .cancelling)
        XCTAssertTrue(progress.isCancelled)
        await inbox.lastHop?.value

        XCTAssertTrue(center.toasts.isEmpty, "the cancelled Progress ends the cancel without waiting out the grace")
        XCTAssertFalse(center.isTracking(id: handle.id))
    }
}
