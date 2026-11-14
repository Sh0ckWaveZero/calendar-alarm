import SwiftUI

/// Add (item == nil) or edit (item != nil) an alarm — time plus optional sound.
/// Adding accepts several days at once and creates one alarm per day.
/// Uses standard iOS chrome: Cancel/Save in the nav bar, Clock-style delete button.
struct AlarmEditSheet: View {
    let item: AlarmItem?
    /// When adding from the calendar: the selected day the new alarm fires on.
    var day: Date? = nil
    /// Seeds the time wheel (9:00 for holiday taps; otherwise the default
    /// time from Settings, or an hour from now when that is off).
    var seedTime: Date? = nil
    @ObservedObject var viewModel: AlarmsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var timeOfDay: Date = Date()
    /// Start-of-day fire days. Adding toggles any number; editing holds one.
    @State private var selectedDays: Set<Date> = []
    @State private var monthCursor = Date()
    @State private var soundName: String?
    @State private var isLoaded = false

    private var sortedDays: [Date] { selectedDays.sorted() }

    /// The time wheel and the "already passed" check follow the earliest day.
    private var earliestDay: Date? { sortedDays.first }

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
            // The iPhone Duo outer display is 678pt tall. A full 216pt wheel
            // plus the month grid runs past the bottom and the last week is
            // clipped, so take the first stack that fits and scroll only then.
            ViewThatFits(in: .vertical) {
                editor(wheelHeight: 216)
                editor(wheelHeight: 140)
                editor(wheelHeight: 96)
                ScrollView { editor(wheelHeight: 96) }
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
                                await viewModel.updateAlarm(item, timeOfDay: timeOfDay, day: earliestDay, soundName: soundName)
                            } else {
                                await viewModel.addAlarms(timeOfDay: timeOfDay, days: sortedDays, soundName: soundName)
                            }
                            dismiss()
                        }
                    }
                    .disabled(isPassed || selectedDays.isEmpty)
                }
            }
            .onAppear(perform: seedValues)
        }
        .presentationSizing(.page)
        .presentationDetents([.large])
        .presentationContentInteraction(.scrolls)
    }

    private func editor(wheelHeight: CGFloat) -> some View {
        VStack(spacing: 8) {
            DatePicker(
                "",
                selection: $timeOfDay,
                in: timeRange,
                displayedComponents: [.hourAndMinute]
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(height: wheelHeight)
            .clipped()
            // Picking today while a past time is set bumps the wheel
            // to the earliest valid time.
            .onChange(of: selectedDays) { bumpPassedTime() }

            calendarCard

            SoundPickerRow(title: Text("Sound"), selection: $soundName)

            if selectedDays.isEmpty {
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
        .padding(.bottom, 8)
    }

    /// Fire day(s) on the app's own month grid, so alarm and holiday dots show
    /// while picking. Adding toggles days; editing moves the single day.
    private var calendarCard: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let isCurrentMonth = calendar.isDate(monthCursor, equalTo: today, toGranularity: .month)
        return VStack(alignment: .leading, spacing: 6) {
            CalendarHeaderView(
                title: CalendarHeaderView.title(for: .month, cursor: monthCursor),
                onToday: { monthCursor = today },
                onPrevious: { if !isCurrentMonth { moveMonth(by: -1) } },
                onNext: { moveMonth(by: 1) }
            )
            CalendarGridView(
                mode: .month,
                cursor: monthCursor,
                alarmDays: viewModel.daysWithAlarms,
                holidayDays: Set(viewModel.holidays.map(\.date)),
                selectedDays: selectedDays,
                minimumDay: today,
                onSelect: select
            )
            CalendarDotLegend()
                .padding(.horizontal, 16)
            if item == nil {
                Text("Pick one or more days. An alarm is created for each day.")
                    .font(.caption)
                    .foregroundStyle(Theme.subtext)
                    .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 4)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .task(id: monthCursor) {
            viewModel.loadHolidaysIfNeeded(around: monthCursor)
        }
    }

    private func select(_ day: Date) {
        if item != nil {
            selectedDays = [day]
        } else if selectedDays.contains(day) {
            selectedDays.remove(day)
        } else {
            selectedDays.insert(day)
        }
    }

    private func moveMonth(by value: Int) {
        monthCursor = Calendar.current.date(byAdding: .month, value: value, to: monthCursor) ?? monthCursor
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
            let editDay = Calendar.current.startOfDay(for: max(item.time, Date()))
            selectedDays = [editDay]
            monthCursor = editDay
            soundName = item.soundName
        } else {
            var time = seedTime ?? AlarmDefaults.timeOfDay ?? Date().addingTimeInterval(3600)
            var seedDay = day ?? Date()
            if DateUtil.combine(day: seedDay, timeOfDay: time) <= Date() {
                // The seeded time already passed today: without a picked day
                // the alarm moves to tomorrow, otherwise the time moves ahead.
                if day == nil {
                    seedDay = DateUtil.nextOccurrence(of: time)
                } else {
                    time = Date().addingTimeInterval(3600)
                }
            }
            timeOfDay = time
            selectedDays = [Calendar.current.startOfDay(for: seedDay)]
            monthCursor = seedDay
            soundName = AlarmDefaults.soundName
        }
    }
}
