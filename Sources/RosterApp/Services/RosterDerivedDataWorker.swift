import RosterCore
import Foundation

struct RosterCalculationProgress: Equatable, Sendable {
    var isActive: Bool
    var message: String
    var completed: Int
    var total: Int

    var fraction: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(completed) / Double(total)))
    }

    static let inactive = RosterCalculationProgress(isActive: false, message: "", completed: 0, total: 1)
}

struct RosterDerivedDataRequest: Sendable {
    let generation: Int
    let profiles: [ContactRosterProfile]
    let searchText: String
    let selectedDate: Date
    let visibleMonth: Date
    let filter: RosterCalendarKind?
    let tagFilter: ContactTagFilter
    let contactTags: [ContactTag]
    let contactTagAssignmentsByContactID: [String: Set<String>]
    let sort: RosterSort
    let language: AppLanguage
    let upcomingRange: Int
}

struct RosterDerivedDataSnapshot: Sendable {
    let allRecords: [RosterRecord]
    let filteredRecords: [RosterRecord]
    let filteredRecordOccurrences: [RosterOccurrence]
    let filteredRecordGroups: [RosterRecordGroup]
    let cachedUpcomingOccurrences: [RosterOccurrence]
    let selectedDateOccurrences: [RosterOccurrence]
    let visibleMonthDates: [Date]
    let visibleMonthTitle: String
    let weekdaySymbols: [String]
    let visibleOccurrencesByDay: [Date: [RosterOccurrence]]
    let visibleFilteredOccurrencesByDay: [Date: [RosterOccurrence]]
}

actor RosterDerivedDataWorker {
    private var cache: [RosterDerivedDataCacheKey: RosterDerivedDataSnapshot] = [:]
    private let service = RosterDerivedDataService()
    private let maxCacheEntries = 24

    func snapshot(
        for request: RosterDerivedDataRequest,
        progress: @escaping @Sendable (RosterCalculationProgress) -> Void
    ) -> RosterDerivedDataSnapshot {
        let key = RosterDerivedDataCacheKey(request)
        if let cached = cache[key] {
            progress(.active(message: "Using cached roster data", completed: 1, total: 1))
            return cached
        }

        progress(.active(message: "Preparing roster records", completed: 0, total: 6))
        let allRecords = service.allRecords(from: request.profiles)

        progress(.active(message: "Filtering roster records", completed: 1, total: 6))
        let filtered = service.filteredRecords(
            from: allRecords,
            searchText: request.searchText,
            filter: request.filter,
            tagFilter: request.tagFilter,
            contactTags: request.contactTags,
            contactTagAssignmentsByContactID: request.contactTagAssignmentsByContactID,
            sort: request.sort
        )

        progress(.active(message: "Grouping roster list", completed: 2, total: 6))
        let groups = service.recordGroups(
            from: filtered.occurrences,
            sort: request.sort,
            locale: request.language.coreLocale
        )

        progress(.active(message: "Calculating upcoming roster data", completed: 3, total: 6))
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

        let snapshot = RosterDerivedDataSnapshot(
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

        progress(.active(message: "Finishing roster data", completed: 6, total: 6))
        cache[key] = snapshot
        trimCacheIfNeeded()
        return snapshot
    }

    func filteredVisibleOccurrences(
        occurrencesByDay: [Date: [RosterOccurrence]],
        searchText: String
    ) -> [Date: [RosterOccurrence]] {
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

private struct RosterDerivedDataCacheKey: Hashable, Sendable {
    let generation: Int
    let searchText: String
    let selectedDate: Date
    let visibleMonth: Date
    let filter: RosterCalendarKind?
    let tagFilter: ContactTagFilter
    let tagSignature: Int
    let tagAssignmentSignature: Int
    let sort: RosterSort
    let locale: CalendarFormattingService.AppLocale
    let upcomingRange: Int

    init(_ request: RosterDerivedDataRequest) {
        generation = request.generation
        searchText = request.searchText
        selectedDate = Calendar.current.startOfDay(for: request.selectedDate)
        visibleMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: request.visibleMonth))
            ?? Calendar.current.startOfDay(for: request.visibleMonth)
        filter = request.filter
        tagFilter = request.tagFilter
        tagSignature = Self.tagSignature(request.contactTags)
        tagAssignmentSignature = Self.assignmentSignature(request.contactTagAssignmentsByContactID)
        sort = request.sort
        locale = request.language.coreLocale
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
