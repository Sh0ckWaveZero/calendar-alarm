import EventKit
import Foundation

/// One holiday shown on the calendar grid (all-day, single day).
struct HolidayEvent: Identifiable, Codable, Equatable {
    /// Start of the holiday's day.
    let date: Date
    let title: String

    var id: String { "\(date.timeIntervalSince1970)-\(title)" }

    init(date: Date, title: String) {
        self.date = Calendar.current.startOfDay(for: date)
        self.title = title
    }
}

/// A source of holidays for a date range.
protocol HolidayProvider {
    func holidays(in range: DateInterval) async throws -> [HolidayEvent]
}

/// Reads holidays from the device's subscribed/holiday calendars via EventKit.
final class EventKitHolidayProvider: HolidayProvider {
    private let store = EKEventStore()
    private var accessGranted = false

    func holidays(in range: DateInterval) async throws -> [HolidayEvent] {
        if !accessGranted {
            accessGranted = try await store.requestFullAccessToEvents()
        }
        guard accessGranted else { return [] }

        let predicate = store.predicateForEvents(withStart: range.start, end: range.end, calendars: nil)
        guard let events = store.events(matching: predicate) as? [EKEvent] else { return [] }
        return events.compactMap { event in
            guard isHolidayCalendar(event.calendar) else { return nil }
            return HolidayEvent(date: event.startDate, title: event.title ?? "")
        }
        .filter { !$0.title.isEmpty }
    }

    /// Apple's holiday calendars arrive as subscriptions ("Holidays in Thailand",
    /// "วันหยุด"); users may also subscribe to other feeds, so check both signals.
    private func isHolidayCalendar(_ calendar: EKCalendar?) -> Bool {
        guard let calendar else { return false }
        if calendar.isSubscribed { return true }
        let name = calendar.title.lowercased()
        return name.contains("holiday") || calendar.title.contains("วันหยุด")
    }
}

/// Fetches Thai holidays from Google's public holiday calendar feed (iCalendar format).
final class ICSHolidayProvider: HolidayProvider {
    static let feedURL = URL(string: "https://calendar.google.com/calendar/ical/th.th%23holiday%40group.v.calendar.google.com/public/basic.ics")!
    private static let cacheTTL: TimeInterval = 7 * 24 * 3600

    private let session: URLSession
    private let cacheURL: URL
    private let calendar: Calendar

    init(session: URLSession = .shared,
         cacheURL: URL? = nil,
         calendar: Calendar = .current) {
        self.session = session
        self.calendar = calendar
        if let cacheURL {
            self.cacheURL = cacheURL
        } else {
            let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            self.cacheURL = directory.appendingPathComponent("thai-holidays.json")
        }
    }

    func holidays(in range: DateInterval) async throws -> [HolidayEvent] {
        let all = try await cachedOrFetchedHolidays()
        return all.filter { range.contains($0.date) }
    }

    private func cachedOrFetchedHolidays() async throws -> [HolidayEvent] {
        let cache = readCache()
        if let cache, Date().timeIntervalSince(cache.fetchedAt) < Self.cacheTTL {
            return cache.holidays
        }
        do {
            let (data, response) = try await session.data(from: Self.feedURL)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            let holidays = ICSParser.parse(data, calendar: calendar)
            if !holidays.isEmpty {
                writeCache(holidays)
            } else if let cache {
                // Feed came back empty — keep serving the old cache.
                return cache.holidays
            }
            return holidays
        } catch {
            // Offline or failed fetch: stale data is better than nothing.
            if let cache, !cache.holidays.isEmpty { return cache.holidays }
            throw error
        }
    }

    private struct Cache: Codable {
        let fetchedAt: Date
        let holidays: [HolidayEvent]
    }

    private func readCache() -> Cache? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode(Cache.self, from: data)
    }

    private func writeCache(_ holidays: [HolidayEvent]) {
        let cache = Cache(fetchedAt: Date(), holidays: holidays)
        if let data = try? JSONEncoder().encode(cache) {
            try? data.write(to: cacheURL, options: .atomic)
        }
    }
}

