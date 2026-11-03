import XCTest
@testable import ToastKit

@MainActor
final class ToastCenterTests: XCTestCase {

    private func makeCenter(
        defaultDuration: TimeInterval = ToastDuration.defaultSeconds,
        capacity: Int = 5
    ) -> (ToastCenter, FakeToastScheduler) {
        let scheduler = FakeToastScheduler()
        let center = ToastCenter(scheduler: scheduler, defaultDuration: defaultDuration, capacity: capacity)
        return (center, scheduler)
    }

    // MARK: - Stack order

    func testNewestToastBecomesTopmost() {
        let (center, _) = makeCenter()
        let first = ToastMessage(title: "first")
        let second = ToastMessage(title: "second")

        center.present(first)
        center.present(second)

        XCTAssertEqual(center.topmost?.id, second.id)
        XCTAssertEqual(center.depth(of: second), 0)
        XCTAssertEqual(center.depth(of: first), 1)
    }

    func testRePresentingSameIDMovesItToTheFrontInsteadOfDuplicating() {
        let (center, _) = makeCenter()
        let id = UUID()
        center.present(ToastMessage(id: id, title: "original"))
        center.present(ToastMessage(title: "other"))
        center.present(ToastMessage(id: id, title: "refreshed"))

        XCTAssertEqual(center.toasts.count, 2)
        XCTAssertEqual(center.topmost?.id, id)
        XCTAssertEqual(center.topmost?.title, "refreshed")
    }

    func testCapacityDropsTheOldestToasts() {
        let (center, _) = makeCenter(capacity: 2)
        let first = ToastMessage(title: "first")
        center.present(first)
        center.present(ToastMessage(title: "second"))
        center.present(ToastMessage(title: "third"))

        XCTAssertEqual(center.toasts.count, 2)
        XCTAssertNil(center.depth(of: first))
    }

    func testCapacityEvictsTimedToastsBeforePersistentOnes() {
        let (center, _) = makeCenter(capacity: 2)
        let pinned = ToastMessage(status: .error, title: "sync failed", duration: 0)
        let routine = ToastMessage(title: "routine")
        let arrival = ToastMessage(title: "arrival")
        center.present(pinned)
        center.present(routine)
        center.present(arrival)

        XCTAssertEqual(
            center.toasts.map(\.id), [pinned.id, arrival.id],
            "a burst of routine toasts must not push out one the user has to acknowledge"
        )
    }

    func testCapacityFallsBackToTheOldestWhenEveryToastIsPersistent() {
        let (center, _) = makeCenter(capacity: 2)
        let first = ToastMessage(title: "first", duration: 0)
        let second = ToastMessage(title: "second", duration: 0)
        let third = ToastMessage(title: "third", duration: 0)
        center.present(first)
        center.present(second)
        center.present(third)

        XCTAssertEqual(center.toasts.map(\.id), [second.id, third.id])
    }

    func testCapacityNeverDropsTheArrival() {
        let (center, _) = makeCenter(capacity: 2)
        let first = ToastMessage(title: "first", duration: 0)
        let second = ToastMessage(title: "second", duration: 0)
        let arrival = ToastMessage(title: "timed arrival", duration: 4)
        center.present(first)
        center.present(second)
        center.present(arrival)

        XCTAssertEqual(center.toasts.map(\.id), [second.id, arrival.id])
    }

    // MARK: - Status

    func testStatusDefaultsToNormal() {
        XCTAssertEqual(ToastMessage(title: "plain").status, .normal)
    }

    func testStatusSurvivesPresentation() {
        let (center, _) = makeCenter()
        center.present(.error, title: "failed")
        XCTAssertEqual(center.topmost?.status, .error)
    }

    func testActionsSurvivePresentation() {
        let (center, _) = makeCenter()
        let swipes = ToastSwipeActions(
            leading: ToastAction(title: "Archive", role: .subdued),
            trailing: ToastAction(title: "Remind me later")
        )
        let tap = ToastAction(title: "Undo")
        center.present(.normal, title: "Moved to Trash", tapAction: tap, swipeActions: swipes)
        XCTAssertEqual(center.topmost?.swipeActions, swipes)
        XCTAssertEqual(center.topmost?.tapAction, tap)
    }

    func testEveryStatusIsRepresented() {
        XCTAssertEqual(
            ToastMessage.Status.allCases,
            [.normal, .warning, .error, .notification]
        )
    }

    // MARK: - Only the topmost is timed

    func testOnlyTheTopmostToastIsTimed() {
        let (center, scheduler) = makeCenter()
        let first = ToastMessage(title: "first", duration: 4)
        let second = ToastMessage(title: "second", duration: 9)

        center.present(first)
        XCTAssertEqual(center.timedToastID, first.id)
        XCTAssertEqual(scheduler.pendingInterval, 4)

        center.present(second)
        XCTAssertEqual(center.timedToastID, second.id)
        XCTAssertEqual(scheduler.pendingInterval, 9, "the countdown moves to the new arrival")
    }

