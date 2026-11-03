import Foundation

/// How a card leaves when code removes it.
///
/// ```swift
/// toasts.dismissAll(removal: .trail())                  // staggered, toward the edge
/// toasts.dismiss(group: "upload", removal: .slide(.trailing))
/// ```
///
/// ``fade`` is the default and what every removal looked like before this type existed.
/// With Reduce Motion on, every removal is a cross-fade and all departing cards fade
/// together. A card the user swipes away, or one they choose an action for, keeps its
/// own exit whatever is asked for here.
public struct ToastRemoval: Hashable, Sendable {

    enum Kind: Hashable, Sendable {
        case fade
        case slide
        case trail
    }

    let kind: Kind
    let direction: ToastRemovalDirection

    private init(kind: Kind, direction: ToastRemovalDirection) {
        self.kind = kind
        self.direction = direction
    }

    /// The card dissolves where it stands. The default; a direction does not apply.
    public static let fade = ToastRemoval(kind: .fade, direction: .inPlace)

    /// The card slides off in `direction` while fading, all departing cards together.
    public static func slide(_ direction: ToastRemovalDirection = .towardAnchor) -> ToastRemoval {
        ToastRemoval(kind: .slide, direction: direction)
    }

    /// The card winds up slightly, then leaves in `direction`, shrinking and blurring,
    /// front card first with the others following a beat behind. The whole batch takes
    /// well under a second however many cards there are.
    public static func trail(_ direction: ToastRemovalDirection = .towardAnchor) -> ToastRemoval {
        ToastRemoval(kind: .trail, direction: direction)
    }
}
