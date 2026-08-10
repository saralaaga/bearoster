import BirthdayCore
import Foundation

struct BirthdayCalculationProgress: Equatable, Sendable {
    var isActive: Bool
    var message: String
    var completed: Int
    var total: Int

    var fraction: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(completed) / Double(total)))
    }

    static let inactive = BirthdayCalculationProgress(isActive: false, message: "", completed: 0, total: 1)
}

struct BirthdayDerivedDataRequest: Sendable {
    let generation: Int
    let profiles: [ContactBirthdayProfile]
    let searchText: String
    let selectedDate: Date
    let visibleMonth: Date
    let filter: BirthdayCalendarKind?
    let sort: BirthdaySort
    let language: AppLanguage
    let upcomingRange: Int
}

struct BirthdayDerivedDataSnapshot: Sendable {
    let allRecords: [BirthdayRecord]
    let filteredRecords: [BirthdayRecord]
    let filteredRecordOccurrences: [BirthdayOccurrence]
    let filteredRecordGroups: [BirthdayMonthGroup]
    let cachedUpcomingOccurrences: [BirthdayOccurrence]
    let selectedDateOccurrences: [BirthdayOccurrence]
    let visibleMonthDates: [Date]
    let visibleMonthTitle: String
    let weekdaySymbols: [String]
    let visibleOccurrencesByDay: [Date: [BirthdayOccurrence]]
    let visibleFilteredOccurrencesByDay: [Date: [BirthdayOccurrence]]
}

actor BirthdayDerivedDataWorker {
    private var cache: [BirthdayDerivedDataCacheKey: BirthdayDerivedDataSnapshot] = [:]
    private let service = BirthdayDerivedDataService()
    private let maxCacheEntries = 24

    func snapshot(
        for request: BirthdayDerivedDataRequest,
        progress: @escaping @Sendable (BirthdayCalculationProgress) -> Void
    ) -> BirthdayDerivedDataSnapshot {
        let key = BirthdayDerivedDataCacheKey(request)
        if let cached = cache[key] {
            progress(.active(message: "Using cached birthday data", completed: 1, total: 1))
            return cached
        }

        progress(.active(message: "Preparing birthday records", completed: 0, total: 6))
        let allRecords = service.allRecords(from: request.profiles)

        progress(.active(message: "Filtering birthday records", completed: 1, total: 6))
        let filtered = service.filteredRecords(
            from: allRecords,
            searchText: request.searchText,
            filter: request.filter,
            sort: request.sort
        )

        progress(.active(message: "Grouping birthday list", completed: 2, total: 6))
        let groups = service.recordGroups(
            from: filtered.occurrences,
            locale: request.language.coreLocale
        )

        progress(.active(message: "Calculating upcoming birthdays", completed: 3, total: 6))
        let upcoming = service.upcomingOccurrences(
            from: allRecords,
            upcomingRange: request.upcomingRange
        )

        progress(.active(message: "Calculating visible month", completed: 4, total: 6))
        let visible = service.visibleMonthData(
            allRecords: allRecords,
            visibleMonth: request.visibleMonth,
            selectedDate: request.selectedDate,
            searchText: request.searchText,
            locale: request.language.coreLocale
        ) { completedDays, totalDays in
            let base = 4.0 / 6.0
            let monthShare = totalDays == 0 ? 0 : (Double(completedDays) / Double(totalDays)) / 6.0
            progress(.active(message: "Calculating visible month", completed: Int((base + monthShare) * 100), total: 100))
        }

        let snapshot = BirthdayDerivedDataSnapshot(
            allRecords: allRecords,
            filteredRecords: filtered.records,
            filteredRecordOccurrences: filtered.occurrences,
            filteredRecordGroups: groups,
            cachedUpcomingOccurrences: upcoming,
            selectedDateOccurrences: visible.selectedDateOccurrences,
            visibleMonthDates: visible.dates,
            visibleMonthTitle: visible.title,
            weekdaySymbols: visible.weekdaySymbols,
            visibleOccurrencesByDay: visible.occurrencesByDay,
            visibleFilteredOccurrencesByDay: visible.filteredOccurrencesByDay
        )

        progress(.active(message: "Finishing birthday data", completed: 6, total: 6))
        cache[key] = snapshot
        trimCacheIfNeeded()
        return snapshot
    }

    func filteredVisibleOccurrences(
        occurrencesByDay: [Date: [BirthdayOccurrence]],
        searchText: String
    ) -> [Date: [BirthdayOccurrence]] {
        service.filterVisibleOccurrences(occurrencesByDay, searchText: searchText)
    }

    private func trimCacheIfNeeded() {
        guard cache.count > maxCacheEntries else { return }
        let overflow = cache.count - maxCacheEntries
        for key in cache.keys.prefix(overflow) {
            cache[key] = nil
        }
    }
}

private struct BirthdayDerivedDataCacheKey: Hashable, Sendable {
    let generation: Int
    let searchText: String
    let selectedDate: Date
    let visibleMonth: Date
    let filter: BirthdayCalendarKind?
    let sort: BirthdaySort
    let locale: CalendarFormattingService.AppLocale
    let upcomingRange: Int

    init(_ request: BirthdayDerivedDataRequest) {
        generation = request.generation
        searchText = request.searchText
        selectedDate = Calendar.current.startOfDay(for: request.selectedDate)
        visibleMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: request.visibleMonth))
            ?? Calendar.current.startOfDay(for: request.visibleMonth)
        filter = request.filter
        sort = request.sort
        locale = request.language.coreLocale
        upcomingRange = request.upcomingRange
    }
}

private extension BirthdayCalculationProgress {
    static func active(message: String, completed: Int, total: Int) -> BirthdayCalculationProgress {
        BirthdayCalculationProgress(isActive: true, message: message, completed: completed, total: max(total, 1))
    }
}
