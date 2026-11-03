import Foundation
import Observation

// MARK: - Tracking

extension ToastCenter {

    /// Presents a persistent progress toast for work that is still going, and returns the
    /// handle that reports on it.
    ///
    /// ```swift
    /// let handle = toasts.track(title: "Syncing", group: "sync")
    /// handle.update(.items(3, of: 10))
    /// handle.succeed()
    /// ```
    ///
    /// The card is never timed while the work runs. Keep the handle until the work ends: a
    /// handle released without an outcome is abandoned, which cancels the work and removes
    /// the card.
    ///
    /// Passing an `id` that is already tracked starts a new run in its place. After a
    /// failure that is how Retry resumes the same card.
    ///
    /// - Parameters:
    ///   - progress: Where the work starts. Indeterminate by default.
    ///   - options: See ``ToastProgressOptions``.
    ///   - onCancel: Called when the user cancels. `nil` offers no Cancel button, unless
    ///     ``ToastProgressHandle/cancels(_:)`` is called later. Call
    ///     ``ToastProgressHandle/finishCancelled()`` once the work has stopped.
    @discardableResult
    public func track(
        id: UUID = UUID(),
        title: String,
        message: String? = nil,
        icon: ToastIcon? = nil,
        progress: ToastProgress = .indeterminate,
        group: ToastGroup? = nil,
        options: ToastProgressOptions = .default,
        onCancel: (@MainActor () -> Void)? = nil
    ) -> ToastProgressHandle {
        startProgress(
            id: id,
            title: title,
            message: message,
            icon: icon,
            progress: progress,
            group: group,
            options: options,
            cancelRoute: onCancel,
            abandonable: true,
            automaticSuccess: nil,
            inbox: nil
        )
    }

    /// Tracks a Foundation `Progress`, such as `URLSessionTask.progress`.
    ///
    /// Cancel is offered when `progress.isCancellable` and calls `progress.cancel()`. With
    /// ``ToastProgressCompletion/automatic(success:)``, the default, the card succeeds when
    /// the `Progress` finishes and finishes as cancelled when it is cancelled, so the
    /// returned handle may be discarded. Pass ``ToastProgressCompletion/manual`` when the
    /// outcome is yours to report. A cancelled `Progress` ends a cancel in both modes, so
    /// Cancel never waits out the grace period; only success and failure stay manual.
    @discardableResult
    public func track(
        _ progress: Progress,
        id: UUID = UUID(),
        title: String,
        message: String? = nil,
        icon: ToastIcon? = nil,
        group: ToastGroup? = nil,
        completion: ToastProgressCompletion = .automatic(success: ToastProgressResult()),
        options: ToastProgressOptions = .default
    ) -> ToastProgressHandle {
        var automaticSuccess: ToastProgressResult?
        if case .automatic(let success) = completion { automaticSuccess = success }

        var cancelRoute: (@MainActor () -> Void)?
        if progress.isCancellable { cancelRoute = { progress.cancel() } }

        let inbox = ToastProgressInbox()
        let handle = startProgress(
            id: id,
            title: title,
            message: message,
            icon: icon,
            progress: ToastProgress(progress),
            group: group,
            options: options,
            cancelRoute: cancelRoute,
            abandonable: automaticSuccess == nil,
            automaticSuccess: automaticSuccess,
            inbox: inbox
        )
        inbox.follow(progress, reportsOutcome: true)
        return handle
    }

