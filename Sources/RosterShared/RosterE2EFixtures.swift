import RosterCore
import Foundation

package struct RosterE2EFixture: Sendable {
    package let snapshot: ContactDataSnapshot
    package let tags: [ContactTag]
    package let assignmentsByContactID: [String: Set<String>]
    package let initialSelection: SidebarSelection
    package var initialSelectedDate: Date? = nil
}

package enum RosterE2EFixtures {
    package static let contactDragAndDrop = RosterE2EFixture(
        snapshot: ContactDataSnapshot(
            profiles: [
                contact(id: "e2e-ada", name: "Ada Lovelace", organization: "Analytical Engines", month: 12, day: 10),
                contact(id: "e2e-grace", name: "Grace Hopper", organization: "Compiler Lab", month: 12, day: 9),
                contact(id: "e2e-alan", name: "Alan Turing", organization: "Bletchley Park", month: 6, day: 23)
            ],
            grouping: ContactGroupingSnapshot(
                containers: [
                    ContactContainerSummary(id: "e2e-container", name: "E2E Contacts", typeName: "Local")
                ],
                groups: [
                    ContactGroupSummary(id: "e2e-friends", containerID: "e2e-container", name: "Friends", contactCount: 1),
                    ContactGroupSummary(id: "e2e-work", containerID: "e2e-container", name: "Work", contactCount: 1)
                ],
                collections: [
                    ContactCollectionSummary(
                        id: ContactCollectionIdentifier.all,
                        title: "All Contacts",
                        kind: .all,
                        parentContainerID: nil,
                        contactCount: 3
                    ),
                    ContactCollectionSummary(
                        id: ContactCollectionIdentifier.container("e2e-container"),
                        title: "E2E Contacts",
                        kind: .container,
                        parentContainerID: "e2e-container",
                        contactCount: 3
                    ),
                    ContactCollectionSummary(
                        id: ContactCollectionIdentifier.group("e2e-friends"),
                        title: "Friends",
                        kind: .group,
                        parentContainerID: "e2e-container",
                        contactCount: 1
                    ),
                    ContactCollectionSummary(
                        id: ContactCollectionIdentifier.group("e2e-work"),
                        title: "Work",
                        kind: .group,
                        parentContainerID: "e2e-container",
                        contactCount: 1
                    )
                ],
                contactIDsByCollectionID: [
                    ContactCollectionIdentifier.all: ["e2e-ada", "e2e-grace", "e2e-alan"],
                    ContactCollectionIdentifier.container("e2e-container"): ["e2e-ada", "e2e-grace", "e2e-alan"],
                    ContactCollectionIdentifier.group("e2e-friends"): ["e2e-grace"],
                    ContactCollectionIdentifier.group("e2e-work"): ["e2e-alan"]
                ],
                groupIDsByContactID: [
                    "e2e-grace": ["e2e-friends"],
                    "e2e-alan": ["e2e-work"]
                ]
            ),
            loadedAt: Date(timeIntervalSince1970: 0)
        ),
        tags: [
            ContactTag(
                id: "e2e-vip",
                name: "VIP",
                color: 0x007AFF,
                sortOrder: 0,
                createdAt: Date(timeIntervalSince1970: 0),
                updatedAt: Date(timeIntervalSince1970: 0)
            )
        ],
        assignmentsByContactID: [:],
        initialSelection: .contacts
    )

    private static func contact(
        id: String,
        name: String,
        organization: String,
        month: Int,
        day: Int
    ) -> ContactRosterProfile {
        ContactRosterProfile(
            id: id,
            displayName: name,
            organizationName: organization,
            records: [
                RosterRecord(
                    id: "\(id)-gregorian",
                    contactID: id,
                    contactName: name,
                    organizationName: organization,
                    kind: .gregorian,
                    components: DateComponents(
                        calendar: Calendar(identifier: .gregorian),
                        year: 1990,
                        month: month,
                        day: day
                    ),
                    source: .appleRoster,
                    syncPolicy: .writeBackToApple
                )
            ]
        )
    }
}

