import BirthdayCore
import Foundation
import Testing
@testable import BirthdayApp

@Suite("Contact architecture")
struct ContactArchitectureTests {
    @Test("Chinese names are projected into pinyin initial sections")
    func chineseNamesUsePinyinInitials() {
        let profiles = [
            ContactBirthdayProfile(id: "huang", displayName: "黄建秀", organizationName: "", records: []),
            ContactBirthdayProfile(id: "ada", displayName: "Ada", organizationName: "", records: [])
        ]
        let grouping = ContactGroupingSnapshot(
            collections: [
                ContactCollectionSummary(
                    id: ContactCollectionIdentifier.all,
                    title: "All Contacts",
                    kind: .all,
                    parentContainerID: nil,
                    contactCount: profiles.count
                )
            ],
            contactIDsByCollectionID: [ContactCollectionIdentifier.all: Set(profiles.map(\.id))]
        )

        let snapshot = ContactListProjectionService().snapshot(
            profiles: profiles,
            grouping: grouping,
            selectedCollectionID: ContactCollectionIdentifier.all,
            searchText: "",
            language: .zhHans,
            noBirthdaysText: "没有生日记录",
            todayText: "今天"
        )

        #expect(snapshot.contactSections.map(\.title) == ["A", "H"])
        #expect(snapshot.contactSections.last?.rows.first?.displayName == "黄建秀")
    }

    @Test("SQLite contact snapshot cache round trips basic snapshots")
    func contactSnapshotCacheRoundTrips() async {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite3")
        let cache = ContactSnapshotCache(databaseURL: databaseURL)
        let profile = ContactBirthdayProfile(id: "a", displayName: "Ada", organizationName: "", records: [])
        let snapshot = ContactDataSnapshot(
            profiles: [profile],
            grouping: ContactGroupingSnapshot(
                collections: [
                    ContactCollectionSummary(
                        id: ContactCollectionIdentifier.all,
                        title: "All Contacts",
                        kind: .all,
                        parentContainerID: nil,
                        contactCount: 1
                    )
                ],
                contactIDsByCollectionID: [ContactCollectionIdentifier.all: ["a"]]
            ),
            fieldAccessLevel: .birthdayOnly,
            loadedAt: Date(timeIntervalSince1970: 42)
        )

        await cache.save(snapshot)
        let loaded = await cache.load(fieldAccessLevel: .birthdayOnly)

        #expect(loaded?.profiles == [profile])
        #expect(loaded?.grouping.collections.first?.contactCount == 1)
        #expect(await cache.load(fieldAccessLevel: .extended) == nil)
    }

    @Test("Selected contact collection filters projected rows locally")
    func selectedCollectionFiltersProjection() {
        let profiles = [
            ContactBirthdayProfile(id: "a", displayName: "Ada", organizationName: "", records: []),
            ContactBirthdayProfile(id: "b", displayName: "Grace", organizationName: "", records: []),
            ContactBirthdayProfile(id: "c", displayName: "黄建秀", organizationName: "", records: [])
        ]
        let collectionID = ContactCollectionIdentifier.group("friends")
        let grouping = ContactGroupingSnapshot(
            collections: [
                ContactCollectionSummary(id: ContactCollectionIdentifier.all, title: "All Contacts", kind: .all, parentContainerID: nil, contactCount: 3),
                ContactCollectionSummary(id: collectionID, title: "Friends", kind: .group, parentContainerID: "icloud", contactCount: 2)
            ],
            contactIDsByCollectionID: [
                ContactCollectionIdentifier.all: Set(profiles.map(\.id)),
                collectionID: ["b", "c"]
            ]
        )

        let snapshot = ContactListProjectionService().snapshot(
            profiles: profiles,
            grouping: grouping,
            selectedCollectionID: collectionID,
            searchText: "",
            language: .zhHans,
            noBirthdaysText: "没有生日记录",
            todayText: "今天"
        )

        #expect(snapshot.visibleContactCount == 2)
        #expect(Set(snapshot.contactSections.flatMap { $0.rows.map(\.id) }) == ["b", "c"])
    }

    @Test("Birthday list age sort orders by computed occurrence age")
    func birthdayListAgeSortUsesOccurrenceAge() throws {
        let service = BirthdayDerivedDataService()
        let now = try #require(gregorianDate(year: 2026, month: 8, day: 10))
        let records = [
            birthdayRecord(id: "younger", name: "Younger", year: 1995, month: 8, day: 20),
            birthdayRecord(id: "unknown", name: "Unknown", year: nil, month: 8, day: 20),
            birthdayRecord(id: "older", name: "Older", year: 1971, month: 8, day: 20)
        ]

        let filtered = service.filteredRecords(
            from: records,
            searchText: "",
            filter: nil,
            sort: .age,
            now: now
        )

        #expect(filtered.occurrences.map(\.record.contactID) == ["older", "younger", "unknown"])
        #expect(filtered.occurrences.map(\.age) == [55, 31, nil])
    }

