import CoreGraphics

/// How a quick swipe follows the finger and where it lands.
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

    /// Where the card sits for a finger `translation` from where the drag began.
    static func follow(_ translation: CGFloat, leading: Bool, trailing: Bool) -> CGFloat {
        if translation < 0 ? leading : trailing {
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
        leading: Bool,
        trailing: Bool
    ) -> ToastTrackSide? {
        guard abs(travel) >= commitDistance || abs(projected) >= flickDistance else { return nil }
        // TODO: Not verified on a right-to-left device or simulator. A leftward drag is
        // always treated as leading here and in ToastCard.flingOut; left unchanged on
        // purpose. Removal directions resolve leading/trailing by layoutDirection
        // independently.
        let towardLeading = travel == 0 ? projected < 0 : travel < 0
        if towardLeading {
            return leading ? .leading : nil
        }
        return trailing ? .trailing : nil
    }
}
