import Foundation
import Observation

/// Where a handle reaches its center. A class of its own so the handle's `deinit`, which
/// is not main-actor isolated, can hold on to the center without touching main-actor state.
///
/// Written once, on the main actor, when the handle is made; read only on the main actor.
final class ToastProgressLink: @unchecked Sendable {
    weak var center: ToastCenter?

    init(center: ToastCenter) {
        self.center = center
    }
}

/// The app's grip on one progress toast.
///
/// ```swift
/// let handle = toasts.track(title: "Syncing")
/// handle.update(.fraction(0.4))
/// handle.succeed()
/// ```
///
/// A handle reports a toast's progress and outcome, and mirrors its state for the app to
/// read. It can be observed. Make exactly one outcome call — ``succeed(_:)``,
/// ``fail(_:retry:)`` or a cancel — and calls after the first outcome are ignored.
///
/// A handle that is released before an outcome, from ``ToastCenter/track(id:title:message:icon:progress:group:options:onCancel:)``
/// alone, is *abandoned*: its work is cancelled through the cancel route if there is one
/// and its card is removed. Debug builds print a warning. Keep the handle for as long as
/// the work runs.
@MainActor
@Observable
public final class ToastProgressHandle: Identifiable {

    public nonisolated let id: UUID

    /// Names the run this handle belongs to. A handle from an earlier run of the same id
    /// is stale, and the center ignores what it says.
    nonisolated let serial: Int

    private nonisolated let link: ToastProgressLink

    /// Where the work is. While it runs, the payload is the latest progress.
    public internal(set) var phase: ToastProgressPhase

    /// True once Cancel was requested by the user, by code, or by cancelling the calling
    /// task.
    public internal(set) var isCancellationRequested = false

    /// False while the card is hidden: swiped away, dismissed or pushed out by newer
    /// toasts. The work continues.
    public internal(set) var isVisible = true

    init(id: UUID, serial: Int, center: ToastCenter, phase: ToastProgressPhase) {
        self.id = id
        self.serial = serial
        self.link = ToastProgressLink(center: center)
        self.phase = phase
    }

    deinit {
        // Touches nothing main-actor isolated: the identifiers and the link are
        // `nonisolated let`s. The center decides on the main actor whether this was an
        // abandonment.
        let link = link
        let id = id
        let serial = serial
        Task { @MainActor in
            link.center?.abandonProgress(id: id, serial: serial)
        }
    }

    // MARK: - Reporting

    /// Shows `progress`. Ignored once the work has an outcome, or while cancelling.
    public func update(_ progress: ToastProgress) {
        link.center?.applyProgress(id: id, serial: serial, value: progress)
    }

    /// Shows a bar at `fraction`, or an indeterminate one for `nil`.
    public func update(fraction: Double?) {
        update(ToastProgress(fraction: fraction))
    }

    /// Changes the words on the card, for something like "Waiting for network…". A `nil`
    /// argument leaves that line alone; pass `.some(nil)` as `message` to remove it.
    public func update(title: String? = nil, message: String?? = nil) {
        link.center?.applyCopy(id: id, serial: serial, title: title, message: message)
    }

    // MARK: - Outcomes

    /// The work finished. The card turns into the result where it stands.
    public func succeed(_ result: ToastProgressResult = ToastProgressResult()) {
        link.center?.finishProgress(id: id, serial: serial, succeeding: result)
    }

    /// The work failed. The card turns into an error where it stands, with Retry when a
    /// `retry` closure is given.
    ///
    /// Tapping Retry runs `retry`, then removes the card unless the same id was tracked
    /// again by then. Start the new run synchronously, or in a `Task` created inside the
    /// closure, passing the same `id` to ``ToastCenter/track(id:title:message:icon:progress:group:options:onCancel:)``
    /// or ``ToastCenter/withProgress(id:title:message:icon:group:cancellable:success:failure:onRetry:options:operation:)``.
    public func fail(_ result: ToastProgressResult = ToastProgressResult(), retry: (@MainActor () -> Void)? = nil) {
        link.center?.finishProgress(id: id, serial: serial, failing: result, retry: retry)
    }

    /// Asks the work to stop, the same way the Cancel button does. The card shows
    /// "Cancelling…" until the work ends.
    public func cancel() {
        link.center?.requestCancel(id: id, serial: serial)
    }

    /// Reports that the work has stopped after a cancel. Needed only when the cancel route
    /// is a bare `onCancel` closure: cancelling a task given to ``cancels(_:)`` finishes
    /// by itself.
    public func finishCancelled() {
        link.center?.finishProgressCancelled(id: id, serial: serial)
    }

    /// Makes Cancel (the button, ``cancel()`` or abandonment) cancel `task`, and finishes
    /// the cancel when the task ends.
    public func cancels<Success: Sendable, Failure: Error>(_ task: Task<Success, Failure>) {
        guard let center = link.center else { return }
        let id = id
        let serial = serial
        center.setCancelRoute(id: id, serial: serial) { task.cancel() }
        Task { @MainActor [weak center] in
            _ = await task.result
            center?.progressTaskEnded(id: id, serial: serial)
        }
    }
}