    @Test("Birthday list name sort groups Chinese names by pinyin initial")
    func birthdayListNameSortUsesPinyinSections() throws {
        let service = BirthdayDerivedDataService()
        let now = try #require(gregorianDate(year: 2026, month: 8, day: 10))
        let records = [
            birthdayRecord(id: "huang", name: "黄建秀", year: 1972, month: 9, day: 10),
            birthdayRecord(id: "ada", name: "Ada", year: 1990, month: 8, day: 20)
        ]

        let filtered = service.filteredRecords(
            from: records,
            searchText: "",
            filter: nil,
            sort: .name,
            now: now
        )
        let groups = service.recordGroups(
            from: filtered.occurrences,
            sort: .name,
            locale: .simplifiedChinese
        )

        #expect(filtered.occurrences.map(\.record.contactID) == ["ada", "huang"])
        #expect(groups.map(\.title) == ["A", "H"])
        #expect(groups.last?.occurrences.first?.record.contactID == "huang")
    }

    @Test("Birthday list calendar sort groups by calendar kind")
    func birthdayListCalendarSortGroupsByCalendarKind() throws {
        let service = BirthdayDerivedDataService()
        let now = try #require(gregorianDate(year: 2026, month: 8, day: 10))
        let records = [
            birthdayRecord(id: "lunar", name: "Lunar", kind: .chinese, year: 1971, month: 7, day: 8),
            birthdayRecord(id: "gregorian", name: "Gregorian", kind: .gregorian, year: 1971, month: 8, day: 20)
        ]

        let filtered = service.filteredRecords(
            from: records,
            searchText: "",
            filter: nil,
            sort: .calendar,
            now: now
        )
        let groups = service.recordGroups(
            from: filtered.occurrences,
            sort: .calendar,
            locale: .simplifiedChinese
        )

        #expect(filtered.occurrences.map(\.record.kind) == [.gregorian, .chinese])
        #expect(groups.map(\.title) == ["公历", "农历"])
        #expect(groups.map { $0.occurrences.first?.record.contactID } == ["gregorian", "lunar"])
    }

    @Test("SQLite cache keeps basic and extended snapshots separate")
    func contactSnapshotCacheSeparatesFieldAccessLevels() async {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite3")
        let cache = ContactSnapshotCache(databaseURL: databaseURL)
        let basic = ContactDataSnapshot(
            profiles: [ContactBirthdayProfile(id: "basic", displayName: "Basic", organizationName: "", records: [])],
            fieldAccessLevel: .birthdayOnly
        )
        let extended = ContactDataSnapshot(
            profiles: [ContactBirthdayProfile(id: "extended", displayName: "Extended", organizationName: "", records: [])],
            fieldAccessLevel: .extended
        )

        await cache.save(basic)
        await cache.save(extended)

        #expect(await cache.load(fieldAccessLevel: .birthdayOnly)?.profiles.first?.id == "basic")
        #expect(await cache.load(fieldAccessLevel: .extended)?.profiles.first?.id == "extended")
    }

    @Test("Contact access scope filters selected groups and ungrouped contacts")
    func contactAccessScopeFiltersSelectedGroupsAndUngroupedContacts() {
        let grouping = ContactGroupingSnapshot(
            groups: [
                ContactGroupSummary(id: "friends", containerID: "icloud", name: "Friends", contactCount: 2),
                ContactGroupSummary(id: "work", containerID: "icloud", name: "Work", contactCount: 1)
            ],
            contactIDsByCollectionID: [
                ContactCollectionIdentifier.all: ["ada", "grace", "linus", "ungrouped"],
                ContactCollectionIdentifier.group("friends"): ["ada", "grace"],
                ContactCollectionIdentifier.group("work"): ["linus"],
                ContactCollectionIdentifier.ungrouped: ["ungrouped"]
            ]
        )
        let scope = ContactAccessScope(
            mode: .selectedGroups,
            allowedGroupIDs: ["friends"],
            includeUngroupedContacts: true
        )

        #expect(scope.allowedContactIDs(in: grouping) == ["ada", "grace", "ungrouped"])
    }

