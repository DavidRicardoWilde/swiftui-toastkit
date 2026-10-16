import CoreGraphics

/// How a quick swipe picks its axis, follows the finger and where it lands.
///
/// Foundation-only so `ToastSwipeTests` can pin the thresholds without a view host.
enum ToastSwipe {

    /// Travel past which letting go runs that side's action rather than springing back.
    static let commitDistance: CGFloat = 88
    /// Flick velocity, as projected travel, that commits even on a short drag.
    static let flickDistance: CGFloat = 220
    /// Toward a side with no action, the card gives this share of the finger's travel…
    static let resistance: CGFloat = 0.18
    /// …and never more than this, so it reads as "not this way" instead of moving.
    static let maxResisted: CGFloat = 24

    /// The axis a swipe moves along, settled by its first movement: with actions on one
    /// axis only, that one; with both, the way the finger went further. A toast with no
    /// actions at all swipes sideways, and only gives a little.
    static func axis(for translation: CGSize, actions: ToastSwipeActions) -> ToastSwipeAxis {
        let horizontal = actions.hasActions(along: .horizontal)
        let vertical = actions.hasActions(along: .vertical)
        if horizontal != vertical { return vertical ? .vertical : .horizontal }
        guard horizontal else { return .horizontal }
        return abs(translation.height) > abs(translation.width) ? .vertical : .horizontal
    }

    /// Where the card sits along `axis` for a finger `translation` along it.
    static func follow(_ translation: CGFloat, along axis: ToastSwipeAxis, actions: ToastSwipeActions) -> CGFloat {
        let side = translation < 0 ? axis.negative : axis.positive
        if actions.action(for: side) != nil {
            return translation
        }
        return min(max(translation * resistance, -maxResisted), maxResisted)
    }

    /// The side a released swipe runs, or `nil` to spring back.
    ///
    /// The direction comes from the gesture's own travel, not its projection, so a flick
    /// that overshoots and reverses still goes the way it was thrown.
    static func commit(
        travel: CGFloat,
        projected: CGFloat,
        along axis: ToastSwipeAxis,
        actions: ToastSwipeActions
    ) -> ToastTrackSide? {
        guard abs(travel) >= commitDistance || abs(projected) >= flickDistance else { return nil }
        let towardNegative = travel == 0 ? projected < 0 : travel < 0
        let side = towardNegative ? axis.negative : axis.positive
        return actions.action(for: side) == nil ? nil : side
    }

    /// The side a card that a swipe lifted onto the track runs when let go: the end it is
    /// armed toward, or, short of that, the side it was flicked toward. `nil` puts it back.
    static func release(
        armed: ToastTrackSide?,
        travel: CGFloat,
        projected: CGFloat,
        along axis: ToastSwipeAxis,
        actions: ToastSwipeActions
    ) -> ToastTrackSide? {
        armed ?? commit(travel: travel, projected: projected, along: axis, actions: actions)
    }
}
