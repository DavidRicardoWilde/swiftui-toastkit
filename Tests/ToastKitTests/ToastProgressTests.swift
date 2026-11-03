import XCTest
@testable import ToastKit

/// The progress toast's life in the model: never timed while it runs, finishing in place,
/// hiding instead of ending, cancelling, retrying and being abandoned. All on a fake
/// clock, with no view host.
@MainActor
final class ToastProgressTests: XCTestCase {

    private struct Failure: Error {}

    private func makeCenter(capacity: Int = 5) -> (ToastCenter, FakeToastScheduler) {
        let scheduler = FakeToastScheduler()
        let center = ToastCenter(scheduler: scheduler, defaultDuration: 4, capacity: capacity)
        return (center, scheduler)
    }

    private func isRunning(_ phase: ToastProgressPhase?) -> Bool {
        phase?.isRunning == true
    }

    // MARK: - Countdown

    func testRunningProgressIsNeverTimed() throws {
        let (center, scheduler) = makeCenter()
        let handle = center.track(title: "Uploading")
        let toast = try XCTUnwrap(center.topmost)

        XCTAssertNil(center.displaySeconds(for: toast))
        XCTAssertNil(center.timedToastID)
        XCTAssertNil(scheduler.pendingInterval)
        XCTAssertTrue(center.isTracking(id: handle.id))
    }

    func testTicksDoNotChangeToasts() {
        let (center, _) = makeCenter()
        let handle = center.track(title: "Uploading")
        // The first determinate value switches the bar's kind and refreshes the toast.
        handle.update(.fraction(0.1))
        let before = center.toasts

        handle.update(.bytes(40, of: 100))
        handle.update(.fraction(0.9))

        XCTAssertEqual(center.toasts, before, "ticks write to the card's cell, never to the stack")
        XCTAssertEqual(center.progressStore.cells[handle.id]?.value, .fraction(0.9))
        XCTAssertEqual(handle.phase, .running(.fraction(0.9)))
    }

    func testSwitchingBetweenIndeterminateAndDeterminateRefreshesTheToast() {
        let (center, _) = makeCenter()
        let handle = center.track(title: "Preparing")
        XCTAssertEqual(center.topmost?.progressPhase, .running(.indeterminate))

        handle.update(.fraction(0.25))
        XCTAssertEqual(center.topmost?.progressPhase, .running(.fraction(0.25)))

        handle.update(.indeterminate)
        XCTAssertEqual(center.topmost?.progressPhase, .running(.indeterminate))
    }

    // MARK: - Finishing in place

    func testSucceedReplacesInPlaceAndTimesATopmostCard() {
        let (center, scheduler) = makeCenter()
        center.present(.normal, title: "below", duration: .indefinite)
        let handle = center.track(title: "Uploading")
        let ids = center.toasts.map(\.id)

        handle.succeed()

        XCTAssertEqual(center.toasts.map(\.id), ids, "same card, same place")
        XCTAssertEqual(center.topmost?.progressPhase, .succeeded)
        XCTAssertEqual(center.topmost?.status, .normal)
        XCTAssertEqual(center.topmost?.icon, .system("checkmark.circle.fill"))
        XCTAssertEqual(center.topmost?.swipeActions, .standard)
        XCTAssertEqual(center.timedToastID, handle.id)
        XCTAssertEqual(scheduler.pendingInterval, 4)
        XCTAssertFalse(center.isTracking(id: handle.id))
        XCTAssertEqual(handle.phase, .succeeded)
    }

    func testTheResultCanBeCustomised() {
        let (center, scheduler) = makeCenter()
        let handle = center.track(title: "Uploading")

        handle.succeed(ToastProgressResult(title: "Uploaded", message: "3 photos", duration: 2))

        XCTAssertEqual(center.topmost?.title, "Uploaded")
        XCTAssertEqual(center.topmost?.message, "3 photos")
        XCTAssertEqual(scheduler.pendingInterval, 2)
    }

