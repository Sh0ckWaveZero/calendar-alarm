import Foundation

/// Day cells for the month/week calendar grids.
enum CalendarGrid {
    /// Weeks (rows) covering `cursor`'s month. Each row holds exactly 7 days,
    /// padded with adjacent-month days so weeks align to `calendar.firstWeekday`.
    static func monthRows(for cursor: Date, calendar: Calendar = .current) -> [[Date]] {
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: cursor)) ?? cursor
        let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
        let leading = (calendar.component(.weekday, from: monthStart) - calendar.firstWeekday + 7) % 7
        let cellCount = ((leading + daysInMonth + 6) / 7) * 7
        let first = calendar.date(byAdding: .day, value: -leading, to: monthStart) ?? monthStart
        return stride(from: 0, to: cellCount, by: 7).map { weekOffset in
            (0..<7).map { dayOffset in
                calendar.date(byAdding: .day, value: weekOffset + dayOffset, to: first) ?? first
            }
        }
    }

    /// The 7 days of the week containing `cursor`, starting at `calendar.firstWeekday`.
    static func weekDays(for cursor: Date, calendar: Calendar = .current) -> [Date] {
        let day = calendar.startOfDay(for: cursor)
        let offset = (calendar.component(.weekday, from: day) - calendar.firstWeekday + 7) % 7
        let weekStart = calendar.date(byAdding: .day, value: -offset, to: day) ?? day
        return (0..<7).map { calendar.date(byAdding: .day, value: $0, to: weekStart) ?? weekStart }
    }

    /// Weekday symbols ordered from `calendar.firstWeekday` (for the grid header).
    static func weekdaySymbols(calendar: Calendar = .current) -> [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let offset = calendar.firstWeekday - 1
        return Array(symbols[offset...] + symbols[..<offset])
    }
}
