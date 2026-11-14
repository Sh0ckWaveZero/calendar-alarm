import SwiftUI

/// In-app settings: theme (light/dark/system), language (English/Thai/system),
/// the default alarm time and sound, and the floating add-button side. Values live in App Storage and take effect
/// immediately — the root view maps them to preferredColorScheme and the locale
/// environment. Flat layout (no grouped Form) so controls aren't double-boxed.
struct SettingsSheet: View {
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    @AppStorage("appLanguage") private var appLanguage = "system"
    @AppStorage("addButtonSide") private var addButtonSide = "left"
    @AppStorage(AlarmDefaults.soundKey) private var defaultSoundName: String?
    @AppStorage(AlarmDefaults.timeEnabledKey) private var defaultTimeEnabled = false
    @AppStorage(AlarmDefaults.timeMinutesKey) private var defaultTimeMinutes = AlarmDefaults.fallbackTimeMinutes

    private var defaultTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: defaultTimeMinutes / 60, minute: defaultTimeMinutes % 60, second: 0, of: Date()
                ) ?? Date()
            },
            set: {
                let parts = Calendar.current.dateComponents([.hour, .minute], from: $0)
                defaultTimeMinutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }
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

                    section(title: Text("Default Time")) {
                        VStack(spacing: 0) {
                            Toggle(isOn: $defaultTimeEnabled) {
                                Text("Use a default time")
                                    .foregroundStyle(Theme.text)
                            }
                            .tint(Theme.accent)
                            .padding(.vertical, 8)
                            if defaultTimeEnabled {
                                Divider()
                                DatePicker(selection: defaultTime, displayedComponents: [.hourAndMinute]) {
                                    Text("Time")
                                        .foregroundStyle(Theme.text)
                                }
                                .tint(Theme.accent)
                                .padding(.vertical, 6)
                            }
                        }
                        .padding(.horizontal, 14)
                        .background(Theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    } caption: {
                        Text("New alarms start at this time. You can still change the time for each alarm.")
                    }

                    section(title: Text("Default Sound")) {
                        SoundPickerRow(title: Text("Sound"), selection: $defaultSoundName)
                    } caption: {
                        Text("Used for new alarms. You can still change the sound for each alarm.")
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
        .presentationSizing(.page)
        .presentationDetents([.large])
        .presentationContentInteraction(.scrolls)
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
