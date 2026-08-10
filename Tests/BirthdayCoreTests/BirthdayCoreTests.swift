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

    @Test("Foundation engine resolves local birthday date specs without Apple contact data")
    func foundationEngineResolvesLocalDateSpec() throws {
        let spec = BirthdayDateSpec(
            personID: "local-person",
            kind: .gregorian,
            components: DateComponents(calendar: Calendar(identifier: .gregorian), year: 1990, month: 8, day: 4)
        )

        let date = try #require(FoundationBirthdayCalendarEngine().occurrence(for: spec, inGregorianYear: 2026))
        let comps = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)

        #expect(comps.year == 2026)
        #expect(comps.month == 8)
        #expect(comps.day == 4)
    }

    @Test("Chinese lunar birthday age uses the civil birth year")
    func chineseLunarAgeUsesCivilBirthYear() throws {
        let engine = FoundationBirthdayCalendarEngine()
        let spec = BirthdayDateSpec(
            personID: "guo",
            kind: .chinese,
            components: DateComponents(calendar: Calendar(identifier: .chinese), year: 1971, month: 7, day: 8)
        )

        let date = try #require(engine.occurrence(for: spec, inGregorianYear: 2026))
        let comps = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)

        #expect(comps.year == 2026)
        #expect(comps.month == 8)
        #expect(comps.day == 20)
        #expect(engine.age(for: spec, on: date) == 55)
    }

    @Test("Chinese lunar next occurrence does not skip the second matching date in a Gregorian year")
    func chineseLunarNextOccurrenceUsesNextMatchingDate() throws {
        let engine = FoundationBirthdayCalendarEngine()
        let spec = BirthdayDateSpec(
            personID: "ge",
            kind: .chinese,
            components: DateComponents(calendar: Calendar(identifier: .chinese), year: 1997, month: 11, day: 16)
        )
        let today = try #require(gregorianDate(year: 2026, month: 8, day: 10))

        let occurrence = try #require(engine.nextOccurrence(for: spec, after: today))
        let comps = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: occurrence.date)

        #expect(comps.year == 2026)
        #expect(comps.month == 12)
        #expect(comps.day == 24)
        #expect(occurrence.age == 29)
    }

    @Test("Age is unknown instead of clamped to zero when birth year is after occurrence")
    func futureBirthYearAgeIsUnknown() throws {
        let engine = FoundationBirthdayCalendarEngine()
        let spec = BirthdayDateSpec(
            personID: "future",
            kind: .gregorian,
            components: DateComponents(calendar: Calendar(identifier: .gregorian), year: 2030, month: 8, day: 4)
        )
        let date = try #require(engine.occurrence(for: spec, inGregorianYear: 2026))

        #expect(engine.age(for: spec, on: date) == nil)
    }

    @Test("A person can project multiple calendar birthday specs into records")
    func personSupportsMultipleBirthdaySpecs() {
        let person = BirthdayPerson(id: "guo", displayName: "郭峰")
        let gregorian = BirthdayDateSpec(
            personID: person.id,
            kind: .gregorian,
            components: DateComponents(calendar: Calendar(identifier: .gregorian), year: 1971, month: 8, day: 20)
        )
        let lunar = BirthdayDateSpec(
            personID: person.id,
            kind: .chinese,
            components: DateComponents(calendar: Calendar(identifier: .chinese), year: 1971, month: 7, day: 8)
        )

        let records = [gregorian, lunar].map { BirthdayRecord(person: person, dateSpec: $0) }

        #expect(records.count == 2)
        #expect(Set(records.map(\.kind)) == [.gregorian, .chinese])
        #expect(records.allSatisfy { $0.contactID == person.id })
    }

    @Test("Legacy cached birthday records without source decode as Apple records")
    func legacyBirthdayRecordDecodesAsAppleSource() throws {
        struct LegacyRecord: Codable {
            let id: String
            let contactID: String
            let contactName: String
            let organizationName: String
            let kind: BirthdayCalendarKind
            let components: DateComponents
        }

        let legacy = LegacyRecord(
            id: "guo-gregorian",
            contactID: "guo",
            contactName: "郭峰",
            organizationName: "",
            kind: .gregorian,
            components: DateComponents(calendar: Calendar(identifier: .gregorian), year: 1971, month: 8, day: 20)
        )
        let data = try JSONEncoder().encode(legacy)
        let record = try JSONDecoder().decode(BirthdayRecord.self, from: data)

        #expect(record.source == .appleBirthday)
        #expect(record.syncPolicy == .writeBackToApple)
        #expect(record.month == 8)
        #expect(record.day == 20)
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

    private func gregorianDate(year: Int, month: Int, day: Int) -> Date? {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day))
    }
}
