import BirthdayCore
import Foundation

struct BirthdayVisibleMonthData: Sendable {
    let dates: [Date]
    let title: String
    let weekdaySymbols: [String]
    let occurrencesByDay: [Date: [BirthdayOccurrence]]
    let filteredOccurrencesByDay: [Date: [BirthdayOccurrence]]
    let selectedDateOccurrences: [BirthdayOccurrence]
}

struct BirthdayDerivedDataService: Sendable {
    private let resolver = BirthdayOccurrenceResolver()

    func allRecords(from profiles: [ContactBirthdayProfile]) -> [BirthdayRecord] {
        profiles.flatMap(\.records)
    }

    func filteredRecords(
        from allRecords: [BirthdayRecord],
        searchText: String,
        filter: BirthdayCalendarKind?,
        sort: BirthdaySort,
        now: Date = Date()
    ) -> (records: [BirthdayRecord], occurrences: [BirthdayOccurrence]) {
        var records = allRecords
        if let filter {
            records = records.filter { $0.kind == filter }
        }
        if !searchText.isEmpty {
            records = records.filter { $0.contactName.localizedCaseInsensitiveContains(searchText) }
        }

        let recordsWithOccurrences = records.map { record in
            (record: record, occurrence: resolver.nextOccurrence(for: record, after: now))
        }

        switch sort {
        case .next:
            records = recordsWithOccurrences.sorted {
                let lhs = $0.occurrence?.date ?? .distantFuture
                let rhs = $1.occurrence?.date ?? .distantFuture
                return lhs < rhs
            }.map(\.record)
        case .name:
            records.sort { $0.contactName.localizedStandardCompare($1.contactName) == .orderedAscending }
        case .age:
            records.sort { ($0.year ?? Int.max) < ($1.year ?? Int.max) }
        case .calendar:
            records.sort { $0.kind.rawValue < $1.kind.rawValue }
        }

        let occurrences = recordsWithOccurrences.compactMap(\.occurrence)
            .sorted { lhs, rhs in
                lhs.date == rhs.date ? lhs.record.contactName < rhs.record.contactName : lhs.date < rhs.date
            }
        return (records, occurrences)
    }

    func recordGroups(
        from occurrences: [BirthdayOccurrence],
        locale: CalendarFormattingService.AppLocale
    ) -> [BirthdayMonthGroup] {
        let grouped = Dictionary(grouping: occurrences) { occurrence in
            let components = Calendar.current.dateComponents([.year, .month], from: occurrence.date)
            guard let year = components.year, let month = components.month else {
                return "unknown"
            }
            return String(format: "%04d-%02d", year, month)
        }

        return grouped.keys.sorted().compactMap { key in
            guard let items = grouped[key], let first = items.first else { return nil }
            return BirthdayMonthGroup(
                id: key,
                title: monthTitle(for: first.date, locale: locale),
                occurrences: items
            )
        }
    }

    func upcomingOccurrences(
        from allRecords: [BirthdayRecord],
        upcomingRange: Int,
        now: Date = Date()
    ) -> [BirthdayOccurrence] {
        allRecords.compactMap { resolver.nextOccurrence(for: $0, after: now) }
            .filter { resolver.daysUntil($0.date, from: now) <= upcomingRange }
            .sorted { $0.date == $1.date ? $0.record.contactName < $1.record.contactName : $0.date < $1.date }
    }

    func visibleMonthData(
        allRecords: [BirthdayRecord],
        visibleMonth: Date,
        selectedDate: Date,
        searchText: String,
        locale: CalendarFormattingService.AppLocale,
        progress: (@Sendable (_ completedDays: Int, _ totalDays: Int) -> Void)? = nil
    ) -> BirthdayVisibleMonthData {
        let dates = visibleMonthDays(containing: visibleMonth)
        var occurrencesByDay: [Date: [BirthdayOccurrence]] = [:]

        for (index, day) in dates.enumerated() {
            let key = dayKey(day)
            occurrencesByDay[key] = resolver.occurrences(on: day, records: allRecords)
            progress?(index + 1, dates.count)
        }

        let filteredOccurrencesByDay = filterVisibleOccurrences(occurrencesByDay, searchText: searchText)
        let selectedDateOccurrences = occurrencesByDay[dayKey(selectedDate)]
            ?? resolver.occurrences(on: selectedDate, records: allRecords)

        return BirthdayVisibleMonthData(
            dates: dates,
            title: monthTitle(for: visibleMonth, locale: locale),
            weekdaySymbols: weekdaySymbols(locale: locale),
            occurrencesByDay: occurrencesByDay,
            filteredOccurrencesByDay: filteredOccurrencesByDay,
            selectedDateOccurrences: selectedDateOccurrences
        )
    }

    func filterVisibleOccurrences(
        _ occurrencesByDay: [Date: [BirthdayOccurrence]],
        searchText: String
    ) -> [Date: [BirthdayOccurrence]] {
        guard !occurrencesByDay.isEmpty else { return [:] }
        guard !searchText.isEmpty else { return occurrencesByDay }
        return occurrencesByDay.mapValues { occurrences in
            occurrences.filter { $0.record.contactName.localizedCaseInsensitiveContains(searchText) }
        }
    }

    func occurrences(on date: Date, allRecords: [BirthdayRecord], cachedByDay: [Date: [BirthdayOccurrence]]) -> [BirthdayOccurrence] {
        cachedByDay[dayKey(date)] ?? resolver.occurrences(on: date, records: allRecords)
    }

    func filteredOccurrences(
        on date: Date,
        searchText: String,
        allRecords: [BirthdayRecord],
        cachedByDay: [Date: [BirthdayOccurrence]],
        cachedFilteredByDay: [Date: [BirthdayOccurrence]]
    ) -> [BirthdayOccurrence] {
        if let occurrences = cachedFilteredByDay[dayKey(date)] {
            return occurrences
        }

        let occurrences = self.occurrences(on: date, allRecords: allRecords, cachedByDay: cachedByDay)
        guard !searchText.isEmpty else { return occurrences }
        return occurrences.filter { $0.record.contactName.localizedCaseInsensitiveContains(searchText) }
    }

    private func visibleMonthDays(containing visibleMonth: Date) -> [Date] {
        let calendar = Calendar.current
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: visibleMonth)) else {
            return []
        }
        let weekday = calendar.component(.weekday, from: startOfMonth) - 1
        guard let start = calendar.date(byAdding: .day, value: -weekday, to: startOfMonth) else {
            return []
        }
        let daysInMonth = calendar.range(of: .day, in: .month, for: startOfMonth)?.count ?? 31
        let cells = Int(ceil(Double(weekday + daysInMonth) / 7.0)) * 7
        return (0..<cells).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private func dayKey(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    private func weekdaySymbols(locale: CalendarFormattingService.AppLocale) -> [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: locale.rawValue)
        return formatter.shortStandaloneWeekdaySymbols
    }

    private func monthTitle(for date: Date, locale: CalendarFormattingService.AppLocale) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: locale.rawValue)
        formatter.dateFormat = locale == .english ? "MMMM yyyy" : "yyyy年M月"
        return formatter.string(from: date)
    }
}
