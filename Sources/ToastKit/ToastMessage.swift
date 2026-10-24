import Foundation

/// One notification in a ``ToastCenter`` stack.
///
/// A toast is data: what it says, how long it stays, and what tapping or swiping it
/// does. How it looks belongs to the ``ToastStyle`` in effect, so the same message reads
/// right in any app that adopts the kit.
///
/// ```swift
/// ToastMessage(title: "Saved")
///
/// ToastMessage(
///     status: .warning,
///     title: "Low storage",
///     message: "Free up space to keep syncing.",
///     icon: .system("externaldrive.badge.exclamationmark"),
///     duration: 8,
///     tapAction: ToastAction(title: "Manage storage") { _ in router.open(.storage) },
///     swipeActions: ToastSwipeActions(trailing: .later(title: "Remind me"))
/// )
///
/// // A group lets related toasts be dismissed together.
/// ToastMessage(title: "Uploading…", group: "upload")
/// ```
///
/// Foundation-only on purpose: the stack's timing rules live in ``ToastCenter`` and are
/// unit-tested without a SwiftUI host.
public struct ToastMessage: Identifiable, Equatable {

    /// Semantic role. The default style derives the card's whole colour scheme from it —
    /// surface wash, edge, glyph, glow — plus the haptic played on arrival. Never spelled
    /// out as a colour at the call site, so the same kind of notice looks the same
    /// everywhere.
    public enum Status: String, CaseIterable, Equatable {
        /// Nothing is wrong and nothing is urgent. Neutral, no hue.
        case normal
        /// Something the user should look at but that has not failed.
        case warning
        /// Something failed.
        case error
        /// An announcement worth surfacing on its own. Carries the app's accent.
        case notification
    }

    /// Identity within the stack. Presenting an id already shown moves that toast to
    /// the front instead of adding a second card, so a repeated notice refreshes.
    public let id: UUID
    public var status: Status
    public var title: String
    /// Optional second line. Keep it short; the default style clamps it to two lines.
    public var message: String?
    /// Replaces the status's own symbol. `nil` uses the status symbol.
    public var icon: ToastIcon?
    /// How long the toast stays up once it is topmost.
    public var duration: ToastDuration
    /// Runs when the card is tapped. `nil` falls back to the stack's `onTap`, if any;
    /// with neither, taps pass through to the content behind.
    public var tapAction: ToastAction?
    /// What swiping toward each side does. Delete one way and later the other, unless
    /// told otherwise.
    public var swipeActions: ToastSwipeActions
    /// A caller-defined kind, so related toasts can be dismissed together with
    /// ``ToastCenter/dismiss(group:removal:scope:)``. `nil` for a toast that belongs to
    /// none. Presenting a toast never replaces another in the same group.
    public var group: ToastGroup?

    public init(
        id: UUID = UUID(),
        status: Status = .normal,
        title: String,
        message: String? = nil,
        icon: ToastIcon? = nil,
        duration: ToastDuration = .automatic,
        tapAction: ToastAction? = nil,
        swipeActions: ToastSwipeActions = .standard
    ) {
        self.id = id
        self.status = status
        self.title = title
        self.message = message
        self.icon = icon
        self.duration = duration
        self.tapAction = tapAction
        self.swipeActions = swipeActions
        self.group = nil
    }

    /// Creates a toast that belongs to `group`. `group` is required here so that the
    /// original initialiser above keeps its exact signature.
    public init(
        id: UUID = UUID(),
        status: Status = .normal,
        title: String,
        message: String? = nil,
        icon: ToastIcon? = nil,
        duration: ToastDuration = .automatic,
        tapAction: ToastAction? = nil,
        swipeActions: ToastSwipeActions = .standard,
        group: ToastGroup?
    ) {
        self.init(
            id: id,
            status: status,
            title: title,
            message: message,
            icon: icon,
            duration: duration,
            tapAction: tapAction,
            swipeActions: swipeActions
        )
        self.group = group
    }
}