    func testABuriedFinishedCardWaitsUntilTopmost() {
        let (center, scheduler) = makeCenter()
        let handle = center.track(title: "Uploading")
        let other = ToastMessage(title: "other")
        center.present(other)
        let pending = scheduler.pendingInterval

        handle.succeed()

        XCTAssertEqual(center.timedToastID, other.id, "the finished card is buried, so it is not timed yet")
        XCTAssertEqual(scheduler.pendingInterval, pending)

        scheduler.fire()
        XCTAssertEqual(center.timedToastID, handle.id)
        XCTAssertEqual(scheduler.pendingInterval, 4)

        scheduler.fire()
        XCTAssertTrue(center.toasts.isEmpty)
    }

    func testFailureUsesErrorStatusAndEightSeconds() {
        let (center, scheduler) = makeCenter()
        let handle = center.track(title: "Uploading", icon: .system("photo"))

        handle.fail(ToastProgressResult(message: "No connection"))

        XCTAssertEqual(center.topmost?.status, .error)
        XCTAssertEqual(center.topmost?.progressPhase, .failed)
        XCTAssertEqual(center.topmost?.message, "No connection")
        XCTAssertNil(center.topmost?.icon, "the error symbol replaces the upload's own icon")
        XCTAssertEqual(scheduler.pendingInterval, 8)
        XCTAssertEqual(center.progressOutcome?.status, .error)
    }

    func testCallsAfterAnOutcomeAreIgnored() {
        let (center, _) = makeCenter()
        let handle = center.track(title: "Uploading")
        handle.succeed()
        let before = center.toasts

        handle.update(.fraction(0.5))
        handle.update(title: "Renamed")
        handle.fail()
        handle.cancel()
        handle.succeed(ToastProgressResult(title: "Again"))

        XCTAssertEqual(center.toasts, before)
        XCTAssertEqual(handle.phase, .succeeded)
    }

    // MARK: - Presenting

    func testRePresentingATrackedIDKeepsItsPhase() {
        let (center, _) = makeCenter()
        let handle = center.track(title: "Uploading")
        center.present(ToastMessage(title: "other"))

        center.present(ToastMessage(id: handle.id, title: "Uploading photos"))

        XCTAssertEqual(center.topmost?.id, handle.id, "re-presenting moves it to the front")
        XCTAssertEqual(center.topmost?.title, "Uploading photos")
        XCTAssertTrue(isRunning(center.topmost?.progressPhase))
        XCTAssertEqual(center.topmost?.swipeActions, .progress)
        XCTAssertNil(center.timedToastID)
        XCTAssertTrue(center.isTracking(id: handle.id))
    }

    func testRePresentingAHiddenCardShowsItAgain() {
        let (center, _) = makeCenter()
        let handle = center.track(title: "Uploading")
        center.dismiss(id: handle.id)
        XCTAssertFalse(handle.isVisible)

        center.present(ToastMessage(id: handle.id, title: "Uploading"))

        XCTAssertTrue(handle.isVisible)
        XCTAssertEqual(center.toasts.map(\.id), [handle.id])
    }

    func testUpdatingTheCopyChangesTheCard() {
        let (center, _) = makeCenter()
        let handle = center.track(title: "Uploading", message: "Preparing")

        handle.update(title: "Waiting for network…", message: .some(nil))

        XCTAssertEqual(center.topmost?.title, "Waiting for network…")
        XCTAssertNil(center.topmost?.message)

        handle.update(message: "Retrying soon")
        XCTAssertEqual(center.topmost?.title, "Waiting for network…")
        XCTAssertEqual(center.topmost?.message, "Retrying soon")
    }

    // MARK: - Hiding

    func testDismissHidesARunningCardAndKeepsTracking() {
        let (center, _) = makeCenter()
        let handle = center.track(title: "Uploading")

        center.dismiss(id: handle.id)

        XCTAssertTrue(center.toasts.isEmpty)
        XCTAssertTrue(center.isTracking(id: handle.id))
        XCTAssertFalse(handle.isVisible)
        XCTAssertTrue(handle.phase.isRunning, "the work carries on")
        XCTAssertEqual(center.departures.count, 1, "a hidden card leaves with a stand-in like any other")
    }

    func testDismissTopmostHidesARunningCard() {
        let (center, _) = makeCenter()
        let handle = center.track(title: "Uploading")

        center.dismissTopmost()

        XCTAssertFalse(handle.isVisible)
        XCTAssertTrue(center.isTracking(id: handle.id))
    }

