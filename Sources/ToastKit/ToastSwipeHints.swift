import SwiftUI

/// When a toast shows what swiping it will do.
///
/// A toast with swipe actions can be lifted onto a track that lays both actions out at its
/// ends — icon, title and subtitle — so the user reads them before letting go. This
/// setting decides what lifts it: a hold, or the swipe itself.
///
/// ```swift
/// MyScreen()
///     .toasts(toasts)
///     .toastSwipeHints(.immediate)
/// ```
///
/// Whichever is set, VoiceOver offers both actions by name, and a card outside a
/// ``ToastStack`` (which has no room for a track) swipes as with ``afterHold``.
public enum ToastSwipeHints: Equatable, Sendable {

    /// A swipe acts straight away: past 88 pt, or on a flick, the card flies off and runs
    /// that side's action. Pressing and holding for about half a second lifts the card
    /// onto the track first. The default.
    case afterHold

    /// The card lifts onto the track as soon as it moves 8 pt, so both actions show from
    /// the first moment of a swipe. Carried 64 pt toward an end, or flicked toward it, the
    /// card runs that end's action when let go; anywhere short of that it settles back.
    /// Pressing and holding still lifts it too.
    case immediate
}

// MARK: - Environment

private struct ToastSwipeHintsKey: EnvironmentKey {
    static let defaultValue = ToastSwipeHints.afterHold
}

public extension EnvironmentValues {
    /// When toasts below this point show their swipe actions. ``ToastSwipeHints/afterHold``
    /// unless set with `toastSwipeHints(_:)`.
    var toastSwipeHints: ToastSwipeHints {
        get { self[ToastSwipeHintsKey.self] }
        set { self[ToastSwipeHintsKey.self] = newValue }
    }
}

public extension View {
    /// Sets when toasts below this point show what swiping them will do.
    ///
    /// ```swift
    /// MyScreen()
    ///     .toasts(toasts)
    ///     .toastSwipeHints(.immediate)    // the track appears as the card starts to move
    /// ```
    func toastSwipeHints(_ hints: ToastSwipeHints) -> some View {
        environment(\.toastSwipeHints, hints)
    }
}
