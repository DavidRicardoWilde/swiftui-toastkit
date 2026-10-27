import SwiftUI
import ToastKit

/// The `ToastMetrics` presets. The watch target compiles only its own files, so this does
/// not share the iOS demo's `SizeChoice`.
enum WatchSize: String, CaseIterable, Identifiable {
    case compact = "Compact"
    case regular = "Regular"
    case large = "Large"

    var id: String { rawValue }

    var metrics: ToastMetrics {
        switch self {
        case .compact: .compact
        case .regular: .regular
        case .large:   .large
        }
    }
}

/// Picks the size the watch demo's toasts are drawn at.
struct WatchSizesSection: View {
    @Binding var size: WatchSize

    var body: some View {
        Section {
            Picker("Size", selection: $size) {
                ForEach(WatchSize.allCases) { choice in
                    Text(choice.rawValue).tag(choice)
                }
            }
        } header: {
            Text("Size")
        } footer: {
            Text("Every preset is full width on the watch. Compact shows a percentage only on progress cards.")
        }
    }
}
