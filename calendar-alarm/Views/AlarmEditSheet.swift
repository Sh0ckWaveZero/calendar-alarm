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
    @State private var soundName: String?
    @State private var isLoaded = false

    private static let dayComponents: Set<Calendar.Component> = [.calendar, .era, .year, .month, .day]

    /// Picked fire days, earliest first (new alarms only).
    private var sortedDays: [Date] {
        targetDays.compactMap { Calendar.current.date(from: $0) }.sorted()
    }

    /// Editing keeps its day; adding is judged by the earliest picked day.
    private var earliestDay: Date? {
        item?.time ?? sortedDays.first
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
            VStack(spacing: 12) {
                DatePicker(
                    "",
                    selection: $timeOfDay,
                    in: timeRange,
                    displayedComponents: [.hourAndMinute]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .onChange(of: targetDays) {
                    // Adding today while a past time is picked bumps the wheel
                    // to the earliest valid time.
                    if isPassed {
                        timeOfDay = Date().addingTimeInterval(120)
                    }
                }

                if item == nil {
                    daysRow
                        .padding(.horizontal, 20)
                }

                SoundPickerRow(title: Text("Sound"), selection: $soundName)
                    .padding(.horizontal, 20)

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
        .presentationDetents([.medium, .large])
    }

    /// Picked fire days (new alarms only) — pushes a multi-select calendar.
    private var daysRow: some View {
        NavigationLink {
            daysPicker
        } label: {
            HStack {
                Text("Date")
                    .foregroundStyle(Theme.text)
                Spacer()
                daysSummary
                    .foregroundStyle(Theme.accent)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.subtext)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var daysSummary: Text {
        let days = sortedDays
        if days.count == 1, let only = days.first {
            return Text(only, format: .dateTime.day().month(.abbreviated).year())
        }
        return Text("\(days.count) days")
    }

    private var daysPicker: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                MultiDatePicker(
                    "Date",
                    selection: $targetDays,
                    in: Calendar.current.startOfDay(for: Date())...
                )
                .tint(Theme.accent)
                Text("Pick one or more days. An alarm is created for each day.")
                    .font(.caption)
                    .foregroundStyle(Theme.subtext)
            }
            .padding(.horizontal, 20)
        }
        .background(Theme.background)
        .navigationTitle(Text("Select Days"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func seedValues() {
        guard !isLoaded else { return }
        isLoaded = true
        if let item {
            timeOfDay = item.time
            soundName = item.soundName
        } else {
            timeOfDay = seedTime ?? Date().addingTimeInterval(3600)
            targetDays = [Calendar.current.dateComponents(Self.dayComponents, from: day ?? Date())]
            soundName = AlarmDefaults.soundName
        }
    }
}
