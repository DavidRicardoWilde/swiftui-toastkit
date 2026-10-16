import SwiftUI
import ToastKit

@main
struct iOSExampleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

/// A tab view, the usual home for toasts on iPhone and iPad. Each tab attaches its own
/// stack to its content, so the stack sits in the tab's safe area, above the tab bar.
struct ContentView: View {
    @State private var settings = ExampleSettings()

    var body: some View {
        TabView {
            NavigationStack {
                Form {
                    ExampleControls(settings: settings)
                }
                .navigationTitle("ToastKit")
            }
            .exampleToasts(settings)
            .tabItem { Label("Playground", systemImage: "rectangle.stack") }

            StylesExample()
                .tabItem { Label("Styles", systemImage: "paintpalette") }
        }
    }
}
