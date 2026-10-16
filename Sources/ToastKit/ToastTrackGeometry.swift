import CoreGraphics
import Foundation

/// Which way a card is swiped or carried: an end of the horizontal track or of the
/// vertical one.
enum ToastTrackSide: Equatable, CaseIterable {
    case leading
    case trailing
    case up
    case down

    var axis: ToastSwipeAxis {
        self == .leading || self == .trailing ? .horizontal : .vertical
    }

    /// -1 toward the leading side or up, +1 toward the trailing side or down.
    var sign: CGFloat {
        self == .leading || self == .up ? -1 : 1
    }
}

/// The two ways a toast can be swiped.
enum ToastSwipeAxis: Equatable {
    case horizontal
    case vertical

    /// The end toward negative coordinates: leading, or up.
    var negative: ToastTrackSide { self == .horizontal ? .leading : .up }
    /// The end toward positive coordinates: trailing, or down.
    var positive: ToastTrackSide { self == .horizontal ? .trailing : .down }

    /// The part of `size` that lies along this axis.
    func component(of size: CGSize) -> CGFloat {
        self == .horizontal ? size.width : size.height
    }
}

extension ToastSwipeActions {
    func action(for side: ToastTrackSide) -> ToastAction? {
        switch side {
        case .leading: leading
        case .trailing: trailing
        case .up: up
        case .down: down
        }
    }

    /// Whether either end of `axis` has an action.
    func hasActions(along axis: ToastSwipeAxis) -> Bool {
        action(for: axis.negative) != nil || action(for: axis.positive) != nil
    }
}

/// Where a long-pressed card sits and travels, and where its actions are drawn.
///
/// Left and right actions sit on one band across the stack's full width, bent gently
/// toward the stack's edge: an arc of radius 900 pt, the same curve as the quick swipe
/// (y ≈ x² ÷ 1800). The lifted card shrinks to half size and rides the band's centre line;
/// each action's label sits between the card and the side of the stack, in the half of
/// the band away from the stack's edge.
///
/// Up and down actions sit on a straight band through the lifted card. Their labels sit
/// beside its ends on the leading side, because the finger carrying the card is below it:
/// a label at the bottom end of the band would be under the finger on the way down.
///
/// The finger that lifted the card stays where it pressed. Its tip reaches about 31 pt
/// past the point it touches, so the card lifts 44 pt away from the stack's edge and the
/// horizontal labels ride 16 pt further: together, enough to keep them clear of a thumb
/// pressing the middle of the card. A stack on the top edge is the exact mirror of one on
/// the bottom: the band bends up, and the card drops 44 pt.
///
/// Foundation-only so `ToastTrackGeometryTests` can pin the numbers without a view host.
struct ToastTrackGeometry: Equatable {

    /// Radius of the arc the band and the card follow.
    static let radius: CGFloat = 900
    static let bandThickness: CGFloat = 72
    /// Height of the track view. The band's crest sits `crestInset` in from its
    /// away-from-edge side, which leaves room for the band to bend toward the edge.
    static let height: CGFloat = 114
    static let crestInset: CGFloat = 44
    /// Scale of a lifted card.
    static let liftScale: CGFloat = 0.5
    /// Scale a card shrinks to as it drops into the action it was let go on.
    static let commitScale: CGFloat = 0.12
    /// How far a lifted card moves off its resting place, away from the stack's edge:
    /// up from a bottom stack, down from a top one.
    static let rise: CGFloat = 44
    /// How far each horizontal label sits off the band's centre line, away from the
    /// stack's edge.
    static let labelLift: CGFloat = 16
    /// Travel along the track that arms an action.
    static let armDistance: CGFloat = 64
    /// How far the band runs past each side of the stack, so its ends leave the screen.
    static let bleed: CGFloat = 10
    static let labelGapToCard: CGFloat = 4
    static let labelGapToSide: CGFloat = 6

    /// How far the vertical band runs up and down from the lifted card's centre.
    static let verticalReach: CGFloat = 104
    /// Distance from the lifted card's centre to the middle of an up or down label.
    static let verticalLabelDistance: CGFloat = 80
    /// The furthest the card can be carried up or down: just past the arming point.
    static let verticalCarryLimit: CGFloat = 72

    /// Travel a carry needs before it settles on an axis, when both have actions.
    static let axisLock: CGFloat = 8
    /// How far the other axis must lead before a carry switches to it, so a diagonal
    /// drag does not flicker between the two.
    static let axisSwitchLead: CGFloat = 16

    /// Width of the card at rest.
    let cardWidth: CGFloat
    /// Width the stack draws in. The band spans all of it.
    let availableWidth: CGFloat
    /// +1 for a stack on the bottom edge, -1 for one on the top: the band always bends
    /// toward its own edge, and everything else mirrors with it.
    let curve: CGFloat

    var bandWidth: CGFloat { availableWidth + 2 * Self.bleed }

    /// Vertical position of the band's crest inside the track view.
    var crestY: CGFloat { curve > 0 ? Self.crestInset : Self.height - Self.crestInset }

    /// The lifted card's centre, before it is carried, relative to its resting centre.
    var liftedCenterY: CGFloat { -curve * Self.rise }

    /// How far the arc has bent away from its crest at `x` from the centre.
    func sag(at x: CGFloat) -> CGFloat {
        let r = Self.radius
        let reach = min(abs(x), r)
        return r - (r * r - reach * reach).squareRoot()
    }

    /// The band's centre line at `x` from the centre, in track-view coordinates.
    func bandY(at x: CGFloat) -> CGFloat {
        crestY + curve * sag(at: x)
    }

    /// Where a horizontal label sits at `x` from the centre, in track-view coordinates:
    /// off the band's centre line, away from the stack's edge.
    func labelY(at x: CGFloat) -> CGFloat {
        bandY(at: x) - curve * Self.labelLift
    }

