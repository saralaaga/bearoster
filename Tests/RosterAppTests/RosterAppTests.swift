import RosterCore
import Foundation
import Network
import Testing
import UniformTypeIdentifiers
@testable import RosterShared

@Suite("Contact architecture")
struct RosterAppTests {
    @Test("Localized copy uses natural English terminology")
    func localizedCopyUsesNaturalEnglish() {
        let l10n = L10n(language: .en)
        #expect(l10n(.list) == "Birthdays")
        #expect(l10n(.aboutBody).contains("Bearoster is for cleaning up"))
        #expect(l10n(.listening) == "Listening…")
        #expect(l10n(.trash) == "Recently Deleted")
    }

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

    @Test("Contact operation journal persists group operations")
    func contactOperationJournalPersistsGroupOperations() async {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite3")
        let store = ContactOperationJournalStore(databaseURL: databaseURL)
        let operation = ContactOperationLog(
            id: "group-op-1",
            contactID: ContactCollectionIdentifier.container("icloud"),
            appleContactID: nil,
            displayName: "Family",
            kind: .createGroup,
            summary: "Create contact group Family",
            contactGroup: ContactGroupOperationPayload(containerID: "icloud", groupID: nil, name: "Family")
        )

        await store.appendOperation(operation)
        let loaded = await store.load()

        #expect(loaded.operations.first?.kind == .createGroup)
        #expect(loaded.operations.first?.contactGroup?.containerID == "icloud")
        #expect(loaded.operations.first?.contactGroup?.name == "Family")
    }

    @Test("Contact collection identifiers expose safe raw Apple IDs")
    func contactCollectionIdentifiersExposeSafeRawAppleIDs() {
        #expect(ContactCollectionIdentifier.groupID(from: ContactCollectionIdentifier.group("friends")) == "friends")
        #expect(ContactCollectionIdentifier.groupID(from: ContactCollectionIdentifier.container("icloud")) == nil)
        #expect(ContactCollectionIdentifier.containerID(from: ContactCollectionIdentifier.container("icloud")) == "icloud")
        #expect(ContactCollectionIdentifier.containerID(from: ContactCollectionIdentifier.group("friends")) == nil)
    }

