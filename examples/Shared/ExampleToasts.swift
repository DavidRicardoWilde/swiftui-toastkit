import SwiftUI
import ToastKit

/// Which ways the example toasts swipe.
enum ExampleSwipes: String, CaseIterable, Identifiable {
    case sideways
    case upAndDown
    case fourWays
    case none

    var id: Self { self }

    var title: String {
        switch self {
        case .sideways: "Left and right"
        case .upAndDown: "Up and down"
        case .fourWays: "All four ways"
        case .none: "No swiping"
        }
    }

    var actions: ToastSwipeActions {
        switch self {
        case .sideways:
            .standard
        case .upAndDown:
            .vertical(up: ExampleToasts.pin, down: .delete)
        case .fourWays:
            ToastSwipeActions(leading: .delete, trailing: .later, up: ExampleToasts.pin, down: ExampleToasts.archive)
        case .none:
            .disabled
        }
    }
}

/// The toasts every example presents, so each app only has to lay them out.
enum ExampleToasts {

    /// An action of the example's own. Like every action, it reaches `onToastAction`,
    /// where the example logs it.
    static var pin: ToastAction {
        ToastAction(
            id: "pin",
            title: "Pin",
            subtitle: "Keep it handy",
            icon: .system("pin"),
            confirmation: "Pinned"
        )
    }

    static var archive: ToastAction {
        ToastAction(
            id: "archive",
            title: "Archive",
            icon: .system("archivebox"),
            confirmation: "Archived",
            role: .subdued
        )
    }

    /// A sample toast for `status`, numbered so the stack's order is easy to follow.
    static func message(
        _ status: ToastMessage.Status,
        swipes: ExampleSwipes,
        number: Int,
        staysUntilDismissed: Bool
    ) -> ToastMessage {
        let copy: (title: String, message: String) = switch status {
        case .normal: ("Changes saved", "Your draft is safe.")
        case .warning: ("Storage almost full", "Free up space to keep syncing.")
        case .error: ("Sync failed", "Check your connection and try again.")
        case .notification: ("New photos", "12 photos from today.")
        }
        return ToastMessage(
            status: status,
            title: "\(copy.title) #\(number)",
            message: copy.message,
            duration: staysUntilDismissed ? .indefinite : .automatic,
            swipeActions: swipes.actions
        )
    }
}

extension ToastMessage.Status {
    var title: String {
        switch self {
        case .normal: "Normal"
        case .warning: "Warning"
        case .error: "Error"
        case .notification: "Notification"
        }
    }
}
