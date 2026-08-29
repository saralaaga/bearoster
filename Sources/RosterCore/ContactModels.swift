import Foundation

public enum ContactFieldAccessLevel: String, Codable, Hashable, Sendable {
    case birthdayOnly
    case extended
}

public struct ContactExtendedProfile: Codable, Hashable, Sendable {
    public var phoneNumbers: [String]
    public var emailAddresses: [String]
    public var postalAddresses: [String]
    public var urlAddresses: [String]
    public var socialProfiles: [String]
    public var instantMessageAddresses: [String]
    public var contactRelations: [String]
    public var dates: [String]
    public var departmentName: String
    public var jobTitle: String

    public init(
        phoneNumbers: [String] = [],
        emailAddresses: [String] = [],
        postalAddresses: [String] = [],
        urlAddresses: [String] = [],
        socialProfiles: [String] = [],
        instantMessageAddresses: [String] = [],
        contactRelations: [String] = [],
        dates: [String] = [],
        departmentName: String = "",
        jobTitle: String = ""
    ) {
        self.phoneNumbers = phoneNumbers
        self.emailAddresses = emailAddresses
        self.postalAddresses = postalAddresses
        self.urlAddresses = urlAddresses
        self.socialProfiles = socialProfiles
        self.instantMessageAddresses = instantMessageAddresses
        self.contactRelations = contactRelations
        self.dates = dates
        self.departmentName = departmentName
        self.jobTitle = jobTitle
    }

    public var hasVisibleFields: Bool {
        !phoneNumbers.isEmpty ||
            !emailAddresses.isEmpty ||
            !postalAddresses.isEmpty ||
            !urlAddresses.isEmpty ||
            !socialProfiles.isEmpty ||
            !instantMessageAddresses.isEmpty ||
            !contactRelations.isEmpty ||
            !dates.isEmpty ||
            !departmentName.isEmpty ||
            !jobTitle.isEmpty
    }
}

public struct ContactContainerSummary: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let typeName: String

    public init(id: String, name: String, typeName: String) {
        self.id = id
        self.name = name
        self.typeName = typeName
    }
}

public struct ContactGroupSummary: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let containerID: String
    public let name: String
    public let contactCount: Int

    public init(id: String, containerID: String, name: String, contactCount: Int) {
        self.id = id
        self.containerID = containerID
        self.name = name
        self.contactCount = contactCount
    }
}

public enum ContactCollectionKind: String, Codable, Hashable, Sendable {
    case all
    case container
    case group
    case ungrouped
    case tag
    case untagged
}

public enum ContactCollectionIdentifier {
    public static let all = "all"
    public static let ungrouped = "ungrouped"
    public static let tagAll = "tag:all"
    public static let tagUntagged = "tag:untagged"

    public static func container(_ id: String) -> String {
        "container:\(id)"
    }

    public static func group(_ id: String) -> String {
        "group:\(id)"
    }

    public static func tag(_ id: String) -> String {
        "tag:\(id)"
    }

    public static func groupID(from collectionID: String) -> String? {
        rawID(from: collectionID, prefix: "group:")
    }

    public static func containerID(from collectionID: String) -> String? {
        rawID(from: collectionID, prefix: "container:")
    }

    private static func rawID(from collectionID: String, prefix: String) -> String? {
        guard collectionID.hasPrefix(prefix) else { return nil }
        return String(collectionID.dropFirst(prefix.count))
    }
}

