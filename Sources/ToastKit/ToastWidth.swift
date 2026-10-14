import CoreGraphics
import Foundation

/// How wide toast cards are drawn.
///
/// Measured against the width *available inside the safe area*, not the raw screen: on
/// a landscape iPhone or a split-screen iPad those differ by a lot, and a card that
/// spilled under the notch or the home indicator would be unreadable at exactly the
/// moment it matters. `fraction(1)` therefore means "as wide as the safe area allows",
/// which is the documented maximum — a `points` value larger than that is clamped down
/// rather than allowed to overflow.
///
/// Foundation-only so `ToastWidthTests` can exercise the clamping without a view host.
public enum ToastWidth: Equatable {

    /// A share of the available width, clamped to `0...1`.
    case fraction(Double)

    /// A fixed point width, clamped to the available width.
    case points(CGFloat)

    /// Wide enough to hold two lines of message text comfortably, narrow enough that the
    /// card still reads as an overlay rather than a bar.
    public static let `default` = ToastWidth.fraction(0.6)

    /// Resolves to a concrete width. Returns `0` for a non-positive container, which is
    /// what SwiftUI hands out for a frame it has not measured yet.
    ///
    /// Very small values are honoured rather than floored: clamping up would silently
    /// override a deliberate choice, and a card too narrow for its content is a mistake
    /// better seen than hidden.
    public func resolved(in available: CGFloat) -> CGFloat {
        guard available > 0 else { return 0 }
        switch self {
        case .fraction(let value):
            guard value.isFinite else { return available }
            return available * CGFloat(min(max(value, 0), 1))
        case .points(let value):
            guard value.isFinite else { return available }
            return min(max(value, 0), available)
        }
    }
}
