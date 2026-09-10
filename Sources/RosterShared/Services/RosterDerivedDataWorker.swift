import RosterCore
import Foundation

package struct RosterCalculationProgress: Equatable, Sendable {
    package var isActive: Bool
    package var message: String
    package var completed: Int
    package var total: Int

    package var fraction: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(completed) / Double(total)))
    }

    package static let inactive = RosterCalculationProgress(isActive: false, message: "", completed: 0, total: 1)
}

package struct RosterDerivedDataRequest: Sendable {
    package let generation: Int
    package let profiles: [ContactRosterProfile]
    package let searchText: String
    package let selectedDate: Date
    package let visibleMonth: Date
    package let filter: RosterCalendarKind?
    package let tagFilter: ContactTagFilter
    package let contactTags: [ContactTag]
    package let contactTagAssignmentsByContactID: [String: Set<String>]
    package let sort: RosterSort
    package let language: AppLanguage
    package let showAge: Bool
    package let openContactText: String
    package let todayText: String
    package let upcomingRange: Int
}

package struct RosterDerivedDataSnapshot: Sendable {
    package let allRecords: [RosterRecord]
    package let filteredRecords: [RosterRecord]
    package let filteredRecordOccurrences: [RosterOccurrence]
    package let filteredRecordGroups: [RosterRecordGroup]
    package let filteredRecordListGroups: [RosterOccurrenceListGroup]
    package let cachedUpcomingOccurrences: [RosterOccurrence]
    package let selectedDateOccurrences: [RosterOccurrence]
    package let visibleMonthDates: [Date]
    package let visibleMonthTitle: String
    package let weekdaySymbols: [String]
    package let visibleOccurrencesByDay: [Date: [RosterOccurrence]]
    package let visibleFilteredOccurrencesByDay: [Date: [RosterOccurrence]]
}

package actor RosterDerivedDataWorker {
    private var cache: [RosterDerivedDataCacheKey: RosterDerivedDataSnapshot] = [:]
    private let service = RosterDerivedDataService()
    private let maxCacheEntries = 24

    package func snapshot(
        for request: RosterDerivedDataRequest,
        progress: @escaping @Sendable (RosterCalculationProgress) -> Void
    ) -> RosterDerivedDataSnapshot {
        let key = RosterDerivedDataCacheKey(request)
        if let cached = cache[key] {
            progress(.active(message: Self.progressText(zhHans: "使用缓存的生日数据", zhHant: "使用快取的生日資料", en: "Using cached birthday data", locale: request.language.coreLocale), completed: 1, total: 1))
            return cached
        }

        progress(.active(message: Self.progressText(zhHans: "准备生日记录", zhHant: "準備生日記錄", en: "Preparing birthday records", locale: request.language.coreLocale), completed: 0, total: 6))
        let allRecords = service.allRecords(from: request.profiles)

        progress(.active(message: Self.progressText(zhHans: "筛选生日记录", zhHant: "篩選生日記錄", en: "Filtering birthday records", locale: request.language.coreLocale), completed: 1, total: 6))
        let filtered = service.filteredRecords(
            from: allRecords,
            searchText: request.searchText,
            filter: request.filter,
            tagFilter: request.tagFilter,
            contactTags: request.contactTags,
            contactTagAssignmentsByContactID: request.contactTagAssignmentsByContactID,
            sort: request.sort
        )

        progress(.active(message: Self.progressText(zhHans: "整理生日列表", zhHant: "整理生日列表", en: "Grouping birthdays", locale: request.language.coreLocale), completed: 2, total: 6))
        let groups = service.recordGroups(
            from: filtered.occurrences,
            sort: request.sort,
            locale: request.language.coreLocale
        )
        let listGroups = service.listGroups(
            from: groups,
            contactTags: request.contactTags,
            contactTagAssignmentsByContactID: request.contactTagAssignmentsByContactID,
            language: request.language,
            showAge: request.showAge,
            openContactText: request.openContactText,
            todayText: request.todayText
        )

        progress(.active(message: Self.progressText(zhHans: "计算近期生日", zhHant: "計算近期生日", en: "Calculating upcoming birthdays", locale: request.language.coreLocale), completed: 3, total: 6))
        let upcoming = service.upcomingOccurrences(
            from: allRecords,
            upcomingRange: request.upcomingRange
        )

        progress(.active(message: Self.progressText(zhHans: "计算本月", zhHant: "計算本月", en: "Calculating this month", locale: request.language.coreLocale), completed: 4, total: 6))
        let visible = service.visibleMonthData(
            allRecords: allRecords,
            visibleMonth: request.visibleMonth,
            selectedDate: request.selectedDate,
            searchText: request.searchText,
            locale: request.language.coreLocale
        ) { completedDays, totalDays in
            let base = 4.0 / 6.0
            let monthShare = totalDays == 0 ? 0 : (Double(completedDays) / Double(totalDays)) / 6.0
            progress(.active(message: Self.progressText(zhHans: "计算本月", zhHant: "計算本月", en: "Calculating this month", locale: request.language.coreLocale), completed: Int((base + monthShare) * 100), total: 100))
        }

        let snapshot = RosterDerivedDataSnapshot(
            allRecords: allRecords,
            filteredRecords: filtered.records,
            filteredRecordOccurrences: filtered.occurrences,
            filteredRecordGroups: groups,
            filteredRecordListGroups: listGroups,
            cachedUpcomingOccurrences: upcoming,
            selectedDateOccurrences: visible.selectedDateOccurrences,
            visibleMonthDates: visible.dates,
            visibleMonthTitle: visible.title,
            weekdaySymbols: visible.weekdaySymbols,
            visibleOccurrencesByDay: visible.occurrencesByDay,
            visibleFilteredOccurrencesByDay: visible.filteredOccurrencesByDay
        )

        progress(.active(message: Self.progressText(zhHans: "完成生日数据", zhHant: "完成生日資料", en: "Finishing birthday data", locale: request.language.coreLocale), completed: 6, total: 6))
        cache[key] = snapshot
        trimCacheIfNeeded()
        return snapshot
    }

    package func filteredVisibleOccurrences(
        occurrencesByDay: [Date: [RosterOccurrence]],
        searchText: String
    ) -> [Date: [RosterOccurrence]] {
        service.filterVisibleOccurrences(occurrencesByDay, searchText: searchText)
    }

    private static func progressText(zhHans: String, zhHant: String, en: String, locale: CalendarFormattingService.AppLocale) -> String {
        switch locale {
        case .english: en
        case .simplifiedChinese: zhHans
        case .traditionalChinese: zhHant
        }
    }

    private func trimCacheIfNeeded() {
        guard cache.count > maxCacheEntries else { return }
        let overflow = cache.count - maxCacheEntries
        for key in cache.keys.prefix(overflow) {
            cache[key] = nil
        }
    }
}

