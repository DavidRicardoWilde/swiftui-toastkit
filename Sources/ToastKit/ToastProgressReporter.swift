import Foundation

/// The mailbox between work on any thread and the main actor.
///
/// Writers store the latest value under a lock and schedule *one* main-actor delivery if
/// none is pending. A loop reporting ten thousand times a second therefore costs at most
/// one write to the center per main-actor turn, with no timer, and the last value always
/// lands. Delivery always hops, even from the main thread, so a call the kit makes itself
/// (cancelling a `Progress`, say) never re-enters the center.
final class ToastProgressInbox: @unchecked Sendable {

    enum Outcome: Equatable, Sendable {
        case finished
        case cancelled
    }

    /// Everything stored since the last delivery. `message` is doubly optional: the outer
    /// level says whether it changed, the inner one is the new value.
    struct Batch: Sendable {
        var progress: ToastProgress?
        var title: String?
        var message: String??
        var outcome: Outcome?
    }

    private let lock = NSLock()
    private var batch = Batch()
    private var hasData = false
    private var hopPending = false
    private var lastHopTask: Task<Void, Never>?
    private var isClosed = false
    private var tokens: [AnyObject] = []

    // Where deliveries go. Written once, by `bind`, on the main actor.
    private weak var center: ToastCenter?
    private var id = UUID()
    private var serial = 0
    private var isBound = false

    /// The most recent delivery, for tests to await.
    var lastHop: Task<Void, Never>? {
        locked { lastHopTask }
    }

    // MARK: - Writing

    func post(_ progress: ToastProgress) {
        locked {
            guard !isClosed else { return }
            batch.progress = progress
            noteData()
        }
    }

    func post(title: String?, message: String??) {
        locked {
            guard !isClosed else { return }
            if let title { batch.title = title }
            if let message { batch.message = message }
            noteData()
        }
    }

    func post(outcome: Outcome) {
        locked {
            guard !isClosed else { return }
            // A cancel wins over a finish that arrives in the same turn.
            if batch.outcome != .cancelled { batch.outcome = outcome }
            noteData()
        }
    }

    /// Keeps `token` alive for as long as the inbox is. Used for observations.
    func retain(_ token: AnyObject) {
        locked {
            if isClosed { return }
            tokens.append(token)
        }
    }

    // MARK: - Binding

    /// Points deliveries at a card. Anything posted before this is delivered now.
    @MainActor
    func bind(center: ToastCenter, id: UUID, serial: Int) {
        locked {
            self.center = center
            self.id = id
            self.serial = serial
            isBound = true
            if hasData { scheduleHop() }
        }
    }

    /// Stops observing and drops anything not yet delivered.
    func close() {
        let released: [AnyObject] = locked {
            isClosed = true
            batch = Batch()
            hasData = false
            defer { tokens = [] }
            return tokens
        }
        withExtendedLifetime(released) {}
    }

    // MARK: - Delivery

    /// Called with the lock held.
    private func noteData() {
        hasData = true
        if isBound { scheduleHop() }
    }

    /// Called with the lock held.
    private func scheduleHop() {
        guard !hopPending else { return }
        hopPending = true
        lastHopTask = Task { @MainActor [weak self] in
            self?.deliver()
        }
    }

    @MainActor
    private func deliver() {
        let delivery: (Batch, ToastCenter, UUID, Int)? = locked {
            hopPending = false
            guard !isClosed, hasData, let center else { return nil }
            let pending = batch
            batch = Batch()
            hasData = false
            return (pending, center, id, serial)
        }
        guard let (pending, center, id, serial) = delivery else { return }
        center.receive(pending, id: id, serial: serial)
    }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

/// Reports progress from the work itself. Sendable: call it from any isolation.
///
/// ```swift
/// try await toasts.withProgress(title: "Uploading") { report in
///     for try await sent in upload.bytesSent {
///         report(.bytes(sent, of: total))
///     }
/// }
/// ```
///
/// Updates coalesce: only the latest value of a burst reaches the card, so reporting as
/// often as the work likes costs the main actor next to nothing.
public struct ToastProgressReporter: Sendable {
    let inbox: ToastProgressInbox

    init(inbox: ToastProgressInbox) {
        self.inbox = inbox
    }

    /// Shows `progress`.
    public func callAsFunction(_ progress: ToastProgress) {
        inbox.post(progress)
    }

    /// Shows a bar at `fraction`, or an indeterminate one for `nil`.
    public func callAsFunction(fraction: Double?) {
        inbox.post(ToastProgress(fraction: fraction))
    }

    /// Changes the words on the card, for something like "Waiting for network…". A `nil`
    /// argument leaves that line alone; pass `.some(nil)` as `message` to remove it.
    public func update(title: String? = nil, message: String?? = nil) {
        inbox.post(title: title, message: message)
    }

    /// Adopts a `Progress`, such as `URLSessionTask.progress`, until it finishes. Its
    /// fraction and counts replace whatever was reported before. The card's outcome is
    /// still up to the operation.
    public func follow(_ progress: Progress) {
        inbox.follow(progress, reportsOutcome: false)
    }
}