    @Test("Selecting a contact collection switches to contacts")
    @MainActor
    func selectingContactCollectionSwitchesToContacts() {
        let model = RosterAppModel()
        let collectionID = ContactCollectionIdentifier.group("friends")

        model.selection = .calendar
        model.selectContactCollection(collectionID)

        #expect(model.selection == .contacts)
        #expect(model.selectedContactCollectionID == collectionID)
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

    @Test("Contact filter condition IDs are stable by condition kind")
    func contactFilterConditionIDsAreStableByConditionKind() {
        #expect(ContactFilterCondition.birthday(.hasBirthday).id == ContactFilterCondition.birthday(.missingBirthday).id)
        #expect(ContactFilterCondition.missingField(.phone).id == ContactFilterCondition.missingField(.email).id)
    }

    @Test("Contact projection applies all contact filter conditions")
    func contactProjectionAppliesAllContactFilterConditions() {
        let birthday = RosterRecord(
            id: "ada-birthday",
            contactID: "a",
            contactName: "Ada",
            organizationName: "",
            kind: .gregorian,
            components: DateComponents(calendar: Calendar(identifier: .gregorian), year: 1990, month: 8, day: 10)
        )
        let profiles = [
            ContactRosterProfile(id: "a", displayName: "Ada", organizationName: "", records: [birthday], emailAddresses: []),
            ContactRosterProfile(id: "b", displayName: "Grace", organizationName: "", records: [], emailAddresses: []),
            ContactRosterProfile(id: "c", displayName: "Linus", organizationName: "", records: [], emailAddresses: ["linus@example.com"])
        ]
        let grouping = ContactGroupingSnapshot(
            collections: [ContactCollectionSummary(id: ContactCollectionIdentifier.all, title: "All Contacts", kind: .all, parentContainerID: nil, contactCount: 3)],
            contactIDsByCollectionID: [ContactCollectionIdentifier.all: Set(profiles.map(\.id))]
        )

        let snapshot = ContactListProjectionService().snapshot(
            profiles: profiles,
            grouping: grouping,
            selectedCollectionID: ContactCollectionIdentifier.all,
            searchText: "",
            contactFilters: [.birthday(.missingBirthday), .missingField(.email)],
            contactFilterMatchMode: .all,
            language: .en,
            noRostersText: "No birthdays",
            todayText: "Today"
        )

        #expect(snapshot.visibleContactCount == 1)
        #expect(snapshot.contactSections.flatMap { $0.rows.map(\.id) } == ["b"])
    }

    @Test("Contact projection applies any contact filter condition")
    func contactProjectionAppliesAnyContactFilterCondition() {
        let birthday = RosterRecord(
            id: "ada-birthday",
            contactID: "a",
            contactName: "Ada",
            organizationName: "",
            kind: .gregorian,
            components: DateComponents(calendar: Calendar(identifier: .gregorian), year: 1990, month: 8, day: 10)
        )
        let profiles = [
            ContactRosterProfile(id: "a", displayName: "Ada", organizationName: "", records: [birthday], emailAddresses: []),
            ContactRosterProfile(id: "b", displayName: "Grace", organizationName: "", records: [], emailAddresses: []),
            ContactRosterProfile(id: "c", displayName: "Linus", organizationName: "", records: [], emailAddresses: ["linus@example.com"])
        ]
        let grouping = ContactGroupingSnapshot(
            collections: [ContactCollectionSummary(id: ContactCollectionIdentifier.all, title: "All Contacts", kind: .all, parentContainerID: nil, contactCount: 3)],
            contactIDsByCollectionID: [ContactCollectionIdentifier.all: Set(profiles.map(\.id))]
        )

        let snapshot = ContactListProjectionService().snapshot(
            profiles: profiles,
            grouping: grouping,
            selectedCollectionID: ContactCollectionIdentifier.all,
            searchText: "",
            contactFilters: [.birthday(.missingBirthday), .missingField(.email)],
            contactFilterMatchMode: .any,
            language: .en,
            noRostersText: "No birthdays",
            todayText: "Today"
        )

        #expect(snapshot.visibleContactCount == 3)
        #expect(Set(snapshot.contactSections.flatMap { $0.rows.map(\.id) }) == ["a", "b", "c"])
    }

    @Test("Group drop move plan removes previous groups in the same container")
    func groupDropMovePlanRemovesPreviousGroupsInSameContainer() {
        let grouping = ContactGroupingSnapshot(
            groups: [
                ContactGroupSummary(id: "friends", containerID: "icloud", name: "Friends", contactCount: 1),
                ContactGroupSummary(id: "work", containerID: "icloud", name: "Work", contactCount: 1),
                ContactGroupSummary(id: "local", containerID: "local", name: "Local", contactCount: 1)
            ],
            contactIDsByCollectionID: [
                ContactCollectionIdentifier.group("friends"): ["ada"],
                ContactCollectionIdentifier.group("work"): [],
                ContactCollectionIdentifier.group("local"): ["ada"]
            ],
            groupIDsByContactID: ["ada": ["friends", "local"]]
        )

        let plan = ContactAssignmentTargetResolver.groupMovePlan(
            contactIDs: ["ada"],
            targetGroupID: "work",
            grouping: grouping
        )

        #expect(plan.contactIDsToAdd == ["ada"])
        #expect(plan.contactIDsByGroupIDToRemove == ["friends": ["ada"]])
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

    @Test("Contact assignment drop accepts text fallback")
    func contactAssignmentDropAcceptsTextFallback() {
        #expect(UTType.contactAssignmentDropTypes.contains(.plainText))
        #expect(UTType.contactAssignmentDropTypes.contains(.text))
    }

    @Test("Text fallback parses dragged contact IDs")
    func textFallbackParsesDraggedContactIDs() {
        #expect(ContactAssignmentTargetResolver.droppedContactIDs(fromText: "ada, grace") == ["ada", "grace"])
    }

    @Test("Contact action URLs carry current contact values")
    func contactActionURLsCarryCurrentContactValues() {
        #expect(ContactActionURLFactory.url(for: .message, phoneNumbers: ["+86 159-6565-9550"], emailAddresses: [])?.absoluteString == "sms:+8615965659550")
        #expect(ContactActionURLFactory.url(for: .call, phoneNumbers: ["+86 159-6565-9550"], emailAddresses: [])?.absoluteString == "tel:+8615965659550")
        #expect(ContactActionURLFactory.url(for: .video, phoneNumbers: [], emailAddresses: ["ada@example.com"])?.absoluteString == "facetime:ada@example.com")
        #expect(ContactActionURLFactory.url(for: .email, phoneNumbers: [], emailAddresses: ["ada@example.com"])?.absoluteString == "mailto:ada@example.com")
        #expect(ContactActionURLFactory.url(for: .email, phoneNumbers: ["159"], emailAddresses: []) == nil)
    }

    @Test("Tagged contact count ignores empty and hidden contacts")
    func taggedContactCountIgnoresEmptyAndHiddenContacts() {
        #expect(RosterAppModel.taggedContactCount(
            assignmentsByContactID: [
                "ada": ["family", "work"],
                "grace": [],
                "hidden": ["family"]
            ],
            visibleContactIDs: ["ada", "grace"]
        ) == 1)
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

@Suite("Contact draft intake")
struct ContactDraftIntakeTests {
    private func payload(_ drafts: [[String: Any]]) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "drafts": drafts])
    }

    private func draftJSON(
        displayName: String = "张伟",
        givenName: String? = "伟",
        familyName: String? = "张",
        phoneNumbers: [String]? = ["13800138000"],
        emailAddresses: [String]? = nil,
        birthdays: [[String: Any]]? = nil,
        extra: [String: Any] = [:]
    ) -> [String: Any] {
        var json: [String: Any] = ["displayName": displayName]
        if let givenName { json["givenName"] = givenName }
        if let familyName { json["familyName"] = familyName }
        if let phoneNumbers { json["phoneNumbers"] = phoneNumbers }
        if let emailAddresses { json["emailAddresses"] = emailAddresses }
        if let birthdays { json["birthdays"] = birthdays }
        for (key, value) in extra { json[key] = value }
        return json
    }

    @Test("Valid batch maps to drafts with apple-sourced birthdays")
    func acceptsValidBatch() throws {
        let data = try payload([
            draftJSON(birthdays: [["date": "1990-08-04", "label": "生日"]])
        ])

        let outcome = ContactDraftIntakeService.process(payload: data, existing: [])

        #expect(outcome.requestError == nil)
        #expect(outcome.rejected.isEmpty)
        #expect(outcome.conflicts.isEmpty)
        let item = try #require(outcome.accepted.first)
        let draft = item.draft
        #expect(draft.id.hasPrefix("agent-"))
        #expect(draft.appleContactID == nil)
        #expect(draft.displayName == "张伟")
        #expect(draft.givenName == "伟")
        #expect(draft.familyName == "张")
        #expect(draft.phoneNumbers == ["13800138000"])
        let spec = try #require(draft.birthdaySpecs.first)
        #expect(spec.personID == draft.id)
        #expect(spec.kind == .gregorian)
        #expect(spec.source == .appleRoster)
        #expect(spec.syncPolicy == .writeBackToApple)
        #expect(spec.components.year == 1990)
        #expect(spec.components.month == 8)
        #expect(spec.components.day == 4)
        #expect(spec.label == "生日")
    }

    @Test("displayName-only draft falls back to given name")
    func fallsBackGivenNameFromDisplayName() throws {
        let data = try payload([draftJSON(givenName: nil, familyName: nil, phoneNumbers: [])])

        let outcome = ContactDraftIntakeService.process(payload: data, existing: [])

        let draft = try #require(outcome.accepted.first).draft
        #expect(draft.givenName == "张伟")
        #expect(draft.familyName == "")
    }

    @Test("Year-less birthday date is accepted")
    func acceptsYearlessBirthday() throws {
        let data = try payload([
            draftJSON(displayName: "李娜", birthdays: [["date": "08-04"]])
        ])

        let outcome = ContactDraftIntakeService.process(payload: data, existing: [])

        let spec = try #require(outcome.accepted.first?.draft.birthdaySpecs.first)
        #expect(spec.components.year == nil)
        #expect(spec.components.month == 8)
        #expect(spec.components.day == 4)
    }

    @Test("Impossible calendar dates are rejected; leap day stays valid")
    func validatesBirthdayDateExistence() throws {
        let data = try payload([
            draftJSON(displayName: "甲", phoneNumbers: [], birthdays: [["date": "02-31"]]),
            draftJSON(displayName: "乙", phoneNumbers: [], birthdays: [["date": "2001-02-29"]]),
            draftJSON(displayName: "丙", phoneNumbers: [], birthdays: [["date": "02-29"]]),
            draftJSON(displayName: "丁", phoneNumbers: [], birthdays: [["date": "2000-02-29"]])
        ])

        let outcome = ContactDraftIntakeService.process(payload: data, existing: [])

        #expect(outcome.requestError == nil)
        #expect(outcome.rejected.map(\.index) == [0, 1])
        #expect(outcome.accepted.map(\.draft.displayName) == ["丙", "丁"])
    }

    @Test("Overlong email addresses are rejected instead of skipping validation")
    func rejectsOverlongEmailAddresses() throws {
        let longLocalPart = String(repeating: "a", count: 250)
        let data = try payload([
            draftJSON(displayName: "李娜", phoneNumbers: [], emailAddresses: ["\(longLocalPart)@example.com"])
        ])

        let outcome = ContactDraftIntakeService.process(payload: data, existing: [])

        #expect(outcome.accepted.isEmpty)
        let rejection = try #require(outcome.rejected.first)
        #expect(rejection.reason.contains("254"))
    }

    @Test("Drafts matching an already-queued journal draft are rejected")
    func rejectsAlreadyQueuedDrafts() throws {
        let queued = [
            ContactIntakeFingerprint(displayName: "张伟", phoneNumbers: ["13800138000"], emailAddresses: [])
        ]
        let data = try payload([
            draftJSON(phoneNumbers: ["138-0013-8000"]),
            draftJSON(displayName: "李娜", phoneNumbers: [])
        ])

        let outcome = ContactDraftIntakeService.process(payload: data, existing: [], queued: queued)

        #expect(outcome.accepted.map(\.draft.displayName) == ["李娜"])
        let rejection = try #require(outcome.rejected.first)
        #expect(rejection.index == 0)
        #expect(rejection.reason.contains("already-queued"))
    }

    @Test("Unknown fields reject only that draft")
    func rejectsUnknownFieldsPerDraft() throws {
        let data = try payload([
            draftJSON(extra: ["contactID": "abc", "appleContactID": "x"]),
            draftJSON(displayName: "王五")
        ])

        let outcome = ContactDraftIntakeService.process(payload: data, existing: [])

        #expect(outcome.accepted.count == 1)
        let rejection = try #require(outcome.rejected.first)
        #expect(rejection.index == 0)
        #expect(rejection.reason.contains("unknown field"))
    }

    @Test("Field violations are reported per item")
    func reportsFieldViolations() throws {
        let data = try payload([
            draftJSON(
                displayName: "",
                phoneNumbers: ["not-a-phone"],
                emailAddresses: ["broken-address"],
                birthdays: [["date": "1990-13-40", "kind": "lunar"]]
            )
        ])

        let outcome = ContactDraftIntakeService.process(payload: data, existing: [])

        #expect(outcome.accepted.isEmpty)
        let reason = try #require(outcome.rejected.first?.reason)
        #expect(reason.contains("displayName is required"))
        #expect(reason.contains("not a valid phone number"))
        #expect(reason.contains("not a valid email address"))
        #expect(reason.contains("unknown field"))
        #expect(reason.contains("not a valid gregorian date"))
    }

    @Test("Request-level guardrails: size, version, count, root keys, shape")
    func enforcesRequestGuardrails() throws {
        let badVersion = try JSONSerialization.data(
            withJSONObject: ["schemaVersion": 99, "drafts": [draftJSON()]]
        )
        #expect(ContactDraftIntakeService.process(payload: badVersion, existing: []).requestError?.contains("schemaVersion") == true)

        let unknownRoot = try JSONSerialization.data(
            withJSONObject: ["schemaVersion": 1, "drafts": [draftJSON()], "mode": "force"]
        )
        #expect(ContactDraftIntakeService.process(payload: unknownRoot, existing: []).requestError?.contains("unknown top-level field") == true)

        let tooMany = try payload(Array(repeating: draftJSON(displayName: "x"), count: 501))
        #expect(ContactDraftIntakeService.process(payload: tooMany, existing: []).requestError?.contains("between 1 and 500") == true)

        let oversized = Data(count: ContactDraftIntakeService.maxPayloadBytes + 1)
        #expect(ContactDraftIntakeService.process(payload: oversized, existing: []).requestError?.contains("bytes") == true)

        let malformed = Data("[not json".utf8)
        #expect(ContactDraftIntakeService.process(payload: malformed, existing: []).requestError != nil)
    }

    @Test("Same name plus shared phone/email marks conflict against existing contacts")
    func conflictsAgainstExistingContacts() throws {
        let existing = [ContactIntakeFingerprint(
            displayName: "张伟",
            phoneNumbers: ["13800138000"],
            emailAddresses: []
        )]
        let data = try payload([
            draftJSON(displayName: "张伟", givenName: nil, familyName: nil),
            draftJSON(displayName: "李娜", givenName: nil, familyName: nil, phoneNumbers: [])
        ])

        let outcome = ContactDraftIntakeService.process(payload: data, existing: existing)

        #expect(outcome.conflicts.count == 1)
        #expect(outcome.conflicts.first?.index == 0)
        #expect(outcome.accepted.count == 1)
        #expect(outcome.accepted.first?.draft.displayName == "李娜")
    }

    @Test("Same name without shared phone or email does not conflict")
    func noConflictWithoutSharedHandle() throws {
        let existing = [ContactIntakeFingerprint(
            displayName: "张伟",
            phoneNumbers: ["13800138000"],
            emailAddresses: []
        )]
        let data = try payload([
            draftJSON(displayName: "张伟", givenName: nil, familyName: nil, phoneNumbers: ["13900139000"])
        ])

        let outcome = ContactDraftIntakeService.process(payload: data, existing: existing)

        #expect(outcome.conflicts.isEmpty)
        #expect(outcome.accepted.count == 1)
    }

    @Test("Batch-internal duplicates are rejected, not queued")
    func rejectsBatchInternalDuplicates() throws {
        let data = try payload([
            draftJSON(),
            draftJSON()
        ])

        let outcome = ContactDraftIntakeService.process(payload: data, existing: [])

        #expect(outcome.accepted.count == 1)
        #expect(outcome.conflicts.isEmpty)
        let rejection = try #require(outcome.rejected.first)
        #expect(rejection.index == 1)
        #expect(rejection.reason.contains("duplicate of draft #0"))
    }

    @Test("Email matching is case-insensitive and phone matching ignores formatting")
    func normalizesHandlesBeforeMatching() throws {
        let existing = [ContactIntakeFingerprint(
            displayName: "Sam",
            phoneNumbers: ["+86 (138) 0013-8000"],
            emailAddresses: ["Sam@Example.COM"]
        )]
        let data = try payload([
            draftJSON(
                displayName: "sam",
                givenName: nil,
                familyName: nil,
                phoneNumbers: ["13800138000"],
                emailAddresses: ["sam@example.com"]
            )
        ])

        let outcome = ContactDraftIntakeService.process(payload: data, existing: existing)

        #expect(outcome.conflicts.count == 1)
    }
}

