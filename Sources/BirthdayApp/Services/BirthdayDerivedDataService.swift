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
    private let formatter = CalendarFormattingService()

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

        let occurrences = sortedOccurrences(
            recordsWithOccurrences.compactMap(\.occurrence),
            sort: sort
        )
        return (records, occurrences)
    }

    func recordGroups(
        from occurrences: [BirthdayOccurrence],
        sort: BirthdaySort,
        locale: CalendarFormattingService.AppLocale
    ) -> [BirthdayRecordGroup] {
        switch sort {
        case .next:
            return monthGroups(from: occurrences, locale: locale)
        case .name:
            return nameGroups(from: occurrences)
        case .age:
            return [
                BirthdayRecordGroup(
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
        _ occurrences: [BirthdayOccurrence],
        sort: BirthdaySort
    ) -> [BirthdayOccurrence] {
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
        from occurrences: [BirthdayOccurrence],
        locale: CalendarFormattingService.AppLocale
    ) -> [BirthdayRecordGroup] {
        let grouped = Dictionary(grouping: occurrences) { occurrence in
            let components = Calendar.current.dateComponents([.year, .month], from: occurrence.date)
            guard let year = components.year, let month = components.month else {
                return "unknown"
            }
            return String(format: "%04d-%02d", year, month)
        }

        return grouped.keys.sorted().compactMap { key in
            guard let items = grouped[key], let first = items.first else { return nil }
            return BirthdayRecordGroup(
                id: key,
                title: monthTitle(for: first.date, locale: locale),
                occurrences: items
            )
        }
    }

    private func nameGroups(from occurrences: [BirthdayOccurrence]) -> [BirthdayRecordGroup] {
        let grouped = Dictionary(grouping: occurrences) { occurrence in
            NameSortKey.sectionKey(for: NameSortKey.romanized(occurrence.record.contactName))
        }

        return grouped.keys.sorted(by: NameSortKey.sectionSortValue(_:_:)).map { key in
            BirthdayRecordGroup(id: "name-\(key)", title: key, occurrences: grouped[key] ?? [])
        }
    }

    private func calendarGroups(
        from occurrences: [BirthdayOccurrence],
        locale: CalendarFormattingService.AppLocale
    ) -> [BirthdayRecordGroup] {
        let grouped = Dictionary(grouping: occurrences, by: \.record.kind)
        return BirthdayCalendarKind.allCases.compactMap { kind in
            guard let items = grouped[kind], !items.isEmpty else { return nil }
            return BirthdayRecordGroup(
                id: "calendar-\(kind.rawValue)",
                title: formatter.calendarName(kind, locale: locale),
                occurrences: items
            )
        }
    }

    private func sortTitle(_ sort: BirthdaySort, locale: CalendarFormattingService.AppLocale) -> String {
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

    private func compareByNextDate(_ lhs: BirthdayOccurrence, _ rhs: BirthdayOccurrence) -> Bool {
        if lhs.date != rhs.date {
            return lhs.date < rhs.date
        }
        return compareByName(lhs, rhs)
    }

    private func compareByName(_ lhs: BirthdayOccurrence, _ rhs: BirthdayOccurrence) -> Bool {
        let lhsKey = NameSortKey.romanized(lhs.record.contactName)
        let rhsKey = NameSortKey.romanized(rhs.record.contactName)
        let comparison = lhsKey.localizedStandardCompare(rhsKey)
        if comparison != .orderedSame {
            return comparison == .orderedAscending
        }
        return compareByNextDateThenID(lhs, rhs)
    }

    private func compareByAge(_ lhs: BirthdayOccurrence, _ rhs: BirthdayOccurrence) -> Bool {
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

    private func compareByCalendar(_ lhs: BirthdayOccurrence, _ rhs: BirthdayOccurrence) -> Bool {
        let lhsIndex = BirthdayCalendarKind.allCases.firstIndex(of: lhs.record.kind) ?? BirthdayCalendarKind.allCases.endIndex
        let rhsIndex = BirthdayCalendarKind.allCases.firstIndex(of: rhs.record.kind) ?? BirthdayCalendarKind.allCases.endIndex
        if lhsIndex != rhsIndex {
            return lhsIndex < rhsIndex
        }
        return compareByNextDate(lhs, rhs)
    }

    private func compareByNextDateThenID(_ lhs: BirthdayOccurrence, _ rhs: BirthdayOccurrence) -> Bool {
        if lhs.date != rhs.date {
            return lhs.date < rhs.date
        }
        return lhs.id < rhs.id
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
