import Foundation

public struct RosterOccurrenceResolver: Sendable {
    public var calendar: Calendar {
        didSet {
            engine = FoundationRosterCalendarEngine(gregorianCalendar: calendar)
        }
    }
    private var engine: FoundationRosterCalendarEngine

    public init(calendar: Calendar = Calendar(identifier: .gregorian)) {
        self.calendar = calendar
        self.engine = FoundationRosterCalendarEngine(gregorianCalendar: calendar)
    }

    public func occurrence(for record: RosterRecord, inGregorianYear year: Int) -> Date? {
        engine.occurrence(for: record.dateSpec, inGregorianYear: year)
    }

    public func nextOccurrence(for record: RosterRecord, after date: Date) -> RosterOccurrence? {
        guard let occurrence = engine.nextOccurrence(for: record.dateSpec, after: date) else { return nil }
        return RosterOccurrence(record: record, date: occurrence.date, age: occurrence.age)
    }

    public func occurrences(inMonthContaining visibleDate: Date, records: [RosterRecord]) -> [RosterOccurrence] {
        let year = calendar.component(.year, from: visibleDate)
        let month = calendar.component(.month, from: visibleDate)

        return records.compactMap { record in
            guard let date = occurrence(for: record, inGregorianYear: year),
                  calendar.component(.month, from: date) == month
            else { return nil }
            return RosterOccurrence(record: record, date: date, age: age(for: record, on: date))
        }
        .sorted { $0.date == $1.date ? $0.record.contactName < $1.record.contactName : $0.date < $1.date }
    }

    public func occurrences(on date: Date, records: [RosterRecord]) -> [RosterOccurrence] {
        let day = calendar.startOfDay(for: date)
        return records.compactMap { record in
            guard let occurrence = occurrence(for: record, inGregorianYear: calendar.component(.year, from: day)),
                  calendar.isDate(occurrence, inSameDayAs: day)
            else { return nil }
            return RosterOccurrence(record: record, date: occurrence, age: age(for: record, on: occurrence))
        }
        .sorted { $0.record.contactName < $1.record.contactName }
    }

    public func age(for record: RosterRecord, on occurrenceDate: Date) -> Int? {
        engine.age(for: record.dateSpec, on: occurrenceDate)
    }

    public func daysUntil(_ date: Date, from start: Date = Date()) -> Int {
        engine.daysUntil(date, from: start)
    }
}