    /// Runs `operation`, showing its progress, and returns its value.
    ///
    /// ```swift
    /// let url = try await toasts.withProgress(title: "Uploading video", group: "upload") { report in
    ///     try await uploader.upload(file) { sent, total in report(.bytes(sent, of: total)) }
    /// }
    /// ```
    ///
    /// The Cancel button and cancelling the calling task both cancel `operation`'s task.
    /// The outcome follows from how it ends: a return value succeeds, a `CancellationError`
    /// (or any error after a cancel) cancels, and any other error fails with `failure`'s
    /// result and is rethrown.
    ///
    /// To retry, call this again with the same `id` from `onRetry`, synchronously or in a
    /// `Task` created inside it; the failed card resumes where it stands.
    ///
    /// - Parameters:
    ///   - cancellable: Offers Cancel. On by default.
    ///   - success: Builds the result card from the returned value.
    ///   - failure: Builds the result card from the error.
    ///   - onRetry: Offers Retry on a failure.
    ///   - operation: The work. It runs off the main actor; report with the reporter.
    public func withProgress<T: Sendable>(
        id: UUID = UUID(),
        title: String,
        message: String? = nil,
        icon: ToastIcon? = nil,
        group: ToastGroup? = nil,
        cancellable: Bool = true,
        success: @escaping @Sendable (T) -> ToastProgressResult = { _ in ToastProgressResult() },
        failure: @escaping @Sendable (any Error) -> ToastProgressResult = { _ in ToastProgressResult() },
        onRetry: (@MainActor () -> Void)? = nil,
        options: ToastProgressOptions = .default,
        operation: @escaping @Sendable (ToastProgressReporter) async throws -> T
    ) async throws -> T {
        let inbox = ToastProgressInbox()
        let reporter = ToastProgressReporter(inbox: inbox)
        let child = Task<T, Error> { try await operation(reporter) }

        var cancelRoute: (@MainActor () -> Void)?
        if cancellable { cancelRoute = { child.cancel() } }

        // Every exit below sets an outcome, so this handle is never abandoned.
        let handle = startProgress(
            id: id,
            title: title,
            message: message,
            icon: icon,
            progress: .indeterminate,
            group: group,
            options: options,
            cancelRoute: cancelRoute,
            abandonable: false,
            automaticSuccess: nil,
            inbox: inbox
        )
        let serial = handle.serial

        do {
            let value = try await withTaskCancellationHandler {
                try await child.value
            } onCancel: {
                child.cancel()
            }
            finishProgress(id: id, serial: serial, succeeding: success(value))
            return value
        } catch {
            if error is CancellationError || child.isCancelled {
                finishProgressCancelled(id: id, serial: serial)
            } else {
                finishProgress(id: id, serial: serial, failing: failure(error), retry: onRetry)
            }
            throw error
        }
    }

    /// True while the work behind `id` is going on, whether its card is showing or hidden.
    public func isTracking(id: UUID) -> Bool {
        progressRecords[id]?.phase.isActive == true
    }

    /// Asks every running progress toast in `group` to cancel, hidden ones included.
    /// Dismissing never cancels; this does.
    ///
    /// - Returns: How many were running and are now cancelling.
    @discardableResult
    public func cancelProgress(group: ToastGroup) -> Int {
        let ids = progressRecords.filter { $0.value.lastMessage.group == group && $0.value.phase.isRunning }.keys
        return ids.reduce(0) { count, id in
            requestCancel(id: id) ? count + 1 : count
        }
    }
}

// MARK: - Starting a run

extension ToastCenter {

    /// The one place a run begins. A card already in the stack under `id` is replaced
    /// where it stands, which is how Retry resumes; otherwise the toast arrives on top.
    func startProgress(
        id: UUID,
        title: String,
        message: String?,
        icon: ToastIcon?,
        progress: ToastProgress,
        group: ToastGroup?,
        options: ToastProgressOptions,
        cancelRoute: (@MainActor () -> Void)?,
        abandonable: Bool,
        automaticSuccess: ToastProgressResult?,
        inbox: ToastProgressInbox?
    ) -> ToastProgressHandle {
        // A run that is replaced stops listening; its handle goes stale.
        progressRecords[id]?.inbox?.close()

        progressSerial += 1
        let serial = progressSerial

        var toast = ToastMessage(
            id: id,
            status: .normal,
            title: title,
            message: message,
            icon: icon,
            duration: .indefinite,
            tapAction: nil,
            swipeActions: options.swipeActions,
            group: group
        )
        toast.progressPhase = .running(progress)

        let cell = progressStore.cell(for: id, initial: progress)
        cell.value = progress
        cell.canCancel = cancelRoute != nil
        cell.canRetry = false
        cell.confirmsCancel = options.confirmsCancel

        let handle = ToastProgressHandle(id: id, serial: serial, center: self, phase: .running(progress))
        var record = ToastProgressRecord(
            serial: serial,
            message: toast,
            progress: progress,
            options: options,
            abandonable: abandonable,
            automaticSuccess: automaticSuccess,
            cancelRoute: cancelRoute,
            inbox: inbox
        )
        record.handle = handle
        // Registered before the toast is shown, so capacity and the countdown see it.
        progressRecords[id] = record
        inbox?.bind(center: self, id: id, serial: serial)

        if !replace(id: id, with: toast) {
            present(toast)
        }

        if !options.announcements.isSilent {
            progressRecords[id]?.milestones.began(at: scheduler.now, fraction: progress.fraction)
            publishProgress(ToastAnnouncement.progressStarted(title: title), urgent: false)
        }
        return handle
    }

