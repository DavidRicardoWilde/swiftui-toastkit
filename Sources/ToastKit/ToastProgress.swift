import Foundation

/// How far a piece of work has got. A plain value: send it from any thread.
///
/// ```swift
/// handle.update(.fraction(0.4))
/// handle.update(.bytes(12_000_000, of: 30_000_000))   // "12 MB of 30 MB", 40%
/// handle.update(.items(3, of: 10))                    // "3 of 10", 30%
/// handle.update(.indeterminate)                       // a sweeping bar, no number
/// ```
///
/// Foundation-only, like the rest of the model: the bar and the text are drawn by the
/// ``ToastStyle`` in effect.
public struct ToastProgress: Equatable, Sendable {

    /// What the unit counts measure, which decides how the detail line is worded.
    public enum Unit: Hashable, Sendable {
        /// No generated detail line; only ``subtitle`` is shown, if there is one.
        case none
        /// A byte count, written the way the system writes file sizes.
        case bytes
        /// A count of things, such as "3 of 10".
        case items
    }

    /// 0...1, clamped. `nil` means indeterminate.
    public var fraction: Double?

    /// Units done so far. `nil` when not known.
    public var completedUnitCount: Int64?

    /// Units expected. `nil` when the total is unknown.
    public var totalUnitCount: Int64?

    public var unit: Unit

    /// Replaces the generated detail line ("12 MB of 30 MB"). `nil` keeps the generated one.
    public var subtitle: String?

    public init(
        fraction: Double? = nil,
        completedUnitCount: Int64? = nil,
        totalUnitCount: Int64? = nil,
        unit: Unit = .none,
        subtitle: String? = nil
    ) {
        if let fraction, fraction.isFinite {
            self.fraction = min(1, max(0, fraction))
        } else {
            self.fraction = nil
        }
        self.completedUnitCount = completedUnitCount
        self.totalUnitCount = totalUnitCount
        self.unit = unit
        self.subtitle = subtitle
    }

    /// Work of unknown length: a sweeping bar and no number.
    public static let indeterminate = ToastProgress()

    /// A fraction of the whole, such as `0.4` for 40%.
    public static func fraction(_ value: Double, subtitle: String? = nil) -> ToastProgress {
        ToastProgress(fraction: value, subtitle: subtitle)
    }

    /// Bytes done out of `total`. The fraction follows when `total` is known and positive;
    /// otherwise the bar is indeterminate and the detail line shows only what is done.
    public static func bytes(_ completed: Int64, of total: Int64?) -> ToastProgress {
        counted(completed, of: total, unit: .bytes)
    }

    /// Things done out of `total`, such as "3 of 10".
    public static func items(_ completed: Int64, of total: Int64?) -> ToastProgress {
        counted(completed, of: total, unit: .items)
    }

    private static func counted(_ completed: Int64, of total: Int64?, unit: Unit) -> ToastProgress {
        let done = max(0, completed)
        guard let total, total > 0 else {
            return ToastProgress(completedUnitCount: done, unit: unit)
        }
        return ToastProgress(
            fraction: Double(done) / Double(total),
            completedUnitCount: done,
            totalUnitCount: total,
            unit: unit
        )
    }

    /// True when there is no fraction to show.
    public var isIndeterminate: Bool { fraction == nil }

    /// The detail line a style shows: ``subtitle``, or the text generated from the unit
    /// counts. `nil` when there is nothing to say.
    ///
    /// - Parameter locale: How numbers and sizes are written.
    public func detailText(locale: Locale = .current) -> String? {
        if let subtitle, !subtitle.isEmpty { return subtitle }
        guard let completed = completedUnitCount else { return nil }
        switch unit {
        case .none:
            return nil
        case .bytes:
            let done = completed.formatted(.byteCount(style: .file).locale(locale))
            guard let total = totalUnitCount, total > 0 else { return done }
            let whole = total.formatted(.byteCount(style: .file).locale(locale))
            return String(localized: "toast.progress.bytes \(done) \(whole)", bundle: .module, locale: locale)
        case .items:
            guard let total = totalUnitCount, total > 0 else {
                return completed.formatted(.number.locale(locale))
            }
            // `Int` interpolates as `%lld`, which is what the string table's key spells out.
            let done = Int(clamping: completed)
            let whole = Int(clamping: total)
            return String(localized: "toast.progress.items \(done) \(whole)", bundle: .module, locale: locale)
        }
    }

    /// The fraction written as a whole percent, such as "42%". `nil` when indeterminate.
    func percentText(locale: Locale = .current) -> String? {
        guard let fraction else { return nil }
        return fraction.formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }

    /// The fraction as a whole number of percent. Only a full bar reads 100.
    var percentValue: Int? {
        fraction.map { $0 >= 1 ? 100 : min(99, Int(($0 * 100).rounded())) }
    }
}

/// Where a progress toast is in its life.
///
/// The `running` payload is a snapshot taken when the phase changes, or when the bar
/// switches between indeterminate and determinate. Ticks do not rewrite it, so the stack
/// is not redrawn for every update; read the live value from
/// ``ToastProgressHandle/phase`` or ``ToastProgressConfiguration/value``.
public enum ToastProgressPhase: Equatable, Sendable {
    /// Work is under way.
    case running(ToastProgress)
    /// Cancel was requested; waiting for the work to stop.
    case cancelling
    /// The work finished.
    case succeeded
    /// The work failed.
    case failed
    /// The work was cancelled and the card is showing the result.
    case cancelled

    /// True while the work is going on: running or cancelling. An active card is never
    /// timed, and dismissing it hides it rather than ending the work.
    var isActive: Bool {
        switch self {
        case .running, .cancelling: true
        case .succeeded, .failed, .cancelled: false
        }
    }

    /// True while the work runs and has not been asked to stop.
    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }
}