    func testBatchCountsHiddenCards() {
        let (center, _) = makeCenter()
        let handle = center.track(title: "Uploading", group: "sync")
        center.present(.normal, title: "plain", group: "sync")

        let removed = center.dismiss(group: "sync")

        XCTAssertEqual(removed, 2)
        XCTAssertEqual(center.batchAnnouncement?.count, 2)
        XCTAssertTrue(center.toasts.isEmpty)
        XCTAssertTrue(center.isTracking(id: handle.id))
    }

    func testDismissAllHidesRunningCardsToo() {
        let (center, _) = makeCenter()
        let handle = center.track(title: "Uploading")
        center.present(.normal, title: "plain")

        XCTAssertEqual(center.dismissAll(removal: nil), 2)
        XCTAssertTrue(center.isTracking(id: handle.id))
    }

    func testWhereClosuresCanTellProgressApart() {
        let (center, _) = makeCenter()
        let handle = center.track(title: "Uploading")
        center.present(.normal, title: "plain")

        let removed = center.dismiss { $0.progressPhase == nil }

        XCTAssertEqual(removed, 1)
        XCTAssertEqual(center.toasts.map(\.id), [handle.id])
    }

    func testPostponeHidesARunningCard() {
        let (center, _) = makeCenter()
        let handle = center.track(title: "Uploading")

        center.postpone(id: handle.id)

        XCTAssertTrue(center.toasts.isEmpty)
        XCTAssertTrue(center.postponed.isEmpty, "a running card is never put aside")
        XCTAssertFalse(handle.isVisible)
        XCTAssertTrue(center.isTracking(id: handle.id))
    }

    func testAFinishedCardPostponesNormally() {
        let (center, _) = makeCenter()
        let handle = center.track(title: "Uploading")
        handle.succeed()

        center.postpone(id: handle.id)

        XCTAssertEqual(center.postponed.map(\.id), [handle.id])
        center.restorePostponed()
        XCTAssertEqual(center.topmost?.progressPhase, .succeeded)
    }

    // MARK: - Capacity

    func testCapacityDropsTimedToastsBeforeHidingProgress() {
        let (center, _) = makeCenter(capacity: 2)
        let handle = center.track(title: "Uploading")
        let routine = ToastMessage(title: "routine")
        let arrival = ToastMessage(title: "arrival")
        center.present(routine)
        center.present(arrival)

        XCTAssertEqual(center.toasts.map(\.id), [handle.id, arrival.id])
        XCTAssertTrue(handle.isVisible)
    }

    func testCapacityDropsAFinishedProgressCardAsATimedToast() {
        let (center, _) = makeCenter(capacity: 2)
        let finished = center.track(title: "Done soon")
        finished.succeed()
        let running = center.track(title: "Still going")
        center.present(ToastMessage(title: "arrival"))

        XCTAssertFalse(center.toasts.contains { $0.id == finished.id }, "the finished card is timed, so it goes first")
        XCTAssertTrue(center.isTracking(id: running.id))
        XCTAssertTrue(running.isVisible)
        XCTAssertNil(center.progressRecords[finished.id], "a finished card that left is forgotten")
    }

    func testCapacityHidesProgressBeforeDroppingPersistentToasts() {
        let (center, _) = makeCenter(capacity: 2)
        let pinned = ToastMessage(status: .error, title: "sync failed", duration: 0)
        center.present(pinned)
        let handle = center.track(title: "Uploading")
        let arrival = ToastMessage(title: "arrival")
        center.present(arrival)

        XCTAssertEqual(center.toasts.map(\.id), [pinned.id, arrival.id])
        XCTAssertFalse(handle.isVisible, "hidden, not dropped")
        XCTAssertTrue(center.isTracking(id: handle.id))
    }

    func testABurstOfProgressCardsHidesTheOldest() {
        let (center, _) = makeCenter(capacity: 3)
        let handles = (0..<5).map { center.track(title: "Upload \($0)") }

        XCTAssertEqual(center.toasts.map(\.id), handles.suffix(3).map(\.id))
        XCTAssertEqual(handles.map(\.isVisible), [false, false, true, true, true])
        XCTAssertTrue(handles.allSatisfy { center.isTracking(id: $0.id) })
    }

    // MARK: - Hidden results

