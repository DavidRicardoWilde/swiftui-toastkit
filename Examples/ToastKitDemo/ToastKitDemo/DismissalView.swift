import SwiftUI
import ToastKit

/// Removes toasts one at a time, by group, by test and all at once, with the removal
/// style and direction chosen below.
struct DismissalView: View {
    let toasts: ToastCenter
    @Bindable var settings: DemoSettings

    @State private var burstCount = 0
    @State private var lastID: UUID?
    @State private var scope = ScopeChoice.onScreen
    @State private var removedCount: Int?

    /// The ``ToastDismissalScope`` values, with names for a picker.
    private enum ScopeChoice: String, CaseIterable, Identifiable {
        case onScreen = "On screen"
        case postponed = "Postponed"
        case everywhere = "Everywhere"

        var id: String { rawValue }

        var scope: ToastDismissalScope {
            switch self {
            case .onScreen:   .onScreen
            case .postponed:  .postponed
            case .everywhere: .everywhere
            }
        }
    }

    private var direction: ToastRemovalDirection { settings.direction.direction }

    var body: some View {
        Form {
            Section {
                Button("Present a toast") {
                    burstCount += 1
                    let toast = ToastMessage(
                        title: "Toast #\(burstCount)",
                        message: "Dismiss it by id below.",
                        duration: .indefinite
                    )
                    lastID = toast.id
                    toasts.present(toast)
                }
                Button("Uploads ×3") {
                    for number in 1...3 {
                        toasts.present(
                            .normal,
                            title: "Uploading photo \(number) of 3",
                            message: "Dismiss them together below.",
                            duration: .indefinite,
                            group: "upload"
                        )
                    }
                }
                Button("Persistent error") {
                    toasts.present(.error, title: "Sync failed", message: "Stays until dismissed.", duration: .indefinite)
                }
                Button("Postpone front toast") {
                    if let front = toasts.topmost { toasts.postpone(id: front.id) }
                }
                .disabled(toasts.topmost == nil)
                Button("Bring back postponed (\(toasts.postponed.count))") { toasts.restorePostponed() }
                    .disabled(toasts.postponed.isEmpty)
            } header: {
                Text("Present")
            } footer: {
                Text("Persistent toasts never time out, so every removal below has something to remove.")
            }

            Section("Single") {
                Button("Dismiss the last one presented") {
                    if let lastID { toasts.dismiss(id: lastID) }
                }
                .disabled(lastID == nil)
                Button("Dismiss front toast") { toasts.dismissTopmost() }
            }

            Section {
                Button("Dismiss uploads (trail)") {
                    removedCount = toasts.dismiss(group: "upload", removal: .trail(direction))
                }
            } header: {
                Text("Group")
            } footer: {
                Text("Postponed members of the group go too.")
            }

            Section("Where") {
                Button("Dismiss errors (slide)") {
                    removedCount = toasts.dismiss(removal: .slide(direction)) { $0.status == .error }
                }
            }

            Section {
                Picker("Scope", selection: $scope) {
                    ForEach(ScopeChoice.allCases) { choice in
                        Text(choice.rawValue).tag(choice)
                    }
                }
                .pickerStyle(.segmented)
                Button("Dismiss all in scope", role: .destructive) {
                    removedCount = toasts.dismissAll(
                        removal: settings.removal.removal(direction),
                        scope: scope.scope
                    )
                }
                if let removedCount {
                    Text("Removed \(removedCount), postponed ones included.")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("All")
            } footer: {
                Text("Uses the removal style below. The postponed scope leaves the cards on screen alone.")
            }

            Section {
                Picker("Removal", selection: $settings.removal) {
                    ForEach(RemovalChoice.allCases) { choice in
                        Text(choice.rawValue).tag(choice)
                    }
                }
                .pickerStyle(.segmented)
                Picker("Direction", selection: $settings.direction) {
                    ForEach(DirectionChoice.allCases) { choice in
                        Text(choice.rawValue).tag(choice)
                    }
                }
            } header: {
                Text("Fade, slide or trail")
            } footer: {
                Text("The removal applies to toasts that expire and to Dismiss front toast. The group and error buttons always use a trail or slide in the chosen direction. With Reduce Motion on, every removal is a cross-fade.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Dismissal")
    }
}
