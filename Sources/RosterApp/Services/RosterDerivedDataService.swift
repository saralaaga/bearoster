import RosterCore
import Foundation

struct RosterVisibleMonthData: Sendable {
    let dates: [Date]
    let title: String
    let weekdaySymbols: [String]
    let occurrencesByDay: [Date: [RosterOccurrence]]
    let filteredOccurrencesByDay: [Date: [RosterOccurrence]]
    let selectedDateOccurrences: [RosterOccurrence]
}

struct RosterDerivedDataService: Sendable {
    private let resolver = RosterOccurrenceResolver()
    private let formatter = CalendarFormattingService()

    func allRecords(from profiles: [ContactRosterProfile]) -> [RosterRecord] {
        profiles.flatMap(\.records)
    }

    func filteredRecords(
        from allRecords: [RosterRecord],
        searchText: String,
        filter: RosterCalendarKind?,
        tagFilter: ContactTagFilter = .all,
        contactTags: [ContactTag] = [],
        contactTagAssignmentsByContactID: [String: Set<String>] = [:],
        sort: RosterSort,
        now: Date = Date()
    ) -> (records: [RosterRecord], occurrences: [RosterOccurrence]) {
        var records = allRecords
        let matchingTagIDs = tagFilter.matchingTagIDs(in: contactTags)
        if let filter {
            records = records.filter { $0.kind == filter }
        }
        records = records.filter {
            tagFilter.contains(
                contactID: $0.contactID,
                assignments: contactTagAssignmentsByContactID,
                matchingTagIDs: matchingTagIDs
            )
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

        let occurrences = sortedOccurrences(
            recordsWithOccurrences.compactMap(\.occurrence),
            sort: sort
        )
        return (records, occurrences)
    }

    func recordGroups(
        from occurrences: [RosterOccurrence],
        sort: RosterSort,
        locale: CalendarFormattingService.AppLocale
    ) -> [RosterRecordGroup] {
        switch sort {
        case .next:
            return monthGroups(from: occurrences, locale: locale)
        case .name:
            return nameGroups(from: occurrences)
        case .age:
            return [
                RosterRecordGroup(
                    id: "age",
                    title: sortTitle(sort, locale: locale),
                    occurrences: occurrences
                )
            ]
        case .calendar:
            return calendarGroups(from: occurrences, locale: locale)
        }
    }

    private func sortedOccurrences(
        _ occurrences: [RosterOccurrence],
        sort: RosterSort
    ) -> [RosterOccurrence] {
        occurrences.sorted { lhs, rhs in
            switch sort {
            case .next:
                return compareByNextDate(lhs, rhs)
            case .name:
                return compareByName(lhs, rhs)
            case .age:
                return compareByAge(lhs, rhs)
            case .calendar:
                return compareByCalendar(lhs, rhs)
            }
        }
    }

    private func monthGroups(
        from occurrences: [RosterOccurrence],
        locale: CalendarFormattingService.AppLocale
    ) -> [RosterRecordGroup] {
        let grouped = Dictionary(grouping: occurrences) { occurrence in
            let components = Calendar.current.dateComponents([.year, .month], from: occurrence.date)
            guard let year = components.year, let month = components.month else {
                return "unknown"
            }
            return String(format: "%04d-%02d", year, month)
        }

        return grouped.keys.sorted().compactMap { key in
            guard let items = grouped[key], let first = items.first else { return nil }
            return RosterRecordGroup(
                id: key,
                title: monthTitle(for: first.date, locale: locale),
                occurrences: items
            )
        }
    }

    private func nameGroups(from occurrences: [RosterOccurrence]) -> [RosterRecordGroup] {
        let grouped = Dictionary(grouping: occurrences) { occurrence in
            NameSortKey.sectionKey(for: NameSortKey.romanized(occurrence.record.contactName))
        }

        return grouped.keys.sorted(by: NameSortKey.sectionSortValue(_:_:)).map { key in
            RosterRecordGroup(id: "name-\(key)", title: key, occurrences: grouped[key] ?? [])
        }
    }

    private func calendarGroups(
        from occurrences: [RosterOccurrence],
        locale: CalendarFormattingService.AppLocale
    ) -> [RosterRecordGroup] {
        let grouped = Dictionary(grouping: occurrences, by: \.record.kind)
        return RosterCalendarKind.allCases.compactMap { kind in
            guard let items = grouped[kind], !items.isEmpty else { return nil }
            return RosterRecordGroup(
                id: "calendar-\(kind.rawValue)",
                title: formatter.calendarName(kind, locale: locale),
                occurrences: items
            )
        }
    }

    private func sortTitle(_ sort: RosterSort, locale: CalendarFormattingService.AppLocale) -> String {
        switch (sort, locale) {
        case (.next, .english): "Next birthday"
        case (.next, .simplifiedChinese): "最近生日"
        case (.next, .traditionalChinese): "最近生日"
        case (.name, .english): "Name"
        case (.name, .simplifiedChinese): "姓名"
        case (.name, .traditionalChinese): "姓名"
        case (.age, .english): "Age"
        case (.age, .simplifiedChinese): "年龄"
        case (.age, .traditionalChinese): "年齡"
        case (.calendar, .english): "Calendar"
        case (.calendar, .simplifiedChinese): "历法"
        case (.calendar, .traditionalChinese): "曆法"
        }
    }

    private func compareByNextDate(_ lhs: RosterOccurrence, _ rhs: RosterOccurrence) -> Bool {
        if lhs.date != rhs.date {
            return lhs.date < rhs.date
        }
        return compareByName(lhs, rhs)
    }

    private func compareByName(_ lhs: RosterOccurrence, _ rhs: RosterOccurrence) -> Bool {
        let lhsKey = NameSortKey.romanized(lhs.record.contactName)
        let rhsKey = NameSortKey.romanized(rhs.record.contactName)
        let comparison = lhsKey.localizedStandardCompare(rhsKey)
        if comparison != .orderedSame {
            return comparison == .orderedAscending
        }
        return compareByNextDateThenID(lhs, rhs)
    }

    private func compareByAge(_ lhs: RosterOccurrence, _ rhs: RosterOccurrence) -> Bool {
        switch (lhs.age, rhs.age) {
        case let (.some(lhsAge), .some(rhsAge)) where lhsAge != rhsAge:
            return lhsAge > rhsAge
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        default:
            return compareByNextDateThenID(lhs, rhs)
        }
    }

    private func compareByCalendar(_ lhs: RosterOccurrence, _ rhs: RosterOccurrence) -> Bool {
        let lhsIndex = RosterCalendarKind.allCases.firstIndex(of: lhs.record.kind) ?? RosterCalendarKind.allCases.endIndex
        let rhsIndex = RosterCalendarKind.allCases.firstIndex(of: rhs.record.kind) ?? RosterCalendarKind.allCases.endIndex
        if lhsIndex != rhsIndex {
            return lhsIndex < rhsIndex
        }
        return compareByNextDate(lhs, rhs)
    }

    private func compareByNextDateThenID(_ lhs: RosterOccurrence, _ rhs: RosterOccurrence) -> Bool {
        if lhs.date != rhs.date {
            return lhs.date < rhs.date
        }
        return lhs.id < rhs.id
    }

    func upcomingOccurrences(
        from allRecords: [RosterRecord],
        upcomingRange: Int,
        now: Date = Date()
    ) -> [RosterOccurrence] {
        allRecords.compactMap { resolver.nextOccurrence(for: $0, after: now) }
            .filter { resolver.daysUntil($0.date, from: now) <= upcomingRange }
            .sorted { $0.date == $1.date ? $0.record.contactName < $1.record.contactName : $0.date < $1.date }
    }

    func visibleMonthData(
        allRecords: [RosterRecord],
        visibleMonth: Date,
        selectedDate: Date,
        searchText: String,
        locale: CalendarFormattingService.AppLocale,
        progress: (@Sendable (_ completedDays: Int, _ totalDays: Int) -> Void)? = nil
    ) -> RosterVisibleMonthData {
        let dates = visibleMonthDays(containing: visibleMonth)
        var occurrencesByDay: [Date: [RosterOccurrence]] = [:]

        for (index, day) in dates.enumerated() {
            let key = dayKey(day)
            occurrencesByDay[key] = resolver.occurrences(on: day, records: allRecords)
            progress?(index + 1, dates.count)
        }

        let filteredOccurrencesByDay = filterVisibleOccurrences(occurrencesByDay, searchText: searchText)
        let selectedDateOccurrences = occurrencesByDay[dayKey(selectedDate)]
            ?? resolver.occurrences(on: selectedDate, records: allRecords)

        return RosterVisibleMonthData(
            dates: dates,
            title: monthTitle(for: visibleMonth, locale: locale),
            weekdaySymbols: weekdaySymbols(locale: locale),
            occurrencesByDay: occurrencesByDay,
            filteredOccurrencesByDay: filteredOccurrencesByDay,
            selectedDateOccurrences: selectedDateOccurrences
        )
    }

    func filterVisibleOccurrences(
        _ occurrencesByDay: [Date: [RosterOccurrence]],
        searchText: String
    ) -> [Date: [RosterOccurrence]] {
        guard !occurrencesByDay.isEmpty else { return [:] }
        guard !searchText.isEmpty else { return occurrencesByDay }
        return occurrencesByDay.mapValues { occurrences in
            occurrences.filter { $0.record.contactName.localizedCaseInsensitiveContains(searchText) }
        }
    }

    func occurrences(on date: Date, allRecords: [RosterRecord], cachedByDay: [Date: [RosterOccurrence]]) -> [RosterOccurrence] {
        cachedByDay[dayKey(date)] ?? resolver.occurrences(on: date, records: allRecords)
    }

    func filteredOccurrences(
        on date: Date,
        searchText: String,
        allRecords: [RosterRecord],
        cachedByDay: [Date: [RosterOccurrence]],
        cachedFilteredByDay: [Date: [RosterOccurrence]]
    ) -> [RosterOccurrence] {
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
