import SwiftUI
import XCTest
import ToastKit

// The README's examples, compiled against the public API only — a plain `import`, not
// `@testable` — so the documentation cannot drift from the code. Each example is a view
// or function that mirrors a README section; the test at the bottom builds them.

// MARK: - Quick start

private struct QuickStartExample: View {
    @State private var toasts = ToastCenter()

    var body: some View {
        Button("Save") {
            toasts.present(.normal, title: "Saved")
        }
        .toasts(toasts)
    }
}

// MARK: - Presenting

@MainActor
private func presentingExamples(_ toasts: ToastCenter, open: @escaping () -> Void) {
    toasts.present(.warning, title: "Low storage", message: "Free up space to keep syncing.")

    toasts.present(ToastMessage(
        status: .notification,
        title: "New photos",
        message: "12 photos from today",
        icon: .system("photo.on.rectangle"),
        duration: 6,
        tapAction: ToastAction(title: "View") { _ in open() }
    ))

    // Re-presenting an id refreshes the card in place.
    let syncID = UUID()
    toasts.present(ToastMessage(id: syncID, title: "Syncing 3 items…", duration: .indefinite))
    toasts.present(ToastMessage(id: syncID, title: "Synced"))
}

@MainActor
private func stackExamples() -> ToastCenter {
    ToastCenter(visibleDepth: 2, capacity: 8)
}

// MARK: - Duration

@MainActor
private func durationExamples() -> ToastCenter {
    let toasts = ToastCenter(defaultDuration: 6)
    toasts.present(ToastMessage(title: "Uses the center's six seconds"))
    toasts.present(ToastMessage(title: "Copied", duration: 2))
    toasts.present(ToastMessage(title: "Sync failed", duration: .indefinite))
    return toasts
}

// MARK: - Actions

private final class ExampleStore {
    func archive(_ id: UUID) {}
    func undo(_ id: UUID) {}
}

@MainActor
private func actionExamples(_ toasts: ToastCenter, store: ExampleStore) {
    // Tap to undo; swipe left to delete, right to see it again next visit.
    let recordID = UUID()
    toasts.present(ToastMessage(
        id: recordID,
        title: "Moved to Trash",
        message: "Tap to undo",
        tapAction: ToastAction(id: "undo", title: "Undo") { toast in store.undo(toast.id) }
    ))

    // Your own words, icons and work on either side.
    toasts.present(ToastMessage(
        title: "Message from Ana",
        swipeActions: ToastSwipeActions(
            leading: ToastAction(
                id: "archive",
                title: "Archive",
                subtitle: "Keeps a copy",
                icon: .system("archivebox"),
                confirmation: "Archived",
                role: .subdued
            ) { toast in store.archive(toast.id) },
            trailing: .later(title: "Snooze", subtitle: "Next visit", icon: .system("moon.zzz"))
        )
    ))

    // One way only, or not at all.
    toasts.present(ToastMessage(title: "One way", swipeActions: ToastSwipeActions(leading: .delete, trailing: nil)))
    toasts.present(ToastMessage(title: "Tap or wait", swipeActions: .disabled))

    // One side replaced; the built-ins reworded.
    let archiveOnly = ToastSwipeActions(leading: ToastAction(title: "Archive", icon: .system("archivebox")) { toast in
        store.archive(toast.id)
    })
    let reworded = ToastSwipeActions(
        leading: .delete(title: "Remove", confirmation: "Removed"),
        trailing: .later(title: "Snooze", subtitle: "Next visit", icon: .system("moon.zzz"))
    )
    toasts.present(ToastMessage(title: "Message from Ana", swipeActions: archiveOnly))
    toasts.present(ToastMessage(title: "Message from Ana", swipeActions: reworded))
    toasts.present(ToastMessage(title: "Message from Ana", swipeActions: ToastSwipeActions(
        leading: .delete,
        trailing: .later(title: "Snooze")
    )))
}

// MARK: - Testing

@MainActor
private final class ExampleScheduler: ToastScheduling {
    var now = Date()
    private var pending: (@MainActor () -> Void)?
    func schedule(after seconds: TimeInterval, action: @escaping @MainActor () -> Void) {
        pending = action
    }
    func cancel() { pending = nil }
    func fire() { pending?() }
}