@Suite("Imported draft queueing")
struct ImportedDraftQueueingTests {
    @MainActor
    private func makeModel() throws -> (model: RosterAppModel, journalURL: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("roster-intake-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("contact-journal.sqlite3")
        let model = RosterAppModel(e2eFixture: RosterE2EFixtures.contactDragAndDrop, journalDatabaseURL: url)
        return (model, url)
    }

    private func acceptedDraft(name: String) -> LocalContactDraft {
        LocalContactDraft(
            id: "agent-\(name)",
            appleContactID: nil,
            displayName: name,
            phoneNumbers: ["13800138000"],
            baseSignature: 0
        )
    }

    @Test("Accepted drafts queue as pending create operations and persist to the journal")
    @MainActor
    func queuesAcceptedDraftsAsPendingCreates() async throws {
        let (model, journalURL) = try makeModel()
        let outcome = ContactDraftIntakeOutcome(
            accepted: [
                ContactDraftIntakeItem(index: 0, draft: acceptedDraft(name: "张伟")),
                ContactDraftIntakeItem(index: 1, draft: acceptedDraft(name: "李娜"))
            ]
        )

        let before = model.pendingContactOperationCount
        await model.queueImportedDrafts(outcome)

        #expect(model.pendingContactOperationCount == before + 2)
        #expect(model.contactOperationLog.prefix(2).allSatisfy { $0.kind == .create && $0.status == .pending })
        #expect(model.contactOperationLog.prefix(2).allSatisfy { $0.appleContactID == nil })
        #expect(model.contactDraftsByID.values.map(\.displayName).sorted() == ["张伟", "李娜"])

        let reloaded = await ContactOperationJournalStore(databaseURL: journalURL).load()
        #expect(reloaded.draftsByContactID.count == 2)
        #expect(reloaded.operations.filter { $0.kind == .create && $0.status == .pending }.count == 2)
    }

    @Test("Conflicted drafts queue with conflict status for user adjudication")
    @MainActor
    func queuesConflictsWithConflictStatus() async throws {
        let (model, _) = try makeModel()
        let outcome = ContactDraftIntakeOutcome(
            accepted: [ContactDraftIntakeItem(index: 0, draft: acceptedDraft(name: "张伟"))],
            conflicts: [ContactDraftIntakeItem(index: 1, draft: acceptedDraft(name: "王五"))]
        )

        await model.queueImportedDrafts(outcome)

        #expect(model.pendingContactOperationCount == 1)
        #expect(model.conflictedContactOperationCount == 1)
        #expect(model.contactOperationLog.first?.displayName == "王五")
        #expect(model.contactOperationLog.first?.status == .conflict)
    }

    @Test("Queued drafts surface as local-only profiles")
    @MainActor
    func surfacesDraftsAsLocalOnlyProfiles() async throws {
        let (model, _) = try makeModel()
        let outcome = ContactDraftIntakeOutcome(
            accepted: [ContactDraftIntakeItem(index: 0, draft: acceptedDraft(name: "张伟"))]
        )

        await model.queueImportedDrafts(outcome)

        let names = model.profiles.map(\.displayName)
        #expect(names.contains("张伟"))
    }

    @Test("Empty outcome queues nothing")
    @MainActor
    func emptyOutcomeIsNoop() async throws {
        let (model, journalURL) = try makeModel()
        let before = model.pendingContactOperationCount

        await model.queueImportedDrafts(ContactDraftIntakeOutcome())

        #expect(model.pendingContactOperationCount == before)
        #expect(model.contactDraftsByID.isEmpty)
        let reloaded = await ContactOperationJournalStore(databaseURL: journalURL).load()
        #expect(reloaded.draftsByContactID.isEmpty)
    }
}

@Suite("Agent access server")
struct AgentAccessServerTests {
    actor StubHandler: AgentAccessHandling {
        var payloads: [Data] = []
        var outcome = ContactDraftIntakeOutcome()

        func queueDrafts(payload: Data) async -> ContactDraftIntakeOutcome {
            payloads.append(payload)
            return outcome
        }

        func pendingSummary() async -> AgentAccessPendingSummary {
            AgentAccessPendingSummary(
                pending: [AgentAccessOperationSummary(displayName: "张伟", status: "pending")],
                conflicts: [],
                failed: [AgentAccessOperationSummary(displayName: "李娜", status: "failed", errorMessage: "denied")]
            )
        }
    }

