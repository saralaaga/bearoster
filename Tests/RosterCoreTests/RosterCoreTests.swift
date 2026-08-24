import Testing
import Foundation
@testable import RosterCore

@Suite("Roster core")
struct RosterCoreTests {
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
        let record = RosterRecord(
            contactID: "a",
            contactName: "Ada",
            organizationName: "",
            kind: .gregorian,
            components: DateComponents(calendar: Calendar(identifier: .gregorian), year: 1990, month: 8, day: 4)
        )
        let date = try #require(RosterOccurrenceResolver().occurrence(for: record, inGregorianYear: 2026))
        let comps = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        #expect(comps.year == 2026)
        #expect(comps.month == 8)
        #expect(comps.day == 4)
    }

    @Test("Foundation engine resolves local birthday date specs without Apple contact data")
    func foundationEngineResolvesLocalDateSpec() throws {
        let spec = RosterDateSpec(
            personID: "local-person",
            kind: .gregorian,
            components: DateComponents(calendar: Calendar(identifier: .gregorian), year: 1990, month: 8, day: 4)
        )

        let date = try #require(FoundationRosterCalendarEngine().occurrence(for: spec, inGregorianYear: 2026))
        let comps = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)

        #expect(comps.year == 2026)
        #expect(comps.month == 8)
        #expect(comps.day == 4)
    }

    @Test("Chinese lunar birthday age uses the civil birth year")
    func chineseLunarAgeUsesCivilBirthYear() throws {
        let engine = FoundationRosterCalendarEngine()
        let spec = RosterDateSpec(
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
        let engine = FoundationRosterCalendarEngine()
        let spec = RosterDateSpec(
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
        let engine = FoundationRosterCalendarEngine()
        let spec = RosterDateSpec(
            personID: "future",
            kind: .gregorian,
            components: DateComponents(calendar: Calendar(identifier: .gregorian), year: 2030, month: 8, day: 4)
        )
        let date = try #require(engine.occurrence(for: spec, inGregorianYear: 2026))

        #expect(engine.age(for: spec, on: date) == nil)
    }

    @Test("A person can project multiple calendar birthday specs into records")
    func personSupportsMultipleRosterSpecs() {
        let person = RosterPerson(id: "guo", displayName: "郭峰")
        let gregorian = RosterDateSpec(
            personID: person.id,
            kind: .gregorian,
            components: DateComponents(calendar: Calendar(identifier: .gregorian), year: 1971, month: 8, day: 20)
        )
        let lunar = RosterDateSpec(
            personID: person.id,
            kind: .chinese,
            components: DateComponents(calendar: Calendar(identifier: .chinese), year: 1971, month: 7, day: 8)
        )

        let records = [gregorian, lunar].map { RosterRecord(person: person, dateSpec: $0) }

        #expect(records.count == 2)
        #expect(Set(records.map(\.kind)) == [.gregorian, .chinese])
        #expect(records.allSatisfy { $0.contactID == person.id })
    }

    @Test("Legacy cached birthday records without source decode as Apple records")
    func legacyRosterRecordDecodesAsAppleSource() throws {
        struct LegacyRecord: Codable {
            let id: String
            let contactID: String
            let contactName: String
            let organizationName: String
            let kind: RosterCalendarKind
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
        let record = try JSONDecoder().decode(RosterRecord.self, from: data)

        #expect(record.source == .appleRoster)
        #expect(record.syncPolicy == .writeBackToApple)
        #expect(record.month == 8)
        #expect(record.day == 20)
    }

    @Test("Legacy contact profiles decode missing editable fields as empty values")
    func legacyContactProfileDecodesWithDefaults() throws {
        let json = """
        {
            "id": "ada",
            "displayName": "Ada Lovelace",
            "organizationName": "Analytical Engines",
            "records": []
        }
        """
        let profile = try JSONDecoder().decode(ContactRosterProfile.self, from: Data(json.utf8))

        #expect(profile.givenName.isEmpty)
        #expect(profile.familyName.isEmpty)
        #expect(profile.nickname.isEmpty)
        #expect(profile.departmentName.isEmpty)
        #expect(profile.jobTitle.isEmpty)
        #expect(profile.phoneNumbers.isEmpty)
        #expect(profile.emailAddresses.isEmpty)
        #expect(profile.postalAddresses.isEmpty)
        #expect(profile.imageData == nil)
    }

    @Test("Formatter renders native Islamic month text")
    func formatsIslamicNativeText() {
        let record = RosterRecord(
            contactID: "b",
            contactName: "Ahmed",
            organizationName: "",
            kind: .islamic,
            components: DateComponents(calendar: Calendar(identifier: .islamic), month: 9, day: 12)
        )
        let text = CalendarFormattingService().originalDate(record, locale: .english)
        #expect(text.contains("رمضان"))
    }

    @Test("Formatter exposes reusable localized calendar strings")
    func formatterExposesReusableLocalizedCalendarStrings() throws {
        let formatter = CalendarFormattingService()
        let date = try #require(gregorianDate(year: 2026, month: 8, day: 20))

        #expect(formatter.fullDate(date, locale: .english).contains("2026"))
        #expect(formatter.monthTitle(date, locale: .english) == "August 2026")
        #expect(formatter.monthTitle(date, locale: .simplifiedChinese) == "2026年8月")
        #expect(formatter.weekdaySymbols(locale: .english).count == 7)
    }

    private func gregorianDate(year: Int, month: Int, day: Int) -> Date? {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day))
    }
}