    func testHiddenFailureReturnsAsANewArrival() {
        let (center, scheduler) = makeCenter()
        let handle = center.track(title: "Uploading")
        center.dismiss(id: handle.id)
        center.present(.normal, title: "other")

        handle.fail(ToastProgressResult(message: "Offline"))

        XCTAssertEqual(center.topmost?.id, handle.id)
        XCTAssertEqual(center.topmost?.status, .error)
        XCTAssertTrue(handle.isVisible)
        XCTAssertEqual(center.timedToastID, handle.id)
        XCTAssertEqual(scheduler.pendingInterval, 8)
        XCTAssertNil(center.progressOutcome, "it arrives; the arrival haptic plays, not the in-place one")
    }

    func testHiddenSuccessIsSilentByDefault() {
        let (center, _) = makeCenter()
        let handle = center.track(title: "Uploading")
        center.dismiss(id: handle.id)
        let announcement = center.progressAnnouncement

        handle.succeed()

        XCTAssertTrue(center.toasts.isEmpty)
        XCTAssertNil(center.progressRecords[handle.id])
        XCTAssertNil(center.progressStore.cells[handle.id])
        XCTAssertEqual(center.progressAnnouncement, announcement)
        XCTAssertNil(center.progressOutcome)
    }

    func testResultWhenHiddenAlwaysShowsASuccess() {
        let (center, _) = makeCenter()
        var options = ToastProgressOptions()
        options.resultWhenHidden = .always
        let handle = center.track(title: "Uploading", options: options)
        center.dismiss(id: handle.id)

        handle.succeed()

        XCTAssertEqual(center.topmost?.id, handle.id)
        XCTAssertEqual(center.topmost?.progressPhase, .succeeded)
    }

    func testResultWhenHiddenNeverKeepsEvenAFailureAway() {
        let (center, _) = makeCenter()
        var options = ToastProgressOptions()
        options.resultWhenHidden = .never
        let handle = center.track(title: "Uploading", options: options)
        center.dismiss(id: handle.id)

        handle.fail()

        XCTAssertTrue(center.toasts.isEmpty)
        XCTAssertNil(center.progressRecords[handle.id])
    }

    // MARK: - Cancelling

    func testCancelMovesToCancellingThenRunsTheRoute() {
        let (center, _) = makeCenter()
        var cancelled = 0
        let handle = center.track(title: "Uploading", onCancel: { cancelled += 1 })
        XCTAssertEqual(center.progressStore.cells[handle.id]?.canCancel, true)

        handle.cancel()

        XCTAssertEqual(cancelled, 1)
        XCTAssertEqual(handle.phase, .cancelling)
        XCTAssertTrue(handle.isCancellationRequested)
        XCTAssertEqual(center.topmost?.progressPhase, .cancelling)
        XCTAssertNil(center.timedToastID, "a cancelling card is still not timed")

        handle.cancel()
        handle.update(.fraction(0.9))
        XCTAssertEqual(cancelled, 1, "asking twice cancels once")
        XCTAssertEqual(handle.phase, .cancelling, "the bar is frozen while it stops")

        handle.finishCancelled()
        XCTAssertTrue(center.toasts.isEmpty)
        XCTAssertFalse(center.isTracking(id: handle.id))
        XCTAssertNil(center.progressRecords[handle.id])
    }

    func testCancelCanShowAResultCard() {
        let (center, scheduler) = makeCenter()
        var options = ToastProgressOptions()
        options.showsCancelledResult = true
        let handle = center.track(title: "Uploading", options: options, onCancel: {})

        handle.cancel()
        handle.finishCancelled()

        XCTAssertEqual(center.topmost?.progressPhase, .cancelled)
        XCTAssertEqual(scheduler.pendingInterval, 4)
        XCTAssertNil(center.progressOutcome, "cancelling by choice has no haptic")
    }

    func testCancelWithoutARouteFinishesAtOnce() {
        let (center, _) = makeCenter()
        let handle = center.track(title: "Uploading")
        XCTAssertEqual(center.progressStore.cells[handle.id]?.canCancel, false)

        handle.cancel()

        XCTAssertTrue(handle.isCancellationRequested)
        XCTAssertTrue(center.toasts.isEmpty)
        XCTAssertFalse(center.isTracking(id: handle.id))
    }

