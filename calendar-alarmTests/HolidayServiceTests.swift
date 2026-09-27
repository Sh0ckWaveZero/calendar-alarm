import XCTest
@testable import calendar_alarm

final class HolidayServiceTests: XCTestCase {

    // MARK: - ICS parser

    func testParsesDateOnlyAndDateTimeEvents() {
        let ics = """
        BEGIN:VCALENDAR
        BEGIN:VEVENT
        DTSTART;VALUE=DATE:20260101
        SUMMARY:New Year's Day
        END:VEVENT
        BEGIN:VEVENT
        DTSTART:20260413T000000Z
        SUMMARY:Songkran Festival
        END:VEVENT
        END:VCALENDAR
        """
        let events = ICSParser.parse(Data(ics.utf8))

        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].title, "New Year's Day")
        XCTAssertEqual(Calendar.current.component(.month, from: events[0].date), 1)
        XCTAssertEqual(Calendar.current.component(.day, from: events[0].date), 1)
        XCTAssertEqual(events[1].title, "Songkran Festival")
        XCTAssertEqual(Calendar.current.component(.day, from: events[1].date), 13)
    }

    func testUnfoldsContinuationLinesAndUnescapes() {
        let ics = """
        BEGIN:VEVENT
        DTSTART;VALUE=DATE:20260728
        SUMMARY:His Majesty King Maha Vajiralongkorn's\r
          Birthday
        DESCRIPTION:comma\\, semicolon\\; done
        END:VEVENT
        """
        let events = ICSParser.parse(Data(ics.utf8))

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].title, "His Majesty King Maha Vajiralongkorn's Birthday")
    }

    func testSkipsEventsWithoutDateOrTitle() {
        let ics = """
        BEGIN:VEVENT
        SUMMARY:No date here
        END:VEVENT
        BEGIN:VEVENT
        DTSTART;VALUE=DATE:20260501
        END:VEVENT
        """
        XCTAssertTrue(ICSParser.parse(Data(ics.utf8)).isEmpty)
    }

    // MARK: - Dedup + provider selection

    func testDedupedByDateAndTitle() {
        let day = Date()
        let merged = HolidayService.deduped([
            HolidayEvent(date: day, title: "วันขึ้นปีใหม่"),
            HolidayEvent(date: day, title: "วันขึ้นปีใหม่"),
            HolidayEvent(date: day, title: "วันสงกรานต์"),
        ])
        XCTAssertEqual(merged.count, 2)
    }

    func testFallsBackToICSWhenEventKitHasNoHolidays() async {
        let ics = ICSStub(holidays: [HolidayEvent(date: date(2026, 12, 5), title: "วันพ่อแห่งชาติ")])
        let service = HolidayService(eventKitProvider: ICSStub(holidays: []), icsProvider: ics)

        let holidays = await service.holidays(in: DateInterval(start: date(2026, 12, 1), duration: 86_400 * 31))

        XCTAssertEqual(holidays.map(\.title), ["วันพ่อแห่งชาติ"])
    }

    func testUsesEventKitWhenItHasHolidays() async {
        let service = HolidayService(
            eventKitProvider: ICSStub(holidays: [HolidayEvent(date: date(2026, 12, 5), title: "Holidays")]),
            icsProvider: ICSStub(holidays: [HolidayEvent(date: date(2026, 12, 5), title: "ICS only")])
        )

        let holidays = await service.holidays(in: DateInterval(start: date(2026, 12, 1), duration: 86_400 * 31))

        XCTAssertEqual(holidays.map(\.title), ["Holidays"])
    }

    func testReturnsEmptyWhenProviderThrows() async {
        let service = HolidayService(
            eventKitProvider: nil,
            icsProvider: ThrowingStub()
        )

        let holidays = await service.holidays(in: DateInterval(start: Date(), duration: 3_600))

        XCTAssertTrue(holidays.isEmpty)
    }

    // MARK: - Helpers

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private final class ICSStub: HolidayProvider, @unchecked Sendable {
        let holidays: [HolidayEvent]
        init(holidays: [HolidayEvent]) { self.holidays = holidays }
        func holidays(in range: DateInterval) async throws -> [HolidayEvent] {
            holidays.filter { range.contains($0.date) }
        }
    }

    private struct ThrowingStub: HolidayProvider {
        func holidays(in range: DateInterval) async throws -> [HolidayEvent] {
            throw URLError(.notConnectedToInternet)
        }
    }
}
