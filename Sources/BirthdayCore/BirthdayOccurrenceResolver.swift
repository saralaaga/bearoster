import Foundation

public struct BirthdayOccurrenceResolver: Sendable {
    public var calendar: Calendar

    public init(calendar: Calendar = Calendar(identifier: .gregorian)) {
        self.calendar = calendar
    }

    public func occurrence(for record: BirthdayRecord, inGregorianYear year: Int) -> Date? {
        guard let month = record.month, let day = record.day else { return nil }

        if record.kind == .gregorian {
            var components = DateComponents()
            components.calendar = calendar
            components.year = year
            components.month = month
            components.day = day
            return calendar.startOfDay(for: calendar.date(from: components) ?? Date.distantPast)
        }

        let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
        let end = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1))!
        let searchStart = calendar.date(byAdding: .day, value: -1, to: start)!

        var matching = DateComponents()
        matching.calendar = Calendar(identifier: record.kind.calendarIdentifier)
        matching.month = month
        matching.day = day
        if record.kind.supportsLeapMonth {
            matching.isLeapMonth = record.isLeapMonth
        }

        var result: Date?
        matching.calendar?.enumerateDates(
            startingAfter: searchStart,
            matching: matching,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        ) { date, _, stop in
            guard let date else {
                stop = true
                return
            }

            if date >= end {
                stop = true
                return
            }

            if date >= start {
                result = calendar.startOfDay(for: date)
                stop = true
            }
        }

        return result
    }

    public func nextOccurrence(for record: BirthdayRecord, after date: Date) -> BirthdayOccurrence? {
        let today = calendar.startOfDay(for: date)
        let year = calendar.component(.year, from: today)

        for offset in 0...8 {
            guard let occurrenceDate = occurrence(for: record, inGregorianYear: year + offset) else {
                continue
            }
            if occurrenceDate >= today {
                return BirthdayOccurrence(
                    record: record,
                    date: occurrenceDate,
                    age: age(for: record, on: occurrenceDate)
                )
            }
        }

        return nil
    }

    public func occurrences(inMonthContaining visibleDate: Date, records: [BirthdayRecord]) -> [BirthdayOccurrence] {
        let year = calendar.component(.year, from: visibleDate)
        let month = calendar.component(.month, from: visibleDate)

        return records.compactMap { record in
            guard let date = occurrence(for: record, inGregorianYear: year),
                  calendar.component(.month, from: date) == month
            else { return nil }
            return BirthdayOccurrence(record: record, date: date, age: age(for: record, on: date))
        }
        .sorted { $0.date == $1.date ? $0.record.contactName < $1.record.contactName : $0.date < $1.date }
    }

    public func occurrences(on date: Date, records: [BirthdayRecord]) -> [BirthdayOccurrence] {
        let day = calendar.startOfDay(for: date)
        return records.compactMap { record in
            guard let occurrence = occurrence(for: record, inGregorianYear: calendar.component(.year, from: day)),
                  calendar.isDate(occurrence, inSameDayAs: day)
            else { return nil }
            return BirthdayOccurrence(record: record, date: occurrence, age: age(for: record, on: occurrence))
        }
        .sorted { $0.record.contactName < $1.record.contactName }
    }

    public func age(for record: BirthdayRecord, on occurrenceDate: Date) -> Int? {
        guard let birthYear = record.year else { return nil }
        let ageCalendar = Calendar(identifier: record.kind.calendarIdentifier)
        guard let occurrenceYear = ageCalendar.dateComponents([.year], from: occurrenceDate).year else { return nil }
        return max(0, occurrenceYear - birthYear)
    }

    public func daysUntil(_ date: Date, from start: Date = Date()) -> Int {
        let startDay = calendar.startOfDay(for: start)
        let targetDay = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: startDay, to: targetDay).day ?? 0
    }
}
