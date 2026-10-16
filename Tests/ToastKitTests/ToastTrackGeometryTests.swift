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

    func testLiftedCardOnATopStackDropsTheSameDistance() {
        // A top stack is the mirror of a bottom one: the card moves 44 pt down.
        XCTAssertEqual(geometry(curve: -1).cardOffset(at: 0).height, 44)
    }

    func testCarriedCardFollowsTheBandAndTurnsWithIt() {
        let bottom = geometry(curve: 1)
        let top = geometry(curve: -1)
        XCTAssertEqual(bottom.cardOffset(at: 80).height, bottom.sag(at: 80) - 44, accuracy: 0.0001)
        XCTAssertEqual(top.cardOffset(at: 80).height, -(top.sag(at: 80) - 44), accuracy: 0.0001)
        XCTAssertEqual(bottom.tilt(at: 90), asin(0.1), accuracy: 0.0001)
        XCTAssertEqual(top.tilt(at: 90), -asin(0.1), accuracy: 0.0001)
        XCTAssertEqual(bottom.tilt(at: 0), 0)
    }

    func testTrackCrestSitsUnderTheLiftedCard() {
        // The track view is centred on the resting card; the offset moves its crest to
        // the lifted card's centre: 44 pt up on a bottom stack, 44 pt down on a top one.
        for track in [geometry(curve: 1), geometry(curve: -1)] {
            let crest = track.crestY - ToastTrackGeometry.height / 2 + track.trackOffset
            XCTAssertEqual(crest, track.cardOffset(at: 0).height, accuracy: 0.0001)
            XCTAssertEqual(track.liftedCenterY, track.cardOffset(at: 0).height)
        }
        XCTAssertEqual(geometry(curve: 1).trackOffset, -31)
        XCTAssertEqual(geometry(curve: -1).trackOffset, 31)
    }

    func testATopStackIsTheMirrorImageOfABottomOne() {
        let bottom = geometry(curve: 1)
        let top = geometry(curve: -1)
        for x: CGFloat in [-150, -64, 0, 90, 140] {
            XCTAssertEqual(top.cardOffset(at: x).height, -bottom.cardOffset(at: x).height, accuracy: 0.0001)
            XCTAssertEqual(top.tilt(at: x), -bottom.tilt(at: x), accuracy: 0.0001)
            // Measured from the resting card's centre, every label lands mirrored too.
            let bottomLabel = bottom.labelY(at: x) - ToastTrackGeometry.height / 2 + bottom.trackOffset
            let topLabel = top.labelY(at: x) - ToastTrackGeometry.height / 2 + top.trackOffset
            XCTAssertEqual(topLabel, -bottomLabel, accuracy: 0.0001)
        }
        XCTAssertEqual(top.cardOffset(vertically: 30).height, 44 + 30)
        XCTAssertEqual(bottom.cardOffset(vertically: -30).height, -44 - 30)
    }

    func testTheBandIsWideEnoughToCarryItsLabelsAboveTheFinger() {
        XCTAssertEqual(ToastTrackGeometry.bandThickness, 72)
        // A two-line label, about 30 pt tall, fits in the band's upper half.
        XCTAssertLessThanOrEqual(ToastTrackGeometry.labelLift + 15, ToastTrackGeometry.bandThickness / 2)
        // Room in the track view for the band on either side of its crest.
        XCTAssertGreaterThanOrEqual(ToastTrackGeometry.crestInset, ToastTrackGeometry.bandThickness / 2)
    }

    func testLabelsRideAwayFromTheStacksEdge() {
        let bottom = geometry(curve: 1)
        let top = geometry(curve: -1)
        XCTAssertEqual(bottom.labelY(at: 0), bottom.bandY(at: 0) - 16, "above the band's centre line")
        XCTAssertEqual(bottom.labelY(at: 140), bottom.bandY(at: 140) - 16, accuracy: 0.0001)
        XCTAssertEqual(top.labelY(at: 0), top.bandY(at: 0) + 16, "below it")
        XCTAssertEqual(top.labelY(at: 140), top.bandY(at: 140) + 16, accuracy: 0.0001)
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

    // MARK: - Up and down

    func testUpAndDownLabelsSitBesideTheVerticalBand() {
        let track = geometry()
        XCTAssertEqual(track.verticalLabelY(for: .up), -80)
        XCTAssertEqual(track.verticalLabelY(for: .down), 80)
        // In the leading label's room, so they clear the band and the card's path.
        XCTAssertEqual(track.verticalLabelX, -140.375, accuracy: 0.0001)
        XCTAssertGreaterThan(track.labelCenter - track.labelWidth / 2, ToastTrackGeometry.bandThickness / 2)
    }

    func testVerticalCarryStopsJustPastArmingAndOnlyTowardActions() {
        let track = geometry()
        XCTAssertEqual(track.carryVertically(-40, up: true, down: true), -40)
        XCTAssertEqual(track.carryVertically(500, up: true, down: true), 72)
        XCTAssertEqual(track.carryVertically(-500, up: false, down: true), 0, "no action, no travel")
        XCTAssertEqual(track.carryVertically(500, up: true, down: false), 0)
    }

    func testAnUpOrDownActionArmsAfterSixtyFourPoints() {
        let track = geometry()
        XCTAssertNil(track.armedSide(at: -63, along: .vertical))
        XCTAssertEqual(track.armedSide(at: -64, along: .vertical), .up)
        XCTAssertEqual(track.armedSide(at: 64, along: .vertical), .down)
    }

    func testACarryTakesTheOnlyAxisWithActionsStraightAway() {
        let sideways = ToastSwipeActions()
        let upDown = ToastSwipeActions.vertical(up: .later, down: .delete)
        XCTAssertEqual(ToastTrackGeometry.carryAxis(for: .zero, current: nil, actions: sideways), .horizontal)
        XCTAssertEqual(ToastTrackGeometry.carryAxis(for: .zero, current: nil, actions: upDown), .vertical)
        XCTAssertNil(ToastTrackGeometry.carryAxis(for: CGSize(width: 50, height: 0), current: nil, actions: .disabled))
    }

    func testWithBothAxesACarryWaitsThenFollowsTheFinger() {
        let fourWays = ToastSwipeActions(up: .later, down: .delete)
        XCTAssertNil(ToastTrackGeometry.carryAxis(for: CGSize(width: 5, height: 5), current: nil, actions: fourWays))
        XCTAssertEqual(
            ToastTrackGeometry.carryAxis(for: CGSize(width: 3, height: -9), current: nil, actions: fourWays),
            .vertical
        )
        XCTAssertEqual(
            ToastTrackGeometry.carryAxis(for: CGSize(width: -9, height: 3), current: nil, actions: fourWays),
            .horizontal
        )
    }

    func testACarrySwitchesAxisOnlyWhenTheOtherClearlyLeads() {
        let fourWays = ToastSwipeActions(up: .later, down: .delete)
        // A diagonal drag stays where it is…
        XCTAssertEqual(
            ToastTrackGeometry.carryAxis(for: CGSize(width: 40, height: 50), current: .horizontal, actions: fourWays),
            .horizontal
        )
        // …until the other way leads by more than 16 pt.
        XCTAssertEqual(
            ToastTrackGeometry.carryAxis(for: CGSize(width: 40, height: 57), current: .horizontal, actions: fourWays),
            .vertical
        )
        XCTAssertEqual(
            ToastTrackGeometry.carryAxis(for: CGSize(width: 57, height: -40), current: .vertical, actions: fourWays),
            .horizontal
        )
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

    func testUpAndDownAreOffUnlessAskedFor() {
        let standard = ToastSwipeActions.standard
        XCTAssertNil(standard.up)
        XCTAssertNil(standard.down)
        XCTAssertEqual(ToastSwipeActions.horizontal(), standard)
    }

    func testActionsCanGoUpAndDownOnlyOrAllFourWays() {
        let upDown = ToastSwipeActions.vertical(up: .later, down: .delete)
        XCTAssertNil(upDown.leading)
        XCTAssertNil(upDown.trailing)
        XCTAssertEqual(upDown.up, .later)
        XCTAssertEqual(upDown.down, .delete)
        XCTAssertFalse(upDown.isEmpty)
        XCTAssertFalse(upDown.hasActions(along: .horizontal))
        XCTAssertTrue(upDown.hasActions(along: .vertical))

        let fourWays = ToastSwipeActions(up: ToastAction(title: "Pin"), down: ToastAction(title: "Archive"))
        XCTAssertEqual(fourWays.leading, .delete)
        XCTAssertEqual(fourWays.trailing, .later)
        XCTAssertEqual(fourWays.action(for: .up)?.title, "Pin")
        XCTAssertEqual(fourWays.action(for: .down)?.title, "Archive")
        XCTAssertTrue(fourWays.hasActions(along: .horizontal))
        XCTAssertTrue(fourWays.hasActions(along: .vertical))
    }

    func testOneUpOrDownActionIsEnoughToSwipeThatWay() {
        let upOnly = ToastSwipeActions.vertical(up: .later, down: nil)
        XCTAssertFalse(upOnly.isEmpty)
        XCTAssertTrue(upOnly.hasActions(along: .vertical))
        XCTAssertTrue(ToastSwipeActions.vertical(up: nil, down: nil).isEmpty)
    }

    func testHandlersDoNotTakePartInEquality() {
        let quiet = ToastAction(id: "undo", title: "Undo")
        let busy = ToastAction(id: "undo", title: "Undo") { _ in }
        XCTAssertEqual(quiet, busy)
        XCTAssertNotEqual(quiet, ToastAction(id: "undo", title: "Undo", role: .destructive))
    }
}
