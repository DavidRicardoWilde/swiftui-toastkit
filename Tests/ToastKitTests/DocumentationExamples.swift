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

    // Up and down instead of sideways, or all four ways.
    let pin = ToastAction(title: "Pin", icon: .system("pin")) { toast in store.archive(toast.id) }
    toasts.present(ToastMessage(title: "Up or down", swipeActions: .vertical(up: pin, down: .delete)))
    toasts.present(ToastMessage(title: "Any way", swipeActions: ToastSwipeActions(
        leading: .delete,
        trailing: .later,
        up: pin,
        down: ToastAction(title: "Archive", icon: .system("archivebox")) { toast in store.archive(toast.id) }
    )))
    toasts.present(ToastMessage(title: "Sideways", swipeActions: .horizontal(leading: .delete, trailing: nil)))

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

/// Both swipe actions on show from the first moment of a swipe, without a hold.
private struct SwipeHintsExample: View {
    @State private var toasts = ToastCenter()

    var body: some View {
        Text("Inbox")
            .toasts(toasts)
            .toastSwipeHints(.immediate)
    }
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
        XCTAssertEqual(durationExamples().defaultDuration, 6)
        XCTAssertEqual(stackExamples().capacity, 8)
        let scheduled = ToastCenter(scheduler: ExampleScheduler())
        scheduled.present(.normal, title: "Timed by a fake clock")
        XCTAssertEqual(scheduled.toasts.count, 1)
        XCTAssertFalse(toasts.toasts.isEmpty)

        // Compiling the views is the point; building one needs no host.
        let views: [any View] = [
            QuickStartExample(),
            SwipeHintsExample(),
            ActionObserverExample(),
            StylingExample(),
            PlacementExample(),
            SystemTabBarExample(),
            CustomTabBarExample(),
            ScopeExample(),
            StaticCardExample()
        ]
        XCTAssertEqual(views.count, 9)
    }
}
