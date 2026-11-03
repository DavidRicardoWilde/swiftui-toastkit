import Foundation
import SwiftUI
import ToastKit

/// Presents toasts that exercise each behaviour: the stack, tapping, swiping in any direction,
/// pressing and holding, placement and the custom tab bar. Dismissal and progress have
/// their own tabs.
struct PlaygroundView: View {
    let toasts: ToastCenter
    @Bindable var settings: DemoSettings

    @State private var burstCount = 0

    var body: some View {
        Form {
            Section("Present") {
                ForEach(ToastMessage.Status.allCases, id: \.self) { status in
                    Button {
                        toasts.present(status, title: status.displayName, message: String(localized: "A \(status.displayName) toast."))
                    } label: {
                        Label(status.displayName, systemImage: status.symbolName)
                    }
                }
            }

            Section {
                Button("Burst of 4") {
                    for status in ToastMessage.Status.allCases {
                        burstCount += 1
                        toasts.present(status, title: String(localized: "Toast #\(burstCount)"), message: String(localized: "Only the front card counts down."))
                    }
                }
                Button("Persistent toast") {
                    toasts.present(
                        .error,
                        title: String(localized: "Sync failed"),
                        message: String(localized: "Stays until you swipe it away."),
                        duration: .indefinite
                    )
                }
                Button("Dismiss all", role: .destructive) { toasts.dismissAll() }
                Button("Bring back postponed (\(toasts.postponed.count))") { toasts.restorePostponed() }
                    .disabled(toasts.postponed.isEmpty)
            } header: {
                Text("Stacking")
            } footer: {
                Text("Up to three cards show; older ones peek out behind the newest. Swiping right sets a toast aside for later; postponed toasts come back when you switch tabs, or right away with the button above. The Dismissal tab has the single, group, error and trail removals.")
            }

            Section("Tap") {
                Button("Toast with a tap action") {
                    toasts.present(
                        .normal,
                        title: String(localized: "Moved to Trash"),
                        message: String(localized: "Tap to undo"),
                        icon: .system("trash"),
                        tapAction: ToastAction(id: "undo", title: String(localized: "Undo")) { toast in
                            settings.recentActions.append(String(localized: "Undo handler ran for “\(toast.title)”"))
                        }
                    )
                }
            }

            Section {
                Button("Custom swipe actions") {
                    toasts.present(ToastMessage(
                        status: .notification,
                        title: String(localized: "New message"),
                        message: String(localized: "Swipe left or right, or press and hold to see both actions."),
                        icon: .system("envelope"),
                        duration: 8,
                        swipeActions: ToastSwipeActions(
                            leading: .delete(title: String(localized: "Delete"), subtitle: String(localized: "Gone for good")),
                            trailing: ToastAction(
                                id: "archive",
                                title: String(localized: "Archive"),
                                subtitle: String(localized: "Keeps a copy"),
                                icon: .system("archivebox"),
                                confirmation: String(localized: "Archived"),
                                role: .subdued,
                                effect: .dismiss
                            )
                        )
                    ))
                }
                Button("Snooze to the right") {
                    toasts.present(
                        .warning,
                        title: String(localized: "Battery low"),
                        message: String(localized: "Swipe right to snooze it until later."),
                        swipeActions: ToastSwipeActions(trailing: .later(title: String(localized: "Snooze")))
                    )
                }
                Button("Swipe up or down") {
                    toasts.present(ToastMessage(
                        status: .notification,
                        title: String(localized: "Meeting in 5 minutes"),
                        message: String(localized: "Swipe up to snooze, down to dismiss."),
                        icon: .system("calendar"),
                        duration: 8,
                        swipeActions: .vertical(
                            up: .later(title: String(localized: "Snooze")),
                            down: .delete(title: String(localized: "Dismiss"))
                        )
                    ))
                }
                Button("Swipe all four ways") {
                    toasts.present(ToastMessage(
                        status: .normal,
                        title: String(localized: "Photo saved"),
                        message: String(localized: "Swipe any way, or press and hold."),
                        icon: .system("photo"),
                        duration: 8,
                        swipeActions: ToastSwipeActions(
                            leading: .delete(title: String(localized: "Delete")),
                            trailing: .later(title: String(localized: "Later")),
                            up: ToastAction(
                                id: "favorite",
                                title: String(localized: "Favorite"),
                                icon: .system("heart"),
                                confirmation: String(localized: "Favorited"),
                                role: .subdued,
                                effect: .dismiss
                            ),
                            down: ToastAction(
                                id: "share",
                                title: String(localized: "Share"),
                                icon: .system("square.and.arrow.up"),
                                role: .subdued,
                                effect: .dismiss
                            )
                        )
                    ))
                }
                Button("No swiping") {
                    toasts.present(
                        .normal,
                        title: String(localized: "Swipe disabled"),
                        message: String(localized: "This one only times out."),
                        swipeActions: .disabled
                    )
                }
            } header: {
                Text("Swipe, press and hold")
            } footer: {
                Text("Press and hold a card to lift it onto a track with its actions, then carry it to one end. With immediate swipe hints the track appears as soon as a swipe starts.")
            }

            Section("Swipe hints") {
                Toggle("Show the track as a swipe starts", isOn: $settings.immediateSwipeHints)
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