    /// Swaps the toast with `id` for `toast` where it stands: no move to the front, no
    /// reset of the countdown. The countdown is then reconciled, so a card that has just
    /// become timed starts its run if it is topmost.
    ///
    /// - Returns: False when no such toast is in the stack.
    @discardableResult
    func replace(id: UUID, with toast: ToastMessage) -> Bool {
        guard let index = toasts.firstIndex(where: { $0.id == id }) else { return false }
        toasts[index] = toast
        progressRecords[id]?.lastMessage = toast
        reconcile()
        return true
    }

    /// Gives a toast that is being presented again the state of the run it belongs to.
    func adoptProgressState(into toast: inout ToastMessage) {
        guard var record = progressRecords[toast.id] else { return }
        if toast.progressPhase == nil {
            toast.progressPhase = record.phase
            if record.phase.isActive { toast.swipeActions = record.options.swipeActions }
        }
        record.lastMessage = toast
        if record.isHidden {
            record.isHidden = false
            record.handle?.isVisible = true
        }
        progressRecords[toast.id] = record
    }
}

// MARK: - Live updates

extension ToastCenter {

    /// Stores a tick. Writes the card's cell and the handle, and the toast itself only when
    /// the bar changes between indeterminate and determinate, so a tick never redraws the
    /// stack.
    func applyProgress(id: UUID, serial: Int, value: ToastProgress) {
        checkCancellationGrace()
        guard var record = activeProgressRecord(id: id, serial: serial, caller: "update") else { return }
        // The bar freezes while the work is being stopped.
        guard record.phase.isRunning else { return }

        let kindChanged = record.progress.isIndeterminate != value.isIndeterminate
        record.progress = value
        progressStore.cells[id]?.value = value
        record.handle?.phase = .running(value)

        if case .milestones = record.options.announcements,
           let percent = record.milestones.next(
               fraction: value.fraction,
               now: scheduler.now,
               isFront: topmost?.id == id,
               isActive: !isSuspended
           ) {
            publishProgress(
                ToastAnnouncement.progressMilestone(title: record.lastMessage.title, percent: percent),
                urgent: false
            )
        }

        if kindChanged { record.phase = .running(value) }
        progressRecords[id] = record
        if kindChanged { refreshMessagePhase(id: id, phase: record.phase) }
    }

    /// Changes the words on a running card.
    func applyCopy(id: UUID, serial: Int, title: String?, message: String??) {
        guard var record = activeProgressRecord(id: id, serial: serial, caller: "update(title:message:)") else {
            return
        }
        if let title { record.lastMessage.title = title }
        if let message { record.lastMessage.message = message }
        progressRecords[id] = record
        if let index = toasts.firstIndex(where: { $0.id == id }) {
            if let title { toasts[index].title = title }
            if let message { toasts[index].message = message }
        }
    }

    /// Rewrites the phase a toast carries, in the stack and in the record's copy.
    private func refreshMessagePhase(id: UUID, phase: ToastProgressPhase) {
        if let index = toasts.firstIndex(where: { $0.id == id }) {
            toasts[index].progressPhase = phase
        }
        progressRecords[id]?.lastMessage.progressPhase = phase
    }

    /// Hands over what an inbox collected since its last delivery.
    func receive(_ batch: ToastProgressInbox.Batch, id: UUID, serial: Int) {
        if batch.title != nil || batch.message != nil {
            applyCopy(id: id, serial: serial, title: batch.title, message: batch.message)
        }
        if let progress = batch.progress {
            applyProgress(id: id, serial: serial, value: progress)
        }
        guard let outcome = batch.outcome else { return }
        switch outcome {
        case .cancelled:
            finishProgressCancelled(id: id, serial: serial)
        case .finished:
            if let success = progressRecords[id]?.automaticSuccess {
                finishProgress(id: id, serial: serial, succeeding: success)
            }
        }
    }
}