private struct ActionObserverExample: View {
    @State private var toasts = ToastCenter()
    let store = ExampleStore()

    var body: some View {
        Color.clear
            .toasts(toasts) { _ in
                // Runs for toasts without a tap action of their own.
            }
            .onToastAction { toast, action in
                switch action.id {
                case ToastAction.deleteID: break
                case ToastAction.laterID: break
                case "archive": store.archive(toast.id)
                default: break
                }
            }
    }
}

@MainActor
private func postponedExamples(_ toasts: ToastCenter) {
    let waiting = toasts.postponed
    toasts.restorePostponed()
    toasts.discardPostponed()
    _ = waiting
}

// MARK: - Dismissing

@MainActor
private func dismissalExamples(_ toasts: ToastCenter) {
    // One toast: by id, or whichever is in front.
    let savedID = UUID()
    toasts.present(ToastMessage(id: savedID, title: "Saved"))
    toasts.dismiss(id: savedID)
    toasts.present(.normal, title: "Copied")
    toasts.dismissTopmost()

    // Toasts that belong together share a group.
    toasts.present(.normal, title: "Uploading photo 1 of 3", group: "upload")
    toasts.present(ToastMessage(title: "Uploading photo 2 of 3", group: "upload"))
    toasts.present(ToastMessage(title: "Uploading photo 3 of 3", group: "upload"))

    // Clear a group — postponed toasts of the group included — or everything that matches.
    toasts.dismiss(group: "upload")
    toasts.dismiss(group: "upload", removal: .slide(.trailing))
    toasts.dismiss(group: "upload", removal: .trail(), scope: .onScreen)
    let failed = toasts.dismiss(removal: .trail()) { $0.status == .error }
    _ = failed

    // The whole stack, with a choice of exit and of what to reach.
    toasts.dismissAll()
    toasts.dismissAll(removal: .trail())
    toasts.dismissAll(removal: .slide(.degrees(-90)), scope: .everywhere)
    toasts.dismissAll(removal: .trail(.vector(dx: 1, dy: -1)), scope: .postponed)

    // Directions: wind up and leave upward, or slide away from the edge the stack hangs from.
    toasts.dismiss(group: "upload", removal: .trail(.degrees(-90)))
    toasts.dismissAll(removal: .slide(.awayFromAnchor))
    toasts.dismissAll(removal: .trail(), scope: .everywhere)

    let directions: [ToastRemovalDirection] = [
        .inPlace, .towardAnchor, .awayFromAnchor, .top, .bottom, .leading, .trailing
    ]
    _ = directions.map { ToastRemoval.slide($0) }
    _ = ToastRemoval.fade
}

private struct RemovalExample: View {
    @State private var toasts = ToastCenter()

    var body: some View {
        Button("Clear") { toasts.dismissAll() }
            .toasts(toasts)
            .toastRemoval(.trail())
    }
}

// MARK: - Progress

private struct ExampleUploader: Sendable {
    func upload(_ file: URL, progress: @Sendable (Int64, Int64) -> Void) async throws -> URL { file }
}

private struct ExampleClient {
    func send(progress: (Double) -> Void) async throws {}
}

@MainActor
private func progressHandleExample(_ toasts: ToastCenter) -> ToastProgressHandle {
    let handle = toasts.track(title: "Syncing", group: "sync")   // indeterminate; never times out
    progressValuesExample(handle)
    handle.update(.items(3, of: 10))                             // "3 of 10"
    handle.update(fraction: 0.8)
    waitingExample(handle)
    handle.update(fraction: 0.9)
    handle.succeed(ToastProgressResult(title: "Synced", message: "10 items"))
    return handle
}

@MainActor
private func progressValuesExample(_ handle: ToastProgressHandle) {
    handle.update(.indeterminate)                                 // a sweeping bar, no number
    handle.update(.fraction(0.4))                                 // 40%
    handle.update(.fraction(0.4, subtitle: "Resizing"))           // your own detail line
    handle.update(.bytes(12_000_000, of: 30_000_000))             // "12 MB of 30 MB"
    handle.update(.items(3, of: 10))                              // "3 of 10"
    handle.update(fraction: nil)                                  // back to indeterminate
}

