import SwiftUI
import ToastKit

@main
struct watchOSExampleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

/// On the watch, cards take the screen's full width; there is no room for a narrower one.
struct ContentView: View {
    @State private var settings = ExampleSettings(widthFraction: 1)

    var body: some View {
        NavigationStack {
            Form {
                ExampleControls(settings: settings)
            }
            .navigationTitle("ToastKit")
        }
        .exampleToasts(settings)
    }
}
