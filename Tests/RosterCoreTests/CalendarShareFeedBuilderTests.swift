import Foundation
import Testing
@testable import RosterCore

@Suite("Calendar share feed")
struct CalendarShareFeedBuilderTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func record(
        kind: RosterCalendarKind = .gregorian,
        id: String,
        name: String = "Ada",
        year: Int? = 1990,
        month: Int,
        day: Int,
        isLeapMonth: Bool = false
    ) -> RosterRecord {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        if kind.supportsLeapMonth {
            components.isLeapMonth = isLeapMonth ? true : nil
        }
        return RosterRecord(
            id: id,
            contactID: "contact-\(id)",
            contactName: name,
            organizationName: "",
            kind: kind,
            components: components
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test("Feed window keeps last week's birthday and drops far-future occurrences")
    func windowFiltering() {
        let records = [
            record(id: "r-newyear", month: 12, day: 31),
            record(id: "r-leapday", name: "Leap", month: 2, day: 29)
        ]

        // Window: 2025-12-25 … 2027-02-05.
        let events = CalendarShareFeedBuilder.events(from: records, today: date(2026, 1, 1))

        #expect(events.filter { $0.uid.contains("r-newyear") }.map { "\($0.year)" } == ["2025", "2026"])
        // Feb 29 wraps to Mar 1 in non-leap years, matching the in-app list;
        // 2025-03-01 fell outside the lookback, 2027-03-01 is beyond the horizon.
        let leapEvents = events.filter { $0.uid.contains("r-leapday") }
        #expect(leapEvents.map { "\($0.year)-\($0.month)-\($0.day)" } == ["2026-3-1"])
    }

    @Test("Lunar birthdays resolve to concrete Gregorian dates")
    func lunarResolution() throws {
        let lunarNewYear = record(kind: .chinese, id: "r-lunar", name: "月月", year: nil, month: 1, day: 1)

        let events = CalendarShareFeedBuilder.events(from: [lunarNewYear], today: date(2026, 9, 27))

        // 正月初一 next falls on 2027-02-06; 2026-02-17 is outside the 7-day lookback.
        let event = try #require(events.single)
        #expect(event.year == 2027)
        #expect(event.month == 2)
        #expect(event.day == 6)
        #expect(event.summary == "月月")
    }

    @Test("ICS escapes text, formats all-day dates, and ends with CRLF")
    func icsSerialization() {
        let events = [
            CalendarShareEvent(uid: "local:a-20261001@share.bearoster.app", summary: "Ada; 汉字, with \\ slash", year: 2026, month: 10, day: 1)
        ]

        let ics = CalendarShareFeedBuilder.ics(for: events, calendarName: "蓝熊名册", stamp: date(2026, 9, 27))

        #expect(ics.hasPrefix("BEGIN:VCALENDAR\r\nVERSION:2.0\r\n"))
        #expect(ics.contains("X-WR-CALNAME:蓝熊名册\r\n"))
        #expect(ics.contains("UID:local:a-20261001@share.bearoster.app\r\n"))
        #expect(ics.contains("DTSTART;VALUE=DATE:20261001\r\n"))
        #expect(ics.contains("DTEND;VALUE=DATE:20261002\r\n"))
        #expect(ics.contains("SUMMARY:Ada\\; 汉字\\, with \\\\ slash\r\n"))
        #expect(ics.contains("DTSTAMP:"))
        #expect(ics.hasSuffix("END:VCALENDAR\r\n"))
    }

    @Test("Long lines fold at octet boundaries without breaking characters")
    func lineFolding() {
        let longName = String(repeating: "蓝", count: 60)

        let folded = CalendarShareFeedBuilder.folded("SUMMARY:\(longName)")

        for line in folded.components(separatedBy: "\r\n") {
            #expect(line.utf8.count <= 75)
        }
        #expect(folded.contains("\r\n "))
        #expect(folded.replacingOccurrences(of: "\r\n ", with: "") == "SUMMARY:\(longName)")
    }

    @Test("Newlines and delimiters are escaped per RFC 5545")
    func escaping() {
        #expect(CalendarShareFeedBuilder.escape("a;b,c\nd\\e") == "a\\;b\\,c\\nd\\\\e")
    }
}

private extension Array {
    var single: Element? {
        count == 1 ? first : nil
    }
}