#if os(iOS) || os(macOS)
@MainActor
private func uploadExample(_ toasts: ToastCenter, uploader: ExampleUploader, file: URL) async throws -> URL {
    try await toasts.withProgress(
        title: "Uploading video",
        group: "upload",
        operation: { report in
            try await uploader.upload(file) { sent, total in report(.bytes(sent, of: total)) }
        }
    )
}
#endif

// Compile-only: it needs a live URLSession task.
@MainActor
private func foundationProgressExample(_ toasts: ToastCenter, _ task: URLSessionTask) {
    // .automatic, the default: the card succeeds when the Progress finishes, so the handle can go.
    toasts.track(task.progress, title: "Downloading", group: "download")

    // .manual: the outcome is yours, for example once the server has answered.
    let handle = toasts.track(task.progress, title: "Uploading", completion: .manual)
    handle.succeed(ToastProgressResult(title: "Uploaded"))
}

// Compile-only: it follows each photo's Progress.
@MainActor
private func aggregateExample(_ toasts: ToastCenter, photos: [Progress]) {
    let batch = Progress(totalUnitCount: Int64(photos.count))
    toasts.track(batch, title: "Uploading \(photos.count) photos", group: "upload")
    for photo in photos {
        batch.addChild(photo, withPendingUnitCount: 1)
    }
}

@MainActor
private func waitingExample(_ handle: ToastProgressHandle) {
    handle.update(title: "Waiting for network…")                   // reword; the bar stays
    handle.update(message: "Will resume when you're back online")
    handle.update(title: "Uploading video", message: .some(nil))   // back again, second line removed
}

// Compile-only: the retry runs a Task.
@MainActor
private func retryExample(_ toasts: ToastCenter, client: ExampleClient, id: UUID = UUID()) {
    let handle = toasts.track(id: id, title: "Sending", onCancel: {})
    Task {
        do {
            try await client.send(progress: { handle.update(fraction: $0) })
            handle.succeed()
        } catch {
            handle.fail(ToastProgressResult(message: "No connection")) {
                retryExample(toasts, client: client, id: id)      // the same id: the card resumes in place
            }
        }
    }
}

// Compile-only: it hands the handle a Task.
@MainActor
private func cancelExamples(_ toasts: ToastCenter, upload: Task<Void, Error>) {
    // Cancel cancels the Task, and the card finishes when the Task ends.
    let handle = toasts.track(title: "Uploading video", group: "upload")
    handle.cancels(upload)

    // From code: one card, or every running card in a group.
    handle.cancel()
    toasts.cancelProgress(group: "upload")

    // Cancelling the Task that awaits withProgress cancels its operation too.
    let job = Task {
        try await toasts.withProgress(title: "Exporting", operation: { _ in
            try await Task.sleep(nanoseconds: 5_000_000_000)
        })
    }
    job.cancel()

    // Ask twice before cancelling, and allow the work longer to stop.
    var options = ToastProgressOptions()
    options.confirmsCancel = true
    options.cancellationGrace = 20
    toasts.track(title: "Deleting", options: options, onCancel: {})
}

@MainActor
private func hiddenExamples(_ toasts: ToastCenter) -> ToastProgressHandle {
    // Dismissing hides a running card; the work, and the handle, carry on.
    let handle = toasts.track(title: "Uploading", group: "upload")
    toasts.dismiss(id: handle.id)

    var options = ToastProgressOptions()
    options.resultWhenHidden = .always          // .failureOnly (the default), .always or .never
    options.showsCancelledResult = true
    options.announcements = .startAndEnd        // .milestones(step:minimumInterval:) by default
    options.successDuration = .seconds(2)
    options.failureDuration = .indefinite

    // Swiping cancels as well as hides.
    options.swipeActions = ToastSwipeActions(leading: .cancelProgress, trailing: .hideProgress)
    let backup = toasts.track(title: "Backing up", options: options, onCancel: {})
    backup.succeed()
    return handle
}

@MainActor
private func progressTestingExample() {
    let scheduler = ExampleScheduler()
    let toasts = ToastCenter(scheduler: scheduler)

    // A running progress toast is never timed.
    let upload = toasts.track(title: "Uploading", onCancel: {})
    scheduler.fire()
    XCTAssertTrue(toasts.isTracking(id: upload.id))

    // Cancel waits for the work to stop, but only for the grace period.
    upload.cancel()
    XCTAssertEqual(upload.phase, .cancelling)
    scheduler.now += 11
    toasts.present(.normal, title: "Anything")          // any update or reconcile checks the grace
    XCTAssertFalse(toasts.isTracking(id: upload.id))
}

