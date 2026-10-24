import XCTest
@testable import ToastKit

/// Batch dismissal, groups, scopes, the D1–D8 rules and the departures the stack draws,
/// all asserted on the model with a fake clock — no view host.
@MainActor
final class ToastDismissalTests: XCTestCase {

    private func makeCenter(
        capacity: Int = 8,
        visibleDepth: Int = 3
    ) -> (ToastCenter, FakeToastScheduler) {
        let scheduler = FakeToastScheduler()
        let center = ToastCenter(
            scheduler: scheduler,
            defaultDuration: 4,
            visibleDepth: visibleDepth,
            capacity: capacity
        )
        return (center, scheduler)
    }

    // MARK: - Groups

    func testDismissingAGroupRemovesOnlyItsToastsAndKeepsOrder() {
        let (center, _) = makeCenter()
        let first = ToastMessage(title: "first", group: "sync")
        let plain = ToastMessage(title: "plain")
        let other = ToastMessage(title: "other", group: "upload")
        let last = ToastMessage(title: "last", group: "sync")
        [first, plain, other, last].forEach { center.present($0) }

        let removed = center.dismiss(group: "sync")

        XCTAssertEqual(removed, 2)
        XCTAssertEqual(center.toasts.map(\.id), [plain.id, other.id])
    }

    func testToastsWithoutAGroupNeverMatch() {
        let (center, _) = makeCenter()
        center.present(.normal, title: "a")
        center.present(.normal, title: "b")

        XCTAssertEqual(center.dismiss(group: "sync"), 0)
        XCTAssertEqual(center.toasts.count, 2)
    }

    func testPresentingNeverReplacesAnotherToastInTheSameGroup() {
        let (center, _) = makeCenter()
        center.present(.normal, title: "one", group: "sync")
        center.present(.normal, title: "two", group: "sync")

        XCTAssertEqual(center.toasts.count, 2)
        XCTAssertEqual(center.toasts.map(\.group), ["sync", "sync"])
    }

    func testTheOriginalInitialiserLeavesTheGroupEmpty() {
        XCTAssertNil(ToastMessage(title: "plain").group)
        XCTAssertEqual(ToastMessage(title: "grouped", group: "sync").group, "sync")
        let index = 1
        let interpolated: ToastGroup = "upload:\(index)"
        XCTAssertEqual(interpolated.rawValue, "upload:1")
        XCTAssertEqual(interpolated, ToastGroup(rawValue: "upload:1"))
    }

    // MARK: - Predicates

    func testDismissingByPredicateRemovesMatchesAndReturnsTheCount() {
        let (center, _) = makeCenter()
        center.present(.error, title: "e1")
        center.present(.normal, title: "n")
        center.present(.error, title: "e2")

        let removed = center.dismiss(removal: .slide()) { $0.status == .error }

        XCTAssertEqual(removed, 2)
        XCTAssertEqual(center.toasts.map(\.title), ["n"])
    }

    // MARK: - Scopes

    private func centerWithOnePostponed() -> (ToastCenter, FakeToastScheduler, ToastMessage, ToastMessage) {
        let (center, scheduler) = makeCenter()
        let postponed = ToastMessage(title: "later", group: "g")
        let showing = ToastMessage(title: "now", group: "g")
        center.present(postponed)
        center.present(showing)
        center.postpone(id: postponed.id)
        return (center, scheduler, showing, postponed)
    }

    func testOnScreenScopeLeavesPostponedToastsAlone() {
        let (center, _, _, _) = centerWithOnePostponed()

        XCTAssertEqual(center.dismiss(group: "g", scope: .onScreen), 1)
        XCTAssertTrue(center.toasts.isEmpty)
        XCTAssertEqual(center.postponed.count, 1)
    }

    func testPostponedScopeLeavesTheStackAlone() {
        let (center, _, showing, _) = centerWithOnePostponed()

        XCTAssertEqual(center.dismiss(group: "g", scope: .postponed), 1)
        XCTAssertEqual(center.toasts.map(\.id), [showing.id])
        XCTAssertTrue(center.postponed.isEmpty)
    }

    func testEverywhereScopeReachesBothAndCountsPostponedToasts() {
        let (center, _, _, _) = centerWithOnePostponed()

        XCTAssertEqual(center.dismiss(group: "g", scope: .everywhere), 2)
        XCTAssertTrue(center.toasts.isEmpty)
        XCTAssertTrue(center.postponed.isEmpty)
    }