    func testExpiryRemovesOnlyTheTopmostAndHandsTheTimerDown() {
        let (center, scheduler) = makeCenter()
        let first = ToastMessage(title: "first", duration: 4)
        let second = ToastMessage(title: "second", duration: 2)

        center.present(first)
        center.present(second)
        scheduler.fire()

        XCTAssertEqual(center.toasts.map(\.id), [first.id])
        XCTAssertEqual(center.timedToastID, first.id)
        XCTAssertEqual(scheduler.pendingInterval, 4, "the newly topmost toast starts its own full timer")
    }

    func testBuriedToastGetsAFullDurationRatherThanTheRemainderOfAnEarlierRun() {
        let (center, scheduler) = makeCenter()
        let first = ToastMessage(title: "first", duration: 10)
        center.present(first)

        // Three seconds burn off `first`'s countdown before it is buried.
        scheduler.advance(3)
        let second = ToastMessage(title: "second", duration: 1)
        center.present(second)
        scheduler.fire()

        XCTAssertEqual(center.timedToastID, first.id)
        XCTAssertEqual(scheduler.pendingInterval, 10)
    }

    func testDismissingABuriedToastLeavesTheRunningCountdownAlone() {
        let (center, scheduler) = makeCenter()
        let first = ToastMessage(title: "first", duration: 4)
        let second = ToastMessage(title: "second", duration: 6)
        center.present(first)
        center.present(second)

        let cancelsBefore = scheduler.cancelCount
        center.dismiss(id: first.id)

        XCTAssertEqual(center.timedToastID, second.id)
        XCTAssertEqual(scheduler.cancelCount, cancelsBefore, "the topmost's countdown was not rescheduled")
    }

    func testDismissingAnAbsentToastIsANoOp() {
        let (center, scheduler) = makeCenter()
        let toast = ToastMessage(title: "only", duration: 5)
        center.present(toast)

        let cancelsBefore = scheduler.cancelCount
        center.dismiss(id: UUID())

        XCTAssertEqual(center.toasts.count, 1)
        XCTAssertEqual(scheduler.cancelCount, cancelsBefore)
    }

    // MARK: - Persistent toasts

    func testPersistentToastIsNeverTimed() {
        let (center, scheduler) = makeCenter()
        center.present(ToastMessage(title: "sticky", duration: 0))

        XCTAssertNil(center.timedToastID)
        XCTAssertNil(scheduler.pendingInterval)
    }

    func testTimedToastBuriedUnderAPersistentOneStopsCountingDown() {
        let (center, scheduler) = makeCenter()
        center.present(ToastMessage(title: "timed", duration: 4))
        center.present(ToastMessage(title: "sticky", duration: 0))

        XCTAssertNil(center.timedToastID)
        XCTAssertNil(scheduler.pendingInterval)
    }

    // MARK: - Interaction pauses the countdown

    func testInteractionPausesAndResumesWithTheTimeThatWasLeft() {
        let (center, scheduler) = makeCenter()
        center.present(ToastMessage(title: "only", duration: 6))

        scheduler.advance(2)
        center.setInteracting(true)
        XCTAssertNil(scheduler.pendingInterval, "no countdown runs while a finger is down")

        // Time spent dragging must not count against the toast.
        scheduler.advance(30)
        center.setInteracting(false)

        XCTAssertEqual(scheduler.pendingInterval, 4)
    }

    func testRepeatedInteractionEdgesDoNotExtendTheCountdown() {
        let (center, scheduler) = makeCenter()
        center.present(ToastMessage(title: "only", duration: 6))

        scheduler.advance(2)
        center.setInteracting(true)
        center.setInteracting(true)
        center.setInteracting(false)
        center.setInteracting(false)

        XCTAssertEqual(scheduler.pendingInterval, 4)
    }

    func testToastArrivingDuringAnInteractionIsTimedOnlyOnceTheFingerLifts() {
        let (center, scheduler) = makeCenter()
        center.present(ToastMessage(title: "first", duration: 6))
        center.setInteracting(true)

        let second = ToastMessage(title: "second", duration: 3)
        center.present(second)
        XCTAssertEqual(center.timedToastID, second.id)
        XCTAssertNil(scheduler.pendingInterval)

        center.setInteracting(false)
        XCTAssertEqual(scheduler.pendingInterval, 3)
    }