private struct ProgressExample: View {
    @State private var toasts = ToastCenter()

    var body: some View {
        VStack {
            Color.clear
                .toasts(toasts)
                .toastStyle(ProgressStyleExample())
            // The bar on its own: indeterminate, or at a fraction.
            ToastProgressBar(value: nil)
            ToastProgressBar(value: 0.4, metrics: .compact)
        }
    }
}

// MARK: - Styling

private struct BannerToastStyle: ToastStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            configuration.icon
            VStack(alignment: .leading, spacing: 2) {
                configuration.title.bold()
                configuration.message?.font(.footnote)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(14)
        .background(.indigo, in: .rect(cornerRadius: 14))
        .opacity(configuration.isLifted ? 0.85 : 1)
    }
}

private struct CardToastStyle: ToastStyle {
    static var drawsProgress: Bool { PlainToastStyle.drawsProgress }

    func makeBody(configuration: Configuration) -> some View {
        PlainToastStyle().makeBody(configuration: configuration)
            .padding()
            .background(.background, in: .rect(cornerRadius: 12))
            .shadow(radius: 8, y: 4)
    }
}

private struct StylingExample: View {
    @State private var toasts = ToastCenter()

    var body: some View {
        VStack {
            Color.clear
                .toasts(toasts)
                .toastStyle(BannerToastStyle())
            Color.clear
                .toasts(toasts)
                .toastStyle(.plain)
            Color.clear
                .toasts(toasts)
                .toastStyle(.glass)
                .toastTheme(ToastTheme(
                    titleFont: .headline,
                    tint: { status in status == .notification ? .pink : ToastTheme.standardTint(status) },
                    cornerRadius: 16
                ))
            Color.clear
                .toasts(toasts)
                .toastStyle(CardToastStyle())
        }
    }
}

/// A style that lays out the progress parts itself, sized from the metrics.
private struct ProgressStyleExample: ToastStyle {
    static var drawsProgress: Bool { true }

    func makeBody(configuration: Configuration) -> some View {
        let metrics = configuration.metrics
        VStack(alignment: .leading, spacing: metrics.progressSpacing) {
            configuration.title
                .font(metrics.titleFont)
                .lineLimit(configuration.progress == nil ? metrics.titleLineLimit : metrics.progressTitleLineLimit)
            if let progress = configuration.progress {
                if let detail = progress.detail {
                    detail.font(metrics.messageFont).monospacedDigit()
                }
                HStack(spacing: 8) {
                    progress.bar
                    progress.cancelButton
                    progress.retryButton
                }
            } else if let message = configuration.message {
                message.font(metrics.messageFont)
            }
        }
        .padding(metrics.contentPadding)
        .background(.background, in: .rect(cornerRadius: metrics.cornerRadius))
    }
}

// Stand-ins for the symbols Xcode generates from an app's asset catalog colour sets.
private extension Color {
    static let brandTextPrimary = Color.primary
    static let brandTextSecondary = Color.secondary
    static let brandNeutral = Color.gray
    static let brandWarning = Color.yellow
    static let brandDanger = Color.pink
    static let brandAccent = Color.purple
}

private extension ToastTheme {
    static let brand = ToastTheme(
        textPrimary: .brandTextPrimary,
        textSecondary: .brandTextSecondary,
        tint: ToastTheme.statusTint(
            normal: .brandNeutral,
            warning: .brandWarning,
            error: .brandDanger,
            notification: .brandAccent
        ),
        actionTint: { role in
            role == .destructive ? .brandDanger : ToastTheme.standardActionTint(role)
        }
    )

    static let onlyErrors = ToastTheme(tint: ToastTheme.statusTint(error: .brandDanger))
}

private struct DesignSystemExample: View {
    @State private var toasts = ToastCenter()

    var body: some View {
        VStack {
            Color.clear
                .toasts(toasts)
                .toastTheme(.brand)
            Color.clear
                .toasts(toasts)
                .toastTheme(.onlyErrors)
        }
    }
}

// MARK: - Placement

private struct PlacementExample: View {
    @State private var toasts = ToastCenter()

