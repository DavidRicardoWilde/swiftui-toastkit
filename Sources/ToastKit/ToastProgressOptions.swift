import Foundation

/// What a progress toast turns into when the work ends. Anything left `nil` takes the
/// kit's default for that outcome.
///
/// ```swift
/// handle.succeed(ToastProgressResult(title: "Uploaded", message: "3 photos"))
/// handle.fail(ToastProgressResult(message: "No connection"), retry: { upload() })
/// ```
public struct ToastProgressResult: Equatable {
    /// `nil` uses "Done" after success and "Couldn't finish" after failure.
    public var title: String?
    public var message: String?
    /// `nil` uses a checkmark after success and the error symbol after failure.
    public var icon: ToastIcon?
    /// `nil` uses ``ToastProgressOptions/successDuration`` or
    /// ``ToastProgressOptions/failureDuration``.
    public var duration: ToastDuration?
    /// What tapping the finished card does.
    public var tapAction: ToastAction?

    public init(
        title: String? = nil,
        message: String? = nil,
        icon: ToastIcon? = nil,
        duration: ToastDuration? = nil,
        tapAction: ToastAction? = nil
    ) {
        self.title = title
        self.message = message
        self.icon = icon
        self.duration = duration
        self.tapAction = tapAction
    }
}

/// Who decides that a tracked Foundation `Progress` has succeeded.
public enum ToastProgressCompletion: Equatable {
    /// Succeed when `Progress.isFinished`, cancel when `Progress.isCancelled`. A handle
    /// that is discarded is normal here: the kit keeps watching the `Progress` itself.
    case automatic(success: ToastProgressResult)
    /// The app calls ``ToastProgressHandle/succeed(_:)`` or
    /// ``ToastProgressHandle/fail(_:retry:)``. Use it when a server reply arrives after the
    /// last byte is sent.
    case manual
}

/// How a progress toast behaves around the edges.
///
/// ```swift
/// var options = ToastProgressOptions()
/// options.failureDuration = .indefinite
/// options.confirmsCancel = true
/// toasts.track(title: "Uploading", options: options)
/// ```
public struct ToastProgressOptions: Equatable {

    /// What happens when work ends while its card is hidden.
    public enum ResultWhenHidden: Equatable, Sendable {
        /// Show the result as a new arrival, success or failure.
        case always
        /// Show a failure as a new arrival and let a success pass silently. The default,
        /// because a failure may need the user, and a success never does.
        case failureOnly
        /// Never bring a hidden card back.
        case never
    }

    /// What VoiceOver is told while the work runs.
    public enum Announcements: Equatable, Sendable {
        /// The start, each `step` of the way, and the outcome. Milestones are at least
        /// `minimumInterval` seconds apart, and only the front card announces them.
        case milestones(step: Double, minimumInterval: TimeInterval)
        /// The start and the outcome only.
        case startAndEnd
        /// Nothing.
        case none
    }

    /// How long a success stays up once it is topmost.
    public var successDuration: ToastDuration

    /// How long a failure stays up once it is topmost. Eight seconds by default, long
    /// enough to reach Retry; use ``ToastDuration/indefinite`` to require acknowledgement.
    public var failureDuration: ToastDuration

    public var resultWhenHidden: ResultWhenHidden

    public var announcements: Announcements

    /// Seconds a cancel may take before the card gives up waiting and finishes as
    /// cancelled anyway, so it cannot hang. Measured on the center's clock.
    public var cancellationGrace: TimeInterval

    /// Shows a short "Cancelled" card after a cancel instead of just removing the card.
    public var showsCancelledResult: Bool

    /// Asks for a second tap within three seconds before Cancel takes effect. The button
    /// reads "Tap again to cancel" in between. VoiceOver's Cancel action never asks.
    public var confirmsCancel: Bool

    /// What swiping the card does while the work runs. ``ToastSwipeActions/progress``,
    /// which hides the card, by default.
    public var swipeActions: ToastSwipeActions

    public init(
        successDuration: ToastDuration = .automatic,
        failureDuration: ToastDuration = .seconds(8),
        resultWhenHidden: ResultWhenHidden = .failureOnly,
        announcements: Announcements = .milestones(step: 0.25, minimumInterval: 5),
        cancellationGrace: TimeInterval = 10,
        showsCancelledResult: Bool = false,
        confirmsCancel: Bool = false,
        swipeActions: ToastSwipeActions = .progress
    ) {
        self.successDuration = successDuration
        self.failureDuration = failureDuration
        self.resultWhenHidden = resultWhenHidden
        self.announcements = announcements
        self.cancellationGrace = cancellationGrace
        self.showsCancelledResult = showsCancelledResult
        self.confirmsCancel = confirmsCancel
        self.swipeActions = swipeActions
    }

    /// The defaults above. Computed: it holds actions, which carry closures.
    public static var `default`: ToastProgressOptions {
        ToastProgressOptions()
    }
}

extension ToastProgressOptions.Announcements {
    /// True for ``none``. Spelled out because comparing with `.none` reads as `Optional.none`.
    var isSilent: Bool {
        if case .none = self { return true }
        return false
    }
}