    func testEmptyingTheStackReleasesAnInteractionThatNeverEnded() {
        let (center, scheduler) = makeCenter()
        center.present(ToastMessage(title: "dragged", duration: 4))
        center.setInteracting(true)

        // The card under the finger is removed before its gesture can report an end.
        center.dismissAll()
        XCTAssertFalse(center.isInteracting)

        center.present(ToastMessage(title: "next", duration: 4))
        XCTAssertEqual(scheduler.pendingInterval, 4, "the next toast counts down instead of waiting for a lift")
    }

    func testDismissingTheLastToastReleasesTheInteraction() {
        let (center, _) = makeCenter()
        let only = ToastMessage(title: "only", duration: 4)
        center.present(only)
        center.setInteracting(true)

        center.dismiss(id: only.id)

        XCTAssertFalse(center.isInteracting)
    }

    func testDismissingABuriedToastKeepsTheInteraction() {
        let (center, scheduler) = makeCenter()
        let buried = ToastMessage(title: "buried", duration: 4)
        center.present(buried)
        center.present(ToastMessage(title: "under the finger", duration: 4))
        center.setInteracting(true)

        center.dismiss(id: buried.id)

        XCTAssertTrue(center.isInteracting, "a finger is still on the front card")
        XCTAssertNil(scheduler.pendingInterval)
    }

    // MARK: - Suspension pauses the countdown

    func testSuspensionPausesAndResumesWithTheTimeThatWasLeft() {
        let (center, scheduler) = makeCenter()
        center.present(ToastMessage(title: "only", duration: 6))

        scheduler.advance(2)
        center.setSuspended(true)
        XCTAssertNil(scheduler.pendingInterval, "nothing expires while the app is away")

        // Time in the background must not count against the toast.
        scheduler.advance(600)
        center.setSuspended(false)

        XCTAssertEqual(scheduler.pendingInterval, 4)
    }

    func testCountdownWaitsForBothTheFingerAndTheForeground() {
        let (center, scheduler) = makeCenter()
        center.present(ToastMessage(title: "only", duration: 6))

        scheduler.advance(1)
        center.setInteracting(true)
        center.setSuspended(true)

        center.setInteracting(false)
        XCTAssertNil(scheduler.pendingInterval, "the app is still in the background")

        center.setSuspended(false)
        XCTAssertEqual(scheduler.pendingInterval, 5)
    }

    func testToastPresentedWhileSuspendedIsTimedOnlyInTheForeground() {
        let (center, scheduler) = makeCenter()
        center.setSuspended(true)

        let toast = ToastMessage(title: "arrived in the background", duration: 4)
        center.present(toast)
        XCTAssertEqual(center.timedToastID, toast.id)
        XCTAssertNil(scheduler.pendingInterval)

        center.setSuspended(false)
        XCTAssertEqual(scheduler.pendingInterval, 4)
    }

    // MARK: - Clearing

    func testDismissAllStopsTheCountdown() {
        let (center, scheduler) = makeCenter()
        center.present(ToastMessage(title: "first", duration: 4))
        center.present(ToastMessage(title: "second", duration: 4))

        center.dismissAll()

        XCTAssertTrue(center.toasts.isEmpty)
        XCTAssertNil(center.timedToastID)
        XCTAssertNil(scheduler.pendingInterval)
    }

    func testDismissTopmostAdvancesTheStack() {
        let (center, scheduler) = makeCenter()
        let first = ToastMessage(title: "first", duration: 4)
        let second = ToastMessage(title: "second", duration: 7)
        center.present(first)
        center.present(second)

        center.dismissTopmost()

        XCTAssertEqual(center.toasts.map(\.id), [first.id])
        XCTAssertEqual(center.timedToastID, first.id)
        XCTAssertEqual(scheduler.pendingInterval, 4)
    }

    // MARK: - Duration

    func testAutomaticDurationUsesTheCentersDefault() {
        let (center, scheduler) = makeCenter(defaultDuration: 7)
        let toast = ToastMessage(title: "automatic")
        XCTAssertEqual(toast.duration, .automatic)

        center.present(toast)

        XCTAssertEqual(center.displaySeconds(for: toast), 7)
        XCTAssertEqual(scheduler.pendingInterval, 7)
    }

    func testTheDefaultDurationIsFourSeconds() {
        let (center, scheduler) = makeCenter()
        center.present(.normal, title: "plain")
        XCTAssertEqual(center.defaultDuration, 4)
        XCTAssertEqual(scheduler.pendingInterval, 4)
    }

    func testAToastsOwnDurationOverridesTheDefault() {
        let (center, scheduler) = makeCenter(defaultDuration: 7)
        center.present(ToastMessage(title: "quick", duration: .seconds(2)))
        XCTAssertEqual(scheduler.pendingInterval, 2)
    }

