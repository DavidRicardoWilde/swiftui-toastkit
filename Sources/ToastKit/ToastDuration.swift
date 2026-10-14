import Foundation

/// How long a toast stays up once it is the topmost card.
///
/// The countdown only runs for the card in front, and it pauses while a finger is on the
/// stack or the app is in the background — see ``ToastCenter``. A duration therefore
/// means "seconds of being seen", not seconds since the toast was presented.
///
/// Number literals work, so `duration: 6` reads as six seconds:
///
/// ```swift
/// ToastMessage(title: "Saved")                          // .automatic: the center's default
/// ToastMessage(title: "Copied", duration: 2)            // two seconds
/// ToastMessage(title: "Sync failed", duration: .indefinite)
/// ```
public enum ToastDuration: Equatable, Sendable {

    /// The presenting center's ``ToastCenter/defaultDuration``. The default.
    case automatic

    /// A fixed number of seconds. Zero or less behaves like ``indefinite``, so the
    /// long-standing `duration: 0` still means "until dismissed".
    case seconds(TimeInterval)

    /// No countdown: the toast stays until the user acts on it or code dismisses it.
    /// Right for a failure the user has to acknowledge.
    case indefinite

    /// Four seconds: long enough to read two lines without rushing, short enough not to
    /// linger. What a ``ToastCenter`` uses for ``automatic`` unless told otherwise.
    public static let defaultSeconds: TimeInterval = 4

    /// The countdown in seconds, or `nil` when the toast waits to be dismissed.
    ///
    /// - Parameter defaultSeconds: What ``automatic`` stands for. Zero or less makes
    ///   automatic toasts wait too.
    public func resolved(defaultSeconds: TimeInterval) -> TimeInterval? {
        let seconds: TimeInterval
        switch self {
        case .automatic: seconds = defaultSeconds
        case .seconds(let value): seconds = value
        case .indefinite: return nil
        }
        return seconds.isFinite && seconds > 0 ? seconds : nil
    }
}

extension ToastDuration: ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral {
    public init(integerLiteral value: Int) {
        self = .seconds(TimeInterval(value))
    }

    public init(floatLiteral value: Double) {
        self = .seconds(value)
    }
}
