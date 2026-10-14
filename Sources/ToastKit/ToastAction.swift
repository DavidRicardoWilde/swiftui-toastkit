import Foundation

/// Something the user can do with a toast: tap it, swipe it, or carry it along the
/// long-press track into an end.
///
/// An action says what it *is* — its words, icon and role — and what happens to the
/// toast afterwards (``Effect``). Its ``handler`` does the work. Every action also
/// reaches any `onToastAction` observer above the stack, so an app can handle actions
/// in one place by ``id`` instead of, or as well as, in closures.
///
/// ```swift
/// // The defaults, as a swipe would offer them.
/// ToastSwipeActions(leading: .delete, trailing: .later)
///
/// // Your own words, icon and work.
/// ToastAction(
///     id: "archive",
///     title: "Archive",
///     subtitle: "Keeps a copy",
///     icon: .system("archivebox"),
///     confirmation: "Archived"
/// ) { toast in
///     store.archive(toast.id)
/// }
/// ```
///
/// Foundation-only, like ``ToastMessage``: the role picks a colour through the style's
/// theme (``ToastTheme/actionTint``), so a call site never paints an action, and the
/// same kind of action looks the same everywhere.
public struct ToastAction: Identifiable {

    /// What kind of action this is. Drives the colour of its end of the track and the
    /// haptic played when it is chosen.
    public enum Role: String, CaseIterable, Equatable {
        /// Removes something. Red by default.
        case destructive
        /// An ordinary follow-up, such as coming back later. Indigo by default.
        case standard
        /// A quiet way out, such as hiding the toast. Graphite by default.
        case subdued
    }

    /// What happens to the toast once the action has run.
    public enum Effect: Equatable {
        /// The toast is removed for good. The default.
        case dismiss
        /// The toast is set aside and comes back the next time its stack appears — in
        /// practice, the next time the user opens the page it lives on. See
        /// ``ToastCenter/postpone(id:)``.
        case postpone
    }

    /// Stable identity for handling the action by name. Defaults to the title.
    public var id: String
    /// The action's name. Shown on the long-press track and read by VoiceOver. Keep it
    /// short: at the default size there is room for about "Remind me later".
    public var title: String
    /// A second, smaller line under the title on the track, such as "Next visit".
    public var subtitle: String?
    /// Drawn before the title on the track.
    public var icon: ToastIcon?
    /// Shown in place of the title once the action is chosen on the track, such as
    /// "Deleted".
    public var confirmation: String?
    public var role: Role
    public var effect: Effect
    /// Runs when the action is chosen, before the toast is dismissed or postponed. It
    /// receives the toast the action was chosen on.
    public var handler: (@MainActor (ToastMessage) -> Void)?

    public init(
        id: String? = nil,
        title: String,
        subtitle: String? = nil,
        icon: ToastIcon? = nil,
        confirmation: String? = nil,
        role: Role = .standard,
        effect: Effect = .dismiss,
        handler: (@MainActor (ToastMessage) -> Void)? = nil
    ) {
        self.id = id ?? title
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.confirmation = confirmation
        self.role = role
        self.effect = effect
        self.handler = handler
    }
}

extension ToastAction: Equatable {
    /// Compares what an action shows and what it does to the toast. Handlers are
    /// closures, which cannot be compared, so two actions differing only in their
    /// handler are equal.
    public static func == (lhs: ToastAction, rhs: ToastAction) -> Bool {
        lhs.id == rhs.id
            && lhs.title == rhs.title
            && lhs.subtitle == rhs.subtitle
            && lhs.icon == rhs.icon
            && lhs.confirmation == rhs.confirmation
            && lhs.role == rhs.role
            && lhs.effect == rhs.effect
    }
}

// MARK: - Built-in actions

public extension ToastAction {

    /// ``id`` of the built-in ``delete`` action.
    static let deleteID = "toastkit.delete"
    /// ``id`` of the built-in ``later`` action.
    static let laterID = "toastkit.later"
    /// ``id`` of the action a stack-level `onTap` runs as.
    static let tapID = "toastkit.tap"

    /// Removes the toast. The default leading swipe — to the left, in a left-to-right
    /// layout.
    static var delete: ToastAction {
        delete(title: nil)
    }

    /// ``delete`` with your own words, icon or work. Anything left `nil` keeps the
    /// built-in value.
    static func delete(
        title: String? = nil,
        subtitle: String? = nil,
        icon: ToastIcon? = nil,
        confirmation: String? = nil,
        handler: (@MainActor (ToastMessage) -> Void)? = nil
    ) -> ToastAction {
        ToastAction(
            id: deleteID,
            title: title ?? String(localized: "toast.action.delete", bundle: .module),
            subtitle: subtitle,
            icon: icon ?? .system("trash"),
            confirmation: confirmation ?? String(localized: "toast.action.delete.done", bundle: .module),
            role: .destructive,
            effect: .dismiss,
            handler: handler
        )
    }

    /// Sets the toast aside until its page is next opened. The default trailing swipe —
    /// to the right, in a left-to-right layout.
    static var later: ToastAction {
        later(title: nil)
    }

    /// ``later`` with your own words, icon or work. Anything left `nil` keeps the
    /// built-in value.
    static func later(
        title: String? = nil,
        subtitle: String? = nil,
        icon: ToastIcon? = nil,
        confirmation: String? = nil,
        handler: (@MainActor (ToastMessage) -> Void)? = nil
    ) -> ToastAction {
        ToastAction(
            id: laterID,
            title: title ?? String(localized: "toast.action.later", bundle: .module),
            subtitle: subtitle ?? String(localized: "toast.action.later.subtitle", bundle: .module),
            icon: icon ?? .system("clock.arrow.circlepath"),
            confirmation: confirmation ?? String(localized: "toast.action.later.done", bundle: .module),
            role: .standard,
            effect: .postpone,
            handler: handler
        )
    }
}

// MARK: - Swipe actions

/// The two things a toast can be swiped into, one toward each side.
///
/// A quick swipe runs an action at once. Pressing and holding first lifts the card onto
/// a track with both actions drawn at its ends — icon, title and subtitle — so the user
/// can see what each way does before letting go.
///
/// By default every toast offers ``ToastAction/delete`` on the leading side and
/// ``ToastAction/later`` on the trailing side. Replace either, or pass `nil` to make that
/// direction do nothing:
///
/// ```swift
/// ToastSwipeActions()                                       // delete ← → later
/// ToastSwipeActions(trailing: .later(title: "Snooze"))      // reworded
/// ToastSwipeActions(leading: .delete, trailing: nil)        // one way only
/// ToastSwipeActions.disabled                                // no swiping
/// ```
///
/// `leading` is the left side and `trailing` the right in a left-to-right layout.
/// Right-to-left mirroring has not been verified yet.
public struct ToastSwipeActions: Equatable {
    /// Run by swiping toward the leading side.
    public var leading: ToastAction?
    /// Run by swiping toward the trailing side.
    public var trailing: ToastAction?

    public init(leading: ToastAction? = .delete, trailing: ToastAction? = .later) {
        self.leading = leading
        self.trailing = trailing
    }

    /// Delete one way, later the other. What every toast offers unless told otherwise.
    public static var standard: ToastSwipeActions {
        ToastSwipeActions()
    }

    /// Neither way does anything, and a long press is inert. The toast leaves when its
    /// countdown ends, when it is tapped, or from code.
    public static var disabled: ToastSwipeActions {
        ToastSwipeActions(leading: nil, trailing: nil)
    }

    /// True when there is nothing to swipe into.
    public var isEmpty: Bool { leading == nil && trailing == nil }
}
