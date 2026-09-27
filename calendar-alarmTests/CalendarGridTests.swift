import XCTest
@testable import calendar_alarm

final class CalendarGridTests: XCTestCase {

    private func makeCalendar(firstWeekday: Int) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = firstWeekday
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, calendar: Calendar) -> Date {
        // Midnight, matching the grid's startOfDay-based cells.
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func testMonthRowsCoverWholeMonthAndPadAdjacentDays() {
        // September 2026 starts on Tuesday; a Sunday-first grid pads Aug 30–31.
        let calendar = makeCalendar(firstWeekday: 1)
        let rows = CalendarGrid.monthRows(for: date(2026, 9, 15, calendar: calendar), calendar: calendar)

        XCTAssertEqual(rows.first?.first, date(2026, 8, 30, calendar: calendar))
        XCTAssertTrue(rows.allSatisfy { $0.count == 7 })
        let allDays = rows.flatMap { $0 }
        XCTAssertEqual(allDays.count % 7, 0)
        let septemberDays = Set(allDays.filter { calendar.component(.month, from: $0) == 9 }
            .map { calendar.component(.day, from: $0) })
        XCTAssertEqual(septemberDays.count, 30)
    }

    func testMonthRowsStartMondayWhenFirstWeekdayIsTwo() {
        let calendar = makeCalendar(firstWeekday: 2)
        // September 2026 starts Tuesday → Monday-first grid pads Aug 31.
        let rows = CalendarGrid.monthRows(for: date(2026, 9, 15, calendar: calendar), calendar: calendar)
        XCTAssertEqual(rows.first?.first, date(2026, 8, 31, calendar: calendar))
    }

    func testWeekDaysForSundayCursorSpansIntoNextMonth() {
        let calendar = makeCalendar(firstWeekday: 1)
        let days = CalendarGrid.weekDays(for: date(2026, 9, 27, calendar: calendar), calendar: calendar)
        XCTAssertEqual(days.first, date(2026, 9, 27, calendar: calendar))
        XCTAssertEqual(days.last, date(2026, 10, 3, calendar: calendar))
    }

    func testWeekDaysForMidweekCursorStartAtWeekStart() {
        let calendar = makeCalendar(firstWeekday: 1)
        let days = CalendarGrid.weekDays(for: date(2026, 9, 23, calendar: calendar), calendar: calendar)
        XCTAssertEqual(days.first, date(2026, 9, 20, calendar: calendar))
        XCTAssertEqual(days.last, date(2026, 9, 26, calendar: calendar))
        XCTAssertEqual(days.count, 7)
    }

    func testWeekdaySymbolsFollowFirstWeekday() {
        XCTAssertEqual(CalendarGrid.weekdaySymbols(calendar: makeCalendar(firstWeekday: 1)).first, "S")
        XCTAssertEqual(CalendarGrid.weekdaySymbols(calendar: makeCalendar(firstWeekday: 2)).first, "M")
    }
}
