import SwiftUI
import ToastKit

/// Switches between the glass default, `.plain` and a custom ``ToastStyle``, and between
/// the standard theme and one built with `ToastTheme.statusTint`.
struct StylesView: View {
    let toasts: ToastCenter
    @Bindable var settings: DemoSettings

    var body: some View {
        Form {
            Section {
                Picker("Style", selection: $settings.style) {
                    ForEach(StyleChoice.allCases) { choice in
                        Text(choice.rawValue).tag(choice)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Style")
            } footer: {
                Text("Glass is the default. Plain draws no surface. Custom is BannerToastStyle in DemoStyles.swift.")
            }

            Section {
                Picker("Theme", selection: $settings.theme) {
                    ForEach(ThemeChoice.allCases) { choice in
                        Text(choice.rawValue).tag(choice)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Theme")
            } footer: {
                Text("Brand maps an app palette with ToastTheme.statusTint and changes the title font and corner radius. The glass style reads the theme; the custom style ignores it.")
            }

            Section("Preview") {
                ForEach(ToastMessage.Status.allCases, id: \.self) { status in
                    Button {
                        toasts.present(
                            status,
                            title: status.displayName,
                            message: "\(settings.style.rawValue) style, \(settings.theme.rawValue) theme"
                        )
                    } label: {
                        Label(status.displayName, systemImage: status.symbolName)
                    }
                }
                Button("One of each") {
                    for status in ToastMessage.Status.allCases {
                        toasts.present(status, title: status.displayName, message: "\(settings.style.rawValue) style")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Styles")
    }
}
