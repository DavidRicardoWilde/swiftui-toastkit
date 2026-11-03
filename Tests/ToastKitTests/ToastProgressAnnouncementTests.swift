import XCTest
@testable import ToastKit

/// When a progress toast speaks, and that what it says is in every language's table.
@MainActor
final class ToastProgressAnnouncementTests: XCTestCase {

    private let start = Date(timeIntervalSince1970: 1_000)

    private func make(
        announcements: ToastProgressOptions.Announcements = .milestones(step: 0.25, minimumInterval: 5)
    ) -> (ToastCenter, FakeToastScheduler, ToastProgressHandle) {
        let scheduler = FakeToastScheduler()
        let center = ToastCenter(scheduler: scheduler, defaultDuration: 4)
        var options = ToastProgressOptions()
        options.announcements = announcements
        let handle = center.track(title: "Uploading", options: options, onCancel: {})
        return (center, scheduler, handle)
    }

    // MARK: - Milestones, in isolation

    func testAMilestoneIsACrossedStep() {
        var milestones = ToastProgressMilestones(step: 0.25, minimumInterval: 0)
        milestones.began(at: start, fraction: 0)

        XCTAssertNil(milestones.next(fraction: 0.1, now: start, isFront: true, isActive: true))
        XCTAssertEqual(milestones.next(fraction: 0.26, now: start, isFront: true, isActive: true), 26)
        XCTAssertNil(milestones.next(fraction: 0.4, now: start, isFront: true, isActive: true), "same step")
        XCTAssertEqual(milestones.next(fraction: 0.51, now: start, isFront: true, isActive: true), 51)
        XCTAssertEqual(milestones.next(fraction: 0.75, now: start, isFront: true, isActive: true), 75)
    }

    func testTheFullBarIsLeftToTheOutcome() {
        var milestones = ToastProgressMilestones(step: 0.25, minimumInterval: 0)
        milestones.began(at: start, fraction: 0)

        XCTAssertEqual(milestones.next(fraction: 0.8, now: start, isFront: true, isActive: true), 80)
        XCTAssertNil(milestones.next(fraction: 1, now: start, isFront: true, isActive: true))
    }

    func testAMilestoneJumpsStraightToTheLatestValue() {
        var milestones = ToastProgressMilestones(step: 0.25, minimumInterval: 0)
        milestones.began(at: start, fraction: 0)

        XCTAssertEqual(milestones.next(fraction: 0.8, now: start, isFront: true, isActive: true), 80)
    }

    func testMilestonesAreSpacedByTheMinimumInterval() {
        var milestones = ToastProgressMilestones(step: 0.25, minimumInterval: 5)
        milestones.began(at: start, fraction: 0)

        XCTAssertNil(
            milestones.next(fraction: 0.3, now: start.addingTimeInterval(2), isFront: true, isActive: true),
            "too soon after the start"
        )
        XCTAssertEqual(
            milestones.next(fraction: 0.32, now: start.addingTimeInterval(5), isFront: true, isActive: true),
            32,
            "folded: the held-back step announces the value it has now"
        )
        XCTAssertNil(milestones.next(fraction: 0.55, now: start.addingTimeInterval(7), isFront: true, isActive: true))
        XCTAssertEqual(
            milestones.next(fraction: 0.6, now: start.addingTimeInterval(10), isFront: true, isActive: true),
            60
        )
    }

    func testOnlyTheFrontCardSpeaks() {
        var milestones = ToastProgressMilestones(step: 0.25, minimumInterval: 0)
        milestones.began(at: start, fraction: 0)

        XCTAssertNil(milestones.next(fraction: 0.3, now: start, isFront: false, isActive: true))
        XCTAssertEqual(
            milestones.next(fraction: 0.35, now: start, isFront: true, isActive: true),
            35,
            "the step crossed while buried is folded into the next update"
        )
    }

    func testNothingIsSaidWhileTheAppIsInactive() {
        var milestones = ToastProgressMilestones(step: 0.25, minimumInterval: 0)
        milestones.began(at: start, fraction: 0)

        XCTAssertNil(milestones.next(fraction: 0.3, now: start, isFront: true, isActive: false))
        XCTAssertEqual(milestones.next(fraction: 0.3, now: start, isFront: true, isActive: true), 30)
    }

    func testABarThatGoesBackwardsMaySpeakAgain() {
        var milestones = ToastProgressMilestones(step: 0.25, minimumInterval: 0)
        milestones.began(at: start, fraction: 0)
        XCTAssertEqual(milestones.next(fraction: 0.6, now: start, isFront: true, isActive: true), 60)

        XCTAssertNil(milestones.next(fraction: 0.1, now: start, isFront: true, isActive: true))
        XCTAssertEqual(milestones.next(fraction: 0.3, now: start, isFront: true, isActive: true), 30)
    }

