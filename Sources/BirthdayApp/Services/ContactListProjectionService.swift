import BirthdayCore
import Foundation

struct ContactListRowModel: Identifiable, Hashable, Sendable {
    let id: String
    let displayName: String
    let subtitle: String
    let kind: BirthdayCalendarKind?
    let kindTitle: String?
    let hasRecords: Bool
    let daysUntil: Int?
    let daysUntilText: String?
    let nextBirthdayText: String?
    let ageText: String?
    let sectionKey: String
    let sortKey: String
}

struct ContactListSectionModel: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let rows: [ContactListRowModel]
}

struct ContactCollectionSectionModel: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let collections: [ContactCollectionSummary]
}

struct ContactListProjectionSnapshot: Hashable, Sendable {
    let collectionSections: [ContactCollectionSectionModel]
    let contactSections: [ContactListSectionModel]
    let visibleContactCount: Int
}

struct ContactListProjectionService: Sendable {
    private let formatter = CalendarFormattingService()

    func snapshot(
        profiles: [ContactBirthdayProfile],
        grouping: ContactGroupingSnapshot,
        selectedCollectionID: String,
        searchText: String,
        language: AppLanguage,
        noBirthdaysText: String,
        todayText: String,
        upcomingOccurrencesByContactID: [String: BirthdayOccurrence] = [:]
    ) -> ContactListProjectionSnapshot {
        let visibleIDs = grouping.contactIDsByCollectionID[selectedCollectionID] ?? Set(profiles.map(\.id))
        let rows = profiles
            .filter { visibleIDs.contains($0.id) }
            .filter { searchText.isEmpty || $0.displayName.localizedCaseInsensitiveContains(searchText) }
            .map {
                rowModel(
                    for: $0,
                    language: language,
                    noBirthdaysText: noBirthdaysText,
                    todayText: todayText,
                    upcomingOccurrence: upcomingOccurrencesByContactID[$0.id]
                )
            }
            .sorted { lhs, rhs in
                let sectionOrder = sectionSortValue(lhs.sectionKey) < sectionSortValue(rhs.sectionKey)
                if lhs.sectionKey != rhs.sectionKey {
                    return sectionOrder
                }
                let comparison = lhs.sortKey.localizedStandardCompare(rhs.sortKey)
                if comparison != .orderedSame {
                    return comparison == .orderedAscending
                }
                return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
            }

        let groupedRows = Dictionary(grouping: rows, by: \.sectionKey)
        let sections = groupedRows.keys.sorted(by: sectionSortValue(_:_:)).map { key in
            ContactListSectionModel(
                id: key,
                title: key,
                rows: groupedRows[key] ?? []
            )
        }

        return ContactListProjectionSnapshot(
            collectionSections: collectionSections(from: grouping),
            contactSections: sections,
            visibleContactCount: rows.count
        )
    }

    private func rowModel(
        for profile: ContactBirthdayProfile,
        language: AppLanguage,
        noBirthdaysText: String,
        todayText: String,
        upcomingOccurrence: BirthdayOccurrence?
    ) -> ContactListRowModel {
        let firstRecord = profile.records.first
        let daysUntil = upcomingOccurrence.map { BirthdayOccurrenceResolver().daysUntil($0.date) }
        let locale = language.coreLocale
        let sortKey = romanizedSortKey(for: profile.displayName)
        return ContactListRowModel(
            id: profile.id,
            displayName: profile.displayName,
            subtitle: firstRecord.map {
                formatter.originalDate($0, locale: locale)
            } ?? noBirthdaysText,
            kind: firstRecord?.kind,
            kindTitle: firstRecord.map { shortKindName($0.kind, language: language, formatter: formatter) },
            hasRecords: !profile.records.isEmpty,
            daysUntil: daysUntil,
            daysUntilText: daysUntil.map { $0 == 0 ? todayText : daysLeftText($0, locale: locale) },
            nextBirthdayText: upcomingOccurrence.map { formatter.occurrenceDate($0.date, locale: locale) },
            ageText: upcomingOccurrence?.age.map { ageText($0, locale: locale) },
            sectionKey: sectionKey(for: sortKey),
            sortKey: sortKey
        )
    }

    private func collectionSections(from grouping: ContactGroupingSnapshot) -> [ContactCollectionSectionModel] {
        let all = grouping.collections.first { $0.id == ContactCollectionIdentifier.all }
            ?? ContactCollectionSummary(
                id: ContactCollectionIdentifier.all,
                title: "All Contacts",
                kind: .all,
                parentContainerID: nil,
                contactCount: 0
            )
        var sections = [
            ContactCollectionSectionModel(id: "all", title: "All Contacts", collections: [all])
        ]

        for container in grouping.containers.sorted(by: { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) {
            let containerCollections = grouping.collections
                .filter { $0.parentContainerID == container.id }
                .sorted { lhs, rhs in
                    if lhs.kind != rhs.kind {
                        return lhs.kind == .container
                    }
                    return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
                }
            guard !containerCollections.isEmpty else { continue }
            sections.append(ContactCollectionSectionModel(
                id: container.id,
                title: container.name,
                collections: containerCollections
            ))
        }

        return sections
    }

    private func romanizedSortKey(for value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "#" }
        let mutable = NSMutableString(string: trimmed) as CFMutableString
        CFStringTransform(mutable, nil, kCFStringTransformToLatin, false)
        CFStringTransform(mutable, nil, kCFStringTransformStripCombiningMarks, false)
        return (mutable as String).uppercased()
    }

    private func sectionKey(for sortKey: String) -> String {
        guard let first = sortKey.first else { return "#" }
        let letter = String(first)
        return letter.range(of: "[A-Z]", options: .regularExpression) == nil ? "#" : letter
    }

    private func sectionSortValue(_ key: String) -> Int {
        if key == "#" { return Int.max }
        guard let scalar = key.unicodeScalars.first else { return Int.max }
        return Int(scalar.value)
    }

    private func sectionSortValue(_ lhs: String, _ rhs: String) -> Bool {
        sectionSortValue(lhs) < sectionSortValue(rhs)
    }

    private func shortKindName(
        _ kind: BirthdayCalendarKind,
        language: AppLanguage,
        formatter: CalendarFormattingService
    ) -> String {
        switch kind {
        case .gregorian: formatter.calendarName(kind, locale: language.coreLocale)
        case .chinese: language.coreLocale == .english ? "Lunar" : formatter.calendarName(kind, locale: language.coreLocale)
        case .hebrew: "עברי"
        case .islamic: "هجري"
        }
    }

    private func ageText(_ age: Int, locale: CalendarFormattingService.AppLocale) -> String {
        switch locale {
        case .english: "Turns \(age)"
        case .simplifiedChinese: "满 \(age) 岁"
        case .traditionalChinese: "滿 \(age) 歲"
        }
    }
}