    private func rpcBody(id: Int, method: String, params: [String: Any] = [:]) throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "jsonrpc": "2.0",
            "id": id,
            "method": method,
            "params": params
        ])
    }

    private func post(
        _ session: URLSession,
        port: UInt16,
        token: String,
        body: Data,
        method: String = "POST",
        path: String = AgentAccessServer.endpointPath
    ) async throws -> (status: Int, data: Data) {
        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)\(path)")!)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = body
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return (status, data)
    }

    @Test("MCP handshake, tool listing, and queue_drafts round-trip over loopback")
    func servesMCPOverLoopback() async throws {
        let handler = StubHandler()
        await handler.setOutcome(ContactDraftIntakeOutcome(
            accepted: [ContactDraftIntakeItem(
                index: 0,
                draft: LocalContactDraft(
                    id: "agent-1",
                    appleContactID: nil,
                    displayName: "张伟",
                    baseSignature: 0
                )
            )],
            rejected: [ContactDraftIntakeRejection(index: 1, reason: "unknown field(s): x")]
        ))
        let server = AgentAccessServer(handler: handler, token: "test-token")
        try await server.start(port: 0)
        defer { server.stop() }
        #expect(server.port != 0)

        let session = URLSession(configuration: .ephemeral)
        defer { session.finishTasksAndInvalidate() }

        // initialize
        let initBody = try JSONSerialization.data(withJSONObject: [
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": [
                "protocolVersion": "2025-11-25",
                "capabilities": [:] as [String: Any],
                "clientInfo": ["name": "test", "version": "1.0"]
            ] as [String: Any]
        ])
        let initResponse = try await post(session, port: server.port, token: "test-token", body: initBody)
        #expect(initResponse.status == 200)
        let initJSON = try #require(
            try JSONSerialization.jsonObject(with: initResponse.data) as? [String: Any]
        )
        let initResult = try #require(initJSON["result"] as? [String: Any])
        let serverInfo = try #require(initResult["serverInfo"] as? [String: Any])
        #expect(serverInfo["name"] as? String == "Bearoster")

        // initialized notification
        let notification = try JSONSerialization.data(withJSONObject: [
            "jsonrpc": "2.0",
            "method": "notifications/initialized"
        ])
        let notificationResponse = try await post(session, port: server.port, token: "test-token", body: notification)
        #expect(notificationResponse.status == 200 || notificationResponse.status == 202)

        // tools/list
        let listBody = try rpcBody(id: 2, method: "tools/list")
        let listResponse = try await post(session, port: server.port, token: "test-token", body: listBody)
        #expect(listResponse.status == 200)
        let listJSON = try #require(
            try JSONSerialization.jsonObject(with: listResponse.data) as? [String: Any]
        )
        let listResult = try #require(listJSON["result"] as? [String: Any])
        let tools = try #require(listResult["tools"] as? [[String: Any]])
        let toolNames = Set(tools.compactMap { $0["name"] as? String })
        #expect(toolNames == ["queue_drafts", "list_pending"])

        // queue_drafts
        let callBody = try rpcBody(id: 3, method: "tools/call", params: [
            "name": "queue_drafts",
            "arguments": [
                "schemaVersion": ContactDraftIntakeService.schemaVersion,
                "drafts": [["displayName": "张伟", "phoneNumbers": ["13800138000"]]]
            ] as [String: Any]
        ])
        let callResponse = try await post(session, port: server.port, token: "test-token", body: callBody)
        #expect(callResponse.status == 200)
        let callJSON = try #require(
            try JSONSerialization.jsonObject(with: callResponse.data) as? [String: Any]
        )
        let callResult = try #require(callJSON["result"] as? [String: Any])
        let content = try #require(callResult["content"] as? [[String: Any]])
        let text = try #require(content.first?["text"] as? String)
        #expect(text.contains("\"accepted\""))
        #expect(text.contains("张伟"))
        #expect(text.contains("unknown field(s): x"))

        // handler received the raw arguments as JSON
        let received = await handler.receivedPayloads()
        #expect(received.count == 1)
        let receivedJSON = try #require(
            try JSONSerialization.jsonObject(with: received[0]) as? [String: Any]
        )
        #expect(receivedJSON["schemaVersion"] as? Int == ContactDraftIntakeService.schemaVersion)

        // list_pending
        let pendingBody = try rpcBody(id: 4, method: "tools/call", params: [
            "name": "list_pending",
            "arguments": [:] as [String: Any]
        ])
        let pendingResponse = try await post(session, port: server.port, token: "test-token", body: pendingBody)
        #expect(pendingResponse.status == 200)
        let pendingText = String(decoding: pendingResponse.data, as: UTF8.self)
        #expect(pendingText.contains("张伟"))
        #expect(pendingText.contains("denied"))
    }

    @Test("Requests without a valid token, wrong path, or wrong method are rejected")
    func enforcesGatewayRules() async throws {
        let server = AgentAccessServer(handler: StubHandler(), token: "secret")
        try await server.start(port: 0)
        defer { server.stop() }

        let session = URLSession(configuration: .ephemeral)
        defer { session.finishTasksAndInvalidate() }

        let body = try rpcBody(id: 1, method: "tools/list")

        let unauthorized = try await post(session, port: server.port, token: "wrong", body: body)
        #expect(unauthorized.status == 401)

        let wrongPath = try await post(session, port: server.port, token: "secret", body: body, path: "/other")
        #expect(wrongPath.status == 404)

        let get = try await post(session, port: server.port, token: "secret", body: Data(), method: "GET")
        #expect(get.status == 405)
    }

    @Test("Malformed pre-auth requests fail with HTTP errors instead of crashing or hanging")
    func rejectsMalformedRequests() async throws {
        let handler = StubHandler()
        let server = AgentAccessServer(handler: handler, token: "secret")
        try await server.start(port: 0)
        defer { server.stop() }

        // Negative Content-Length used to crash the parser on an invalid range.
        let negative = try await sendRaw("POST /mcp HTTP/1.1\r\nContent-Length: -5\r\n\r\n", port: server.port)
        #expect(negative.status == 400)

        // A body beyond the cap is refused before it is ever buffered.
        let oversized = try await sendRaw("POST /mcp HTTP/1.1\r\nContent-Length: 99999999\r\n\r\n", port: server.port)
        #expect(oversized.status == 413)

        // A header section that never fits is cut off instead of growing the buffer.
        let junk = String(repeating: "a", count: 70_000)
        let hugeHeader = try await sendRaw("POST /mcp HTTP/1.1\r\nX-Junk: \(junk)\r\n\r\n", port: server.port)
        #expect(hugeHeader.status == 431)

        // A non-numeric Content-Length is a client error, not an empty body.
        let garbage = try await sendRaw("POST /mcp HTTP/1.1\r\nContent-Length: abc\r\n\r\n", port: server.port)
        #expect(garbage.status == 400)

        let payloads = await handler.receivedPayloads()
        #expect(payloads.isEmpty)
    }

    @Test("Bytes pipelined after a full request do not invoke the handler twice")
    func handlesSingleRequestPerConnection() async throws {
        let handler = StubHandler()
        let server = AgentAccessServer(handler: handler, token: "secret")
        try await server.start(port: 0)
        defer { server.stop() }

        let initializeBody = try rpcBody(id: 1, method: "initialize", params: [
            "protocolVersion": "2025-11-25",
            "capabilities": [:] as [String: Any],
            "clientInfo": ["name": "test", "version": "1.0"]
        ] as [String: Any])
        let initializeResponse = try await sendRaw(rawRequest(body: initializeBody, token: "secret"), port: server.port)
        #expect(initializeResponse.status == 200)

        let callBody = try rpcBody(id: 2, method: "tools/call", params: [
            "name": "queue_drafts",
            "arguments": [
                "schemaVersion": ContactDraftIntakeService.schemaVersion,
                "drafts": [["displayName": "张伟"]]
            ] as [String: Any]
        ])
        let single = rawRequest(body: callBody, token: "secret")
        let response = try await sendRaw(single + single, port: server.port)
        #expect(response.status == 200)

        // Leave time for a duplicate dispatch to (wrongly) land before counting.
        try await Task.sleep(for: .milliseconds(200))
        let payloads = await handler.receivedPayloads()
        #expect(payloads.count == 1)
    }

    private func rawRequest(body: Data, token: String) -> String {
        // The MCP transport validates Content-Type/Accept, so the raw request
        // must carry the same headers URLSession and curl send.
        "POST /mcp HTTP/1.1\r\n"
            + "Content-Type: application/json\r\n"
            + "Accept: application/json\r\n"
            + "Content-Length: \(body.count)\r\n"
            + "Authorization: Bearer \(token)\r\n"
            + "\r\n"
            + String(decoding: body, as: UTF8.self)
    }

    /// URLSession cannot send malformed requests, so the malformed/pipelined
    /// tests write raw bytes to a fresh TCP connection and read until the
    /// server closes it.
    private func sendRaw(_ request: String, port: UInt16) async throws -> (status: Int, data: Data) {
        try await withCheckedThrowingContinuation { continuation in
            let box = RawResponseBox(continuation)
            let accumulator = RawResponseAccumulator()
            let queue = DispatchQueue(label: "roster.test.agent-access.raw")
            let connection = NWConnection(
                host: NWEndpoint.Host("127.0.0.1"),
                port: NWEndpoint.Port(rawValue: port)!,
                using: .tcp
            )

            @Sendable func complete() {
                let received = accumulator.value
                let text = String(decoding: received, as: UTF8.self)
                let parts = text.split(separator: " ", maxSplits: 2)
                let status = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
                let body: Data
                if let headerEnd = received.range(of: Data("\r\n\r\n".utf8)) {
                    body = received.subdata(in: headerEnd.upperBound..<received.count)
                } else {
                    body = Data()
                }
                connection.cancel()
                box.resumeOnce(returning: (status, body))
            }

            @Sendable func pump() {
                connection.receive(minimumIncompleteLength: 1, maximumLength: 1 << 16) { data, _, isComplete, error in
                    if let data, !data.isEmpty {
                        accumulator.append(data)
                    }
                    if error != nil || isComplete {
                        complete()
                        return
                    }
                    pump()
                }
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(content: Data(request.utf8), completion: .contentProcessed { _ in
                        pump()
                    })
                case .failed:
                    box.resumeOnce(returning: (0, Data()))
                default:
                    break
                }
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + 5) {
                box.resumeOnce(returning: (0, Data()))
            }
        }
    }
}

private final class RawResponseBox: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<(status: Int, data: Data), any Error>?

    init(_ continuation: CheckedContinuation<(status: Int, data: Data), any Error>) {
        self.continuation = continuation
    }

    func resumeOnce(returning value: (status: Int, data: Data)) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(returning: value)
    }
}

private final class RawResponseAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ chunk: Data) {
        lock.lock()
        data.append(chunk)
        lock.unlock()
    }

    var value: Data {
        lock.lock()
        defer { lock.unlock() }
        return data
    }
}

extension AgentAccessServerTests.StubHandler {
    func setOutcome(_ outcome: ContactDraftIntakeOutcome) {
        self.outcome = outcome
    }

    func receivedPayloads() -> [Data] {
        payloads
    }
}
