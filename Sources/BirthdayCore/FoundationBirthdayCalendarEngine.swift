import Foundation

public protocol BirthdayCalendarCalculating: Sendable {
    func occurrence(for spec: BirthdayDateSpec, inGregorianYear year: Int) -> Date?
    func nextOccurrence(for spec: BirthdayDateSpec, after date: Date) -> BirthdayOccurrenceDate?
    func age(for spec: BirthdayDateSpec, on occurrenceDate: Date) -> Int?
    func daysUntil(_ date: Date, from start: Date) -> Int
}

public struct BirthdayOccurrenceDate: Codable, Hashable, Sendable {
    public let date: Date
    public let age: Int?

    public init(date: Date, age: Int?) {
        self.date = date
        self.age = age
    }
}

public struct FoundationBirthdayCalendarEngine: BirthdayCalendarCalculating {
    public var gregorianCalendar: Calendar

    public init(gregorianCalendar: Calendar = Calendar(identifier: .gregorian)) {
        self.gregorianCalendar = gregorianCalendar
    }

    public func occurrence(for spec: BirthdayDateSpec, inGregorianYear year: Int) -> Date? {
        guard let month = spec.month, let day = spec.day else { return nil }

        if spec.kind == .gregorian {
            var components = DateComponents()
            components.calendar = gregorianCalendar
            components.year = year
            components.month = month
            components.day = day
            guard let date = gregorianCalendar.date(from: components) else { return nil }
            return gregorianCalendar.startOfDay(for: date)
        }

        let start = gregorianCalendar.date(from: DateComponents(year: year, month: 1, day: 1))!
        let end = gregorianCalendar.date(from: DateComponents(year: year + 1, month: 1, day: 1))!
        let searchStart = gregorianCalendar.date(byAdding: .day, value: -1, to: start)!

        var matching = DateComponents()
        matching.calendar = Calendar(identifier: spec.kind.calendarIdentifier)
        matching.month = month
        matching.day = day
        if spec.kind.supportsLeapMonth {
            matching.isLeapMonth = spec.isLeapMonth
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
                result = gregorianCalendar.startOfDay(for: date)
                stop = true
            }
        }

        return result
    }

    public func nextOccurrence(for spec: BirthdayDateSpec, after date: Date) -> BirthdayOccurrenceDate? {
        let today = gregorianCalendar.startOfDay(for: date)
        let year = gregorianCalendar.component(.year, from: today)

        if spec.kind != .gregorian,
           let occurrenceDate = nextNonGregorianOccurrence(for: spec, after: today, startingGregorianYear: year) {
            return BirthdayOccurrenceDate(
                date: occurrenceDate,
                age: age(for: spec, on: occurrenceDate)
            )
        }

        for offset in 0...8 {
            guard let occurrenceDate = occurrence(for: spec, inGregorianYear: year + offset) else {
                continue
            }
            if occurrenceDate >= today {
                return BirthdayOccurrenceDate(
                    date: occurrenceDate,
                    age: age(for: spec, on: occurrenceDate)
                )
            }
        }

        return nil
    }

    private func nextNonGregorianOccurrence(
        for spec: BirthdayDateSpec,
        after today: Date,
        startingGregorianYear year: Int
    ) -> Date? {
        guard let matching = nonGregorianMatchingComponents(for: spec) else { return nil }
        guard let searchStart = gregorianCalendar.date(byAdding: .day, value: -1, to: today),
              let searchEnd = gregorianCalendar.date(from: DateComponents(year: year + 9, month: 1, day: 1))
        else { return nil }

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

            if date >= searchEnd {
                stop = true
                return
            }

            let day = gregorianCalendar.startOfDay(for: date)
            if day >= today {
                result = day
                stop = true
            }
        }

        return result
    }

    private func nonGregorianMatchingComponents(for spec: BirthdayDateSpec) -> DateComponents? {
        guard let month = spec.month, let day = spec.day else { return nil }
        var matching = DateComponents()
        matching.calendar = Calendar(identifier: spec.kind.calendarIdentifier)
        matching.month = month
        matching.day = day
        if spec.kind.supportsLeapMonth {
            matching.isLeapMonth = spec.isLeapMonth
        }
        return matching
    }

    public func age(for spec: BirthdayDateSpec, on occurrenceDate: Date) -> Int? {
        guard let birthYear = spec.year else { return nil }
        let ageCalendar = ageCalendar(for: spec)
        guard let occurrenceYear = ageCalendar.dateComponents([.year], from: occurrenceDate).year else { return nil }
        let age = occurrenceYear - birthYear
        return age >= 0 ? age : nil
    }

    public func daysUntil(_ date: Date, from start: Date = Date()) -> Int {
        let startDay = gregorianCalendar.startOfDay(for: start)
        let targetDay = gregorianCalendar.startOfDay(for: date)
        return gregorianCalendar.dateComponents([.day], from: startDay, to: targetDay).day ?? 0
    }

    private func ageCalendar(for spec: BirthdayDateSpec) -> Calendar {
        switch spec.kind {
        case .gregorian, .chinese:
            gregorianCalendar
        case .hebrew, .islamic:
            Calendar(identifier: spec.kind.calendarIdentifier)
        }
    }
}
