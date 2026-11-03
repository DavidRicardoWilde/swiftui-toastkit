import Foundation
import SwiftUI
import ToastKit

/// A compact version of the demo for the watch: each status, a stack, swipe actions
/// and a tap action, with the stack at the top or the bottom of the screen.
struct WatchContentView: View {
    @State private var toasts = ToastCenter()
    @State private var placement = ToastPlacement.bottom
    @State private var lastAction: String?
    @State private var size = WatchSize.regular
    @State private var immediateSwipeHints = false

    var body: some View {
        NavigationStack {
            List {
                Section("Present") {
                    ForEach(ToastMessage.Status.allCases, id: \.self) { status in
                        Button(Self.displayName(for: status)) {
                            toasts.present(status, title: Self.title(for: status))
                        }
                    }
                }

                Section("Stack") {
                    Button("Burst of three") {
                        toasts.present(.normal, title: String(localized: "Synced"))
                        toasts.present(.warning, title: String(localized: "Battery low"))
                        toasts.present(.notification, title: String(localized: "New message"))
                    }
                    Button("Dismiss all", role: .destructive) { toasts.dismissAll() }
                    Button("Bring back postponed (\(toasts.postponed.count))") { toasts.restorePostponed() }
                        .disabled(toasts.postponed.isEmpty)
                }

                Section("Actions") {
                    Button("Swipe left or right") {
                        toasts.present(ToastMessage(
                            status: .notification,
                            title: String(localized: "New message"),
                            message: String(localized: "Swipe either way."),
                            duration: 8,
                            swipeActions: ToastSwipeActions(
                                leading: .delete(title: String(localized: "Delete")),
                                trailing: .later(title: String(localized: "Later"))
                            )
                        ))
                    }
                    Button("Swipe up or down") {
                        toasts.present(ToastMessage(
                            status: .notification,
                            title: String(localized: "Meeting in 5 minutes"),
                            message: String(localized: "Swipe up or down."),
                            duration: 8,
                            swipeActions: .vertical(
                                up: .later(title: String(localized: "Snooze")),
                                down: .delete(title: String(localized: "Dismiss"))
                            )
                        ))
                    }
                    Toggle("Instant hints", isOn: $immediateSwipeHints)
                    Button("Tap to undo") {
                        toasts.present(
                            .normal,
                            title: String(localized: "Moved to Trash"),
                            tapAction: ToastAction(id: "undo", title: String(localized: "Undo")) { _ in
                                lastAction = String(localized: "Undo")
                            }
                        )
                    }
                    if let lastAction {
                        Text("Last: \(lastAction)")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Placement") {
                    Picker("Placement", selection: $placement) {
                        Text("Top").tag(ToastPlacement.top)
                        Text("Bottom").tag(ToastPlacement.bottom)
                    }
                }

                WatchSizesSection(size: $size)

                WatchDismissSection(toasts: toasts)

                WatchProgressSection(toasts: toasts)
            }
            .navigationTitle("ToastKit")
            .toasts(toasts, placement: placement)
            .toastMetrics(size.metrics)
            .toastSwipeHints(immediateSwipeHints ? .immediate : .afterHold)
            .onToastAction { _, action in
                lastAction = action.title
            }
        }
    }

    private static func displayName(for status: ToastMessage.Status) -> String {
        switch status {
        case .normal:       String(localized: "Normal")
        case .warning:      String(localized: "Warning")
        case .error:        String(localized: "Error")
        case .notification: String(localized: "Notification")
        }
    }

    private static func title(for status: ToastMessage.Status) -> String {
        switch status {
        case .normal:       String(localized: "Saved")
        case .warning:      String(localized: "Battery low")
        case .error:        String(localized: "Sync failed")
        case .notification: String(localized: "New message")
        }
    }
}

#Preview {
    WatchContentView()
}
