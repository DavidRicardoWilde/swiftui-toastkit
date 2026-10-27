import SwiftUI
import ToastKit

/// Removes toasts: the front one, a group and everything, with a chosen direction.
struct WatchDismissSection: View {
    let toasts: ToastCenter

    @State private var direction = Direction.towardAnchor

    /// The directions worth a tap on a small screen.
    private enum Direction: String, CaseIterable, Identifiable {
        case towardAnchor = "Toward edge"
        case awayFromAnchor = "Away from edge"
        case leading = "Leading"
        case trailing = "Trailing"

        var id: String { rawValue }

        var value: ToastRemovalDirection {
            switch self {
            case .towardAnchor:   .towardAnchor
            case .awayFromAnchor: .awayFromAnchor
            case .leading:        .leading
            case .trailing:       .trailing
            }
        }
    }

    var body: some View {
        Section {
            Button("Dismiss front toast") { toasts.dismissTopmost() }
            Button("Uploads ×3") {
                for number in 1...3 {
                    toasts.present(
                        .normal,
                        title: "Uploading \(number) of 3",
                        duration: .indefinite,
                        group: "upload"
                    )
                }
            }
            Button("Dismiss uploads") {
                toasts.dismiss(group: "upload", removal: .trail(direction.value))
            }
            Button("Trail all") {
                toasts.dismissAll(removal: .trail(direction.value))
            }
            Picker("Direction", selection: $direction) {
                ForEach(Direction.allCases) { choice in
                    Text(choice.rawValue).tag(choice)
                }
            }
        } header: {
            Text("Dismiss")
        }
    }
}
