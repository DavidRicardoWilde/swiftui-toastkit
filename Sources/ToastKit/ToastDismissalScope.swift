import Foundation

/// Which toasts a batch dismissal reaches.
public enum ToastDismissalScope: Sendable {
    /// Only the toasts in the stack — the ones showing or waiting behind the visible cards.
    case onScreen
    /// Only the toasts set aside by a postpone action. See ``ToastCenter/postponed``.
    case postponed
    /// Both.
    case everywhere

    var includesOnScreen: Bool { self != .postponed }
    var includesPostponed: Bool { self != .onScreen }
}
