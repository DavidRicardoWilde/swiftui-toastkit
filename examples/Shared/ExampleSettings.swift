import SwiftUI
import ToastKit

/// What an example's controls set, the stack they present into, and what has happened
/// to its toasts.
@MainActor
@Observable
final class ExampleSettings {
    var status: ToastMessage.Status = .notification
    var swipes: ExampleSwipes = .sideways
    var staysUntilDismissed = false
    /// `toastSwipeHints(.immediate)` when on: the swipe itself shows the actions.
    var showsActionsAsSwipeStarts = true
    var placement: ToastPlacement = .bottom
    /// Share of the safe area's width each card takes.
    var widthFraction: Double

    /// Newest first.
    private(set) var log: [String] = []
    private var presented = 0

    let toasts = ToastCenter()

    init(widthFraction: Double = 0.6) {
        self.widthFraction = widthFraction
    }

    var hints: ToastSwipeHints {
        showsActionsAsSwipeStarts ? .immediate : .afterHold
    }

    var width: ToastWidth {
        .fraction(widthFraction)
    }

    func present() {
        presented += 1
        toasts.present(ExampleToasts.message(
            status,
            swipes: swipes,
            number: presented,
            staysUntilDismissed: staysUntilDismissed
        ))
    }

    /// Called from `onToastAction` for every tap, swipe and track choice.
    func record(_ action: ToastAction, on toast: ToastMessage) {
        log.insert("\(action.title): \(toast.title)", at: 0)
        if log.count > 30 { log.removeLast() }
    }
}