    func testDismissingAGroupClearsPostponedToastsByDefault() {
        let (center, _, _, _) = centerWithOnePostponed()

        XCTAssertEqual(center.dismiss(group: "g"), 2)
        XCTAssertTrue(center.postponed.isEmpty)
    }

    func testPlainDismissAllLeavesPostponedToastsButTheScopedOneClearsThem() {
        let (center, _, _, _) = centerWithOnePostponed()
        center.dismissAll()
        XCTAssertEqual(center.postponed.count, 1)

        XCTAssertEqual(center.dismissAll(removal: nil, scope: .everywhere), 1)
        XCTAssertTrue(center.postponed.isEmpty)
    }

    // MARK: - The countdown

    func testABatchThatSparesTheTopmostLeavesTheCountdownAlone() {
        let (center, scheduler) = makeCenter()
        center.present(.normal, title: "a", group: "g")
        center.present(.normal, title: "b", group: "g")
        center.present(.normal, title: "top")
        let timed = center.timedToastID
        let interval = scheduler.pendingInterval
        let cancels = scheduler.cancelCount

        XCTAssertEqual(center.dismiss(group: "g"), 2)

        XCTAssertEqual(center.timedToastID, timed)
        XCTAssertEqual(scheduler.pendingInterval, interval)
        XCTAssertEqual(scheduler.cancelCount, cancels)
    }

    func testABatchThatRemovesTheTopmostTimesTheNextToastAtFullDurationAtOnce() {
        let (center, scheduler) = makeCenter()
        let buried = ToastMessage(title: "buried")
        center.present(buried)
        center.present(.normal, title: "top", group: "g")
        scheduler.advance(3)

        center.dismiss(group: "g", removal: .trail())

        XCTAssertEqual(center.timedToastID, buried.id)
        XCTAssertEqual(scheduler.pendingInterval, 4)
    }

    func testABatchCancelsTheTimerAtMostOnce() {
        let (center, scheduler) = makeCenter()
        for index in 0..<4 { center.present(.normal, title: "t\(index)", group: "g") }
        let cancels = scheduler.cancelCount

        center.dismiss(group: "g")

        XCTAssertLessThanOrEqual(scheduler.cancelCount - cancels, 1)
    }

    func testEmptyingTheStackReleasesTheInteraction() {
        let (center, _) = makeCenter()
        center.present(.normal, title: "a", group: "g")
        center.present(.normal, title: "b", group: "g")
        center.setInteracting(true)

        center.dismiss(group: "g")

        XCTAssertFalse(center.isInteracting)
    }

    // MARK: - A lifted card (D6)

    func testALiftedCardRemovedByCodeCancelsItsHoldAndLeavesAtOnce() {
        let (center, scheduler) = makeCenter()
        let buried = ToastMessage(title: "buried")
        let lifted = ToastMessage(title: "lifted", group: "g")
        center.present(buried)
        center.present(lifted)
        center.setLifted(lifted.id)
        center.setInteracting(true)

        center.dismiss(group: "g", removal: .trail())

        XCTAssertFalse(center.isInteracting)
        XCTAssertTrue(center.departures.isEmpty)
        XCTAssertEqual(center.timedToastID, buried.id)
        XCTAssertEqual(scheduler.pendingInterval, 4)
    }

    func testABatchWhileACardIsLiftedRecordsNoDepartures() {
        let (center, _) = makeCenter()
        let lifted = ToastMessage(title: "lifted")
        center.present(.normal, title: "behind", group: "g")
        center.present(lifted)
        center.setLifted(lifted.id)
        center.setInteracting(true)

        center.dismiss(group: "g")

        XCTAssertTrue(center.departures.isEmpty)
        XCTAssertTrue(center.isInteracting, "the lifted card is still held")
    }

    // MARK: - Announcements (D8)