    @Test("Contact snapshot scope removes non-selected profiles and extended fields")
    func contactSnapshotScopeRemovesNonSelectedProfilesAndExtendedFields() {
        let profiles = [
            ContactBirthdayProfile(id: "ada", displayName: "Ada", organizationName: "", records: []),
            ContactBirthdayProfile(id: "grace", displayName: "Grace", organizationName: "", records: []),
            ContactBirthdayProfile(id: "linus", displayName: "Linus", organizationName: "", records: [])
        ]
        let snapshot = ContactDataSnapshot(
            profiles: profiles,
            grouping: ContactGroupingSnapshot(
                groups: [ContactGroupSummary(id: "friends", containerID: "icloud", name: "Friends", contactCount: 2)],
                contactIDsByCollectionID: [
                    ContactCollectionIdentifier.all: Set(profiles.map(\.id)),
                    ContactCollectionIdentifier.group("friends"): ["ada", "grace"]
                ]
            ),
            extendedProfilesByID: [
                "ada": ContactExtendedProfile(phoneNumbers: ["1"]),
                "linus": ContactExtendedProfile(phoneNumbers: ["2"])
            ],
            fieldAccessLevel: .extended
        )

        let scoped = snapshot.scoped(to: ContactAccessScope(
            mode: .selectedGroups,
            allowedGroupIDs: ["friends"],
            includeUngroupedContacts: false
        ))

        #expect(scoped.profiles.map(\.id) == ["ada", "grace"])
        #expect(scoped.extendedProfilesByID.keys.sorted() == ["ada"])
    }

    @Test("Contact projection deduplicates multiple selected groups")
    func contactProjectionDeduplicatesMultipleSelectedGroups() {
        let profiles = [
            ContactBirthdayProfile(id: "ada", displayName: "Ada", organizationName: "", records: []),
            ContactBirthdayProfile(id: "grace", displayName: "Grace", organizationName: "", records: []),
            ContactBirthdayProfile(id: "linus", displayName: "Linus", organizationName: "", records: [])
        ]
        let grouping = ContactGroupingSnapshot(
            containers: [ContactContainerSummary(id: "icloud", name: "iCloud", typeName: "CardDAV")],
            groups: [
                ContactGroupSummary(id: "friends", containerID: "icloud", name: "Friends", contactCount: 2),
                ContactGroupSummary(id: "work", containerID: "icloud", name: "Work", contactCount: 2)
            ],
            collections: [
                ContactCollectionSummary(id: ContactCollectionIdentifier.all, title: "All Contacts", kind: .all, parentContainerID: nil, contactCount: 3),
                ContactCollectionSummary(id: ContactCollectionIdentifier.group("friends"), title: "Friends", kind: .group, parentContainerID: "icloud", contactCount: 2),
                ContactCollectionSummary(id: ContactCollectionIdentifier.group("work"), title: "Work", kind: .group, parentContainerID: "icloud", contactCount: 2)
            ],
            contactIDsByCollectionID: [
                ContactCollectionIdentifier.all: Set(profiles.map(\.id)),
                ContactCollectionIdentifier.group("friends"): ["ada", "grace"],
                ContactCollectionIdentifier.group("work"): ["grace", "linus"]
            ]
        )

        let snapshot = ContactListProjectionService().snapshot(
            profiles: profiles,
            grouping: grouping,
            accessScope: ContactAccessScope(
                mode: .selectedGroups,
                allowedGroupIDs: ["friends", "work"],
                includeUngroupedContacts: false
            ),
            selectedCollectionID: ContactCollectionIdentifier.all,
            searchText: "",
            language: .en,
            noBirthdaysText: "No birthdays",
            todayText: "Today"
        )

        #expect(snapshot.visibleContactCount == 3)
        #expect(Set(snapshot.contactSections.flatMap { $0.rows.map(\.id) }) == ["ada", "grace", "linus"])
    }

    @Test("SQLite cache separates contact access scopes")
    func contactSnapshotCacheSeparatesAccessScopes() async {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite3")
        let cache = ContactSnapshotCache(databaseURL: databaseURL)
        let allSnapshot = ContactDataSnapshot(
            profiles: [ContactBirthdayProfile(id: "all", displayName: "All", organizationName: "", records: [])],
            fieldAccessLevel: .birthdayOnly
        )
        let selectedScope = ContactAccessScope(
            mode: .selectedGroups,
            allowedGroupIDs: ["friends"],
            includeUngroupedContacts: false
        )
        let selectedSnapshot = ContactDataSnapshot(
            profiles: [ContactBirthdayProfile(id: "selected", displayName: "Selected", organizationName: "", records: [])],
            fieldAccessLevel: .birthdayOnly
        )

        await cache.save(allSnapshot, accessScope: .all)
        await cache.save(selectedSnapshot, accessScope: selectedScope)

        #expect(await cache.load(fieldAccessLevel: .birthdayOnly, accessScope: .all)?.profiles.first?.id == "all")
        #expect(await cache.load(fieldAccessLevel: .birthdayOnly, accessScope: selectedScope)?.profiles.first?.id == "selected")
    }

