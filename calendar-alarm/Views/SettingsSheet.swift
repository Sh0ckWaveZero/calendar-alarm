import SwiftUI

/// In-app settings: theme (light/dark/system), language (English/Thai/system),
/// and the floating add-button side. Values live in App Storage and take effect
/// immediately — the root view maps them to preferredColorScheme and the locale
/// environment. Flat layout (no grouped Form) so controls aren't double-boxed.
struct SettingsSheet: View {
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    @AppStorage("appLanguage") private var appLanguage = "system"
    @AppStorage("addButtonSide") private var addButtonSide = "left"
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    section(title: Text("Theme")) {
                        Picker("Theme", selection: $appearanceMode) {
                            Text("System").tag("system")
                            Text("Light").tag("light")
                            Text("Dark").tag("dark")
                        }
                        .pickerStyle(.segmented)
                    } caption: {
                        Text("System follows your device appearance.")
                    }

                    section(title: Text("Language")) {
                        Picker("Language", selection: $appLanguage) {
                            Text("System").tag("system")
                            Text(verbatim: "English").tag("en")
                            Text(verbatim: "ไทย").tag("th")
                        }
                        .pickerStyle(.segmented)
                    } caption: {
                        Text("System follows your device language.")
                    }

                    section(title: Text("Add Button")) {
                        Picker("Add Button", selection: $addButtonSide) {
                            Text("Left").tag("left")
                            Text("Right").tag("right")
                        }
                        .pickerStyle(.segmented)
                    } caption: {
                        Text("Where the floating + button sits.")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .navigationTitle(Text("Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func section<Control: View, Caption: View>(
        title: Text,
        @ViewBuilder control: () -> Control,
        @ViewBuilder caption: () -> Caption
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            title
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.text)
            control()
            caption()
                .font(.caption)
                .foregroundStyle(Theme.subtext)
        }
    }
}