    func testBatchesAndDismissAllAnnounceButSingleRemovalsDoNot() {
        let (center, scheduler) = makeCenter()
        XCTAssertNil(center.batchAnnouncement)

        center.present(.normal, title: "a", group: "g")
        center.present(.normal, title: "b", group: "g")
        center.present(.normal, title: "c")
        center.dismiss(group: "g")
        XCTAssertEqual(center.batchAnnouncement, ToastBatchAnnouncement(count: 2, serial: 1))

        center.dismissAll()
        XCTAssertEqual(center.batchAnnouncement, ToastBatchAnnouncement(count: 1, serial: 2))

        let single = ToastMessage(title: "single")
        center.present(single)
        center.dismiss(id: single.id)
        center.present(.normal, title: "expires")
        scheduler.fire()
        XCTAssertEqual(center.batchAnnouncement?.serial, 2)
    }

    func testRemovingOnlyPostponedToastsDoesNotAnnounce() {
        let (center, _, _, _) = centerWithOnePostponed()
        center.dismiss(group: "g", scope: .onScreen)
        let serial = center.batchAnnouncement?.serial

        center.dismiss(group: "g", scope: .postponed)

        XCTAssertEqual(center.batchAnnouncement?.serial, serial)
    }

    func testDismissingAnEmptyStackDoesNotAnnounce() {
        let (center, _) = makeCenter()
        center.dismissAll()
        XCTAssertNil(center.batchAnnouncement)
    }

    // MARK: - Departures

    func testOnlyVisibleCardsGetADepartureFrontFirstWithTheRemovalStored() {
        let (center, _) = makeCenter(visibleDepth: 2)
        let toasts = (0..<4).map { ToastMessage(title: "t\($0)") }
        toasts.forEach { center.present($0) }

        center.dismissAll(removal: .trail())

        XCTAssertEqual(center.departures.map(\.toast.id), [toasts[3].id, toasts[2].id])
        XCTAssertEqual(center.departures.map(\.depth), [0, 1])
        XCTAssertEqual(center.departures.map(\.order), [0, 1])
        XCTAssertEqual(center.departures.map(\.batchCount), [2, 2])
        XCTAssertEqual(
            center.departures.map(\.removal),
            [ToastRemoval?.some(.trail()), ToastRemoval?.some(.trail())]
        )
    }

    func testABuriedCardRemovedAloneKeepsItsDepth() {
        let (center, _) = makeCenter()
        let toasts = (0..<3).map { ToastMessage(title: "t\($0)") }
        toasts.forEach { center.present($0) }

        center.dismiss(id: toasts[1].id)

        XCTAssertEqual(center.departures.map(\.depth), [1])
        XCTAssertEqual(center.departures.map(\.batchCount), [1])
    }

    func testExpiryStoresNoRemovalSoTheStacksDefaultApplies() {
        let (center, scheduler) = makeCenter()
        center.present(.normal, title: "a")

        scheduler.fire()

        XCTAssertEqual(center.departures.count, 1)
        XCTAssertNil(center.departures.first?.removal)
    }

    func testCardsRunningTheirOwnExitGetNoDeparture() {
        let (center, _) = makeCenter()
        let flung = ToastMessage(title: "flung")
        center.present(flung)
        center.present(.normal, title: "top")
        center.beginOwnExit(id: flung.id)

        center.dismissAll(removal: .slide())

        XCTAssertEqual(center.departures.map(\.toast.title), ["top"])
        XCTAssertEqual(center.departures.map(\.batchCount), [1])
    }

    func testOwnExitMarksForGoneToastsArePrunedOnTheNextChange() {
        let (center, _) = makeCenter()
        let flung = ToastMessage(title: "flung")
        center.present(flung)
        center.beginOwnExit(id: flung.id)
        center.dismiss(id: flung.id)

        center.present(.normal, title: "next")

        XCTAssertTrue(center.ownExitIDs.isEmpty)
    }

    func testAnUnknownToastCannotBeMarkedAsExiting() {
        let (center, _) = makeCenter()
        center.beginOwnExit(id: UUID())
        XCTAssertTrue(center.ownExitIDs.isEmpty)
    }

    func testPresentingAnIDAgainDropsItsDeparture() {
        let (center, _) = makeCenter()
        let toast = ToastMessage(title: "again")
        center.present(toast)
        center.dismiss(id: toast.id)
        XCTAssertEqual(center.departures.count, 1)

        center.present(toast)

        XCTAssertTrue(center.departures.isEmpty)
    }