// MARK: - Outcomes

extension ToastCenter {

    /// The work finished: the card becomes a success where it stands.
    func finishProgress(id: UUID, serial: Int, succeeding result: ToastProgressResult) {
        guard let record = activeProgressRecord(id: id, serial: serial, caller: "succeed") else { return }
        var toast = record.lastMessage
        toast.title = result.title ?? String(localized: "toast.progress.done", bundle: .module)
        toast.message = result.message
        toast.icon = result.icon ?? .system("checkmark.circle.fill")
        toast.duration = result.duration ?? record.options.successDuration
        toast.tapAction = result.tapAction
        toast.swipeActions = .standard
        toast.progressPhase = .succeeded
        conclude(
            id: id,
            record: record,
            toast: toast,
            retry: nil,
            haptic: toast.status,
            speech: (text: ToastAnnouncement.progressSucceeded(title: record.lastMessage.title), urgent: false),
            surfacesWhenHidden: record.options.resultWhenHidden == .always
        )
    }

    /// The work failed: the card becomes an error where it stands, with Retry if there is
    /// a closure to run.
    func finishProgress(
        id: UUID,
        serial: Int,
        failing result: ToastProgressResult,
        retry: (@MainActor () -> Void)?
    ) {
        guard let record = activeProgressRecord(id: id, serial: serial, caller: "fail") else { return }
        var toast = record.lastMessage
        toast.status = .error
        toast.title = result.title ?? String(localized: "toast.progress.failed", bundle: .module)
        toast.message = result.message
        toast.icon = result.icon
        toast.duration = result.duration ?? record.options.failureDuration
        toast.tapAction = result.tapAction
        toast.swipeActions = .standard
        toast.progressPhase = .failed
        conclude(
            id: id,
            record: record,
            toast: toast,
            retry: retry,
            haptic: .error,
            speech: (text: ToastAnnouncement.progressFailed(title: record.lastMessage.title), urgent: true),
            surfacesWhenHidden: record.options.resultWhenHidden != .never
        )
    }

    /// The work has stopped after a cancel.
    func finishProgressCancelled(id: UUID, serial: Int) {
        guard let record = activeProgressRecord(id: id, serial: serial, caller: "finishCancelled") else { return }
        completeCancel(id: id, record: record)
    }

    /// Ends a cancel: the card is removed, or turns into a short "Cancelled" result when
    /// the options ask for one. A hidden card ends silently.
    private func completeCancel(id: UUID, record: ToastProgressRecord) {
        let title = record.lastMessage.title
        if record.options.showsCancelledResult && !record.isHidden {
            var toast = record.lastMessage
            toast.title = String(localized: "toast.progress.cancelled", bundle: .module)
            toast.message = nil
            toast.icon = .system("xmark.circle.fill")
            toast.duration = record.options.successDuration
            toast.tapAction = nil
            toast.swipeActions = .standard
            toast.progressPhase = .cancelled
            conclude(
                id: id,
                record: record,
                toast: toast,
                retry: nil,
                haptic: nil,
                speech: (text: ToastAnnouncement.progressCancelled(title: title), urgent: false),
                surfacesWhenHidden: false
            )
            return
        }

        finalizeRecord(id: id, record: record, phase: .cancelled, retry: nil)
        if !record.isHidden {
            // No longer active, so this removes the card instead of hiding it.
            remove(where: { $0.id == id }, scope: .onScreen, removal: nil, announces: false)
            speak(ToastAnnouncement.progressCancelled(title: title), urgent: false, options: record.options)
        }
        dropProgressRecord(id: id)
    }

