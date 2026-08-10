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
}