// MARK: - App Store screenshot fixtures

extension RosterE2EFixtures {
    /// Deterministic, entirely fictional data used to capture App Store screenshots.
    /// Never derived from the user's real Contacts database.
    package static func storeScreenshots(selection: SidebarSelection) -> RosterE2EFixture {
        RosterE2EFixture(
            snapshot: storeDemoSnapshot,
            tags: storeDemoTags,
            assignmentsByContactID: storeDemoAssignments,
            initialSelection: selection,
            initialSelectedDate: storeDemoSelectedDate
        )
    }

    /// Anchors the calendar screenshot on a day that has birthdays, so the
    /// detail panel is populated instead of showing an empty "today" state.
    private static let storeDemoSelectedDate: Date? = {
        var components = Calendar.current.dateComponents([.year], from: Date())
        components.month = 9
        components.day = 13
        return Calendar.current.date(from: components)
    }()

    private static let storeDemoTags: [ContactTag] = [
        ContactTag(id: "store-vip", name: "重要客户", color: 0xD9483B, sortOrder: 0),
        ContactTag(id: "store-friend", name: "朋友", color: 0x2F7CF6, sortOrder: 1),
        ContactTag(id: "store-college", name: "同学", color: 0x1E9E8A, parentTagID: "store-friend", sortOrder: 0),
        ContactTag(id: "store-followup", name: "待跟进", color: 0x8E5BD9, sortOrder: 2)
    ]

    private static let storeDemoAssignments: [String: Set<String>] = [
        "store-jiahe": ["store-vip"],
        "store-amelia": ["store-vip", "store-followup"],
        "store-zhiyuan": ["store-friend"],
        "store-wanning": ["store-friend", "store-college"],
        "store-okafor": ["store-followup"],
        "store-hexu": ["store-college"],
        "store-bailu": ["store-friend"]
    ]

