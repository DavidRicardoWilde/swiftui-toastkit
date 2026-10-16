import CoreGraphics
import XCTest
@testable import ToastKit

/// The long-press track's numbers, pinned without a view host: a 90%-wide card on a
/// 390 pt stack, a typical phone layout.
final class ToastTrackGeometryTests: XCTestCase {

    private func geometry(curve: CGFloat = 1) -> ToastTrackGeometry {
        ToastTrackGeometry(cardWidth: 351, availableWidth: 390, curve: curve)
    }

    // MARK: - The curve

    func testBandIsFlatAtTheCrestAndBendsEvenlyBothWays() {
        let track = geometry()
        XCTAssertEqual(track.sag(at: 0), 0)
        XCTAssertEqual(track.sag(at: 130), track.sag(at: -130))
        // The quick-swipe curve: about x² ÷ 1800, so roughly 9.4 pt at 130 pt out.
        XCTAssertEqual(track.sag(at: 130), 9.44, accuracy: 0.01)
    }

    func testBandBendsTowardTheStacksEdge() {
        let bottom = geometry(curve: 1)
        let top = geometry(curve: -1)
        XCTAssertGreaterThan(bottom.bandY(at: 150), bottom.bandY(at: 0), "down toward a bottom edge")
        XCTAssertLessThan(top.bandY(at: 150), top.bandY(at: 0), "up toward a top edge")
    }

    // MARK: - The lifted card

    func testLiftedCardOnABottomStackRisesClearOfTheThumb() {
        let offset = geometry(curve: 1).cardOffset(at: 0)
        XCTAssertEqual(offset.width, 0)
        XCTAssertEqual(offset.height, -44)
    }

    func testLiftedCardOnATopStackKeepsItsSmallOffset() {
        // No room above a card hanging from the top edge: it moves 7 pt down, as before.
        XCTAssertEqual(geometry(curve: -1).cardOffset(at: 0).height, 7)
    }

    func testCarriedCardFollowsTheBandAndTurnsWithIt() {
        let bottom = geometry(curve: 1)
        let top = geometry(curve: -1)
        XCTAssertEqual(bottom.cardOffset(at: 80).height, bottom.sag(at: 80) - 44, accuracy: 0.0001)
        XCTAssertEqual(top.cardOffset(at: 80).height, -(top.sag(at: 80) - 7), accuracy: 0.0001)
        XCTAssertEqual(bottom.tilt(at: 90), asin(0.1), accuracy: 0.0001)
        XCTAssertEqual(top.tilt(at: 90), -asin(0.1), accuracy: 0.0001)
        XCTAssertEqual(bottom.tilt(at: 0), 0)
    }

    func testTrackCrestSitsUnderTheLiftedCard() {
        // The track view is centred on the resting card; the offset moves its crest to
        // the lifted card's centre: 44 pt up on a bottom stack, 7 pt down on a top one.
        for track in [geometry(curve: 1), geometry(curve: -1)] {
            let crest = track.crestY - ToastTrackGeometry.height / 2 + track.trackOffset
            XCTAssertEqual(crest, track.cardOffset(at: 0).height, accuracy: 0.0001)
        }
        XCTAssertEqual(geometry(curve: 1).trackOffset, -31)
        XCTAssertEqual(geometry(curve: -1).trackOffset, -6)
    }

    func testTheBandIsWideEnoughToCarryItsLabelsAboveTheFinger() {
        XCTAssertEqual(ToastTrackGeometry.bandThickness, 72)
        // A two-line label, about 30 pt tall, fits in the band's upper half.
        XCTAssertLessThanOrEqual(ToastTrackGeometry.labelLift + 15, ToastTrackGeometry.bandThickness / 2)
        // Room in the track view for the band on either side of its crest.
        XCTAssertGreaterThanOrEqual(ToastTrackGeometry.crestInset, ToastTrackGeometry.bandThickness / 2)
    }

    func testLabelsRideAboveTheBandsCentreLineOnEitherEdge() {
        for track in [geometry(curve: 1), geometry(curve: -1)] {
            XCTAssertEqual(track.labelY(at: 0), track.bandY(at: 0) - 16)
            XCTAssertEqual(track.labelY(at: 140), track.bandY(at: 140) - 16, accuracy: 0.0001)
        }
    }

    func testLabelsOnABottomStackClearAThumbPressingTheMiddleOfTheCard() {
        // A thumb's tip reaches about 31 pt above where it touches. Pressing the card's
        // middle, a two-line label's lower edge (15 pt below its centre) must sit above it.
        let track = geometry(curve: 1)
        let x = track.labelCenter
        let labelCenter = track.labelY(at: x) - ToastTrackGeometry.height / 2 + track.trackOffset
        XCTAssertLessThanOrEqual(labelCenter + 15, -31)
    }

    // MARK: - Labels and carrying

    func testLabelsSitBetweenTheLiftedCardAndTheSide() {
        let track = geometry()
        // Card edge at 87.75 + 4 pt; side at 195 − 6 pt.
        XCTAssertEqual(track.labelCenter, 140.375, accuracy: 0.0001)
        XCTAssertEqual(track.labelWidth, 97.25, accuracy: 0.0001)
        XCTAssertEqual(track.labelX(for: .leading), -140.375, accuracy: 0.0001)
        XCTAssertEqual(track.labelX(for: .trailing), 140.375, accuracy: 0.0001)
    }

    func testCarryStopsShortOfTheLabelAndOnlyTowardActions() {
        let track = geometry()
        XCTAssertEqual(track.carry(-40, leading: true, trailing: true), -40)
        XCTAssertEqual(track.carry(500, leading: true, trailing: true), 130.375, accuracy: 0.0001)
        XCTAssertEqual(track.carry(-500, leading: false, trailing: true), 0, "no action, no travel")
        XCTAssertEqual(track.carry(500, leading: true, trailing: false), 0)
    }

