import SwiftUI
import ToastKit

/// Persistent progress toasts: work that runs while the card stays up, then turns into
/// its result in place. Named `ProgressDemoView` so it never shadows SwiftUI's own
/// `ProgressView`.
@MainActor
struct ProgressDemoView: View {
    let toasts: ToastCenter
    @Bindable var settings: DemoSettings

    @State private var cancelsBySwipe = false
    @State private var confirmsCancel = false

    /// The options every demo below shares. Built on the main actor and passed in; it is
    /// never captured by an operation closure.
    private var options: ToastProgressOptions {
        var options = ToastProgressOptions()
        options.confirmsCancel = confirmsCancel
        if cancelsBySwipe {
            options.swipeActions = ToastSwipeActions(leading: .cancelProgress, trailing: .hideProgress)
        }
        return options
    }

    var body: some View {
        Form {
            Section {
                Button("Photo upload") { uploadPhoto() }
                Button("Video upload (Cancel cancels the Task)") { uploadVideo() }
                Button("Sync that fails, then Retry") { sync(id: UUID(), attempt: 1) }
            } header: {
                Text("Run")
            } footer: {
                Text("The photo upload reports bytes from withProgress. The video upload is a Task handed to the handle with cancels(_:), so Cancel stops it. The sync fails on its first attempt; Retry starts a new run on the same card.")
            }

            Section {
                Button("Burst of 6") { burst() }
                Button("Swipe to hide, then fail") { hideThenFail() }
                Button("Cancel the burst") { toasts.cancelProgress(group: "burst") }
            } header: {
                Text("Stack")
            } footer: {
                Text("The stack holds five, so the burst hides its oldest running card instead of losing it. Hiding never cancels. Swipe the second button's card away, and the failure brings it back.")
            }

            Section {
                Toggle("Swipe left cancels", isOn: $cancelsBySwipe)
                Toggle("Confirm Cancel", isOn: $confirmsCancel)
            } header: {
                Text("Options")
            } footer: {
                Text("A swipe only hides a running card unless Swipe left cancels is on. Confirm Cancel asks for a second tap on Cancel. Both apply to the next progress toast.")
            }

            platformSection

            Section {
                Button("Dismiss all", role: .destructive) { toasts.dismissAll() }
            } footer: {
                Text("Dismissing running cards hides them; the work goes on.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Progress")
    }

    // MARK: - Platform sections

    @ViewBuilder
    private var platformSection: some View {
        #if os(macOS)
        Section {
            Button("Copy a folder (Foundation Progress)") { copyFolder() }
        } header: {
            Text("macOS")
        } footer: {
            Text("A Foundation Progress of kind file, copying, tracked with track(_:title:). The kit reads its fraction, byte counts and cancellation. Hover a card to reveal its buttons; their tooltips name each action.")
        }
        #elseif os(visionOS)
        Section {
            Button("Prepare a scene (indeterminate, then determinate)") { prepareScene() }
        } header: {
            Text("visionOS")
        } footer: {
            Text("Starts indeterminate, then switches to a bar. Look at a card to see its hover effect on the buttons. There are no haptics on visionOS.")
        }
        #endif
    }

    // MARK: - Common demos

    private func uploadPhoto() {
        let runOptions = options
        let total: Int64 = 24_000_000
        Task { @MainActor in
            do {
                try await toasts.withProgress(
                    title: "Uploading photo",
                    message: "IMG_2041.heic",
                    icon: .system("photo"),
                    group: "progress",
                    success: { (_: Void) in ToastProgressResult(title: "Photo uploaded", message: "IMG_2041.heic") },
                    options: runOptions,
                    operation: { (report: ToastProgressReporter) async throws -> Void in
                        var sent: Int64 = 0
                        while sent < total {
                            try await Task.sleep(for: .milliseconds(120))
                            sent = min(total, sent + 900_000)
                            report(.bytes(sent, of: total))
                        }
                    }
                )
            } catch {
                // The card already shows the outcome.
            }
        }
    }

    private func uploadVideo() {
        let total: Int64 = 120_000_000
        let handle = toasts.track(
            title: "Uploading video",
            message: "Holiday.mov",
            icon: .system("video"),
            progress: .bytes(0, of: total),
            group: "progress",
            options: options
        )
        let task = Task { @MainActor in
            var sent: Int64 = 0
            while sent < total {
                try await Task.sleep(for: .milliseconds(150))
                sent = min(total, sent + 2_000_000)
                handle.update(.bytes(sent, of: total))
            }
            handle.succeed(ToastProgressResult(title: "Video uploaded", message: "Holiday.mov"))
        }
        // Cancel, and abandoning the handle, now cancel this task, which finishes the card.
        handle.cancels(task)
    }

    private func sync(id: UUID, attempt: Int) {
        let runOptions = options
        Task { @MainActor in
            do {
                try await toasts.withProgress(
                    id: id,
                    title: attempt == 1 ? "Syncing library" : "Syncing library, attempt \(attempt)",
                    icon: .system("arrow.triangle.2.circlepath"),
                    group: "progress",
                    success: { (_: Void) in ToastProgressResult(title: "Library synced") },
                    failure: { _ in
                        ToastProgressResult(title: "Sync failed", message: "The server went away. Try again.")
                    },
                    onRetry: { sync(id: id, attempt: attempt + 1) },
                    options: runOptions,
                    operation: { (report: ToastProgressReporter) async throws -> Void in
                        for step in 1...10 {
                            try await Task.sleep(for: .milliseconds(250))
                            report(.items(Int64(step), of: 10))
                            if attempt == 1, step == 6 { throw DemoSyncError.offline }
                        }
                    }
                )
            } catch {
                // The card already shows the outcome.
            }
        }
    }

    private func burst() {
        let runOptions = options
        for number in 1...6 {
            Task { @MainActor in
                do {
                    try await toasts.withProgress(
                        title: "Copying file \(number) of 6",
                        icon: .system("doc.on.doc"),
                        group: "burst",
                        options: runOptions,
                        operation: { (report: ToastProgressReporter) async throws -> Void in
                            let steps = 20 + number * 6
                            for step in 1...steps {
                                try await Task.sleep(for: .milliseconds(200))
                                report(fraction: Double(step) / Double(steps))
                            }
                        }
                    )
                } catch {
                    // The card already shows the outcome.
                }
            }
        }
    }

    private func hideThenFail() {
        let handle = toasts.track(
            title: "Exporting report",
            message: "Swipe this away. It fails in a few seconds.",
            icon: .system("square.and.arrow.up"),
            progress: .fraction(0.4),
            group: "progress",
            options: options
        )
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(6))
            handle.fail(ToastProgressResult(title: "Export failed", message: "The disk is full."))
        }
    }