    private static let storeDemoSnapshot: ContactDataSnapshot = {
        let contacts: [ContactRosterProfile] = [
            storeContact("store-jiahe", "陈嘉禾", "云图设计", given: "嘉禾", family: "陈",
                         org: "云图设计", title: "设计总监", phone: "+86 138 0000 1024",
                         email: "jiahe@example.com", month: 9, day: 13),
            storeContact("store-amelia", "Amelia Hart", "", given: "Amelia", family: "Hart",
                         org: "Northwind Studio", title: "Producer", phone: "+1 415 555 0142",
                         email: "amelia@example.com", month: 9, day: 15),
            storeContact("store-zhiyuan", "林知远", "明远科技", given: "知远", family: "林",
                         org: "明远科技", title: "技术负责人", phone: "+86 139 0000 3388",
                         email: "zhiyuan@example.com", month: 9, day: 18),
            storeContact("store-okafor", "Daniel Okafor", "", given: "Daniel", family: "Okafor",
                         org: "Brightline Labs", title: "Researcher", month: 9, day: 21),
            storeContact("store-wanning", "苏晚宁", "", given: "晚宁", family: "苏",
                         org: "独立摄影", title: "摄影师", email: "wanning@example.com",
                         month: 9, day: 26, lunar: (month: 8, day: 15)),
            storeContact("store-ruiz", "Marta Ruiz", "", given: "Marta", family: "Ruiz",
                         org: "Casa Verde", title: "Partner", month: 9, day: 30),
            storeContact("store-hexu", "何叙", "", given: "叙", family: "何",
                         org: "山与海工作室", title: "主理人", month: 10, day: 4),
            storeContact("store-priya", "Priya Raman", "", given: "Priya", family: "Raman",
                         org: "Lumen Analytics", title: "Data Lead", phone: "+44 20 5550 0188",
                         month: 10, day: 12),
            storeContact("store-zhouzhi", "周执", "", given: "执", family: "周",
                         org: "象限建筑", title: "建筑师", month: 11, day: 2),
            storeContact("store-berg", "Thomas Berg", "", given: "Thomas", family: "Berg",
                         org: "Fjord Works", title: "Founder", month: 11, day: 19),
            storeContact("store-bailu", "白露", "", given: "露", family: "白",
                         org: "长野书店", title: "店长", month: 12, day: 8, lunar: (month: 10, day: 20)),
            storeContact("store-feldman", "Noah Feldman", "", given: "Noah", family: "Feldman",
                         org: "Harbor Point", title: "Editor", month: 1, day: 22,
                         hebrew: (month: 5, day: 12)),
            storeContact("store-shenyi", "沈亦", "", given: "亦", family: "沈",
                         org: "未名教育", title: "课程研发", month: 3, day: 5),
            storeContact("store-rossi", "Chiara Rossi", "", given: "Chiara", family: "Rossi",
                         org: "Studio Rossa", title: "Art Director", month: 5, day: 16,
                         islamic: (month: 12, day: 3)),
            storeContact("store-park", "Jimin Park", "", given: "Jimin", family: "Park",
                         org: "Sundae Type", title: "Type Designer", month: 7, day: 9),
            storeContact("store-nadia", "Nadia Haddad", "", given: "Nadia", family: "Haddad",
                         org: "Cedar & Co.", title: "Analyst", month: 2, day: 27)
        ]

        let allIDs = contacts.map(\.id)
        let groupMembers: [String: Set<String>] = [
            "store-group-work": ["store-jiahe", "store-zhiyuan", "store-okafor", "store-priya", "store-zhouzhi"],
            "store-group-family": ["store-wanning", "store-bailu", "store-shenyi"],
            "store-group-college": ["store-wanning", "store-hexu", "store-berg"]
        ]

        var contactIDsByCollectionID: [String: Set<String>] = [
            ContactCollectionIdentifier.all: Set(allIDs),
            ContactCollectionIdentifier.container("store-container-icloud"): Set(allIDs),
            ContactCollectionIdentifier.container("store-container-local"): []
        ]
        var groupIDsByContactID: [String: Set<String>] = [:]
        for (groupID, memberIDs) in groupMembers {
            contactIDsByCollectionID[ContactCollectionIdentifier.group(groupID)] = memberIDs
            for memberID in memberIDs {
                groupIDsByContactID[memberID, default: []].insert(groupID)
            }
        }

        let collections: [ContactCollectionSummary] = [
            ContactCollectionSummary(id: ContactCollectionIdentifier.all, title: "All Contacts",
                                     kind: .all, parentContainerID: nil, contactCount: allIDs.count),
            ContactCollectionSummary(id: ContactCollectionIdentifier.container("store-container-icloud"),
                                     title: "iCloud", kind: .container, parentContainerID: nil,
                                     contactCount: allIDs.count),
            ContactCollectionSummary(id: ContactCollectionIdentifier.container("store-container-local"),
                                     title: "On My Mac", kind: .container, parentContainerID: nil,
                                     contactCount: 0),
            ContactCollectionSummary(id: ContactCollectionIdentifier.group("store-group-work"),
                                     title: "同事", kind: .group,
                                     parentContainerID: "store-container-icloud", contactCount: 5),
            ContactCollectionSummary(id: ContactCollectionIdentifier.group("store-group-family"),
                                     title: "家人", kind: .group,
                                     parentContainerID: "store-container-icloud", contactCount: 3),
            ContactCollectionSummary(id: ContactCollectionIdentifier.group("store-group-college"),
                                     title: "大学同学", kind: .group,
                                     parentContainerID: "store-container-local", contactCount: 3)
        ]

        let extendedProfiles: [String: ContactExtendedProfile] = [
            "store-jiahe": ContactExtendedProfile(
                phoneNumbers: ["+86 138 0000 1024", "+86 10 5555 0100"],
                emailAddresses: ["jiahe@example.com", "hello@cloudatlas.example"],
                urlAddresses: ["cloudatlas.example"], jobTitle: "设计总监"),
            "store-amelia": ContactExtendedProfile(
                phoneNumbers: ["+1 415 555 0142"],
                emailAddresses: ["amelia@example.com"],
                postalAddresses: ["1200 Market St, San Francisco, CA"],
                jobTitle: "Producer"),
            "store-wanning": ContactExtendedProfile(
                phoneNumbers: ["+86 137 0000 2201"],
                emailAddresses: ["wanning@example.com"],
                urlAddresses: ["wanning.example"], jobTitle: "摄影师"),
            "store-zhiyuan": ContactExtendedProfile(
                phoneNumbers: ["+86 139 0000 3388"],
                emailAddresses: ["zhiyuan@example.com"], jobTitle: "技术负责人")
        ]

        return ContactDataSnapshot(
            profiles: contacts,
            grouping: ContactGroupingSnapshot(
                containers: [
                    ContactContainerSummary(id: "store-container-icloud", name: "iCloud", typeName: "CardDAV"),
                    ContactContainerSummary(id: "store-container-local", name: "On My Mac", typeName: "Local")
                ],
                groups: [
                    ContactGroupSummary(id: "store-group-work", containerID: "store-container-icloud",
                                        name: "同事", contactCount: 5),
                    ContactGroupSummary(id: "store-group-family", containerID: "store-container-icloud",
                                        name: "家人", contactCount: 3),
                    ContactGroupSummary(id: "store-group-college", containerID: "store-container-local",
                                        name: "大学同学", contactCount: 3)
                ],
                collections: collections,
                contactIDsByCollectionID: contactIDsByCollectionID,
                groupIDsByContactID: groupIDsByContactID
            ),
            extendedProfilesByID: extendedProfiles,
            fieldAccessLevel: .extended,
            loadedAt: Date(timeIntervalSince1970: 0)
        )
    }()