    func testAnActionArmsAfterSixtyFourPoints() {
        let track = geometry()
        XCTAssertNil(track.armedSide(at: 63))
        XCTAssertNil(track.armedSide(at: -63))
        XCTAssertEqual(track.armedSide(at: -64), .leading)
        XCTAssertEqual(track.armedSide(at: 64), .trailing)
    }

    func testANarrowCardStillLeavesTheArmingDistanceToCarry() {
        // A watch-sized stack: the labels' middle is closer than 74 pt, yet the card must
        // still be able to travel far enough to arm.
        let tight = ToastTrackGeometry(cardWidth: 184, availableWidth: 184, curve: 1)
        XCTAssertLessThan(tight.labelCenter - 10, ToastTrackGeometry.armDistance)
        XCTAssertEqual(tight.carryLimit, ToastTrackGeometry.armDistance)
        XCTAssertGreaterThanOrEqual(tight.labelWidth, 0)
    }

    // MARK: - The colour wash

    func testWashIsSolidThenFadesToNothingAtTheCentre() {
        let stops = ToastTrackWash.leadingStops(fadeStart: 1.0 / 3.0)
        XCTAssertEqual(stops.first?.location, 0)
        XCTAssertEqual(stops.first?.strength, 1)
        XCTAssertEqual(stops[1].location, 1.0 / 6.0, accuracy: 0.0001, "solid a third of the way to the centre")
        XCTAssertEqual(stops[1].strength, 1)
        XCTAssertEqual(stops.last?.location, 0.5)
        XCTAssertEqual(stops.last?.strength, 0, "nothing at the centre, so the two ends meet without a seam")
        for (earlier, later) in zip(stops, stops.dropFirst()) {
            XCTAssertLessThanOrEqual(earlier.location, later.location)
            XCTAssertGreaterThanOrEqual(earlier.strength, later.strength)
        }
    }

    func testFadeStartMovesWhereTheColourStopsBeingSolid() {
        XCTAssertEqual(ToastTrackWash.leadingStops(fadeStart: 1.0 / 2.0)[1].location, 0.25, accuracy: 0.0001)
        XCTAssertEqual(ToastTrackWash.leadingStops(fadeStart: 1.0 / 4.0)[1].location, 0.125, accuracy: 0.0001)
    }
}

final class ToastActionTests: XCTestCase {

    func testActionIdDefaultsToItsTitle() {
        XCTAssertEqual(ToastAction(title: "Archive").id, "Archive")
        XCTAssertEqual(ToastAction(id: "archive", title: "Archive").id, "archive")
    }

    func testCustomActionsDismissUnlessToldOtherwise() {
        XCTAssertEqual(ToastAction(title: "Archive").effect, .dismiss)
        XCTAssertEqual(ToastAction(title: "Snooze", effect: .postpone).effect, .postpone)
    }

    func testEveryToastSwipesToDeleteAndLaterByDefault() {
        let swipes = ToastMessage(title: "plain").swipeActions
        XCTAssertEqual(swipes, .standard)
        XCTAssertEqual(swipes.leading?.id, ToastAction.deleteID)
        XCTAssertEqual(swipes.trailing?.id, ToastAction.laterID)
        XCTAssertNil(ToastMessage(title: "plain").tapAction, "taps pass through unless asked for")
    }

    func testDeleteRemovesTheToastAndLaterPostponesIt() {
        XCTAssertEqual(ToastAction.delete.role, .destructive)
        XCTAssertEqual(ToastAction.delete.effect, .dismiss)
        XCTAssertEqual(ToastAction.delete.icon, .system("trash"))
        XCTAssertNotNil(ToastAction.delete.confirmation)

        XCTAssertEqual(ToastAction.later.role, .standard)
        XCTAssertEqual(ToastAction.later.effect, .postpone)
        XCTAssertNotNil(ToastAction.later.subtitle)
        XCTAssertNotNil(ToastAction.later.icon)
    }

    func testBuiltInActionsTakeYourWordsAndKeepTheirBehaviour() {
        let snooze = ToastAction.later(title: "Snooze", subtitle: "Until tomorrow", icon: .system("moon"))
        XCTAssertEqual(snooze.id, ToastAction.laterID)
        XCTAssertEqual(snooze.title, "Snooze")
        XCTAssertEqual(snooze.subtitle, "Until tomorrow")
        XCTAssertEqual(snooze.icon, .system("moon"))
        XCTAssertEqual(snooze.effect, .postpone)

        let remove = ToastAction.delete(title: "Remove")
        XCTAssertEqual(remove.title, "Remove")
        XCTAssertEqual(remove.icon, ToastAction.delete.icon, "unset parts keep the built-in value")
    }

    func testOneSideCanBeReplacedOrTurnedOff() {
        let custom = ToastSwipeActions(trailing: ToastAction(title: "Pin"))
        XCTAssertEqual(custom.leading, .delete, "the other side keeps its default")
        XCTAssertEqual(custom.trailing?.title, "Pin")

        let oneWay = ToastSwipeActions(leading: .delete, trailing: nil)
        XCTAssertNil(oneWay.trailing)
        XCTAssertFalse(oneWay.isEmpty)
        XCTAssertTrue(ToastSwipeActions.disabled.isEmpty)
    }

    func testHandlersDoNotTakePartInEquality() {
        let quiet = ToastAction(id: "undo", title: "Undo")
        let busy = ToastAction(id: "undo", title: "Undo") { _ in }
        XCTAssertEqual(quiet, busy)
        XCTAssertNotEqual(quiet, ToastAction(id: "undo", title: "Undo", role: .destructive))
    }
}