    /// Shows the result of a run that has ended.
    ///
    /// A card in the stack is replaced where it stands. A hidden one comes back as a new
    /// arrival if `surfacesWhenHidden`, and otherwise the run is forgotten without a word.
    private func conclude(
        id: UUID,
        record: ToastProgressRecord,
        toast: ToastMessage,
        retry: (@MainActor () -> Void)?,
        haptic: ToastMessage.Status?,
        speech: (text: String, urgent: Bool),
        surfacesWhenHidden: Bool
    ) {
        guard let phase = toast.progressPhase else { return }
        finalizeRecord(id: id, record: record, phase: phase, retry: retry)
        progressRecords[id]?.lastMessage = toast

        if record.isHidden {
            guard surfacesWhenHidden else {
                dropProgressRecord(id: id)
                return
            }
            // A new arrival: it takes the front, the countdown, and the arrival haptic.
            present(toast)
            speak(speech.text, urgent: speech.urgent, options: record.options)
            return
        }

        if !replace(id: id, with: toast) {
            present(toast)
        }
        if let haptic {
            progressAnnouncementSerial += 1
            progressOutcome = ToastProgressOutcome(status: haptic, serial: progressAnnouncementSerial)
        }
        speak(speech.text, urgent: speech.urgent, options: record.options)
    }

    /// Marks the run over: no more work to reach, nothing to cancel, no inbox.
    private func finalizeRecord(
        id: UUID,
        record: ToastProgressRecord,
        phase: ToastProgressPhase,
        retry: (@MainActor () -> Void)?
    ) {
        record.inbox?.close()
        var record = record
        record.phase = phase
        record.cancelRoute = nil
        record.cancellingSince = nil
        record.abandonable = false
        record.retry = retry
        record.isRetrying = false
        record.inbox = nil
        progressRecords[id] = record

        record.handle?.phase = phase
        if let cell = progressStore.cells[id] {
            cell.canCancel = false
            cell.canRetry = retry != nil
        }
    }

    /// Forgets a run whose card is gone.
    func dropProgressRecord(id: UUID) {
        progressRecords[id]?.inbox?.close()
        progressRecords[id] = nil
        progressStore.remove(id)
    }

    /// Forgets the runs that have ended and whose cards have left the stack.
    func pruneFinishedProgress() {
        guard !progressRecords.isEmpty else { return }
        let showing = Set(toasts.map(\.id)).union(postponed.map(\.id))
        for (id, record) in progressRecords where !record.phase.isActive && !showing.contains(id) {
            dropProgressRecord(id: id)
        }
    }

    /// Takes a running card out of the stack's accounting without ending its work.
    func markProgressHidden(_ toast: ToastMessage) {
        guard var record = progressRecords[toast.id], record.phase.isActive else { return }
        record.isHidden = true
        record.lastMessage = toast
        record.handle?.isVisible = false
        progressRecords[toast.id] = record
    }
}

// MARK: - Cancelling

extension ToastCenter {

    /// Starts a cancel: the card shows "Cancelling…" and the cancel route runs. With no
    /// route there is nothing to wait for, and the cancel finishes at once.
    ///
    /// - Parameter serial: The run the caller belongs to. `nil` from the card's own button.
    /// - Returns: False when nothing was running to cancel.
    @discardableResult
    func requestCancel(id: UUID, serial: Int? = nil) -> Bool {
        guard var record = progressRecords[id], serial == nil || serial == record.serial else {
            debugIgnored("cancel", id: id)
            return false
        }
        guard record.phase.isRunning else { return false }

        record.isCancellationRequested = true
        record.handle?.isCancellationRequested = true
        guard let route = record.cancelRoute else {
            progressRecords[id] = record
            completeCancel(id: id, record: record)
            return true
        }

        record.phase = .cancelling
        record.cancellingSince = scheduler.now
        progressRecords[id] = record
        record.handle?.phase = .cancelling
        refreshMessagePhase(id: id, phase: .cancelling)
        scheduleCancellationGraceCheck(after: record.options.cancellationGrace)
        // Last, and with the record already stored: the route may finish the cancel
        // before it returns.
        route()
        return true
    }

    /// The swipe that hides a card and cancels its work.
    func hideAndCancel(id: UUID) {
        dismiss(id: id)
        requestCancel(id: id)
    }

    /// Installs the way Cancel reaches the work, and offers the button.
    func setCancelRoute(id: UUID, serial: Int, route: @escaping @MainActor () -> Void) {
        guard var record = activeProgressRecord(id: id, serial: serial, caller: "cancels") else { return }
        record.cancelRoute = route
        progressRecords[id] = record
        progressStore.cells[id]?.canCancel = true
        // Cancel was asked for before the route existed: run it now.
        if !record.phase.isRunning { route() }
    }

