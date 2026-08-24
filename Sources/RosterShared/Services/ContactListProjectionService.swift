import RosterCore
import Foundation

package struct ContactListRowModel: Identifiable, Hashable, Sendable {
    package let id: String
    package let displayName: String
    package let subtitle: String
    package let tags: [ContactTag]
    package let kind: RosterCalendarKind?
    package let kindTitle: String?
    package let hasRecords: Bool
    package let daysUntil: Int?
    package let daysUntilText: String?
    package let nextRosterText: String?
    package let ageText: String?
    package let sectionKey: String
    package let sortKey: String
}

package struct ContactListSectionModel: Identifiable, Hashable, Sendable {
    package let id: String
    package let title: String
    package let rows: [ContactListRowModel]
}

package struct ContactCollectionSectionModel: Identifiable, Hashable, Sendable {
    package let id: String
    package let title: String
    package let collections: [ContactCollectionSummary]
}

package struct ContactListProjectionSnapshot: Hashable, Sendable {
    package let collectionSections: [ContactCollectionSectionModel]
    package let contactSections: [ContactListSectionModel]
    package let visibleContactCount: Int
}

package struct ContactListProjectionRequest: Hashable, Sendable {
    package var profiles: [ContactRosterProfile]
    package var grouping: ContactGroupingSnapshot
    package var contactTags: [ContactTag]
    package var tagIDsByContactID: [String: Set<String>]
    package var accessScope: ContactAccessScope
    package var selectedCollectionID: String
    package var selectedTagFilter: ContactTagFilter?
    package var searchText: String
    package var language: AppLanguage
    package var noRostersText: String
    package var todayText: String
    package var upcomingOccurrencesByContactID: [String: RosterOccurrence]

    package init(
        profiles: [ContactRosterProfile],
        grouping: ContactGroupingSnapshot,
        contactTags: [ContactTag] = [],
        tagIDsByContactID: [String: Set<String>] = [:],
        accessScope: ContactAccessScope = .all,
        selectedCollectionID: String,
        selectedTagFilter: ContactTagFilter? = nil,
        searchText: String,
        language: AppLanguage,
        noRostersText: String,
        todayText: String,
        upcomingOccurrencesByContactID: [String: RosterOccurrence] = [:]
    ) {
        self.profiles = profiles
        self.grouping = grouping
        self.contactTags = contactTags
        self.tagIDsByContactID = tagIDsByContactID
        self.accessScope = accessScope
        self.selectedCollectionID = selectedCollectionID
        self.selectedTagFilter = selectedTagFilter
        self.searchText = searchText
        self.language = language
        self.noRostersText = noRostersText
        self.todayText = todayText
        self.upcomingOccurrencesByContactID = upcomingOccurrencesByContactID
    }
}

package actor ContactListProjectionWorker {
    private let service = ContactListProjectionService()
    private var cache: [ContactListProjectionRequest: ContactListProjectionSnapshot] = [:]
    private let maxCacheEntries = 16

    package var cacheEntryCount: Int {
        cache.count
    }

    package func snapshot(for request: ContactListProjectionRequest) -> ContactListProjectionSnapshot {
        if let cached = cache[request] {
            return cached
        }

        let snapshot = service.snapshot(
            profiles: request.profiles,
            grouping: request.grouping,
            contactTags: request.contactTags,
            tagIDsByContactID: request.tagIDsByContactID,
            accessScope: request.accessScope,
            selectedCollectionID: request.selectedCollectionID,
            selectedTagFilter: request.selectedTagFilter,
            searchText: request.searchText,
            language: request.language,
            noRostersText: request.noRostersText,
            todayText: request.todayText,
            upcomingOccurrencesByContactID: request.upcomingOccurrencesByContactID
        )
        cache[request] = snapshot
        trimCacheIfNeeded()
        return snapshot
    }

    private func trimCacheIfNeeded() {
        guard cache.count > maxCacheEntries else { return }
        let overflow = cache.count - maxCacheEntries
        for key in cache.keys.prefix(overflow) {
            cache[key] = nil
        }
    }
}