    func testFinishingAndClearingDepartures() {
        let (center, _) = makeCenter()
        let first = ToastMessage(title: "first")
        center.present(first)
        center.present(.normal, title: "second")
        center.dismissAll()
        XCTAssertEqual(center.departures.count, 2)

        let firstToken = center.departures.first { $0.toast.id == first.id }?.token
        center.finishDeparture(token: firstToken ?? UUID())
        XCTAssertEqual(center.departures.map(\.toast.title), ["second"])

        center.clearDepartures()
        XCTAssertTrue(center.departures.isEmpty)
    }

    func testAStaleDepartureTokenCannotEndALaterDepartureOfTheSameToast() {
        let (center, _) = makeCenter()
        let toast = ToastMessage(title: "again")
        center.present(toast)
        center.dismiss(id: toast.id)
        let staleToken = center.departures.first?.token

        center.present(toast)
        center.dismiss(id: toast.id)
        XCTAssertEqual(center.departures.count, 1)
        XCTAssertNotEqual(center.departures.first?.token, staleToken)

        center.finishDeparture(token: staleToken ?? UUID())

        XCTAssertEqual(center.departures.count, 1)
    }

    func testAStaleLiftedIDIsForgottenSoLaterRemovalsGetDepartures() {
        let (center, _) = makeCenter()
        let toast = ToastMessage(title: "top")
        center.present(.normal, title: "behind")
        center.present(toast)
        center.setLifted(UUID())

        center.dismiss(id: toast.id)

        XCTAssertEqual(center.departures.map(\.toast.id), [toast.id])
    }

    func testDeparturesOlderThanFiveSecondsArePruned() {
        let (center, scheduler) = makeCenter()
        let old = ToastMessage(title: "old")
        center.present(old)
        center.dismiss(id: old.id)
        scheduler.advance(4)
        center.present(.normal, title: "a")
        XCTAssertEqual(center.departures.count, 1)

        scheduler.advance(2)
        center.present(.normal, title: "b")

        XCTAssertTrue(center.departures.isEmpty)
    }

    func testDeparturesAreCappedAtCapacityPlusVisibleDepth() {
        let (center, _) = makeCenter(capacity: 2, visibleDepth: 1)

        for index in 0..<8 {
            let toast = ToastMessage(title: "t\(index)")
            center.present(toast)
            center.dismiss(id: toast.id)
        }

        XCTAssertEqual(center.departures.count, 3)
        XCTAssertEqual(center.departures.last?.toast.title, "t7")
    }

    func testACapacityDropAddsADepartureForTheVisibleCardItTakes() {
        let (center, _) = makeCenter(capacity: 2)
        let oldest = ToastMessage(title: "oldest")
        center.present(oldest)
        center.present(.normal, title: "middle")

        center.present(.normal, title: "arrival")

        XCTAssertEqual(center.toasts.count, 2)
        XCTAssertEqual(center.departures.map(\.toast.id), [oldest.id])
        // Planned against the stack as it was drawn, before the arrival: [oldest, middle].
        XCTAssertEqual(center.departures.map(\.depth), [1])
        XCTAssertNil(center.departures.first?.removal)
    }

    func testPostponingAddsADeparture() {
        let (center, _) = makeCenter()
        let toast = ToastMessage(title: "later")
        center.present(.normal, title: "behind")
        center.present(toast)

        center.postpone(id: toast.id)

        XCTAssertEqual(center.departures.map(\.toast.id), [toast.id])
        XCTAssertEqual(center.postponed.map(\.id), [toast.id])
    }

    // MARK: - Planning

    func testThePlannerSkipsCardsThatAreNotRemovedVisibleOrFree() {
        let toasts = (0..<4).map { ToastMessage(title: "t\($0)") }
        let ids = Set(toasts.map(\.id))

        let plan = ToastDeparture.plan(
            removing: ids,
            from: toasts,
            visibleDepth: 3,
            removal: nil,
            excluding: [toasts[2].id],
            at: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(plan.map(\.toast.id), [toasts[3].id, toasts[1].id])
        XCTAssertEqual(plan.map(\.depth), [0, 2])
        XCTAssertEqual(plan.map(\.order), [0, 1])
    }

    // MARK: - Announcement text

    func testTheBatchAnnouncementIsLocalisedAndCarriesTheCount() {
        let text = ToastAnnouncement.batchDismissed(count: 3)

        XCTAssertTrue(text.contains("3"))
        XCTAssertNotEqual(text, "toast.a11y.dismissed 3")
        XCTAssertFalse(text.contains("toast.a11y"))
    }
}