    func testStartingPartWayThroughDoesNotAnnounceTheStepAlreadyPast() {
        var milestones = ToastProgressMilestones(step: 0.25, minimumInterval: 0)
        milestones.began(at: start, fraction: 0.3)

        XCTAssertNil(milestones.next(fraction: 0.4, now: start, isFront: true, isActive: true))
        XCTAssertEqual(milestones.next(fraction: 0.5, now: start, isFront: true, isActive: true), 50)
    }

    func testIndeterminateWorkNeverHitsAMilestone() {
        var milestones = ToastProgressMilestones()
        XCTAssertNil(milestones.next(fraction: nil, now: start, isFront: true, isActive: true))
    }

    func testAbsurdStepsAreBounded() {
        var tiny = ToastProgressMilestones(step: 0, minimumInterval: 0)
        tiny.began(at: start, fraction: 0)
        XCTAssertEqual(tiny.next(fraction: 0.5, now: start, isFront: true, isActive: true), 50)

        var huge = ToastProgressMilestones(step: 50, minimumInterval: -3)
        huge.began(at: start, fraction: 0)
        XCTAssertNil(huge.next(fraction: 0.99, now: start, isFront: true, isActive: true), "one step is the whole bar")
    }

    // MARK: - Through the center

    func testStartingIsAnnounced() {
        let (center, _, handle) = make()

        XCTAssertEqual(center.progressAnnouncement?.text, ToastAnnouncement.progressStarted(title: "Uploading"))
        XCTAssertEqual(center.progressAnnouncement?.isUrgent, false)
        withExtendedLifetime(handle) {}
    }

    func testMilestonesAreAnnouncedAtMostEveryFiveSeconds() {
        let (center, scheduler, handle) = make()
        let started = center.progressAnnouncement

        handle.update(.fraction(0.3))
        XCTAssertEqual(center.progressAnnouncement, started, "the start was just spoken")

        scheduler.advance(6)
        handle.update(.fraction(0.31))
        XCTAssertEqual(center.progressAnnouncement?.text, ToastAnnouncement.progressMilestone(title: "Uploading", percent: 31))
        let spoken = center.progressAnnouncement

        scheduler.advance(1)
        handle.update(.fraction(0.55))
        XCTAssertEqual(center.progressAnnouncement, spoken)

        scheduler.advance(5)
        handle.update(.fraction(0.6))
        XCTAssertEqual(center.progressAnnouncement?.text, ToastAnnouncement.progressMilestone(title: "Uploading", percent: 60))
    }

    func testABuriedCardAnnouncesNoMilestones() {
        let (center, scheduler, handle) = make()
        center.present(.normal, title: "other")
        let before = center.progressAnnouncement

        scheduler.advance(10)
        handle.update(.fraction(0.5))

        XCTAssertEqual(center.progressAnnouncement, before)
    }

    func testAHiddenCardAnnouncesNoMilestones() {
        let (center, scheduler, handle) = make()
        center.dismiss(id: handle.id)
        let before = center.progressAnnouncement

        scheduler.advance(10)
        handle.update(.fraction(0.5))

        XCTAssertEqual(center.progressAnnouncement, before)
    }

    func testNothingIsAnnouncedWhileTheAppIsSuspended() {
        let (center, scheduler, handle) = make()
        center.setSuspended(true)
        let before = center.progressAnnouncement

        scheduler.advance(10)
        handle.update(.fraction(0.5))

        XCTAssertEqual(center.progressAnnouncement, before)
    }

    func testStartAndEndSkipsTheMilestones() {
        let (center, scheduler, handle) = make(announcements: .startAndEnd)
        XCTAssertEqual(center.progressAnnouncement?.text, ToastAnnouncement.progressStarted(title: "Uploading"))
        let started = center.progressAnnouncement

        scheduler.advance(30)
        handle.update(.fraction(0.5))
        XCTAssertEqual(center.progressAnnouncement, started)

        handle.succeed()
        XCTAssertEqual(center.progressAnnouncement?.text, ToastAnnouncement.progressSucceeded(title: "Uploading"))
    }

    func testNoneSaysNothingAtAll() {
        let (center, scheduler, handle) = make(announcements: .none)

        scheduler.advance(30)
        handle.update(.fraction(0.5))
        handle.fail()

        XCTAssertNil(center.progressAnnouncement)
    }

    func testAFailureIsUrgent() {
        let (center, _, handle) = make()

        handle.fail()

        XCTAssertEqual(center.progressAnnouncement?.text, ToastAnnouncement.progressFailed(title: "Uploading"))
        XCTAssertEqual(center.progressAnnouncement?.isUrgent, true)
    }

    func testASuccessIsNotUrgent() {
        let (center, _, handle) = make()

        handle.succeed()

        XCTAssertEqual(center.progressAnnouncement?.text, ToastAnnouncement.progressSucceeded(title: "Uploading"))
        XCTAssertEqual(center.progressAnnouncement?.isUrgent, false)
    }

