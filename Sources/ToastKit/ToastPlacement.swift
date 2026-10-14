import SwiftUI

/// Where on the screen a stack of toasts appears.
///
/// ```swift
/// MyScreen().toasts(toasts)                       // .bottom, the default
/// MyScreen().toasts(toasts, placement: .top)
/// ```
///
/// A stack hangs from its edge: the newest card sits closest to it and older ones recede
/// inward. At the bottom it sits above whatever the safe area already covers — a tab bar,
/// a tab bar's accessory, the home indicator — and lifts itself above anything marked
/// with `toastObstruction()`. See `README.md`, "Placement".
///
/// A struct rather than an enum so further positions can be added without breaking a
/// `switch` in anyone's code.
public struct ToastPlacement: Hashable, Sendable {

    enum Anchor: Hashable, Sendable {
        case top
        case bottom
    }

    let anchor: Anchor

    /// Hangs from the top of the safe area, below any navigation bar.
    public static let top = ToastPlacement(anchor: .top)

    /// Sits on the bottom of the safe area, above a tab bar and its accessory. The
    /// default.
    public static let bottom = ToastPlacement(anchor: .bottom)

    var alignment: Alignment { anchor == .top ? .top : .bottom }
    /// Scale anchor, so a shrinking card keeps its anchored edge pinned.
    var unitPoint: UnitPoint { anchor == .top ? .top : .bottom }
    var transitionEdge: Edge { anchor == .top ? .top : .bottom }
    /// The side padding is applied to when the stack keeps clear of something.
    var paddingEdge: Edge.Set { anchor == .top ? .top : .bottom }
    /// Sign applied to the per-depth peek offset.
    var peekSign: CGFloat { anchor == .top ? 1 : -1 }
    /// +1 when the stack's edge is below it, -1 when above: the swipe's curve and the
    /// long-press track both bend toward the edge.
    var curve: CGFloat { anchor == .bottom ? 1 : -1 }
}