package struct ContactListProjectionService: Sendable {
    private let formatter = CalendarFormattingService()

    package func snapshot(
        profiles: [ContactRosterProfile],
        grouping: ContactGroupingSnapshot,
        contactTags: [ContactTag] = [],
        tagIDsByContactID: [String: Set<String>] = [:],
        accessScope: ContactAccessScope = .all,
        selectedCollectionID: String,
        selectedTagFilter: ContactTagFilter? = nil,
        searchText: String,
        language: AppLanguage,
        noRostersText: String,
        todayText: String,
        upcomingOccurrencesByContactID: [String: RosterOccurrence] = [:]
    ) -> ContactListProjectionSnapshot {
        let profileIDs = Set(profiles.map(\.id))
        let visibleIDs = visibleContactIDs(
            profiles: profiles,
            grouping: grouping,
            tagIDsByContactID: tagIDsByContactID,
            contactTags: contactTags,
            accessScope: accessScope,
            selectedCollectionID: selectedCollectionID,
            selectedTagFilter: selectedTagFilter
        )
        let tagsByID = Dictionary(uniqueKeysWithValues: contactTags.map { ($0.id, $0) })
        let unsortedRows = profiles
            .filter { visibleIDs.contains($0.id) }
            .filter {
                searchText.isEmpty ||
                    $0.displayName.localizedCaseInsensitiveContains(searchText) ||
                    tags(for: $0.id, tagIDsByContactID: tagIDsByContactID, tagsByID: tagsByID)
                    .contains { $0.name.localizedCaseInsensitiveContains(searchText) }
            }
            .map {
                rowModel(
                    for: $0,
                    tags: tags(for: $0.id, tagIDsByContactID: tagIDsByContactID, tagsByID: tagsByID),
                    language: language,
                    noRostersText: noRostersText,
                    todayText: todayText,
                    upcomingOccurrence: upcomingOccurrencesByContactID[$0.id]
                )
            }

        let sectionSortValues = Dictionary(
            uniqueKeysWithValues: Set(unsortedRows.map(\.sectionKey)).map {
                ($0, NameSortKey.sectionSortValue($0))
            }
        )
        let rows = unsortedRows
            .sorted { lhs, rhs in
                if lhs.sectionKey != rhs.sectionKey {
                    return (sectionSortValues[lhs.sectionKey] ?? Int.max) < (sectionSortValues[rhs.sectionKey] ?? Int.max)
                }
                let comparison = lhs.sortKey.localizedStandardCompare(rhs.sortKey)
                if comparison != .orderedSame {
                    return comparison == .orderedAscending
                }
                return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
            }

        let groupedRows = Dictionary(grouping: rows, by: \.sectionKey)
        let sections = groupedRows.keys.sorted(by: NameSortKey.sectionSortValue(_:_:)).map { key in
            ContactListSectionModel(
                id: key,
                title: key,
                rows: groupedRows[key] ?? []
            )
        }

        return ContactListProjectionSnapshot(
            collectionSections: collectionSections(
                from: grouping,
                accessScope: accessScope,
                profileIDs: profileIDs
            ),
            contactSections: sections,
            visibleContactCount: rows.count
        )
    }

    private func visibleContactIDs(
        profiles: [ContactRosterProfile],
        grouping: ContactGroupingSnapshot,
        tagIDsByContactID: [String: Set<String>],
        contactTags: [ContactTag],
        accessScope: ContactAccessScope,
        selectedCollectionID: String,
        selectedTagFilter: ContactTagFilter?
    ) -> Set<String> {
        let profileIDs = Set(profiles.map(\.id))
        let scopedIDs = accessScope.allowedContactIDs(in: grouping) ?? profileIDs

        if let selectedTagFilter {
            let matchingTagIDs = selectedTagFilter.matchingTagIDs(in: contactTags)
            return profileIDs
                .intersection(scopedIDs)
                .filter {
                    selectedTagFilter.contains(
                        contactID: $0,
                        assignments: tagIDsByContactID,
                        matchingTagIDs: matchingTagIDs
                    )
                }
        }

        guard selectedCollectionID != ContactCollectionIdentifier.all else {
            return scopedIDs.intersection(profileIDs)
        }

        let collectionIDs = grouping.contactIDsByCollectionID[selectedCollectionID] ?? profileIDs
        return collectionIDs
            .intersection(scopedIDs)
            .intersection(profileIDs)
    }

    private func rowModel(
        for profile: ContactRosterProfile,
        tags: [ContactTag],
        language: AppLanguage,
        noRostersText: String,
        todayText: String,
        upcomingOccurrence: RosterOccurrence?
    ) -> ContactListRowModel {
        let firstRecord = profile.records.first
        let daysUntil = upcomingOccurrence.map { RosterOccurrenceResolver().daysUntil($0.date) }
        let locale = language.coreLocale
        let sortKey = NameSortKey.romanized(profile.displayName)
        return ContactListRowModel(
            id: profile.id,
            displayName: profile.displayName,
            subtitle: firstRecord.map {
                formatter.originalDate($0, locale: locale)
            } ?? noRostersText,
            tags: tags,
            kind: firstRecord?.kind,
            kindTitle: firstRecord.map { shortKindName($0.kind, language: language, formatter: formatter) },
            hasRecords: !profile.records.isEmpty,
            daysUntil: daysUntil,
            daysUntilText: daysUntil.map { $0 == 0 ? todayText : daysLeftText($0, locale: locale) },
            nextRosterText: upcomingOccurrence.map { formatter.occurrenceDate($0.date, locale: locale) },
            ageText: upcomingOccurrence?.age.map { ageText($0, locale: locale) },
            sectionKey: NameSortKey.sectionKey(for: sortKey),
            sortKey: sortKey
        )
    }

    private func collectionSections(
        from grouping: ContactGroupingSnapshot,
        accessScope: ContactAccessScope,
        profileIDs: Set<String>
    ) -> [ContactCollectionSectionModel] {
        if accessScope.mode == .selectedGroups {
            return scopedCollectionSections(from: grouping, accessScope: accessScope, profileIDs: profileIDs)
        }

        let all = grouping.collections.first { $0.id == ContactCollectionIdentifier.all }
            ?? ContactCollectionSummary(
                id: ContactCollectionIdentifier.all,
                title: "All Contacts",
                kind: .all,
                parentContainerID: nil,
                contactCount: 0
            )
        var libraryCollections = [all]
        if let ungrouped = grouping.collections.first(where: { $0.id == ContactCollectionIdentifier.ungrouped }),
           ungrouped.contactCount > 0 {
            libraryCollections.append(ungrouped)
        }
        var sections = [
            ContactCollectionSectionModel(id: "all", title: "All Contacts", collections: libraryCollections)
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

    private func scopedCollectionSections(
        from grouping: ContactGroupingSnapshot,
        accessScope: ContactAccessScope,
        profileIDs: Set<String>
    ) -> [ContactCollectionSectionModel] {
        var libraryCollections = [
            ContactCollectionSummary(
                id: ContactCollectionIdentifier.all,
                title: "All Contacts",
                kind: .all,
                parentContainerID: nil,
                contactCount: profileIDs.count
            )
        ]

        if accessScope.includeUngroupedContacts {
            let ungroupedIDs = (grouping.contactIDsByCollectionID[ContactCollectionIdentifier.ungrouped] ?? [])
                .intersection(profileIDs)
            if !ungroupedIDs.isEmpty {
                libraryCollections.append(ContactCollectionSummary(
                    id: ContactCollectionIdentifier.ungrouped,
                    title: "Ungrouped",
                    kind: .ungrouped,
                    parentContainerID: nil,
                    contactCount: ungroupedIDs.count
                ))
            }
        }

        var sections = [
            ContactCollectionSectionModel(id: "all", title: "All Contacts", collections: libraryCollections)
        ]

        for container in grouping.containers.sorted(by: { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) {
            let selectedGroupCollections = grouping.groups
                .filter { $0.containerID == container.id && accessScope.allowedGroupIDs.contains($0.id) }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                .compactMap { group -> ContactCollectionSummary? in
                    let collectionID = ContactCollectionIdentifier.group(group.id)
                    let count = (grouping.contactIDsByCollectionID[collectionID] ?? []).intersection(profileIDs).count
                    guard count > 0 else { return nil }
                    return ContactCollectionSummary(
                        id: collectionID,
                        title: group.name,
                        kind: .group,
                        parentContainerID: container.id,
                        contactCount: count
                    )
                }

            guard !selectedGroupCollections.isEmpty else { continue }
            sections.append(ContactCollectionSectionModel(
                id: container.id,
                title: container.name,
                collections: selectedGroupCollections
            ))
        }

        return sections
    }

    private func shortKindName(
        _ kind: RosterCalendarKind,
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

    private func tags(
        for contactID: String,
        tagIDsByContactID: [String: Set<String>],
        tagsByID: [String: ContactTag]
    ) -> [ContactTag] {
        (tagIDsByContactID[contactID] ?? [])
            .compactMap { tagsByID[$0] }
            .sorted {
                if $0.sortOrder != $1.sortOrder {
                    return $0.sortOrder < $1.sortOrder
                }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
    }

    private func allContactsTitle(language: AppLanguage) -> String {
        switch language.coreLocale {
        case .english: "All Contacts"
        case .simplifiedChinese: "全部联系人"
        case .traditionalChinese: "全部聯絡人"
        }
    }
}
