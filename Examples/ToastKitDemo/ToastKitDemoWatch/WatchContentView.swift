import SwiftUI
import ToastKit

/// A compact version of the demo for the watch: each status, a stack, swipe actions
/// and a tap action, with the stack at the top or the bottom of the screen.
struct WatchContentView: View {
    @State private var toasts = ToastCenter()
    @State private var placement = ToastPlacement.bottom
    @State private var lastAction: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Present") {
                    ForEach(ToastMessage.Status.allCases, id: \.self) { status in
                        Button(status.rawValue.capitalized) {
                            toasts.present(status, title: Self.title(for: status))
                        }
                    }
                }

                Section("Stack") {
                    Button("Burst of three") {
                        toasts.present(.normal, title: "Synced")
                        toasts.present(.warning, title: "Battery low")
                        toasts.present(.notification, title: "New message")
                    }
                    Button("Dismiss all", role: .destructive) { toasts.dismissAll() }
                    Button("Bring back postponed (\(toasts.postponed.count))") { toasts.restorePostponed() }
                        .disabled(toasts.postponed.isEmpty)
                }

                Section("Actions") {
                    Button("Swipe left or right") {
                        toasts.present(ToastMessage(
                            status: .notification,
                            title: "New message",
                            message: "Swipe either way.",
                            duration: 8,
                            swipeActions: ToastSwipeActions(
                                leading: .delete(title: "Delete"),
                                trailing: .later(title: "Later")
                            )
                        ))
                    }
                    Button("Tap to undo") {
                        toasts.present(
                            .normal,
                            title: "Moved to Trash",
                            tapAction: ToastAction(id: "undo", title: "Undo") { _ in
                                lastAction = "Undo"
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
            }
            .navigationTitle("ToastKit")
            .toasts(toasts, placement: placement, width: .fraction(1))
            .onToastAction { _, action in
                lastAction = action.title
            }
        }
    }

    private static func title(for status: ToastMessage.Status) -> String {
        switch status {
        case .normal:       "Saved"
        case .warning:      "Battery low"
        case .error:        "Sync failed"
        case .notification: "New message"
        }
    }
}

#Preview {
    WatchContentView()
}
