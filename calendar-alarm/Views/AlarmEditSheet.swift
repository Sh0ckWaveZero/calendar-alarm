import SwiftUI

/// Add (item == nil) or edit (item != nil) an alarm — time plus optional sound.
/// Uses standard iOS chrome: Cancel/Save in the nav bar, Clock-style delete button.
struct AlarmEditSheet: View {
    let item: AlarmItem?
    @ObservedObject var viewModel: AlarmsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var timeOfDay: Date = Date()
    @State private var soundName: String?
    @State private var isLoaded = false

    /// For editing, the alarm keeps its day; the candidate must still be in the future.
    private var resolvedDate: Date {
        if let item {
            return DateUtil.combine(day: item.time, timeOfDay: timeOfDay)
        }
        return DateUtil.nextOccurrence(of: timeOfDay)
    }

    private var isPassed: Bool { resolvedDate <= Date() }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                DatePicker(
                    "",
                    selection: $timeOfDay,
                    displayedComponents: [.hourAndMinute]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()

                soundPicker
                    .padding(.horizontal, 20)

                if isPassed {
                    Text("This time has already passed.")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if item != nil {
                    Button(role: .destructive) {
                        Task {
                            await viewModel.deleteAlarm(item!)
                            dismiss()
                        }
                    } label: {
                        Text("Delete Alarm")
                    }
                    .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background)
            .navigationTitle(item == nil ? Text("New Alarm") : Text("Edit Alarm"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if let item {
                                await viewModel.updateAlarm(item, timeOfDay: timeOfDay, soundName: soundName)
                            } else {
                                await viewModel.addAlarm(timeOfDay: timeOfDay, soundName: soundName)
                            }
                            dismiss()
                        }
                    }
                    .disabled(isPassed)
                }
            }
            .onAppear(perform: seedValues)
        }
        .presentationDetents([.medium])
    }

    private var soundPicker: some View {
        HStack {
            Text("Sound")
                .foregroundStyle(Theme.text)
            Spacer()
            Picker("Sound", selection: $soundName) {
                Text(String(localized: "Default")).tag(String?.none)
                ForEach(SoundCatalog.sounds, id: \.file) { sound in
                    Text(sound.label).tag(String?.some(sound.file))
                }
            }
            .pickerStyle(.menu)
            .tint(Theme.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func seedValues() {
        guard !isLoaded else { return }
        isLoaded = true
        if let item {
            timeOfDay = item.time
            soundName = item.soundName
        } else {
            timeOfDay = Date().addingTimeInterval(3600)
            soundName = nil
        }
    }
}
