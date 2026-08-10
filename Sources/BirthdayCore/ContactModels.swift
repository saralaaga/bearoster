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
}

public enum ContactCollectionIdentifier {
    public static let all = "all"

    public static func container(_ id: String) -> String {
        "container:\(id)"
    }

    public static func group(_ id: String) -> String {
        "group:\(id)"
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
    public var profiles: [ContactBirthdayProfile]
    public var grouping: ContactGroupingSnapshot
    public var extendedProfilesByID: [String: ContactExtendedProfile]
    public var fieldAccessLevel: ContactFieldAccessLevel
    public var loadedAt: Date

    public init(
        profiles: [ContactBirthdayProfile],
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
}