    var body: some View {
        VStack {
            Color.clear.toasts(toasts, placement: .top)
            Color.clear.toasts(toasts, width: .fraction(0.9))
            Color.clear.toasts(toasts, width: .points(320))
        }
    }
}

// MARK: - Sizing

private struct SizingExample: View {
    @State private var toasts = ToastCenter()

    var body: some View {
        VStack {
            Color.clear
                .toasts(toasts)
                .toastMetrics(.compact)
            Color.clear
                .toasts(toasts)
                .toastMetrics(.large)
            // An explicit width beats the preset's.
            Color.clear
                .toasts(toasts, width: .fraction(0.9))
                .toastMetrics(.large)
            Color.clear
                .toasts(toasts)
                .toastMetrics(ToastMetrics(
                    width: .fraction(0.8),
                    cornerRadius: 12,
                    messageLineLimit: 3,
                    progressBarHeight: 6
                ))
            Color.clear
                .toasts(toasts)
                .toastTheme(.brand)
                .toastMetrics(.compact)
        }
    }
}

/// A system tab bar: put the stack inside the tab, where the bar is in the safe area.
private struct SystemTabBarExample: View {
    @State private var toasts = ToastCenter()

    var body: some View {
        TabView {
            Text("Home")
                .toasts(toasts)
                .tabItem { Label("Home", systemImage: "house") }
        }
    }
}

/// A custom tab bar drawn over the content: mark it, and the stack clears it.
private struct CustomTabBarExample: View {
    @State private var toasts = ToastCenter()
    @State private var isExpanded = true

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear
            HStack {
                Text("Home")
                Text("Search")
            }
            .frame(maxWidth: .infinity)
            .frame(height: isExpanded ? 96 : 56)
            .background(.bar)
            .toastObstruction()
        }
        .toasts(toasts)
    }
}

/// A bar hosted outside the page that holds the stack: a scope around both.
private struct ScopeExample: View {
    @State private var toasts = ToastCenter()
    @State private var showsPlayer = true

    var body: some View {
        NavigationStack {
            Text("Library")
                .toasts(toasts)
        }
        .safeAreaInset(edge: .bottom) {
            Text("Now playing")
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(.thinMaterial)
                .toastObstruction(showsPlayer)
        }
        .toastObstructionScope()
    }
}

// MARK: - A card on its own

private struct StaticCardExample: View {
    var body: some View {
        ToastCard(toast: ToastMessage(status: .warning, title: "Low storage"))
            .frame(width: 320)
            .padding()
    }
}

// MARK: - Building them

@MainActor
final class DocumentationExamplesTests: XCTestCase {

    func testTheReadmeExamplesBuild() {
        let toasts = ToastCenter()
        let store = ExampleStore()
        presentingExamples(toasts, open: {})
        actionExamples(toasts, store: store)
        postponedExamples(toasts)
        let dismissing = ToastCenter()
        dismissalExamples(dismissing)
        XCTAssertTrue(dismissing.toasts.isEmpty)
        XCTAssertEqual(durationExamples().defaultDuration, 6)
        XCTAssertEqual(stackExamples().capacity, 8)
        let scheduled = ToastCenter(scheduler: ExampleScheduler())
        scheduled.present(.normal, title: "Timed by a fake clock")
        XCTAssertEqual(scheduled.toasts.count, 1)
        XCTAssertFalse(toasts.toasts.isEmpty)

        let progressing = ToastCenter()
        let synced = progressHandleExample(progressing)
        XCTAssertEqual(synced.phase, .succeeded)
        XCTAssertFalse(progressing.isTracking(id: synced.id))
        let hidden = hiddenExamples(progressing)
        XCTAssertFalse(hidden.isVisible)
        XCTAssertTrue(progressing.isTracking(id: hidden.id))
        progressTestingExample()

        // Compiling the views is the point; building one needs no host.
        let views: [any View] = [
            QuickStartExample(),
            ActionObserverExample(),
            StylingExample(),
            DesignSystemExample(),
            PlacementExample(),
            SizingExample(),
            SystemTabBarExample(),
            CustomTabBarExample(),
            ScopeExample(),
            StaticCardExample(),
            RemovalExample(),
            ProgressExample()
        ]
        XCTAssertEqual(views.count, 12)
    }
}