public struct ContactTag: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var color: UInt
    public var parentTagID: String?
    public var sortOrder: Int
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        name: String,
        color: UInt = 0x007AFF,
        parentTagID: String? = nil,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.parentTagID = parentTagID
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct ContactAccessScope: Codable, Hashable, Sendable {
    public enum Mode: String, Codable, Hashable, Sendable {
        case allContacts
        case selectedGroups
    }

    public var mode: Mode
    public var allowedGroupIDs: Set<String>
    public var includeUngroupedContacts: Bool

    public init(
        mode: Mode = .allContacts,
        allowedGroupIDs: Set<String> = [],
        includeUngroupedContacts: Bool = true
    ) {
        self.mode = mode
        self.allowedGroupIDs = allowedGroupIDs
        self.includeUngroupedContacts = includeUngroupedContacts
    }

    public static let all = ContactAccessScope()

    public var cacheKey: String {
        switch mode {
        case .allContacts:
            return "all"
        case .selectedGroups:
            let groups = allowedGroupIDs.sorted().joined(separator: ",")
            let ungrouped = includeUngroupedContacts ? "ungrouped" : "grouped-only"
            return "selected:\(ungrouped):\(groups)"
        }
    }

    public func pruned(availableGroupIDs: Set<String>) -> ContactAccessScope {
        var copy = self
        copy.allowedGroupIDs.formIntersection(availableGroupIDs)
        return copy
    }

    public func allowedContactIDs(in grouping: ContactGroupingSnapshot) -> Set<String>? {
        guard mode == .selectedGroups else { return nil }

        var contactIDs = Set<String>()
        for groupID in allowedGroupIDs {
            let collectionID = ContactCollectionIdentifier.group(groupID)
            contactIDs.formUnion(grouping.contactIDsByCollectionID[collectionID] ?? [])
        }

        if includeUngroupedContacts {
            contactIDs.formUnion(grouping.contactIDsByCollectionID[ContactCollectionIdentifier.ungrouped] ?? [])
        }

        return contactIDs
    }
}

public struct ContactCollectionSummary: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let kind: ContactCollectionKind
    public let parentContainerID: String?
    public let contactCount: Int

    public init(
        id: String,
        title: String,
        kind: ContactCollectionKind,
        parentContainerID: String?,
        contactCount: Int
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.parentContainerID = parentContainerID
        self.contactCount = contactCount
    }
}

public struct ContactGroupingSnapshot: Codable, Hashable, Sendable {
    public var containers: [ContactContainerSummary]
    public var groups: [ContactGroupSummary]
    public var collections: [ContactCollectionSummary]
    public var contactIDsByCollectionID: [String: Set<String>]
    public var groupIDsByContactID: [String: Set<String>]

    public init(
        containers: [ContactContainerSummary] = [],
        groups: [ContactGroupSummary] = [],
        collections: [ContactCollectionSummary] = [],
        contactIDsByCollectionID: [String: Set<String>] = [:],
        groupIDsByContactID: [String: Set<String>] = [:]
    ) {
        self.containers = containers
        self.groups = groups
        self.collections = collections
        self.contactIDsByCollectionID = contactIDsByCollectionID
        self.groupIDsByContactID = groupIDsByContactID
    }

    public static let empty = ContactGroupingSnapshot()
}

public struct ContactDataSnapshot: Codable, Hashable, Sendable {
    public var profiles: [ContactRosterProfile]
    public var grouping: ContactGroupingSnapshot
    public var extendedProfilesByID: [String: ContactExtendedProfile]
    public var fieldAccessLevel: ContactFieldAccessLevel
    public var loadedAt: Date

    public init(
        profiles: [ContactRosterProfile],
        grouping: ContactGroupingSnapshot = .empty,
        extendedProfilesByID: [String: ContactExtendedProfile] = [:],
        fieldAccessLevel: ContactFieldAccessLevel = .birthdayOnly,
        loadedAt: Date = Date()
    ) {
        self.profiles = profiles
        self.grouping = grouping
        self.extendedProfilesByID = extendedProfilesByID
        self.fieldAccessLevel = fieldAccessLevel
        self.loadedAt = loadedAt
    }

    public func scoped(to accessScope: ContactAccessScope) -> ContactDataSnapshot {
        guard let allowedIDs = accessScope.allowedContactIDs(in: grouping) else { return self }
        let scopedProfiles = profiles.filter { allowedIDs.contains($0.id) }
        let scopedExtendedProfiles = extendedProfilesByID.filter { allowedIDs.contains($0.key) }
        return ContactDataSnapshot(
            profiles: scopedProfiles,
            grouping: grouping,
            extendedProfilesByID: scopedExtendedProfiles,
            fieldAccessLevel: fieldAccessLevel,
            loadedAt: loadedAt
        )
    }
}
