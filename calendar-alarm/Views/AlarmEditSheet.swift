import SwiftUI

/// Add (item == nil) or edit (item != nil) an alarm — time plus optional sound.
/// Adding accepts several days at once and creates one alarm per day.
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
    @State private var targetDays: Set<DateComponents> = []
    @State private var editDay: Date = Date()
    @State private var soundName: String?
    @State private var isLoaded = false

    private static let dayComponents: Set<Calendar.Component> = [.calendar, .era, .year, .month, .day]

    /// Picked fire days, earliest first (new alarms only).
    private var sortedDays: [Date] {
        targetDays.compactMap { Calendar.current.date(from: $0) }.sorted()
    }

    /// Editing has one day; adding is judged by the earliest picked day.
    private var earliestDay: Date? {
        item == nil ? sortedDays.first : editDay
    }

    private var isPassed: Bool {
        guard let earliestDay else { return false }
        return DateUtil.combine(day: earliestDay, timeOfDay: timeOfDay) <= Date()
    }

    /// When the earliest fire day is today, past times are not selectable on the wheel.
    private var timeRange: ClosedRange<Date> {
        if let earliestDay, Calendar.current.isDateInToday(earliestDay) {
            return Date()...Date.distantFuture
        }
        return Date.distantPast...Date.distantFuture
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    DatePicker(
                        "",
                        selection: $timeOfDay,
                        in: timeRange,
                        displayedComponents: [.hourAndMinute]
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    // Picking today while a past time is set bumps the wheel
                    // to the earliest valid time.
                    .onChange(of: targetDays) { bumpPassedTime() }
                    .onChange(of: editDay) { bumpPassedTime() }

                    calendarCard

                    SoundPickerRow(title: Text("Sound"), selection: $soundName)

                    if item == nil && targetDays.isEmpty {
                        Text("Select at least one day.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    } else if isPassed {
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
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
                                await viewModel.updateAlarm(item, timeOfDay: timeOfDay, day: editDay, soundName: soundName)
                            } else {
                                await viewModel.addAlarms(timeOfDay: timeOfDay, days: sortedDays, soundName: soundName)
                            }
                            dismiss()
                        }
                    }
                    .disabled(isPassed || (item == nil && targetDays.isEmpty))
                }
            }
            .onAppear(perform: seedValues)
        }
    }

    /// Fire day(s): adding picks any number of days, editing moves the one day.
    private var calendarCard: some View {
        let today = Calendar.current.startOfDay(for: Date())
        return VStack(alignment: .leading, spacing: 8) {
            if item == nil {
                MultiDatePicker("Date", selection: $targetDays, in: today...)
                Text("Pick one or more days. An alarm is created for each day.")
                    .font(.caption)
                    .foregroundStyle(Theme.subtext)
            } else {
                DatePicker("Date", selection: $editDay, in: today..., displayedComponents: [.date])
                    .datePickerStyle(.graphical)
            }
        }
        .tint(Theme.accent)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func bumpPassedTime() {
        if isPassed {
            timeOfDay = Date().addingTimeInterval(120)
        }
    }

    private func seedValues() {
        guard !isLoaded else { return }
        isLoaded = true
        if let item {
            timeOfDay = item.time
            // An alarm that already fired today can only move forward.
            editDay = max(item.time, Calendar.current.startOfDay(for: Date()))
            soundName = item.soundName
        } else {
            timeOfDay = seedTime ?? Date().addingTimeInterval(3600)
            targetDays = [Calendar.current.dateComponents(Self.dayComponents, from: day ?? Date())]
            soundName = AlarmDefaults.soundName
        }
    }
}
