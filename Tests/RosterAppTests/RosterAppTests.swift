import RosterCore
import Foundation
import Testing
@testable import RosterApp

@Suite("Contact architecture")
struct RosterAppTests {
    @Test("Chinese names are projected into pinyin initial sections")
    func chineseNamesUsePinyinInitials() {
        let profiles = [
            ContactRosterProfile(id: "huang", displayName: "黄建秀", organizationName: "", records: []),
            ContactRosterProfile(id: "ada", displayName: "Ada", organizationName: "", records: [])
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
            noRostersText: "没有生日记录",
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
        let profile = ContactRosterProfile(id: "a", displayName: "Ada", organizationName: "", records: [])
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

    @Test("Local contact drafts preserve editable contact fields")
    func contactDraftsPreserveEditableFields() {
        let profile = ContactRosterProfile(
            id: "ada",
            displayName: "Ada Lovelace",
            organizationName: "Analytical Engines",
            records: [],
            givenName: "Ada",
            familyName: "Lovelace",
            nickname: "Countess",
            departmentName: "Research",
            jobTitle: "Mathematician",
            phoneNumbers: ["123"],
            emailAddresses: ["ada@example.com"],
            postalAddresses: ["1 Example Street"]
        )

        let draft = LocalContactDraft(profile: profile, extended: nil, birthdaySpecs: [])
        let roundTrip = draft.profile

        #expect(roundTrip.givenName == "Ada")
        #expect(roundTrip.familyName == "Lovelace")
        #expect(roundTrip.nickname == "Countess")
        #expect(roundTrip.departmentName == "Research")
        #expect(roundTrip.jobTitle == "Mathematician")
        #expect(roundTrip.phoneNumbers == ["123"])
        #expect(roundTrip.emailAddresses == ["ada@example.com"])
        #expect(roundTrip.postalAddresses == ["1 Example Street"])
    }

    @Test("Contact operation journal persists drafts operations and policy")
    func contactOperationJournalPersistsState() async {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite3")
        let store = ContactOperationJournalStore(databaseURL: databaseURL)
        let components = DateComponents(calendar: Calendar(identifier: .gregorian), year: 1990, month: 8, day: 11)
        let spec = RosterDateSpec(
            id: "ada-gregorian",
            personID: "ada",
            kind: .gregorian,
            components: components,
            source: .appleRoster,
            syncPolicy: .writeBackToApple
        )
        let draft = LocalContactDraft(
            id: "ada",
            appleContactID: "ada",
            displayName: "Ada Lovelace",
            organizationName: "Analytical Engines",
            birthdaySpecs: [spec],
            isDeleted: true,
            deletedAt: Date(timeIntervalSince1970: 12),
            baseSignature: 42,
            updatedAt: Date(timeIntervalSince1970: 24)
        )
        let operation = ContactOperationLog(
            id: "op-1",
            contactID: "ada",
            appleContactID: "ada",
            displayName: "Ada Lovelace",
            kind: .delete,
            summary: "Moved Ada Lovelace to Trash",
            draft: draft,
            createdAt: Date(timeIntervalSince1970: 30),
            updatedAt: Date(timeIntervalSince1970: 30)
        )

        await store.setWritePolicy(.automatic)
        await store.saveDraft(draft)
        await store.appendOperation(operation)

        let loaded = await store.load()

        #expect(loaded.writePolicy == .automatic)
        #expect(loaded.draftsByContactID["ada"]?.isDeleted == true)
        #expect(loaded.draftsByContactID["ada"]?.profile.records.first?.month == 8)
        #expect(loaded.operations.map(\.id) == ["op-1"])
        #expect(loaded.operations.first?.status == .pending)
    }

    @Test("Selected contact collection filters projected rows locally")
    func selectedCollectionFiltersProjection() {
        let profiles = [
            ContactRosterProfile(id: "a", displayName: "Ada", organizationName: "", records: []),
            ContactRosterProfile(id: "b", displayName: "Grace", organizationName: "", records: []),
            ContactRosterProfile(id: "c", displayName: "黄建秀", organizationName: "", records: [])
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
            noRostersText: "没有生日记录",
            todayText: "今天"
        )

        #expect(snapshot.visibleContactCount == 2)
        #expect(Set(snapshot.contactSections.flatMap { $0.rows.map(\.id) }) == ["b", "c"])
    }

    @Test("Roster list age sort orders by computed occurrence age")
    func rosterListAgeSortUsesOccurrenceAge() throws {
        let service = RosterDerivedDataService()
        let now = try #require(gregorianDate(year: 2026, month: 8, day: 10))
        let records = [
            rosterRecord(id: "younger", name: "Younger", year: 1995, month: 8, day: 20),
            rosterRecord(id: "unknown", name: "Unknown", year: nil, month: 8, day: 20),
            rosterRecord(id: "older", name: "Older", year: 1971, month: 8, day: 20)
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

    @Test("Roster list name sort groups Chinese names by pinyin initial")
    func rosterListNameSortUsesPinyinSections() throws {
        let service = RosterDerivedDataService()
        let now = try #require(gregorianDate(year: 2026, month: 8, day: 10))
        let records = [
            rosterRecord(id: "huang", name: "黄建秀", year: 1972, month: 9, day: 10),
            rosterRecord(id: "ada", name: "Ada", year: 1990, month: 8, day: 20)
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

    @Test("Roster list calendar sort groups by calendar kind")
    func rosterListCalendarSortGroupsByCalendarKind() throws {
        let service = RosterDerivedDataService()
        let now = try #require(gregorianDate(year: 2026, month: 8, day: 10))
        let records = [
            rosterRecord(id: "lunar", name: "Lunar", kind: .chinese, year: 1971, month: 7, day: 8),
            rosterRecord(id: "gregorian", name: "Gregorian", kind: .gregorian, year: 1971, month: 8, day: 20)
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
            profiles: [ContactRosterProfile(id: "basic", displayName: "Basic", organizationName: "", records: [])],
            fieldAccessLevel: .birthdayOnly
        )
        let extended = ContactDataSnapshot(
            profiles: [ContactRosterProfile(id: "extended", displayName: "Extended", organizationName: "", records: [])],
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
            ContactRosterProfile(id: "ada", displayName: "Ada", organizationName: "", records: []),
            ContactRosterProfile(id: "grace", displayName: "Grace", organizationName: "", records: []),
            ContactRosterProfile(id: "linus", displayName: "Linus", organizationName: "", records: [])
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
            ContactRosterProfile(id: "ada", displayName: "Ada", organizationName: "", records: []),
            ContactRosterProfile(id: "grace", displayName: "Grace", organizationName: "", records: []),
            ContactRosterProfile(id: "linus", displayName: "Linus", organizationName: "", records: [])
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
            noRostersText: "No birthdays",
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
            profiles: [ContactRosterProfile(id: "all", displayName: "All", organizationName: "", records: [])],
            fieldAccessLevel: .birthdayOnly
        )
        let selectedScope = ContactAccessScope(
            mode: .selectedGroups,
            allowedGroupIDs: ["friends"],
            includeUngroupedContacts: false
        )
        let selectedSnapshot = ContactDataSnapshot(
            profiles: [ContactRosterProfile(id: "selected", displayName: "Selected", organizationName: "", records: [])],
            fieldAccessLevel: .birthdayOnly
        )

        await cache.save(allSnapshot, accessScope: .all)
        await cache.save(selectedSnapshot, accessScope: selectedScope)

        #expect(await cache.load(fieldAccessLevel: .birthdayOnly, accessScope: .all)?.profiles.first?.id == "all")
        #expect(await cache.load(fieldAccessLevel: .birthdayOnly, accessScope: selectedScope)?.profiles.first?.id == "selected")
    }

    @Test("Local birthday store persists extra birthday specs by person")
    func localRosterStoreRoundTripsExtraSpecs() async {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite3")
        let store = LocalRosterStore(databaseURL: databaseURL)
        let spec = RosterDateSpec(
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
    func localRosterStoreDeletesSpecsForRemovedContacts() async {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite3")
        let store = LocalRosterStore(databaseURL: databaseURL)
        let guoSpec = RosterDateSpec(
            id: "local-guo",
            personID: "guo",
            kind: .chinese,
            components: DateComponents(calendar: Calendar(identifier: .chinese), year: 1971, month: 7, day: 8),
            source: .local,
            syncPolicy: .localOnly
        )
        let adaSpec = RosterDateSpec(
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

    @Test("Contact tag store persists tags and assignments")
    func contactTagStoreRoundTripsTagsAndAssignments() async {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite3")
        let store = ContactTagStore(databaseURL: databaseURL)
        let tag = ContactTag(id: "family", name: "Family", color: 0x34C759, sortOrder: 1)

        await store.saveTag(tag)
        await store.assign(tagIDs: [tag.id], to: ["ada", "grace"])
        let loaded = await store.load()

        #expect(loaded.tags.map(\.id) == ["family"])
        #expect(loaded.tags.first?.name == "Family")
        #expect(loaded.tags.first?.color == 0x34C759)
        #expect(loaded.tags.first?.sortOrder == 1)
        #expect(loaded.tags.first?.parentTagID == nil)
        #expect(loaded.assignmentsByContactID["ada"] == ["family"])
        #expect(loaded.assignmentsByContactID["grace"] == ["family"])
    }

    @Test("Contact tag store deletes tag assignments without deleting other tags")
    func contactTagStoreDeletesTagAssignments() async {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite3")
        let store = ContactTagStore(databaseURL: databaseURL)
        let parent = ContactTag(id: "family", name: "Family", color: 0x34C759)
        let child = ContactTag(id: "parents", name: "Parents", color: 0x5856D6, parentTagID: "family")
        let other = ContactTag(id: "work", name: "Work", color: 0xFF9500)

        await store.saveTag(parent)
        await store.saveTag(child)
        await store.saveTag(other)
        await store.assign(tagIDs: ["family", "parents", "work"], to: ["ada"])
        await store.deleteTags(tagIDs: ["family", "parents"])
        let loaded = await store.load()

        #expect(loaded.tags.map(\.id) == ["work"])
        #expect(loaded.assignmentsByContactID["ada"] == ["work"])
    }

    @Test("Slash separated tag input creates a normalized tag path")
    func slashSeparatedTagInputCreatesNormalizedPath() {
        #expect(RosterAppModel.tagPathComponents(from: " 家人 / 亲戚 ") == ["家人", "亲戚"])
        #expect(RosterAppModel.tagPathComponents(from: "家人//亲戚/") == ["家人", "亲戚"])
        #expect(RosterAppModel.tagPathComponents(from: "") == [])
    }

    @Test("Parent tag filter includes child tag contacts")
    func parentTagFilterIncludesChildTagContacts() {
        let profiles = [
            ContactRosterProfile(id: "a", displayName: "Ada", organizationName: "", records: []),
            ContactRosterProfile(id: "b", displayName: "Grace", organizationName: "", records: []),
            ContactRosterProfile(id: "c", displayName: "Linus", organizationName: "", records: [])
        ]
        let parent = ContactTag(id: "family", name: "Family", color: 0x34C759)
        let child = ContactTag(id: "parents", name: "Parents", color: 0x5856D6, parentTagID: "family")
        let grouping = ContactGroupingSnapshot(
            collections: [ContactCollectionSummary(id: ContactCollectionIdentifier.all, title: "All Contacts", kind: .all, parentContainerID: nil, contactCount: 3)],
            contactIDsByCollectionID: [ContactCollectionIdentifier.all: Set(profiles.map(\.id))]
        )

        let snapshot = ContactListProjectionService().snapshot(
            profiles: profiles,
            grouping: grouping,
            contactTags: [parent, child],
            tagIDsByContactID: ["a": ["family"], "b": ["parents"]],
            selectedCollectionID: ContactCollectionIdentifier.all,
            selectedTagFilter: .tag("family"),
            searchText: "",
            language: .en,
            noRostersText: "No birthdays",
            todayText: "Today"
        )

        #expect(snapshot.visibleContactCount == 2)
        #expect(Set(snapshot.contactSections.flatMap { $0.rows.map(\.id) }) == ["a", "b"])
    }

    @Test("Contact projection worker caches matching requests")
    func contactProjectionWorkerCachesMatchingRequests() async {
        let profiles = [
            ContactRosterProfile(id: "a", displayName: "Ada", organizationName: "", records: []),
            ContactRosterProfile(id: "b", displayName: "Grace", organizationName: "", records: [])
        ]
        let grouping = ContactGroupingSnapshot(
            collections: [ContactCollectionSummary(id: ContactCollectionIdentifier.all, title: "All Contacts", kind: .all, parentContainerID: nil, contactCount: 2)],
            contactIDsByCollectionID: [ContactCollectionIdentifier.all: Set(profiles.map(\.id))]
        )
        let worker = ContactListProjectionWorker()
        let request = ContactListProjectionRequest(
            profiles: profiles,
            grouping: grouping,
            selectedCollectionID: ContactCollectionIdentifier.all,
            searchText: "",
            language: .en,
            noRostersText: "No birthdays",
            todayText: "Today"
        )

        let first = await worker.snapshot(for: request)
        let second = await worker.snapshot(for: request)
        var searchedRequest = request
        searchedRequest.searchText = "Ada"
        let searched = await worker.snapshot(for: searchedRequest)

        #expect(first == second)
        #expect(first.visibleContactCount == 2)
        #expect(searched.visibleContactCount == 1)
        #expect(await worker.cacheEntryCount == 2)
    }

    @Test("Empty tag pruning keeps parents with assigned descendants")
    func emptyTagPruningKeepsParentsWithAssignedDescendants() {
        let parent = ContactTag(id: "family", name: "Family", color: 0x34C759)
        let child = ContactTag(id: "parents", name: "Parents", color: 0x5856D6, parentTagID: "family")
        let stale = ContactTag(id: "stale", name: "Stale", color: 0x8E8E93)
        let staleChild = ContactTag(id: "stale-child", name: "Stale Child", color: 0x8E8E93, parentTagID: "stale")

        let emptyTagIDs = ContactTagTree(tags: [parent, child, stale, staleChild])
            .emptySubtreeTagIDs(assignmentsByContactID: ["ada": ["parents"]])

        #expect(emptyTagIDs == ["stale", "stale-child"])
    }

    @Test("Roster list filters records by contact tag")
    func rosterListFiltersByContactTag() throws {
        let service = RosterDerivedDataService()
        let now = try #require(gregorianDate(year: 2026, month: 8, day: 10))
        let records = [
            rosterRecord(id: "ada", name: "Ada", year: 1990, month: 8, day: 20),
            rosterRecord(id: "grace", name: "Grace", year: 1991, month: 8, day: 20)
        ]

        let filtered = service.filteredRecords(
            from: records,
            searchText: "",
            filter: nil,
            tagFilter: .tag("family"),
            contactTags: [ContactTag(id: "family", name: "Family"), ContactTag(id: "parents", name: "Parents", parentTagID: "family")],
            contactTagAssignmentsByContactID: ["ada": ["parents"]],
            sort: .next,
            now: now
        )

        #expect(filtered.records.map(\.contactID) == ["ada"])
        #expect(filtered.occurrences.map(\.record.contactID) == ["ada"])
    }

    @Test("Roster list groups expose precomputed row display fields")
    func rosterListGroupsPrecomputeRowDisplayFields() throws {
        let service = RosterDerivedDataService()
        let record = rosterRecord(id: "ada", name: "Ada", year: 1990, month: 8, day: 30)
        let occurrence = RosterOccurrence(
            record: record,
            date: Date().addingTimeInterval(86_400),
            age: 36
        )
        let groups = [
            RosterRecordGroup(id: "next", title: "Next", occurrences: [occurrence])
        ]

        let listGroups = service.listGroups(
            from: groups,
            contactTags: [ContactTag(id: "family", name: "Family")],
            contactTagAssignmentsByContactID: ["ada": ["family"]],
            language: .en,
            showAge: true,
            openContactText: "Open contact",
            todayText: "Today"
        )
        let item = try #require(listGroups.first?.items.first)

        #expect(listGroups.first?.items.count == 1)
        #expect(item.contactID == "ada")
        #expect(item.contactName == "Ada")
        #expect(item.tags.map(\.name) == ["Family"])
        #expect(item.kindTitle == "Gregorian")
        #expect(item.metaText.contains("36"))
        #expect(item.daysUntilText.isEmpty == false)
        #expect(item.accessibilityLabel == "Open contact: Ada")
    }

    @Test("Contact drag uses full selection only when the dragged row is selected")
    func contactDragUsesSelectedBatchOnlyFromSelectedRow() {
        let selectedIDs: Set<String> = ["ada", "grace"]

        #expect(ContactDragSelectionResolver.draggedContactIDs(
            draggedContactID: "ada",
            selectedContactIDs: selectedIDs,
            isSelectionMode: true
        ) == selectedIDs)

        #expect(ContactDragSelectionResolver.draggedContactIDs(
            draggedContactID: "linus",
            selectedContactIDs: selectedIDs,
            isSelectionMode: true
        ) == ["linus"])

        #expect(ContactDragSelectionResolver.draggedContactIDs(
            draggedContactID: "ada",
            selectedContactIDs: selectedIDs,
            isSelectionMode: false
        ) == ["ada"])
    }

    @Test("Group drop targets include only real groups in visible collection sections")
    func groupDropTargetsIncludeOnlyRealGroups() {
        let sections = [
            ContactCollectionSectionModel(
                id: "all",
                title: "All Contacts",
                collections: [
                    ContactCollectionSummary(
                        id: ContactCollectionIdentifier.all,
                        title: "All Contacts",
                        kind: .all,
                        parentContainerID: nil,
                        contactCount: 3
                    ),
                    ContactCollectionSummary(
                        id: ContactCollectionIdentifier.ungrouped,
                        title: "Ungrouped",
                        kind: .ungrouped,
                        parentContainerID: nil,
                        contactCount: 1
                    )
                ]
            ),
            ContactCollectionSectionModel(
                id: "icloud",
                title: "iCloud",
                collections: [
                    ContactCollectionSummary(
                        id: ContactCollectionIdentifier.container("icloud"),
                        title: "iCloud All",
                        kind: .container,
                        parentContainerID: "icloud",
                        contactCount: 3
                    ),
                    ContactCollectionSummary(
                        id: ContactCollectionIdentifier.group("friends"),
                        title: "Friends",
                        kind: .group,
                        parentContainerID: "icloud",
                        contactCount: 2
                    ),
                    ContactCollectionSummary(
                        id: ContactCollectionIdentifier.group("work"),
                        title: "Work",
                        kind: .group,
                        parentContainerID: "icloud",
                        contactCount: 1
                    )
                ]
            )
        ]

        let targets = ContactAssignmentTargetResolver.groupDropCollections(from: sections)
        #expect(targets.map(\.id) == [
            ContactCollectionIdentifier.group("friends"),
            ContactCollectionIdentifier.group("work")
        ])
    }

    @Test("Contact drop payloads are merged into unique contact IDs")
    func contactDropPayloadsMergeUniqueContactIDs() {
        let payloads = [
            ContactAssignmentDragPayload(contactIDs: ["ada", "grace"]),
            ContactAssignmentDragPayload(contactIDs: ["ada", "linus"])
        ]

        #expect(ContactAssignmentTargetResolver.droppedContactIDs(from: payloads) == ["ada", "grace", "linus"])
    }

    @Test("Group drop collections only expose actual groups")
    func groupDropCollectionsOnlyExposeActualGroups() {
        let sections = [
            ContactCollectionSectionModel(
                id: "all",
                title: "All Contacts",
                collections: [
                    ContactCollectionSummary(
                        id: ContactCollectionIdentifier.all,
                        title: "All Contacts",
                        kind: .all,
                        parentContainerID: nil,
                        contactCount: 5
                    ),
                    ContactCollectionSummary(
                        id: ContactCollectionIdentifier.ungrouped,
                        title: "Ungrouped",
                        kind: .ungrouped,
                        parentContainerID: nil,
                        contactCount: 2
                    )
                ]
            ),
            ContactCollectionSectionModel(
                id: "icloud",
                title: "iCloud",
                collections: [
                    ContactCollectionSummary(
                        id: ContactCollectionIdentifier.container("icloud"),
                        title: "iCloud",
                        kind: .container,
                        parentContainerID: "icloud",
                        contactCount: 5
                    ),
                    ContactCollectionSummary(
                        id: ContactCollectionIdentifier.group("family"),
                        title: "Family",
                        kind: .group,
                        parentContainerID: "icloud",
                        contactCount: 2
                    )
                ]
            )
        ]

        #expect(ContactAssignmentTargetResolver.groupDropCollections(from: sections).map(\.id) == [
            ContactCollectionIdentifier.group("family")
        ])
    }