    private static func storeContact(
        _ id: String,
        _ name: String,
        _ org: String,
        given: String,
        family: String,
        org organizationName: String,
        title: String,
        phone: String = "",
        email: String = "",
        month: Int,
        day: Int,
        lunar: (month: Int, day: Int)? = nil,
        hebrew: (month: Int, day: Int)? = nil,
        islamic: (month: Int, day: Int)? = nil
    ) -> ContactRosterProfile {
        var records = [
            RosterRecord(
                id: "\(id)-gregorian",
                contactID: id,
                contactName: name,
                organizationName: organizationName,
                kind: .gregorian,
                components: DateComponents(calendar: Calendar(identifier: .gregorian),
                                           year: 1990, month: month, day: day),
                source: .appleRoster,
                syncPolicy: .writeBackToApple
            )
        ]
        if let lunar {
            records.append(RosterRecord(
                id: "\(id)-chinese", contactID: id, contactName: name,
                organizationName: organizationName, kind: .chinese,
                components: DateComponents(calendar: Calendar(identifier: .chinese),
                                           year: 1992, month: lunar.month, day: lunar.day),
                source: .appleRoster, syncPolicy: .writeBackToApple))
        }
        if let hebrew {
            records.append(RosterRecord(
                id: "\(id)-hebrew", contactID: id, contactName: name,
                organizationName: organizationName, kind: .hebrew,
                components: DateComponents(calendar: Calendar(identifier: .hebrew),
                                           year: 1990, month: hebrew.month, day: hebrew.day),
                source: .appleRoster, syncPolicy: .writeBackToApple))
        }
        if let islamic {
            records.append(RosterRecord(
                id: "\(id)-islamic", contactID: id, contactName: name,
                organizationName: organizationName, kind: .islamic,
                components: DateComponents(calendar: Calendar(identifier: .islamic),
                                           year: 1990, month: islamic.month, day: islamic.day),
                source: .appleRoster, syncPolicy: .writeBackToApple))
        }

        return ContactRosterProfile(
            id: id,
            displayName: name,
            organizationName: org,
            records: records,
            givenName: given,
            familyName: family,
            nickname: "",
            departmentName: "",
            jobTitle: title,
            phoneNumbers: phone.isEmpty ? [] : [phone],
            emailAddresses: email.isEmpty ? [] : [email]
        )
    }
}
