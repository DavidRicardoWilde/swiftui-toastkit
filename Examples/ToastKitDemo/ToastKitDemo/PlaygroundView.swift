import SwiftUI
import ToastKit

/// Presents toasts that exercise each behaviour: the stack, tapping, swiping either way,
/// pressing and holding, placement and the custom tab bar.
struct PlaygroundView: View {
    let toasts: ToastCenter
    @Bindable var settings: DemoSettings

    @State private var burstCount = 0

    var body: some View {
        Form {
            Section("Present") {
                ForEach(ToastMessage.Status.allCases, id: \.self) { status in
                    Button {
                        toasts.present(status, title: status.displayName, message: "A \(status.rawValue) toast.")
                    } label: {
                        Label(status.displayName, systemImage: status.symbolName)
                    }
                }
            }

            Section {
                Button("Burst of 4") {
                    for status in ToastMessage.Status.allCases {
                        burstCount += 1
                        toasts.present(status, title: "Toast #\(burstCount)", message: "Only the front card counts down.")
                    }
                }
                Button("Persistent toast") {
                    toasts.present(
                        .error,
                        title: "Sync failed",
                        message: "Stays until you swipe it away.",
                        duration: .indefinite
                    )
                }
                Button("Dismiss front toast") { toasts.dismissTopmost() }
                Button("Dismiss all", role: .destructive) { toasts.dismissAll() }
                Button("Bring back postponed (\(toasts.postponed.count))") { toasts.restorePostponed() }
                    .disabled(toasts.postponed.isEmpty)
            } header: {
                Text("Stacking")
            } footer: {
                Text("Up to three cards show; older ones peek out behind the newest. Swiping right sets a toast aside for later; postponed toasts come back when you switch tabs, or right away with the button above.")
            }

            Section("Tap") {
                Button("Toast with a tap action") {
                    toasts.present(
                        .normal,
                        title: "Moved to Trash",
                        message: "Tap to undo",
                        icon: .system("trash"),
                        tapAction: ToastAction(id: "undo", title: "Undo") { toast in
                            settings.recentActions.append("Undo handler ran for “\(toast.title)”")
                        }
                    )
                }
            }

            Section {
                Button("Custom swipe actions") {
                    toasts.present(ToastMessage(
                        status: .notification,
                        title: "New message",
                        message: "Swipe left or right, or press and hold to see both actions.",
                        icon: .system("envelope"),
                        duration: 8,
                        swipeActions: ToastSwipeActions(
                            leading: .delete(title: "Delete", subtitle: "Gone for good"),
                            trailing: ToastAction(
                                id: "archive",
                                title: "Archive",
                                subtitle: "Keeps a copy",
                                icon: .system("archivebox"),
                                confirmation: "Archived",
                                role: .subdued,
                                effect: .dismiss
                            )
                        )
                    ))
                }
                Button("Snooze to the right") {
                    toasts.present(
                        .warning,
                        title: "Battery low",
                        message: "Swipe right to snooze it until later.",
                        swipeActions: ToastSwipeActions(trailing: .later(title: "Snooze"))
                    )
                }
                Button("No swiping") {
                    toasts.present(
                        .normal,
                        title: "Swipe disabled",
                        message: "This one only times out.",
                        swipeActions: .disabled
                    )
                }
            } header: {
                Text("Swipe left / right, press and hold")
            } footer: {
                Text("Press and hold a card to lift it onto a track with both actions, then carry it to one end.")
            }

            Section("Placement") {
                Picker("Placement", selection: $settings.placement) {
                    Text("Top").tag(ToastPlacement.top)
                    Text("Bottom").tag(ToastPlacement.bottom)
                }
                .pickerStyle(.segmented)
                Toggle("Tall custom tab bar", isOn: $settings.tallTabBar)
            }

            Section("Recent actions") {
                if settings.recentActions.isEmpty {
                    Text("Tap or swipe a toast.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(settings.recentActions.enumerated().reversed()), id: \.offset) { _, entry in
                        Text(entry)
                            .font(.callout)
                    }
                    Button("Clear", role: .destructive) { settings.recentActions.removeAll() }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Playground")
    }
}