    func testTheOutcomeNamesTheTitleItRanUnder() {
        let (center, _, handle) = make()

        handle.update(title: "Uploading 3 photos")
        handle.succeed(ToastProgressResult(title: "Uploaded"))

        XCTAssertEqual(
            center.progressAnnouncement?.text,
            ToastAnnouncement.progressSucceeded(title: "Uploading 3 photos")
        )
    }

    func testAVisibleCancelIsAnnouncedAndAHiddenOneIsNot() {
        let (center, _, handle) = make()
        handle.cancel()
        handle.finishCancelled()
        XCTAssertEqual(center.progressAnnouncement?.text, ToastAnnouncement.progressCancelled(title: "Uploading"))

        let (hiddenCenter, _, hidden) = make()
        hiddenCenter.dismiss(id: hidden.id)
        let before = hiddenCenter.progressAnnouncement
        hidden.cancel()
        hidden.finishCancelled()
        XCTAssertEqual(hiddenCenter.progressAnnouncement, before)
    }

    func testEveryLineGetsItsOwnSerial() {
        let (center, _, handle) = make()
        let first = center.progressAnnouncement?.serial

        handle.fail()

        XCTAssertNotNil(first)
        XCTAssertNotEqual(center.progressAnnouncement?.serial, first)
    }

    func testAnInPlaceOutcomeTriggersTheHapticAndAnArrivalDoesNot() {
        let (center, _, handle) = make()
        XCTAssertNil(center.progressOutcome)

        handle.succeed()
        XCTAssertEqual(center.progressOutcome?.status, .normal)
        let serial = center.progressOutcome?.serial

        let (failing, _, other) = make()
        other.fail()
        XCTAssertEqual(failing.progressOutcome?.status, .error)
        XCTAssertNotNil(serial)
    }
}

/// Every key the progress toast adds has a translation, with the same placeholders.
final class ToastProgressLocalisationTests: XCTestCase {

    private let languages = ["en", "ja", "zh-Hans", "zh-Hant"]

    private let keys = [
        "toast.action.hide",
        "toast.action.cancel",
        "toast.progress.cancelling",
        "toast.progress.confirmCancel",
        "toast.progress.retry",
        "toast.progress.inProgress",
        "toast.progress.done",
        "toast.progress.failed",
        "toast.progress.cancelled",
        "toast.progress.bytes %@ %@",
        "toast.progress.items %lld %lld",
        "toast.a11y.progress.started %@",
        "toast.a11y.progress.milestone %@ %lld",
        "toast.a11y.progress.succeeded %@",
        "toast.a11y.progress.failed %@",
        "toast.a11y.progress.cancelled %@"
    ]

    private func table(for language: String) throws -> Bundle {
        let path = try XCTUnwrap(Bundle.module.path(forResource: language, ofType: "lproj"), language)
        return try XCTUnwrap(Bundle(path: path), language)
    }

    private func placeholders(in text: String) -> [String] {
        var found: [String] = []
        var index = text.startIndex
        while let percent = text[index...].firstIndex(of: "%") {
            let rest = text[text.index(after: percent)...]
            let spec = rest.prefix { $0.isNumber || $0 == "$" || $0 == "@" || $0 == "l" || $0 == "d" }
            found.append(String(spec))
            index = text.index(after: percent)
        }
        return found.sorted()
    }

    func testEveryKeyIsTranslatedInEveryLanguage() throws {
        for language in languages {
            let bundle = try table(for: language)
            for key in keys {
                let value = bundle.localizedString(forKey: key, value: "MISSING", table: nil)
                XCTAssertNotEqual(value, "MISSING", "\(language) lacks \(key)")
            }
        }
    }

    func testTranslationsKeepTheEnglishPlaceholders() throws {
        let english = try table(for: "en")
        for language in languages where language != "en" {
            let bundle = try table(for: language)
            for key in keys where key.contains("%") {
                let expected = placeholders(in: english.localizedString(forKey: key, value: nil, table: nil))
                let actual = placeholders(in: bundle.localizedString(forKey: key, value: nil, table: nil))
                XCTAssertEqual(actual, expected, "\(language) changes the placeholders of \(key)")
            }
        }
    }

    func testTheAnnouncementsResolve() {
        let lines = [
            ToastAnnouncement.progressStarted(title: "Photos"),
            ToastAnnouncement.progressMilestone(title: "Photos", percent: 50),
            ToastAnnouncement.progressSucceeded(title: "Photos"),
            ToastAnnouncement.progressFailed(title: "Photos"),
            ToastAnnouncement.progressCancelled(title: "Photos")
        ]
        for line in lines {
            XCTAssertTrue(line.contains("Photos"), line)
            XCTAssertFalse(line.contains("toast.a11y"), "the string table must resolve: \(line)")
        }
        XCTAssertTrue(ToastAnnouncement.progressMilestone(title: "Photos", percent: 50).contains("50"))
    }

    func testTheBuiltInActionsAreNamed() {
        XCTAssertFalse(ToastAction.hideProgress.title.contains("toast.action"))
        XCTAssertFalse(ToastAction.cancelProgress.title.contains("toast.action"))
    }
}