    func testCancelGraceFinishesAStuckCancel() {
        let (center, scheduler) = makeCenter()
        let handle = center.track(title: "Uploading", onCancel: {})
        handle.cancel()

        scheduler.advance(9)
        center.checkCancellationGrace()
        XCTAssertEqual(handle.phase, .cancelling, "still within the 10 seconds")

        scheduler.advance(2)
        center.checkCancellationGrace()
        XCTAssertTrue(center.toasts.isEmpty)
        XCTAssertFalse(center.isTracking(id: handle.id))
    }

    func testTheGraceIsAlsoCheckedWhenAnotherCardUpdates() {
        let (center, scheduler) = makeCenter()
        let stuck = center.track(title: "Stuck", onCancel: {})
        let other = center.track(title: "Other")
        stuck.cancel()

        scheduler.advance(11)
        other.update(.fraction(0.5))

        XCTAssertFalse(center.isTracking(id: stuck.id))
        XCTAssertEqual(center.toasts.map(\.id), [other.id])
    }

    func testTheGraceIsAlsoCheckedWhenTheCountdownIsReconciled() {
        let (center, scheduler) = makeCenter()
        let stuck = center.track(title: "Stuck", onCancel: {})
        stuck.cancel()

        scheduler.advance(11)
        center.present(.normal, title: "anything")

        XCTAssertFalse(center.isTracking(id: stuck.id))
        XCTAssertEqual(center.toasts.count, 1)
    }

    func testCancelProgressGroupReturnsTheCount() {
        let (center, _) = makeCenter()
        var cancelled = 0
        let first = center.track(title: "One", group: "upload", onCancel: { cancelled += 1 })
        let second = center.track(title: "Two", group: "upload", onCancel: { cancelled += 1 })
        let other = center.track(title: "Other", group: "sync", onCancel: { cancelled += 1 })
        center.dismiss(id: second.id)

        XCTAssertEqual(center.cancelProgress(group: "upload"), 2, "a hidden card is cancelled too")
        XCTAssertEqual(cancelled, 2)
        XCTAssertEqual(first.phase, .cancelling)
        XCTAssertEqual(second.phase, .cancelling)
        XCTAssertTrue(isRunning(other.phase))
        XCTAssertEqual(center.cancelProgress(group: "upload"), 0, "already cancelling")
    }

    func testHideAndCancelFromTheSwipe() {
        let (center, _) = makeCenter()
        var cancelled = 0
        let handle = center.track(title: "Uploading", onCancel: { cancelled += 1 })

        center.hideAndCancel(id: handle.id)

        XCTAssertTrue(center.toasts.isEmpty, "a flung-out card must not sit invisible in the stack")
        XCTAssertFalse(handle.isVisible)
        XCTAssertEqual(handle.phase, .cancelling)
        XCTAssertEqual(cancelled, 1)

        handle.finishCancelled()
        XCTAssertTrue(center.toasts.isEmpty, "a hidden cancel ends silently")
        XCTAssertNil(center.progressRecords[handle.id])
    }

    func testTheCancelProgressActionIsRecognisedByID() {
        XCTAssertEqual(ToastAction.cancelProgress.id, ToastAction.cancelProgressID)
        XCTAssertEqual(ToastAction.hideProgress.id, ToastAction.hideProgressID)
        XCTAssertEqual(ToastSwipeActions.progress.leading?.id, ToastAction.hideProgressID)
        XCTAssertEqual(ToastSwipeActions.progress.trailing?.id, ToastAction.hideProgressID)
        XCTAssertEqual(ToastAction.cancelProgress.role, .destructive)
        XCTAssertEqual(ToastAction.hideProgress.role, .subdued)
    }

    // MARK: - Retry

    func testRetryWithTheSameIDResumesInPlace() {
        let (center, _) = makeCenter()
        center.present(.normal, title: "below", duration: .indefinite)
        let first = center.track(title: "Uploading")
        center.present(.normal, title: "above", duration: .indefinite)
        first.fail(retry: {})
        let order = center.toasts.map(\.id)

        let second = center.track(id: first.id, title: "Uploading again")

        XCTAssertEqual(center.toasts.map(\.id), order, "no move to the front")
        XCTAssertTrue(isRunning(center.toasts[1].progressPhase))
        XCTAssertEqual(center.toasts[1].status, .normal)
        XCTAssertEqual(center.toasts[1].title, "Uploading again")
        XCTAssertTrue(center.isTracking(id: first.id))
        XCTAssertNotEqual(first.serial, second.serial)
        XCTAssertEqual(center.progressStore.cells[first.id]?.canRetry, false)
    }