    #if os(macOS)
    // MARK: - macOS

    /// Carries a Foundation `Progress` into a detached loop. `Progress` is documented as
    /// thread safe, but is not declared `Sendable`.
    private final class ProgressBox: @unchecked Sendable {
        let progress: Progress

        init(_ progress: Progress) {
            self.progress = progress
        }
    }

    private func copyFolder() {
        let total: Int64 = 60_000_000
        let progress = Progress(totalUnitCount: total)
        progress.kind = .file
        progress.fileOperationKind = .copying
        progress.isCancellable = true
        toasts.track(
            progress,
            title: "Copying “Project Files”",
            message: "To Backup",
            icon: .system("folder"),
            group: "progress",
            options: options
        )
        let box = ProgressBox(progress)
        Task.detached {
            while !box.progress.isCancelled, box.progress.completedUnitCount < total {
                try? await Task.sleep(for: .milliseconds(150))
                box.progress.completedUnitCount = min(total, box.progress.completedUnitCount + 1_500_000)
            }
        }
    }
    #endif

    #if os(visionOS)
    // MARK: - visionOS

    private func prepareScene() {
        let handle = toasts.track(
            title: "Preparing scene",
            message: "Preparing…",
            icon: .system("visionpro"),
            group: "progress",
            options: options
        )
        let task = Task { @MainActor in
            try await Task.sleep(for: .seconds(2))
            handle.update(title: nil, message: .some(nil))
            for step in 1...20 {
                try await Task.sleep(for: .milliseconds(150))
                handle.update(fraction: Double(step) / 20)
            }
            handle.succeed(ToastProgressResult(title: "Scene ready"))
        }
        handle.cancels(task)
    }
    #endif
}

/// Why the demo's first sync attempt fails. Plain and `Sendable`, so an operation closure
/// can throw it.
private enum DemoSyncError: Error {
    case offline
}
