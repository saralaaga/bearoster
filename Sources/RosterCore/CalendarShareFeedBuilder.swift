import Foundation

/// One resolved birthday occurrence in the subscribable feed.
public struct CalendarShareEvent: Equatable, Sendable {
    public let uid: String
    public let summary: String
    public let year: Int
    public let month: Int
    public let day: Int

    public init(uid: String, summary: String, year: Int, month: Int, day: Int) {
        self.uid = uid
        self.summary = summary
        self.year = year
        self.month = month
        self.day = day
    }
}

/// Builds the iCalendar body for the calendar-share subscription feed.
///
/// Birthdays are expanded into concrete dates over a rolling window instead
/// of using RRULE: lunar/hebrew/islamic birthdays do not map onto a yearly
/// Gregorian recurrence, and concrete dates stay correct in every subscriber
/// client. Subscribed calendars are fully replaced on refresh, so a sliding
/// window is enough.
public enum CalendarShareFeedBuilder {
    /// Recent birthdays stay visible for a week; the feed reaches ~13 months
    /// ahead so subscribers always see the next occurrence.
    public static let lookbackDays = 7
    public static let horizonDays = 400

    private static let gregorianCalendar = Calendar(identifier: .gregorian)

    public static func events(
        from records: [RosterRecord],
        today: Date,
        calendar: Calendar = Calendar(identifier: .gregorian),
        resolver: RosterOccurrenceResolver = RosterOccurrenceResolver()
    ) -> [CalendarShareEvent] {
        let today = calendar.startOfDay(for: today)
        guard let windowStart = calendar.date(byAdding: .day, value: -lookbackDays, to: today),
              let windowEnd = calendar.date(byAdding: .day, value: horizonDays, to: today)
        else { return [] }

        let currentYear = calendar.component(.year, from: today)
        var events: [CalendarShareEvent] = []
        var seenUIDs = Set<String>()

        for record in records {
            for year in (currentYear - 1)...(currentYear + 1) {
                guard let date = resolver.occurrence(for: record, inGregorianYear: year),
                      date >= windowStart, date < windowEnd
                else { continue }
                let components = calendar.dateComponents([.year, .month, .day], from: date)
                guard let resolvedYear = components.year,
                      let month = components.month,
                      let day = components.day
                else { continue }
                let stamp = String(format: "%04d%02d%02d", resolvedYear, month, day)
                let uid = "\(record.id)-\(stamp)@share.bearoster.app"
                guard seenUIDs.insert(uid).inserted else { continue }
                events.append(
                    CalendarShareEvent(uid: uid, summary: record.contactName, year: resolvedYear, month: month, day: day)
                )
            }
        }

        return events.sorted { lhs, rhs in
            let lhsDay = (lhs.year, lhs.month, lhs.day)
            let rhsDay = (rhs.year, rhs.month, rhs.day)
            if lhsDay != rhsDay { return lhsDay < rhsDay }
            return lhs.summary.localizedStandardCompare(rhs.summary) == .orderedAscending
        }
    }

    public static func ics(
        for events: [CalendarShareEvent],
        calendarName: String,
        stamp: Date = Date()
    ) -> String {
        var lines = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//Bearoster//Calendar Share//CN",
            "CALSCALE:GREGORIAN",
            "X-WR-CALNAME:\(escape(calendarName))"
        ]
        for event in events {
            let startDay = String(format: "%04d%02d%02d", event.year, event.month, event.day)
            guard let endDay = nextDay(afterYear: event.year, month: event.month, day: event.day) else { continue }
            lines.append(contentsOf: [
                "BEGIN:VEVENT",
                "UID:\(event.uid)",
                "DTSTAMP:\(utcStamp(stamp))",
                "DTSTART;VALUE=DATE:\(startDay)",
                "DTEND;VALUE=DATE:\(endDay)",
                "SUMMARY:\(escape(event.summary))",
                "TRANSP:TRANSPARENT",
                "END:VEVENT"
            ])
        }
        lines.append("END:VCALENDAR")
        return lines.map { folded($0) }.joined(separator: "\r\n") + "\r\n"
    }

    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\r\n", with: "\\n")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\n")
    }

    /// RFC 5545 folding: lines longer than 75 octets continue with CRLF plus
    /// a single space, and folds never split a UTF-8 character.
    static func folded(_ line: String) -> String {
        let bytes = Array(line.utf8)
        guard bytes.count > 75 else { return line }

        var parts: [String] = []
        var index = 0
        while index < bytes.count {
            let budget = parts.isEmpty ? 75 : 74
            var end = min(index + budget, bytes.count)
            if end < bytes.count {
                while end > index && (bytes[end] & 0xC0) == 0x80 {
                    end -= 1
                }
            }
            parts.append(String(decoding: bytes[index..<end], as: UTF8.self))
            index = end
        }
        return parts.joined(separator: "\r\n ")
    }

    private static func nextDay(afterYear year: Int, month: Int, day: Int) -> String? {
        guard let date = gregorianCalendar.date(from: DateComponents(year: year, month: month, day: day)),
              let nextDay = gregorianCalendar.date(byAdding: .day, value: 1, to: date)
        else { return nil }
        let components = gregorianCalendar.dateComponents([.year, .month, .day], from: nextDay)
        guard let nextYear = components.year, let nextMonth = components.month, let nextDayNumber = components.day else {
            return nil
        }
        return String(format: "%04d%02d%02d", nextYear, nextMonth, nextDayNumber)
    }

    private static func utcStamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return formatter.string(from: date)
    }
}
