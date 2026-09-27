import SwiftUI

/// Date helpers for the alarm list.
enum DateUtil {
    /// Section heading: Today / Tomorrow, otherwise a fully localized
    /// "Friday, September 26". Returns Text so SwiftUI resolves the keys with
    /// the environment locale (in-app language override).
    static func heading(for day: Date, calendar: Calendar = .current) -> Text {
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: day)
        if target == today { return Text("Today") }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today), target == tomorrow {
            return Text("Tomorrow")
        }
        return Text(target, format: .dateTime.weekday(.wide).month(.wide).day())
    }

    /// The next occurrence of a picked time-of-day: today if still ahead, otherwise tomorrow.
    static func nextOccurrence(of time: Date, from now: Date = Date(), calendar: Calendar = .current) -> Date {
        let components = calendar.dateComponents([.hour, .minute], from: time)
        var candidate = calendar.date(bySettingHour: components.hour ?? 0,
                                      minute: components.minute ?? 0,
                                      second: 0, of: now) ?? now
        if candidate <= now {
            candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        }
        return candidate
    }

    /// Combines the day of an existing alarm with a picked time-of-day.
    static func combine(day: Date, timeOfDay: Date, calendar: Calendar = .current) -> Date {
        let timeComponents = calendar.dateComponents([.hour, .minute], from: timeOfDay)
        return calendar.date(bySettingHour: timeComponents.hour ?? 0,
                             minute: timeComponents.minute ?? 0,
                             second: 0, of: day) ?? day
    }
}
