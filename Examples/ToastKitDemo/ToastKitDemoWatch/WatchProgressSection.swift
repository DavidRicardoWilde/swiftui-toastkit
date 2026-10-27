import SwiftUI
import ToastKit

/// A workout-sync flow: indeterminate while connecting, then a bar, with Cancel and a
/// result.
struct WatchProgressSection: View {
    let toasts: ToastCenter

    var body: some View {
        Section {
            Button("Sync workout") { syncWorkout() }
            Button("Sync, then fail") { syncWorkout(failing: true) }
        } header: {
            Text("Progress")
        } footer: {
            Text("Starts as Connecting…, then fills. Cancel is on the card. Success plays a selection haptic. Compact shows the percentage only.")
        }
    }

    @MainActor
    private func syncWorkout(failing: Bool = false) {
        let handle = toasts.track(
            title: "Syncing workout",
            message: "Connecting…",
            icon: .system("figure.run")
        )
        let task = Task { @MainActor in
            try await Task.sleep(for: .seconds(2))
            handle.update(title: nil, message: .some(nil))
            for step in 1...20 {
                try await Task.sleep(for: .milliseconds(200))
                handle.update(fraction: Double(step) / 20)
                if failing, step == 14 {
                    handle.fail(ToastProgressResult(title: "Sync failed", message: "Try again from your phone."))
                    return
                }
            }
            handle.succeed(ToastProgressResult(title: "Workout synced"))
        }
        handle.cancels(task)
    }
}
