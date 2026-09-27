import SwiftUI

/// Add (item == nil) or edit (item != nil) an alarm — time plus optional sound.
/// Uses standard iOS chrome: Cancel/Save in the nav bar, Clock-style delete button.
struct AlarmEditSheet: View {
    let item: AlarmItem?
    /// When adding from the calendar: the selected day the new alarm fires on.
    var day: Date? = nil
    /// Seeds the time wheel (9:00 for holiday taps; otherwise an hour from now).
    var seedTime: Date? = nil
    @ObservedObject var viewModel: AlarmsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var timeOfDay: Date = Date()
    @State private var targetDay: Date = Calendar.current.startOfDay(for: Date())
    @State private var soundName: String?
    @State private var isLoaded = false

    /// Editing keeps its day; adding uses the picked day (seeded from the
    /// calendar selection, otherwise today).
    private var resolvedDate: Date {
        if let item {
            return DateUtil.combine(day: item.time, timeOfDay: timeOfDay)
        }
        return DateUtil.combine(day: targetDay, timeOfDay: timeOfDay)
    }

    private var isPassed: Bool { resolvedDate <= Date() }

    /// When the fire day is today, past times are not selectable on the wheel.
    private var timeRange: ClosedRange<Date> {
        let day = item?.time ?? targetDay
        if Calendar.current.isDateInToday(day) {
            return Date()...Date.distantFuture
        }
        return Date.distantPast...Date.distantFuture
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                DatePicker(
                    "",
                    selection: $timeOfDay,
                    in: timeRange,
                    displayedComponents: [.hourAndMinute]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .onChange(of: targetDay) { _, newDay in
                    // Switching back to today while a past time is picked bumps
                    // the wheel to the earliest valid time.
                    if Calendar.current.isDateInToday(newDay),
                       DateUtil.combine(day: newDay, timeOfDay: timeOfDay) <= Date() {
                        timeOfDay = Date().addingTimeInterval(120)
                    }
                }

                if item == nil {
                    dayPicker
                        .padding(.horizontal, 20)
                }

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
                                await viewModel.addAlarm(timeOfDay: timeOfDay, day: targetDay, soundName: soundName)
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

    /// Picked fire day (new alarms only) — compact native date picker in a card row.
    private var dayPicker: some View {
        HStack {
            Text("Date")
                .foregroundStyle(Theme.text)
            Spacer()
            DatePicker(
                "",
                selection: $targetDay,
                in: Calendar.current.startOfDay(for: Date())...,
                displayedComponents: [.date]
            )
            .labelsHidden()
            .tint(Theme.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
            timeOfDay = seedTime ?? Date().addingTimeInterval(3600)
            targetDay = Calendar.current.startOfDay(for: day ?? Date())
            soundName = nil
        }
    }
}
