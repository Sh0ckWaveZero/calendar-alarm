import SwiftUI

/// Month or week display inside the alarms list header.
enum CalendarDisplayMode {
    case month
    case week
}

/// Header (`‹ title ›`), weekday symbols, and the day grid for month/week mode.
/// Days with alarms get a bell-colored dot; the selected day gets a filled circle.
struct CalendarGridView: View {
    let mode: CalendarDisplayMode
    /// The date the grid is anchored to (drives chevrons and in-month styling).
    let cursor: Date
    let alarmDays: Set<Date>
    @Binding var selection: Date?
    var onPrevious: () -> Void
    var onNext: () -> Void

    private let calendar = Calendar.current
    private var columns: [GridItem] { Array(repeating: GridItem(.flexible()), count: 7) }

    private var gridRows: [[Date]] {
        mode == .month ? CalendarGrid.monthRows(for: cursor, calendar: calendar)
                       : [CalendarGrid.weekDays(for: cursor, calendar: calendar)]
    }

    private var title: String {
        mode == .month
            ? cursor.formatted(.dateTime.month(.wide).year())
            : weekTitle
    }

    /// "Sep 21 – 27" for a single-week strip.
    private var weekTitle: String {
        let days = CalendarGrid.weekDays(for: cursor, calendar: calendar)
        guard let first = days.first, let last = days.last else { return "" }
        if calendar.isDate(first, equalTo: last, toGranularity: .month) {
            return "\(first.formatted(.dateTime.month(.abbreviated).day())) – \(last.formatted(.dateTime.day()))"
        }
        return "\(first.formatted(.dateTime.month(.abbreviated).day())) – \(last.formatted(.dateTime.month(.abbreviated).day()))"
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button(action: onPrevious) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .frame(width: 32, height: 32)
                }
                Spacer()
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.text)
                Spacer()
                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .frame(width: 32, height: 32)
                }
            }
            .tint(Theme.accent)

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
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func cell(for day: Date) -> some View {
        let dayStart = calendar.startOfDay(for: day)
        let isSelected = selection == dayStart
        let isToday = dayStart == calendar.startOfDay(for: Date())
        let hasAlarm = alarmDays.contains(dayStart)
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
                Circle()
                    .fill(hasAlarm ? Theme.bellOn : Theme.bellOn.opacity(0))
                    .frame(width: 5, height: 5)
            }
        }
        .buttonStyle(.plain)
    }
}