    /// A task given to ``ToastProgressHandle/cancels(_:)`` ended.
    func progressTaskEnded(id: UUID, serial: Int) {
        guard let record = progressRecords[id], record.serial == serial, record.phase == .cancelling else { return }
        completeCancel(id: id, record: record)
    }

    /// Finishes every cancel that has waited longer than its grace. Looked at on each
    /// update and each reconcile, and by a timer as a last resort.
    func checkCancellationGrace() {
        guard !isCheckingCancellationGrace, !progressRecords.isEmpty else { return }
        isCheckingCancellationGrace = true
        defer { isCheckingCancellationGrace = false }

        let now = scheduler.now
        for (id, record) in progressRecords where record.phase == .cancelling {
            guard let since = record.cancellingSince,
                  now.timeIntervalSince(since) >= record.options.cancellationGrace else { continue }
            completeCancel(id: id, record: record)
        }
    }

    /// Production safety net. Under a fake clock `now` does not move, so this finds
    /// nothing to do; tests advance the clock and call `checkCancellationGrace()`.
    private func scheduleCancellationGraceCheck(after grace: TimeInterval) {
        let seconds = grace.isFinite ? min(max(0, grace), 86_400) : 86_400
        let nanoseconds = UInt64((seconds + 0.05) * 1_000_000_000)
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: nanoseconds)
            self?.checkCancellationGrace()
        }
    }

    /// A handle was released. If its run is still going and nobody else can finish it, the
    /// work is stopped and the card removed.
    func abandonProgress(id: UUID, serial: Int) {
        guard let record = progressRecords[id],
              record.serial == serial,
              record.phase.isActive,
              record.abandonable,
              record.handle == nil else { return }

        #if DEBUG
        print("ToastKit: ToastProgressHandle for '\(record.lastMessage.title)' was released without succeed/fail/cancel")
        #endif
        record.cancelRoute?()
        finalizeRecord(id: id, record: record, phase: .cancelled, retry: nil)
        if !record.isHidden {
            remove(where: { $0.id == id }, scope: .onScreen, removal: nil, announces: false)
        }
        dropProgressRecord(id: id)
    }
}

// MARK: - Retry

extension ToastCenter {

    /// Runs a failed card's retry closure, then removes the card unless the same id was
    /// tracked again by the end of the turn.
    func retryProgress(id: UUID) {
        guard var record = progressRecords[id],
              record.phase == .failed,
              let retry = record.retry,
              !record.isRetrying else { return }
        record.isRetrying = true
        progressRecords[id] = record
        let serial = record.serial

        retry()

        // A run started synchronously, or in a main-actor `Task` made inside the closure,
        // has claimed the id by the time this runs.
        pendingRetryCheck = Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, let current = self.progressRecords[id], current.serial == serial else { return }
            self.dismiss(id: id)
        }
    }
}

// MARK: - Speaking

extension ToastCenter {

    /// Queues a line for the stack to speak, unless the options ask for silence.
    private func speak(_ text: String, urgent: Bool, options: ToastProgressOptions) {
        guard !options.announcements.isSilent else { return }
        publishProgress(text, urgent: urgent)
    }

    func publishProgress(_ text: String, urgent: Bool) {
        progressAnnouncementSerial += 1
        progressAnnouncement = ToastProgressAnnouncement(
            text: text,
            isUrgent: urgent,
            serial: progressAnnouncementSerial
        )
    }
}

// MARK: - Lookup

extension ToastCenter {

    /// The record for `id` if `serial` still names its run and the work has no outcome yet.
    /// A stale handle, or a call after the outcome, finds nothing.
    private func activeProgressRecord(id: UUID, serial: Int, caller: String) -> ToastProgressRecord? {
        guard let record = progressRecords[id], record.serial == serial, record.phase.isActive else {
            debugIgnored(caller, id: id)
            return nil
        }
        return record
    }

    private func debugIgnored(_ caller: String, id: UUID) {
        #if DEBUG
        print("ToastKit: \(caller) ignored: the progress toast \(id) has ended or belongs to a newer run")
        #endif
    }
}