/// Minimal iCalendar VEVENT reader: unfolds lines, takes DTSTART and SUMMARY.
enum ICSParser {
    static func parse(_ data: Data, calendar: Calendar = .current) -> [HolidayEvent] {
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        // RFC 5545 unfolding: a CRLF+space sequence was inserted when folding,
        // so removing it restores the original long line.
        let unfolded = text
            .replacingOccurrences(of: "\r\n ", with: "")
            .replacingOccurrences(of: "\n ", with: "")
        var events: [HolidayEvent] = []
        var currentDate: Date?
        var currentTitle: String?

        for rawLine in unfolded.split(separator: /\r?\n/) {
            let line = String(rawLine)
            if line.hasPrefix("BEGIN:VEVENT") {
                currentDate = nil
                currentTitle = nil
            } else if line.hasPrefix("DTSTART") {
                currentDate = parseDate(after: line, calendar: calendar)
            } else if line.hasPrefix("SUMMARY") {
                currentTitle = unescape(value(after: line))
            } else if line.hasPrefix("END:VEVENT") {
                if let date = currentDate, let title = currentTitle, !title.isEmpty {
                    events.append(HolidayEvent(date: date, title: title))
                }
                currentDate = nil
                currentTitle = nil
            }
        }
        return events.sorted { $0.date < $1.date }
    }

    private static func value(after line: String) -> String {
        if let colon = line.firstIndex(of: ":") {
            return String(line[line.index(after: colon)...])
        }
        return ""
    }

    /// Handles "DTSTART;VALUE=DATE:20260101" and "DTSTART:20260101T000000Z".
    private static func parseDate(after line: String, calendar: Calendar) -> Date? {
        let raw = value(after: line).trimmingCharacters(in: .whitespaces)
        let digits = raw.prefix(8)
        guard digits.count == 8, let day = Int(digits) else { return nil }
        var components = DateComponents()
        components.year = day / 10000
        components.month = (day / 100) % 100
        components.day = day % 100
        return calendar.date(from: components).map { calendar.startOfDay(for: $0) }
    }

    private static func unescape(_ text: String) -> String {
        text.replacingOccurrences(of: "\\n", with: " ")
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }
}

/// Chooses a holiday source once per session: the device's own holiday calendars
/// when available, otherwise the online Thai holidays feed.
final class HolidayService {
    private let eventKitProvider: HolidayProvider?
    private let icsProvider: HolidayProvider
    private var activeProvider: HolidayProvider?

    init(eventKitProvider: HolidayProvider? = EventKitHolidayProvider(),
         icsProvider: HolidayProvider = ICSHolidayProvider()) {
        self.eventKitProvider = eventKitProvider
        self.icsProvider = icsProvider
    }

    func holidays(in range: DateInterval) async -> [HolidayEvent] {
        let provider = await resolvedProvider()
        do {
            let events = try await provider.holidays(in: range)
            return Self.deduped(events)
        } catch {
            DebugLog.write("holidays failed: \(error)")
            return []
        }
    }

    private func resolvedProvider() async -> HolidayProvider {
        if let activeProvider { return activeProvider }
        if let eventKitProvider {
            // One-year probe: if the device has holiday calendars, use them;
            // otherwise fall back to the online Thai feed.
            let probe = DateInterval(start: Date(), duration: 365 * 24 * 3600)
            if let events = try? await eventKitProvider.holidays(in: probe), !events.isEmpty {
                activeProvider = eventKitProvider
                return eventKitProvider
            }
        }
        activeProvider = icsProvider
        return icsProvider
    }

    static func deduped(_ events: [HolidayEvent]) -> [HolidayEvent] {
        var seen = Set<String>()
        return events.filter { seen.insert($0.id).inserted }
    }
}