    func testAStaleHandleCannotFinishANewRun() {
        let (center, _) = makeCenter()
        let first = center.track(title: "Uploading")
        first.fail()
        let second = center.track(id: first.id, title: "Uploading")

        first.succeed()
        first.update(.fraction(0.7))
        first.cancel()

        XCTAssertTrue(isRunning(second.phase))
        XCTAssertTrue(center.isTracking(id: second.id))
        XCTAssertTrue(isRunning(center.topmost?.progressPhase))
        XCTAssertEqual(center.progressStore.cells[second.id]?.value, .indeterminate)
    }

    func testRetryThatDoesNotRetrackDismisses() async {
        let (center, _) = makeCenter()
        var retried = 0
        let handle = center.track(title: "Uploading")
        handle.fail(retry: { retried += 1 })
        XCTAssertEqual(center.progressStore.cells[handle.id]?.canRetry, true)

        center.retryProgress(id: handle.id)
        center.retryProgress(id: handle.id)
        await center.pendingRetryCheck?.value

        XCTAssertEqual(retried, 1, "a second tap before the check does nothing")
        XCTAssertTrue(center.toasts.isEmpty)
        XCTAssertNil(center.progressRecords[handle.id])
        withExtendedLifetime(handle) {}
    }

    func testRetryThatRetracksKeepsTheCard() async {
        let (center, _) = makeCenter()
        let id = UUID()
        let first = center.track(id: id, title: "Uploading")
        var second: ToastProgressHandle?
        first.fail(retry: { second = center.track(id: id, title: "Uploading") })

        center.retryProgress(id: id)
        await center.pendingRetryCheck?.value

        XCTAssertEqual(center.toasts.map(\.id), [id])
        XCTAssertTrue(center.isTracking(id: id))
        withExtendedLifetime((first, second)) {}
    }

    // MARK: - Abandonment

    func testAnAbandonedManualHandleCancelsAndRemoves() async {
        let (center, _) = makeCenter()
        var cancelled = false
        let id = UUID()
        _ = center.track(id: id, title: "Uploading", onCancel: { cancelled = true })
        for _ in 0..<5 { await Task.yield() }

        XCTAssertTrue(cancelled, "the work must not carry on invisibly")
        XCTAssertTrue(center.toasts.isEmpty)
        XCTAssertFalse(center.isTracking(id: id))
        XCTAssertNil(center.progressRecords[id])
    }

    func testAHandleWithAnOutcomeIsNotAbandoned() async {
        let (center, _) = makeCenter()
        let id = UUID()
        do {
            let handle = center.track(id: id, title: "Uploading")
            handle.succeed()
        }
        for _ in 0..<5 { await Task.yield() }

        XCTAssertEqual(center.topmost?.progressPhase, .succeeded)
    }

    func testCancellingATaskGivenToTheHandleFinishesTheCancel() async {
        let (center, _) = makeCenter()
        let handle = center.track(title: "Uploading")
        let task = Task<Void, Error> { try await Task.sleep(nanoseconds: 60_000_000_000) }
        handle.cancels(task)
        XCTAssertEqual(center.progressStore.cells[handle.id]?.canCancel, true)

        handle.cancel()
        _ = await task.result
        for _ in 0..<5 { await Task.yield() }

        XCTAssertTrue(task.isCancelled)
        XCTAssertTrue(center.toasts.isEmpty)
        XCTAssertFalse(center.isTracking(id: handle.id))
        withExtendedLifetime(handle) {}
    }

    // MARK: - withProgress

    func testWithProgressReturnsTheValue() async throws {
        let (center, scheduler) = makeCenter()
        let id = UUID()

        let value = try await center.withProgress(
            id: id,
            title: "Uploading",
            operation: { report -> Int in
                report(.fraction(0.5))
                return 42
            }
        )

        XCTAssertEqual(value, 42)
        XCTAssertEqual(center.topmost?.progressPhase, .succeeded)
        XCTAssertEqual(center.timedToastID, id)
        XCTAssertEqual(scheduler.pendingInterval, 4)
    }

