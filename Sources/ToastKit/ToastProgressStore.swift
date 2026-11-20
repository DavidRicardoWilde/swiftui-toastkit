import Foundation
import Observation

/// The live state of one progress card, observed on its own.
///
/// Ticks write here and nowhere else, so only the card that reads a cell redraws when its
/// value moves. Were the values in ``ToastCenter/toasts``, every tick would redraw and
/// re-animate the whole stack.
@Observable
final class ToastProgressCell {
    /// The latest progress, updated on every tick.
    var value: ToastProgress
    /// A way to cancel exists, so the card can offer Cancel.
    var canCancel = false
    /// A retry closure exists, so a failed card can offer Retry.
    var canRetry = false
    /// The first tap on Cancel only arms it. See ``ToastProgressOptions/confirmsCancel``.
    var confirmsCancel = false

    init(value: ToastProgress) {
        self.value = value
    }
}

/// The cells of the cards in a center, by toast id.
///
/// The dictionary changes only when a cell is added or removed, which is also when the
/// stack needs to look again.
@Observable
final class ToastProgressStore {
    private(set) var cells: [UUID: ToastProgressCell] = [:]

    func cell(for id: UUID, initial: ToastProgress) -> ToastProgressCell {
        if let existing = cells[id] { return existing }
        let cell = ToastProgressCell(value: initial)
        cells[id] = cell
        return cell
    }

    func remove(_ id: UUID) {
        guard cells[id] != nil else { return }
        cells[id] = nil
    }
}

/// Everything the center remembers about one tracked toast, kept while the work is active
/// and until a finished card has left.
///
/// Held by id in `ToastCenter.progressRecords`. The handle is referenced weakly, which is
/// what lets a released handle be noticed.
struct ToastProgressRecord {
    /// Names this run. A handle from an earlier run of the same id has a different one,
    /// and its calls are ignored.
    let serial: Int
    /// What the toast in the stack carries: refreshed on a phase change, not on a tick.
    var phase: ToastProgressPhase
    /// The latest progress.
    var progress: ToastProgress
    var options: ToastProgressOptions
    /// Set for a Foundation `Progress` that completes itself.
    var automaticSuccess: ToastProgressResult?
    /// A manual handle that is released unfinished takes its card with it.
    var abandonable: Bool
    var cancelRoute: (@MainActor () -> Void)?
    var retry: (@MainActor () -> Void)?
    var isRetrying = false
    var isCancellationRequested = false
    weak var handle: ToastProgressHandle?
    /// The card is out of the stack while the work goes on.
    var isHidden = false
    /// The toast as last drawn, for bringing a hidden card back.
    var lastMessage: ToastMessage
    var cancellingSince: Date?
    var milestones: ToastProgressMilestones
    var inbox: ToastProgressInbox?

    init(
        serial: Int,
        message: ToastMessage,
        progress: ToastProgress,
        options: ToastProgressOptions,
        abandonable: Bool,
        automaticSuccess: ToastProgressResult?,
        cancelRoute: (@MainActor () -> Void)?,
        inbox: ToastProgressInbox?
    ) {
        self.serial = serial
        self.phase = .running(progress)
        self.progress = progress
        self.options = options
        self.abandonable = abandonable
        self.automaticSuccess = automaticSuccess
        self.cancelRoute = cancelRoute
        self.lastMessage = message
        self.inbox = inbox
        switch options.announcements {
        case .milestones(let step, let interval):
            self.milestones = ToastProgressMilestones(step: step, minimumInterval: interval)
        case .startAndEnd, .none:
            self.milestones = ToastProgressMilestones()
        }
    }
}

/// A line for the stack to speak. The serial changes with every one, so two lines with the
/// same words are both spoken.
struct ToastProgressAnnouncement: Equatable {
    let text: String
    /// Failures cut in; everything else waits its turn.
    let isUrgent: Bool
    let serial: Int
}

/// How a card ended in place, for the haptic. The serial changes with every outcome.
struct ToastProgressOutcome: Equatable {
    let status: ToastMessage.Status
    let serial: Int
}
