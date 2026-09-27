import SwiftUI

/// Month or week display inside the alarms list header.
enum CalendarDisplayMode {
    case month
    case week
}

/// Static header above the paging calendar: title, Today, and chevrons.
struct CalendarHeaderView: View {
    let title: String
    var onToday: () -> Void
    var onPrevious: () -> Void
    var onNext: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.text)
            Spacer()
            Button(action: onToday) {
                Text("Today")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Theme.accent))
            }
            .buttonStyle(.plain)
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Previous month"))
            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Next month"))
        }
        .tint(Theme.accent)
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    /// "September 2569 BE" for months, "27 Sep – 3 Oct" for a week strip.
    static func title(for mode: CalendarDisplayMode, cursor: Date, calendar: Calendar = .current) -> String {
        switch mode {
        case .month:
            return cursor.formatted(.dateTime.month(.wide).year())
        case .week:
            let days = CalendarGrid.weekDays(for: cursor, calendar: calendar)
            guard let first = days.first, let last = days.last else { return "" }
            if calendar.isDate(first, equalTo: last, toGranularity: .month) {
                return "\(first.formatted(.dateTime.month(.abbreviated).day())) – \(last.formatted(.dateTime.day()))"
            }
            return "\(first.formatted(.dateTime.month(.abbreviated).day())) – \(last.formatted(.dateTime.month(.abbreviated).day()))"
        }
    }
}

/// One calendar page: weekday symbols plus the day grid for `cursor`'s month/week.
/// Days with alarms get a bell-colored dot; holidays a red dot; the selected day
/// a filled circle. Slid by a TabView in the parent — never handles its own swipe.
struct CalendarGridView: View {
    let mode: CalendarDisplayMode
    /// The date the page is anchored to (its month, or any day of its week).
    let cursor: Date
    let alarmDays: Set<Date>
    let holidayDays: Set<Date>
    @Binding var selection: Date?

    private let calendar = Calendar.current
    private var columns: [GridItem] { Array(repeating: GridItem(.flexible()), count: 7) }

    private var gridRows: [[Date]] {
        mode == .month ? CalendarGrid.monthRows(for: cursor, calendar: calendar)
                       : [CalendarGrid.weekDays(for: cursor, calendar: calendar)]
    }

    var body: some View {
        VStack(spacing: 10) {
            LazyVGrid(columns: columns, spacing: 6) {
                // Index-based id — the short symbols repeat ("S", "T").
                ForEach(Array(CalendarGrid.weekdaySymbols(calendar: calendar).enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Theme.subtext)
                }
            }

            ForEach(gridRows.indices, id: \.self) { row in
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(gridRows[row], id: \.self) { day in
                        cell(for: day)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func cell(for day: Date) -> some View {
        let dayStart = calendar.startOfDay(for: day)
        let isSelected = selection == dayStart
        let isToday = dayStart == calendar.startOfDay(for: Date())
        let hasAlarm = alarmDays.contains(dayStart)
        let hasHoliday = holidayDays.contains(dayStart)
        let inScope = calendar.isDate(day, equalTo: cursor, toGranularity: mode == .month ? .month : .weekOfYear)

        Button {
            selection = dayStart
        } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.subheadline.monospacedDigit())
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundStyle(isSelected ? Color.white : (inScope ? Theme.text : Theme.subtext.opacity(0.5)))
                    .frame(width: 32, height: 32)
                    .background {
                        if isSelected {
                            Circle().fill(Theme.accent)
                        } else if isToday {
                            Circle().stroke(Theme.accent.opacity(0.5), lineWidth: 1.5)
                        }
                    }
                // Bell-colored dot = alarm, red dot = holiday (both can coexist).
                HStack(spacing: 3) {
                    if hasAlarm {
                        Circle().fill(Theme.bellOn).frame(width: 5, height: 5)
                    }
                    if hasHoliday {
                        Circle().fill(Theme.danger).frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
        }
        .buttonStyle(.plain)
    }
}