    func testWithProgressUsesTheSuccessClosure() async throws {
        let (center, _) = makeCenter()

        _ = try await center.withProgress(
            title: "Uploading",
            success: { count in ToastProgressResult(title: "Uploaded \(count)") },
            operation: { _ -> Int in 3 }
        )

        XCTAssertEqual(center.topmost?.title, "Uploaded 3")
    }

    func testWithProgressRethrowsAndFails() async {
        let (center, _) = makeCenter()
        var retried = false

        do {
            _ = try await center.withProgress(
                title: "Uploading",
                failure: { _ in ToastProgressResult(message: "Boom") },
                onRetry: { retried = true },
                operation: { _ -> Int in throw Failure() }
            )
            XCTFail("expected the error to be rethrown")
        } catch {
            XCTAssertTrue(error is Failure)
        }

        XCTAssertEqual(center.topmost?.progressPhase, .failed)
        XCTAssertEqual(center.topmost?.status, .error)
        XCTAssertEqual(center.topmost?.message, "Boom")
        let id = center.topmost?.id
        XCTAssertEqual(id.flatMap { center.progressStore.cells[$0]?.canRetry }, true)
        XCTAssertFalse(retried)
    }

    func testCancellingTheCallerCancelsTheOperation() async {
        let (center, _) = makeCenter()
        let task = Task { @MainActor in
            try await center.withProgress(title: "Uploading", operation: { _ -> Int in
                try await Task.sleep(nanoseconds: 60_000_000_000)
                return 1
            })
        }
        var spins = 0
        while center.toasts.isEmpty, spins < 1_000 {
            await Task.yield()
            spins += 1
        }
        XCTAssertFalse(center.toasts.isEmpty, "the card should be up while the operation runs")

        task.cancel()
        let result = await task.result

        if case .success = result { XCTFail("a cancelled operation must not succeed") }
        XCTAssertTrue(center.toasts.isEmpty, "cancelled, so removed with no result card")
        XCTAssertTrue(center.progressRecords.isEmpty)
    }

    func testTheCancelButtonCancelsTheOperation() async {
        let (center, _) = makeCenter()
        let task = Task { @MainActor in
            try await center.withProgress(title: "Uploading", operation: { _ -> Int in
                try await Task.sleep(nanoseconds: 60_000_000_000)
                return 1
            })
        }
        var spins = 0
        while center.toasts.isEmpty, spins < 1_000 {
            await Task.yield()
            spins += 1
        }
        guard let id = center.topmost?.id else { return XCTFail("the card should be up") }
        XCTAssertEqual(center.progressStore.cells[id]?.canCancel, true)

        center.requestCancel(id: id)
        let result = await task.result

        if case .success = result { XCTFail("a cancelled operation must not succeed") }
        XCTAssertTrue(center.toasts.isEmpty)
        XCTAssertFalse(center.isTracking(id: id))
    }

    func testANonCancellableOperationOffersNoCancel() async throws {
        let (center, _) = makeCenter()
        // The operation waits on a gate rather than the clock.
        let (gate, gateControl) = AsyncStream<Void>.makeStream()
        let task = Task { @MainActor in
            try await center.withProgress(title: "Saving", cancellable: false, operation: { _ -> Int in
                for await _ in gate {}
                return 1
            })
        }
        var spins = 0
        while center.toasts.isEmpty, spins < 1_000 {
            await Task.yield()
            spins += 1
        }
        let id = try XCTUnwrap(center.topmost?.id)
        XCTAssertEqual(center.progressStore.cells[id]?.canCancel, false)

        gateControl.finish()
        _ = try await task.value
    }

    func testTheReporterCoalescesToTheLatestValue() async throws {
        let (center, _) = makeCenter()
        let inbox = ToastProgressInbox()
        let reporter = ToastProgressReporter(inbox: inbox)
        let handle = center.track(title: "Uploading")
        inbox.bind(center: center, id: handle.id, serial: handle.serial)

        for step in 1...100 {
            reporter(.fraction(Double(step) / 100))
        }
        await inbox.lastHop?.value

        XCTAssertEqual(center.progressStore.cells[handle.id]?.value, .fraction(1))
        withExtendedLifetime(handle) {}
    }
}
