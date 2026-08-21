import RosterCore
import Foundation

struct RosterE2EFixture: Sendable {
    let snapshot: ContactDataSnapshot
    let tags: [ContactTag]
    let assignmentsByContactID: [String: Set<String>]
    let initialSelection: SidebarSelection
}

enum RosterE2EFixtures {
    static let contactDragAndDrop = RosterE2EFixture(
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
