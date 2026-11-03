import Foundation

// Everything that touches Foundation's `Progress` and key-value observing lives here, so
// the rest of the progress model stays free of Darwin-only API.

extension ToastProgress {

    /// How a `Progress` reads as a toast's progress.
    ///
    /// - The fraction is `fractionCompleted`, or `nil` while the `Progress` is
    ///   indeterminate.
    /// - The unit counts are `.bytes` when `kind == .file` and `.items` otherwise.
    /// - `localizedAdditionalDescription` becomes the subtitle only for a file, where the
    ///   system writes it well ("3 MB of 10 MB — 2 minutes remaining"). Anything else uses
    ///   the generated detail line.
    init(_ progress: Progress) {
        let isFile = progress.kind == .file
        let total = progress.totalUnitCount
        let known = total > 0
        let completed = progress.completedUnitCount
        // The property is imported as an implicitly unwrapped `String!`.
        let description: String? = progress.localizedAdditionalDescription
        self.init(
            fraction: progress.isIndeterminate ? nil : progress.fractionCompleted,
            completedUnitCount: known || completed > 0 ? completed : nil,
            totalUnitCount: known ? total : nil,
            unit: isFile ? .bytes : .items,
            subtitle: isFile && description?.isEmpty == false ? description : nil
        )
    }
}

extension ToastProgressInbox {

    /// Starts watching `progress` on whatever thread it changes on. Each change is posted
    /// as a snapshot and coalesced like any other report.
    ///
    /// - Parameter reportsOutcome: Also post `finished` and `cancelled`, which the center
    ///   turns into the card's outcome. Off when the operation decides the outcome itself.
    func follow(_ progress: Progress, reportsOutcome: Bool) {
        // The observation is not guaranteed to keep what it observes alive.
        retain(progress)

        let snapshot: @Sendable (Progress) -> Void = { [weak self] progress in
            self?.post(ToastProgress(progress))
        }
        retain(progress.observe(\.fractionCompleted, options: [.initial, .new]) { progress, _ in
            snapshot(progress)
        })
        retain(progress.observe(\.completedUnitCount, options: [.new]) { progress, _ in
            snapshot(progress)
        })
        retain(progress.observe(\.totalUnitCount, options: [.new]) { progress, _ in
            snapshot(progress)
        })

        guard reportsOutcome else { return }
        let outcome: @Sendable (Progress) -> Void = { [weak self] progress in
            if progress.isCancelled {
                self?.post(outcome: .cancelled)
            } else if progress.isFinished {
                self?.post(outcome: .finished)
            }
        }
        retain(progress.observe(\.isCancelled, options: [.initial, .new]) { progress, _ in
            outcome(progress)
        })
        retain(progress.observe(\.isFinished, options: [.initial, .new]) { progress, _ in
            outcome(progress)
        })
    }
}