private struct RosterDerivedDataCacheKey: Hashable, Sendable {
    private static let calendar = Calendar(identifier: .gregorian)

    package let generation: Int
    package let searchText: String
    package let selectedDate: Date
    package let visibleMonth: Date
    package let filter: RosterCalendarKind?
    package let tagFilter: ContactTagFilter
    package let tagSignature: Int
    package let tagAssignmentSignature: Int
    package let sort: RosterSort
    package let locale: CalendarFormattingService.AppLocale
    package let showAge: Bool
    package let upcomingRange: Int

    package init(_ request: RosterDerivedDataRequest) {
        generation = request.generation
        searchText = request.searchText
        selectedDate = Self.calendar.startOfDay(for: request.selectedDate)
        visibleMonth = Self.calendar.date(from: Self.calendar.dateComponents([.year, .month], from: request.visibleMonth))
            ?? Self.calendar.startOfDay(for: request.visibleMonth)
        filter = request.filter
        tagFilter = request.tagFilter
        tagSignature = Self.tagSignature(request.contactTags)
        tagAssignmentSignature = Self.assignmentSignature(request.contactTagAssignmentsByContactID)
        sort = request.sort
        locale = request.language.coreLocale
        showAge = request.showAge
        upcomingRange = request.upcomingRange
    }

    private static func assignmentSignature(_ assignments: [String: Set<String>]) -> Int {
        var hasher = Hasher()
        for contactID in assignments.keys.sorted() {
            hasher.combine(contactID)
            for tagID in (assignments[contactID] ?? []).sorted() {
                hasher.combine(tagID)
            }
        }
        return hasher.finalize()
    }

    private static func tagSignature(_ tags: [ContactTag]) -> Int {
        var hasher = Hasher()
        for tag in tags.sorted(by: { $0.id < $1.id }) {
            hasher.combine(tag.id)
            hasher.combine(tag.name)
            hasher.combine(tag.parentTagID)
            hasher.combine(tag.sortOrder)
        }
        return hasher.finalize()
    }
}

private extension RosterCalculationProgress {
    static func active(message: String, completed: Int, total: Int) -> RosterCalculationProgress {
        RosterCalculationProgress(isActive: true, message: message, completed: completed, total: max(total, 1))
    }
}