    func testIndefiniteToastsAreNeverTimed() {
        let (center, scheduler) = makeCenter()
        let toast = ToastMessage(title: "sticky", duration: .indefinite)
        center.present(toast)

        XCTAssertNil(center.displaySeconds(for: toast))
        XCTAssertNil(center.timedToastID)
        XCTAssertNil(scheduler.pendingInterval)
    }

    func testANonPositiveDefaultMakesAutomaticToastsWait() {
        let (center, scheduler) = makeCenter(defaultDuration: 0)
        center.present(ToastMessage(title: "automatic"))
        XCTAssertNil(scheduler.pendingInterval)
    }

    func testDurationLiteralsMeanSeconds() {
        let six: ToastDuration = 6
        let half: ToastDuration = 0.5
        XCTAssertEqual(six, .seconds(6))
        XCTAssertEqual(half, .seconds(0.5))
        XCTAssertNil(ToastDuration.seconds(0).resolved(defaultSeconds: 4), "zero still means until dismissed")
        XCTAssertNil(ToastDuration.seconds(-1).resolved(defaultSeconds: 4))
        XCTAssertNil(ToastDuration.seconds(.infinity).resolved(defaultSeconds: 4))
    }

    // MARK: - Postponing

    func testPostponingTakesTheToastOffScreenAndKeepsIt() {
        let (center, scheduler) = makeCenter()
        let below = ToastMessage(title: "below", duration: 5)
        let later = ToastMessage(title: "later", duration: 3)
        center.present(below)
        center.present(later)

        center.postpone(id: later.id)

        XCTAssertEqual(center.toasts.map(\.id), [below.id])
        XCTAssertEqual(center.postponed.map(\.id), [later.id])
        XCTAssertEqual(center.timedToastID, below.id, "the toast beneath takes over the countdown")
        XCTAssertEqual(scheduler.pendingInterval, 5)
    }

    func testRestoringBringsPostponedToastsBackWithAFreshCountdown() {
        let (center, scheduler) = makeCenter()
        let first = ToastMessage(title: "first", duration: 3)
        let second = ToastMessage(title: "second", duration: 6)
        center.present(first)
        center.present(second)
        center.postpone(id: first.id)
        center.postpone(id: second.id)
        XCTAssertTrue(center.toasts.isEmpty)
        XCTAssertNil(scheduler.pendingInterval)

        center.restorePostponed()

        XCTAssertEqual(center.toasts.map(\.id), [first.id, second.id], "postponed last, back in front")
        XCTAssertTrue(center.postponed.isEmpty)
        XCTAssertEqual(center.timedToastID, second.id)
        XCTAssertEqual(scheduler.pendingInterval, 6)
    }

    func testPostponingAToastThatIsNotShowingDoesNothing() {
        let (center, _) = makeCenter()
        center.postpone(id: UUID())
        XCTAssertTrue(center.postponed.isEmpty)
    }

    func testDismissingAPostponedToastForgetsIt() {
        let (center, _) = makeCenter()
        let toast = ToastMessage(title: "later")
        center.present(toast)
        center.postpone(id: toast.id)

        center.dismiss(id: toast.id)
        center.restorePostponed()

        XCTAssertTrue(center.toasts.isEmpty)
        XCTAssertTrue(center.postponed.isEmpty)
    }

    func testPresentingAPostponedIdAgainTakesItOutOfWaiting() {
        let (center, _) = makeCenter()
        let toast = ToastMessage(title: "later")
        center.present(toast)
        center.postpone(id: toast.id)

        center.present(toast)

        XCTAssertEqual(center.toasts.map(\.id), [toast.id])
        XCTAssertTrue(center.postponed.isEmpty)
    }

    func testDismissAllLeavesPostponedToastsWaiting() {
        let (center, _) = makeCenter()
        let waiting = ToastMessage(title: "waiting")
        center.present(waiting)
        center.postpone(id: waiting.id)
        center.present(.normal, title: "showing")

        center.dismissAll()

        XCTAssertTrue(center.toasts.isEmpty)
        XCTAssertEqual(center.postponed.map(\.id), [waiting.id])

        center.discardPostponed()
        XCTAssertTrue(center.postponed.isEmpty)
    }

    func testPostponedToastsAreCappedAtCapacity() {
        let (center, _) = makeCenter(capacity: 2)
        let toasts = (0..<3).map { ToastMessage(title: "toast \($0)") }
        for toast in toasts {
            center.present(toast)
            center.postpone(id: toast.id)
        }
        XCTAssertEqual(center.postponed.map(\.id), [toasts[1].id, toasts[2].id], "the oldest goes first")
    }

    func testPostponingTheLastToastReleasesTheInteraction() {
        let (center, _) = makeCenter()
        let toast = ToastMessage(title: "only")
        center.present(toast)
        center.setInteracting(true)

        center.postpone(id: toast.id)

        XCTAssertFalse(center.isInteracting)
    }
}