    @Test("Local birthday store persists extra birthday specs by person")
    func localBirthdayStoreRoundTripsExtraSpecs() async {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite3")
        let store = LocalBirthdayStore(databaseURL: databaseURL)
        let spec = BirthdayDateSpec(
            id: "local-extra",
            personID: "guo",
            kind: .chinese,
            components: DateComponents(calendar: Calendar(identifier: .chinese), year: 1971, month: 7, day: 8),
            source: .local,
            syncPolicy: .localOnly
        )

        await store.saveLocalOnlySpecs([spec], for: "guo")
        let loaded = await store.loadAll()

        #expect(loaded["guo"] == [spec])
    }

    @Test("Local birthday store deletes specs for removed contacts")
    func localBirthdayStoreDeletesSpecsForRemovedContacts() async {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite3")
        let store = LocalBirthdayStore(databaseURL: databaseURL)
        let guoSpec = BirthdayDateSpec(
            id: "local-guo",
            personID: "guo",
            kind: .chinese,
            components: DateComponents(calendar: Calendar(identifier: .chinese), year: 1971, month: 7, day: 8),
            source: .local,
            syncPolicy: .localOnly
        )
        let adaSpec = BirthdayDateSpec(
            id: "local-ada",
            personID: "ada",
            kind: .gregorian,
            components: DateComponents(calendar: Calendar(identifier: .gregorian), year: 1990, month: 8, day: 4),
            source: .local,
            syncPolicy: .localOnly
        )

        await store.saveLocalOnlySpecs([guoSpec], for: "guo")
        await store.saveLocalOnlySpecs([adaSpec], for: "ada")
        await store.deleteLocalOnlySpecs(for: ["guo"])
        let loaded = await store.loadAll()

        #expect(loaded["guo"] == nil)
        #expect(loaded["ada"] == [adaSpec])
    }

    @Test("Birthday edit draft separates Apple fields from local-only extra records")
    func birthdayEditDraftSplitsAppleAndLocalSpecs() throws {
        let appleBirthday = BirthdayRecord(
            id: "apple-gregorian",
            contactID: "guo",
            contactName: "郭峰",
            organizationName: "",
            kind: .gregorian,
            components: DateComponents(calendar: Calendar(identifier: .gregorian), year: 1971, month: 8, day: 20),
            source: .appleBirthday,
            syncPolicy: .writeBackToApple
        )
        let profile = ContactBirthdayProfile(id: "guo", displayName: "郭峰", organizationName: "", records: [appleBirthday])
        var draft = BirthdayEditDraft(profile: profile)
        draft.entries.append(BirthdayEditEntry(personID: "guo", kind: .chinese))
        draft.entries[1].year = "1971"
        draft.entries[1].month = "7"
        draft.entries[1].day = "8"

        let payload = try #require(draft.payload(personID: "guo"))

        #expect(payload.gregorian?.month == 8)
        #expect(payload.gregorian?.day == 20)
        #expect(payload.nonGregorian == nil)
        #expect(payload.localOnlyDateSpecs.count == 1)
        #expect(payload.localOnlyDateSpecs.first?.kind == .chinese)
    }

    @Test("Birthday edit draft treats legacy contact records as Apple editable fields")
    func birthdayEditDraftPreservesLegacyAppleBirthday() throws {
        let legacyAppleBirthday = BirthdayRecord(
            id: "guo-gregorian",
            contactID: "guo",
            contactName: "郭峰",
            organizationName: "",
            kind: .gregorian,
            components: DateComponents(calendar: Calendar(identifier: .gregorian), year: 1971, month: 8, day: 20),
            source: .local,
            syncPolicy: .localOnly
        )
        let profile = ContactBirthdayProfile(id: "guo", displayName: "郭峰", organizationName: "", records: [legacyAppleBirthday])
        let draft = BirthdayEditDraft(profile: profile)
        let payload = try #require(draft.payload(personID: "guo"))

        #expect(payload.gregorian?.year == 1971)
        #expect(payload.gregorian?.month == 8)
        #expect(payload.gregorian?.day == 20)
        #expect(payload.localOnlyDateSpecs.isEmpty)
    }

    private func birthdayRecord(
        id: String,
        name: String,
        kind: BirthdayCalendarKind = .gregorian,
        year: Int?,
        month: Int,
        day: Int
    ) -> BirthdayRecord {
        BirthdayRecord(
            id: "\(id)-\(kind.rawValue)",
            contactID: id,
            contactName: name,
            organizationName: "",
            kind: kind,
            components: DateComponents(
                calendar: Calendar(identifier: kind.calendarIdentifier),
                year: year,
                month: month,
                day: day
            )
        )
    }

    private func gregorianDate(year: Int, month: Int, day: Int) -> Date? {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day))
    }
}