    /// The direction of the band at `x`, in radians: what a card or label there turns by.
    func tilt(at x: CGFloat) -> Double {
        Double(curve) * asin(Double(max(-1, min(1, x / Self.radius))))
    }

    /// The lifted card's centre at `x` along the horizontal band, relative to its resting
    /// centre.
    func cardOffset(at x: CGFloat) -> CGSize {
        CGSize(width: x, height: curve * sag(at: x) + liftedCenterY)
    }

    /// The lifted card's centre `y` up or down the vertical band, relative to its resting
    /// centre.
    func cardOffset(vertically y: CGFloat) -> CGSize {
        CGSize(width: 0, height: liftedCenterY + y)
    }

    /// Vertical offset that puts the band's crest under the lifted card's centre when the
    /// track view is centred on the resting card.
    var trackOffset: CGFloat {
        liftedCenterY - (crestY - Self.height / 2)
    }

    private var labelInner: CGFloat { cardWidth * Self.liftScale / 2 + Self.labelGapToCard }
    private var labelOuter: CGFloat { max(labelInner, availableWidth / 2 - Self.labelGapToSide) }

    /// Distance from the centre to the middle of each label.
    var labelCenter: CGFloat { (labelInner + labelOuter) / 2 }

    /// Room each label has between the lifted card and the side of the stack.
    var labelWidth: CGFloat { labelOuter - labelInner }

    /// Signed centre of a horizontal side's label: where the card drops when that action
    /// is chosen.
    func labelX(for side: ToastTrackSide) -> CGFloat {
        side == .leading ? -labelCenter : labelCenter
    }

    /// Centre of the up and down labels across the stack: in the same room as the leading
    /// label, beside the vertical band rather than on it.
    var verticalLabelX: CGFloat { -labelCenter }

    /// Signed distance from the lifted card's centre to an up or down label, and where the
    /// card drops when that action is chosen.
    func verticalLabelY(for side: ToastTrackSide) -> CGFloat {
        side == .up ? -Self.verticalLabelDistance : Self.verticalLabelDistance
    }

    /// The furthest the card can be carried sideways: just short of a label's middle.
    var carryLimit: CGFloat { max(Self.armDistance, labelCenter - 10) }

    /// Where the card sits sideways for a finger `translation` from where it lifted. It
    /// does not travel toward an end that has no action.
    func carry(_ translation: CGFloat, leading: Bool, trailing: Bool) -> CGFloat {
        let lower = leading ? -carryLimit : 0
        let upper = trailing ? carryLimit : 0
        return min(max(translation, lower), upper)
    }

    /// Where the card sits up or down for a finger `translation` from where it lifted. It
    /// does not travel toward an end that has no action.
    func carryVertically(_ translation: CGFloat, up: Bool, down: Bool) -> CGFloat {
        let lower = up ? -Self.verticalCarryLimit : 0
        let upper = down ? Self.verticalCarryLimit : 0
        return min(max(translation, lower), upper)
    }

    /// The end the card is armed toward at `offset` along `axis`, once it has travelled
    /// far enough.
    func armedSide(at offset: CGFloat, along axis: ToastSwipeAxis = .horizontal) -> ToastTrackSide? {
        if offset <= -Self.armDistance { return axis.negative }
        if offset >= Self.armDistance { return axis.positive }
        return nil
    }

    /// The axis a lifted card is carried along for a finger `translation` from where it
    /// lifted, given the axis it is on now. With actions on one axis only, that one. With
    /// both, the way the finger has gone further, once it has moved `axisLock`; after that
    /// the other axis takes over only when it leads by `axisSwitchLead`. `nil` until then,
    /// and with no actions at all.
    static func carryAxis(
        for translation: CGSize,
        current: ToastSwipeAxis?,
        actions: ToastSwipeActions
    ) -> ToastSwipeAxis? {
        let horizontal = actions.hasActions(along: .horizontal)
        let vertical = actions.hasActions(along: .vertical)
        if horizontal != vertical { return vertical ? .vertical : .horizontal }
        guard horizontal else { return nil }
        let across = abs(translation.width)
        let upDown = abs(translation.height)
        switch current {
        case .horizontal:
            return upDown > across + axisSwitchLead ? .vertical : .horizontal
        case .vertical:
            return across > upDown + axisSwitchLead ? .horizontal : .vertical
        case nil:
            guard max(across, upDown) >= axisLock else { return nil }
            return upDown > across ? .vertical : .horizontal
        }
    }
}

/// The colour laid over each end of a band.
///
/// Strongest at the end and solid for part of the way in, then an eased fade to nothing
/// at the centre, so the two ends meet without a seam.
enum ToastTrackWash {

    /// An end's opacity at rest, when armed or chosen, and while another end is armed.
    static let restingStrength = 0.45
    static let armedStrength = 0.9
    static let dimmedStrength = 0.14

    /// Smoothstep from 1 down to 0, sampled finely enough that the fade has no kink.
    private static let ramp: [Double] = [1, 0.896, 0.648, 0.352, 0.104, 0]

    /// The leading end's stops, from its edge (location 0) to the centre (0.5). It is
    /// solid for `fadeStart` of the way in, then fades; the trailing end mirrors these
    /// about 0.5.
    static func leadingStops(fadeStart: Double) -> [(location: Double, strength: Double)] {
        let solidEnd = min(max(fadeStart, 0), 1) * 0.5
        let steps = Double(ramp.count - 1)
        var stops: [(location: Double, strength: Double)] = [(0, 1)]
        for (index, strength) in ramp.enumerated() {
            stops.append((solidEnd + (0.5 - solidEnd) * Double(index) / steps, strength))
        }
        return stops
    }
}
