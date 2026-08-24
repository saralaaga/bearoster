import RosterCore
import Foundation

package struct RosterVisibleMonthData: Sendable {
    package let dates: [Date]
    package let title: String
    package let weekdaySymbols: [String]
    package let occurrencesByDay: [Date: [RosterOccurrence]]
    package let filteredOccurrencesByDay: [Date: [RosterOccurrence]]
    package let selectedDateOccurrences: [RosterOccurrence]
}

package struct RosterDerivedDataService: Sendable {
    private let resolver = RosterOccurrenceResolver()
    private let formatter = CalendarFormattingService()
    private let calendar = Calendar(identifier: .gregorian)

    package func allRecords(from profiles: [ContactRosterProfile]) -> [RosterRecord] {
        profiles.flatMap(\.records)
    }

    package func filteredRecords(
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

    package func recordGroups(
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

    package func listGroups(
        from groups: [RosterRecordGroup],
        contactTags: [ContactTag],
        contactTagAssignmentsByContactID: [String: Set<String>],
        language: AppLanguage,
        showAge: Bool,
        openContactText: String,
        todayText: String
    ) -> [RosterOccurrenceListGroup] {
        let tagsByID = Dictionary(uniqueKeysWithValues: contactTags.map { ($0.id, $0) })
        return groups.map { group in
            RosterOccurrenceListGroup(
                id: group.id,
                title: group.title,
                items: group.occurrences.map {
                    listItem(
                        for: $0,
                        tags: tags(for: $0.record.contactID, assignments: contactTagAssignmentsByContactID, tagsByID: tagsByID),
                        language: language,
                        showAge: showAge,
                        openContactText: openContactText,
                        todayText: todayText
                    )
                }
            )
        }
    }

    private func sortedOccurrences(
        _ occurrences: [RosterOccurrence],
        sort: RosterSort
    ) -> [RosterOccurrence] {
        if sort == .name {
            return occurrences
                .map { (occurrence: $0, nameKey: NameSortKey.romanized($0.record.contactName)) }
                .sorted { lhs, rhs in
                    let comparison = lhs.nameKey.localizedStandardCompare(rhs.nameKey)
                    if comparison != .orderedSame {
                        return comparison == .orderedAscending
                    }
                    return compareByNextDateThenID(lhs.occurrence, rhs.occurrence)
                }
                .map { $0.occurrence }
        }

        return occurrences.sorted { lhs, rhs in
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
            let components = calendar.dateComponents([.year, .month], from: occurrence.date)
            guard let year = components.year, let month = components.month else {
                return "unknown"
            }
            return String(format: "%04d-%02d", year, month)
        }

        return grouped.keys.sorted().compactMap { key in
            guard let items = grouped[key], let first = items.first else { return nil }
            return RosterRecordGroup(
                id: key,
                title: formatter.monthTitle(first.date, locale: locale),
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

    private func listItem(
        for occurrence: RosterOccurrence,
        tags: [ContactTag],
        language: AppLanguage,
        showAge: Bool,
        openContactText: String,
        todayText: String
    ) -> RosterOccurrenceListItem {
        let locale = language.coreLocale
        let daysUntil = resolver.daysUntil(occurrence.date)
        var metaParts = [
            formatter.originalDate(occurrence.record, locale: locale),
            formatter.occurrenceDate(occurrence.date, locale: locale)
        ]
        if showAge, let age = occurrence.age {
            metaParts.append("\(age)")
        }
        return RosterOccurrenceListItem(
            id: occurrence.id,
            contactID: occurrence.record.contactID,
            contactName: occurrence.record.contactName,
            tags: tags,
            kind: occurrence.record.kind,
            kindTitle: shortKindName(occurrence.record.kind, language: language),
            metaText: metaParts.joined(separator: " · "),
            daysUntil: daysUntil,
            daysUntilText: daysUntil == 0 ? todayText : daysLeftText(daysUntil, locale: locale),
            isToday: calendar.isDateInToday(occurrence.date),
            accessibilityLabel: "\(openContactText): \(occurrence.record.contactName)"
        )
    }

    private func shortKindName(_ kind: RosterCalendarKind, language: AppLanguage) -> String {
        switch kind {
        case .gregorian: formatter.calendarName(kind, locale: language.coreLocale)
        case .chinese: language.coreLocale == .english ? "Lunar" : formatter.calendarName(kind, locale: language.coreLocale)
        case .hebrew: "עברי"
        case .islamic: "هجري"
        }
    }

    private func tags(
        for contactID: String,
        assignments: [String: Set<String>],
        tagsByID: [String: ContactTag]
    ) -> [ContactTag] {
        (assignments[contactID] ?? [])
            .compactMap { tagsByID[$0] }
            .sorted {
                if $0.sortOrder != $1.sortOrder {
                    return $0.sortOrder < $1.sortOrder
                }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
    }

    package func upcomingOccurrences(
        from allRecords: [RosterRecord],
        upcomingRange: Int,
        now: Date = Date()
    ) -> [RosterOccurrence] {
        allRecords.compactMap { resolver.nextOccurrence(for: $0, after: now) }
            .filter { resolver.daysUntil($0.date, from: now) <= upcomingRange }
            .sorted { $0.date == $1.date ? $0.record.contactName < $1.record.contactName : $0.date < $1.date }
    }

    package func visibleMonthData(
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
            title: formatter.monthTitle(visibleMonth, locale: locale),
            weekdaySymbols: formatter.weekdaySymbols(locale: locale),
            occurrencesByDay: occurrencesByDay,
            filteredOccurrencesByDay: filteredOccurrencesByDay,
            selectedDateOccurrences: selectedDateOccurrences
        )
    }

    package func filterVisibleOccurrences(
        _ occurrencesByDay: [Date: [RosterOccurrence]],
        searchText: String
    ) -> [Date: [RosterOccurrence]] {
        guard !occurrencesByDay.isEmpty else { return [:] }
        guard !searchText.isEmpty else { return occurrencesByDay }
        return occurrencesByDay.mapValues { occurrences in
            occurrences.filter { $0.record.contactName.localizedCaseInsensitiveContains(searchText) }
        }
    }

    package func occurrences(on date: Date, allRecords: [RosterRecord], cachedByDay: [Date: [RosterOccurrence]]) -> [RosterOccurrence] {
        cachedByDay[dayKey(date)] ?? resolver.occurrences(on: date, records: allRecords)
    }

    package func filteredOccurrences(
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
        calendar.startOfDay(for: date)
    }
}
