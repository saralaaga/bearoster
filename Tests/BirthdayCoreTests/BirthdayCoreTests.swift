import Testing
import Foundation
@testable import BirthdayCore

@Suite("Birthday core")
struct BirthdayCoreTests {
    @Test("Chinese lunar phrase parser recognizes leap month dates")
    func parsesChineseLeapMonth() throws {
        let parsed = try #require(DatePhraseParser().parse("今年农历闰六月初五是公历几号"))
        #expect(parsed.calendarKind == .chinese)
        #expect(parsed.month == 6)
        #expect(parsed.day == 5)
        #expect(parsed.isLeapMonth)
    }

    @Test("Islamic parser keeps Hijri month identity")
    func parsesIslamicRamadan() throws {
        let parsed = try #require(DatePhraseParser().parse("Islamic Ramadan 12"))
        #expect(parsed.calendarKind == .islamic)
        #expect(parsed.month == 9)
        #expect(parsed.day == 12)
    }

    @Test("Hebrew parser recognizes native Elul")
    func parsesHebrewElul() throws {
        let parsed = try #require(DatePhraseParser().parse("Hebrew Elul 1"))
        #expect(parsed.calendarKind == .hebrew)
        #expect(parsed.month == 6)
        #expect(parsed.day == 1)
    }

    @Test("Gregorian birthday resolves in requested year")
    func resolvesGregorianOccurrence() throws {
        let record = BirthdayRecord(
            contactID: "a",
            contactName: "Ada",
            organizationName: "",
            kind: .gregorian,
            components: DateComponents(calendar: Calendar(identifier: .gregorian), year: 1990, month: 8, day: 4)
        )
        let date = try #require(BirthdayOccurrenceResolver().occurrence(for: record, inGregorianYear: 2026))
        let comps = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        #expect(comps.year == 2026)
        #expect(comps.month == 8)
        #expect(comps.day == 4)
    }

    @Test("Formatter renders native Islamic month text")
    func formatsIslamicNativeText() {
        let record = BirthdayRecord(
            contactID: "b",
            contactName: "Ahmed",
            organizationName: "",
            kind: .islamic,
            components: DateComponents(calendar: Calendar(identifier: .islamic), month: 9, day: 12)
        )
        let text = CalendarFormattingService().originalDate(record, locale: .english)
        #expect(text.contains("رمضان"))
    }
}