    @Test("Drag payload preserves dragged contact identity")
    func dragPayloadPreservesDraggedContactIdentity() {
        let payload = ContactAssignmentDragPayload(contactIDs: ["ada"])
        #expect(payload.contactIDs == ["ada"])
    }

    @Test("Drag payload for selected row carries the full selected batch")
    func dragPayloadUsesFullSelectedBatch() {
        let selectedIDs: Set<String> = ["ada", "grace"]

        #expect(ContactDragSelectionResolver.draggedContactIDs(
            draggedContactID: "ada",
            selectedContactIDs: selectedIDs,
            isSelectionMode: true
        ) == selectedIDs)

        #expect(ContactDragSelectionResolver.draggedContactIDs(
            draggedContactID: "linus",
            selectedContactIDs: selectedIDs,
            isSelectionMode: true
        ) == ["linus"])
    }

    @Test("E2E contact fixture opens contacts with a droppable tag target")
    func e2eContactFixtureProvidesDragScenario() {
        let fixture = RosterE2EFixtures.contactDragAndDrop
        let tagID = fixture.tags.first?.id

        #expect(fixture.initialSelection == .contacts)
        #expect(fixture.snapshot.profiles.map(\.id).contains("e2e-ada"))
        #expect(tagID == "e2e-vip")
        #expect(fixture.assignmentsByContactID["e2e-ada"] == nil)
        #expect(fixture.snapshot.grouping.collections.contains {
            $0.id == ContactCollectionIdentifier.group("e2e-friends") && $0.kind == .group
        })
    }

    @Test("Roster edit draft separates Apple fields from local-only extra records")
    func rosterEditDraftSplitsAppleAndLocalSpecs() throws {
        let appleRoster = RosterRecord(
            id: "apple-gregorian",
            contactID: "guo",
            contactName: "郭峰",
            organizationName: "",
            kind: .gregorian,
            components: DateComponents(calendar: Calendar(identifier: .gregorian), year: 1971, month: 8, day: 20),
            source: .appleRoster,
            syncPolicy: .writeBackToApple
        )
        let profile = ContactRosterProfile(id: "guo", displayName: "郭峰", organizationName: "", records: [appleRoster])
        var draft = RosterEditDraft(profile: profile)
        draft.entries.append(RosterEditEntry(personID: "guo", kind: .chinese))
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

    @Test("Roster edit draft treats legacy contact records as Apple editable fields")
    func rosterEditDraftPreservesLegacyAppleRoster() throws {
        let legacyAppleRoster = RosterRecord(
            id: "guo-gregorian",
            contactID: "guo",
            contactName: "郭峰",
            organizationName: "",
            kind: .gregorian,
            components: DateComponents(calendar: Calendar(identifier: .gregorian), year: 1971, month: 8, day: 20),
            source: .local,
            syncPolicy: .localOnly
        )
        let profile = ContactRosterProfile(id: "guo", displayName: "郭峰", organizationName: "", records: [legacyAppleRoster])
        let draft = RosterEditDraft(profile: profile)
        let payload = try #require(draft.payload(personID: "guo"))

        #expect(payload.gregorian?.year == 1971)
        #expect(payload.gregorian?.month == 8)
        #expect(payload.gregorian?.day == 20)
        #expect(payload.localOnlyDateSpecs.isEmpty)
    }

    private func rosterRecord(
        id: String,
        name: String,
        kind: RosterCalendarKind = .gregorian,
        year: Int?,
        month: Int,
        day: Int
    ) -> RosterRecord {
        RosterRecord(
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
