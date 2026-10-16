import CoreGraphics
import Foundation

/// Which end of the action track.
enum ToastTrackSide: Equatable {
    case leading
    case trailing
}

extension ToastSwipeActions {
    func action(for side: ToastTrackSide) -> ToastAction? {
        side == .leading ? leading : trailing
    }
}

/// Where a long-pressed card sits and travels, and where its actions are drawn.
///
/// The track is one band across the stack's full width, bent gently toward the stack's
/// edge: an arc of radius 900 pt, the same curve as the quick swipe (y ≈ x² ÷ 1800). The
/// lifted card shrinks to half size and rides the band's centre line; each action's label
/// sits between the card and the side of the stack, in the band's upper half.
///
/// The finger that lifted the card stays where it pressed, below the band. Its tip
/// reaches about 31 pt above the point it touches, so on a bottom stack the card lifts
/// 44 pt and the labels ride 16 pt above the band's centre line: together, enough to keep
/// them clear of a thumb pressing the middle of the card.
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
    /// How far a lifted card on a bottom stack moves up off its resting place, clear of
    /// the thumb beneath it.
    static let bottomRise: CGFloat = 44
    /// How far a lifted card on a top stack moves down off its resting place. There is
    /// no room above a card hanging from the top edge, so it keeps a small offset.
    static let topRise: CGFloat = 7
    /// How far each action's label sits above the band's centre line, in its upper half,
    /// whichever edge the stack hangs from.
    static let labelLift: CGFloat = 16
    /// Travel along the track that arms an action.
    static let armDistance: CGFloat = 64
    /// How far the band runs past each side of the stack, so its ends leave the screen.
    static let bleed: CGFloat = 10
    static let labelGapToCard: CGFloat = 4
    static let labelGapToSide: CGFloat = 6

    /// Width of the card at rest.
    let cardWidth: CGFloat
    /// Width the stack draws in. The band spans all of it.
    let availableWidth: CGFloat
    /// +1 for a stack on the bottom edge, -1 for one on the top: the band always bends
    /// toward its own edge.
    let curve: CGFloat

    var bandWidth: CGFloat { availableWidth + 2 * Self.bleed }

    /// How far the lifted card moves off its resting place, away from the stack's edge.
    var rise: CGFloat { curve > 0 ? Self.bottomRise : Self.topRise }

    /// Vertical position of the band's crest inside the track view.
    var crestY: CGFloat { curve > 0 ? Self.crestInset : Self.height - Self.crestInset }

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

    /// Where an action's label sits at `x` from the centre, in track-view coordinates:
    /// above the band's centre line, away from the finger.
    func labelY(at x: CGFloat) -> CGFloat {
        bandY(at: x) - Self.labelLift
    }

    /// The direction of the band at `x`, in radians: what a card or label there turns by.
    func tilt(at x: CGFloat) -> Double {
        Double(curve) * asin(Double(max(-1, min(1, x / Self.radius))))
    }

    /// The lifted card's centre at `x`, relative to its resting centre.
    func cardOffset(at x: CGFloat) -> CGSize {
        CGSize(width: x, height: curve * (sag(at: x) - rise))
    }

    /// Vertical offset that puts the band's crest under the lifted card's centre when the
    /// track view is centred on the resting card.
    var trackOffset: CGFloat {
        -curve * rise - (crestY - Self.height / 2)
    }

    private var labelInner: CGFloat { cardWidth * Self.liftScale / 2 + Self.labelGapToCard }
    private var labelOuter: CGFloat { max(labelInner, availableWidth / 2 - Self.labelGapToSide) }

    /// Distance from the centre to the middle of each label.
    var labelCenter: CGFloat { (labelInner + labelOuter) / 2 }

    /// Room each label has between the lifted card and the side of the stack.
    var labelWidth: CGFloat { labelOuter - labelInner }

    /// Signed centre of a side's label: where the card drops when that action is chosen.
    func labelX(for side: ToastTrackSide) -> CGFloat {
        side == .leading ? -labelCenter : labelCenter
    }

    /// The furthest the card can be carried: just short of a label's middle.
    var carryLimit: CGFloat { max(Self.armDistance, labelCenter - 10) }

    /// Where the card sits for a finger `translation` from where it lifted. It does not
    /// travel toward an end that has no action.
    func carry(_ translation: CGFloat, leading: Bool, trailing: Bool) -> CGFloat {
        let lower = leading ? -carryLimit : 0
        let upper = trailing ? carryLimit : 0
        return min(max(translation, lower), upper)
    }

    /// The end the card is armed toward at `x`, once it has travelled far enough.
    func armedSide(at x: CGFloat) -> ToastTrackSide? {
        if x <= -Self.armDistance { return .leading }
        if x >= Self.armDistance { return .trailing }
        return nil
    }
}

/// The colour laid over each end of the band.
///
/// Strongest at the end and solid for part of the way in, then an eased fade to nothing
/// at the centre, so the two ends meet without a seam.
enum ToastTrackWash {

    /// An end's opacity at rest, when armed or chosen, and while the other end is armed.
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
