import Contacts
import Foundation

public enum RosterCalendarKind: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case gregorian
    case chinese
    case hebrew
    case islamic

    public var id: String { rawValue }

    public var calendarIdentifier: Calendar.Identifier {
        switch self {
        case .gregorian: .gregorian
        case .chinese: .chinese
        case .hebrew: .hebrew
        case .islamic: .islamic
        }
    }

    public var supportsLeapMonth: Bool {
        self == .chinese
    }

    public static func contactsSupportedNonGregorian(_ identifier: Calendar.Identifier?) -> RosterCalendarKind? {
        switch identifier {
        case .some(.chinese): .chinese
        case .some(.hebrew): .hebrew
        case .some(.islamic): .islamic
        default: nil
        }
    }
}

public enum RosterPersonSource: String, Codable, Hashable, Sendable {
    case local
    case appleImported
    case merged
}

public enum RosterDateSpecSource: String, Codable, Hashable, Sendable {
    case local
    case appleRoster
    case appleNonGregorianRoster
}

public enum RosterDateSyncPolicy: String, Codable, Hashable, Sendable {
    case localOnly
    case writeBackToApple
}

public struct RosterPerson: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var displayName: String
    public var organizationName: String
    public var appleContactIdentifier: String?
    public var source: RosterPersonSource

    public init(
        id: String,
        displayName: String,
        organizationName: String = "",
        appleContactIdentifier: String? = nil,
        source: RosterPersonSource = .local
    ) {
        self.id = id
        self.displayName = displayName
        self.organizationName = organizationName
        self.appleContactIdentifier = appleContactIdentifier
        self.source = source
    }
}

public struct RosterDateSpec: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let personID: String
    public var kind: RosterCalendarKind
    public var components: DateComponents
    public var label: String?
    public var source: RosterDateSpecSource
    public var syncPolicy: RosterDateSyncPolicy

    public init(
        id: String? = nil,
        personID: String,
        kind: RosterCalendarKind,
        components: DateComponents,
        label: String? = nil,
        source: RosterDateSpecSource = .local,
        syncPolicy: RosterDateSyncPolicy = .localOnly
    ) {
        let normalized = components.normalized(for: kind)
        self.id = id ?? Self.stableID(
            personID: personID,
            kind: kind,
            components: normalized,
            source: source
        )
        self.personID = personID
        self.kind = kind
        self.components = normalized
        self.label = label
        self.source = source
        self.syncPolicy = syncPolicy
    }

    public var year: Int? { components.year }
    public var month: Int? { components.month }
    public var day: Int? { components.day }
    public var isLeapMonth: Bool { components.isLeapMonth == true }

    private static func stableID(
        personID: String,
        kind: RosterCalendarKind,
        components: DateComponents,
        source: RosterDateSpecSource
    ) -> String {
        [
            personID,
            kind.rawValue,
            source.rawValue,
            components.year.map(String.init) ?? "any",
            components.month.map(String.init) ?? "nil",
            components.day.map(String.init) ?? "nil",
            components.isLeapMonth == true ? "leap" : "regular"
        ].joined(separator: ":")
    }
}

public struct RosterRecord: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let contactID: String
    public let contactName: String
    public let organizationName: String
    public let kind: RosterCalendarKind
    public let components: DateComponents
    public let source: RosterDateSpecSource
    public let syncPolicy: RosterDateSyncPolicy

    public init(
        id: String? = nil,
        contactID: String,
        contactName: String,
        organizationName: String,
        kind: RosterCalendarKind,
        components: DateComponents,
        source: RosterDateSpecSource = .local,
        syncPolicy: RosterDateSyncPolicy = .localOnly
    ) {
        self.id = id ?? "\(contactID)-\(kind.rawValue)"
        self.contactID = contactID
        self.contactName = contactName
        self.organizationName = organizationName
        self.kind = kind
        self.components = components.normalized(for: kind)
        self.source = source
        self.syncPolicy = syncPolicy
    }

    public init(person: RosterPerson, dateSpec: RosterDateSpec) {
        self.id = dateSpec.id
        self.contactID = person.id
        self.contactName = person.displayName
        self.organizationName = person.organizationName
        self.kind = dateSpec.kind
        self.components = dateSpec.components
        self.source = dateSpec.source
        self.syncPolicy = dateSpec.syncPolicy
    }

    public var year: Int? { components.year }
    public var month: Int? { components.month }
    public var day: Int? { components.day }
    public var isLeapMonth: Bool { components.isLeapMonth == true }

    public var dateSpec: RosterDateSpec {
        RosterDateSpec(
            id: id,
            personID: contactID,
            kind: kind,
            components: components,
            source: source,
            syncPolicy: syncPolicy
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case contactID
        case contactName
        case organizationName
        case kind
        case components
        case source
        case syncPolicy
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        contactID = try container.decode(String.self, forKey: .contactID)
        contactName = try container.decode(String.self, forKey: .contactName)
        organizationName = try container.decode(String.self, forKey: .organizationName)
        kind = try container.decode(RosterCalendarKind.self, forKey: .kind)
        components = try container.decode(DateComponents.self, forKey: .components).normalized(for: kind)
        source = try container.decodeIfPresent(RosterDateSpecSource.self, forKey: .source)
            ?? Self.defaultSource(forID: id, kind: kind)
        syncPolicy = try container.decodeIfPresent(RosterDateSyncPolicy.self, forKey: .syncPolicy)
            ?? Self.defaultSyncPolicy(forID: id)
    }

    private static func defaultSource(forID id: String, kind: RosterCalendarKind) -> RosterDateSpecSource {
        guard !id.hasPrefix("local:") else { return .local }
        return kind == .gregorian ? .appleRoster : .appleNonGregorianRoster
    }

    private static func defaultSyncPolicy(forID id: String) -> RosterDateSyncPolicy {
        id.hasPrefix("local:") ? .localOnly : .writeBackToApple
    }
}

public struct ContactRosterProfile: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var displayName: String
    public var givenName: String
    public var familyName: String
    public var nickname: String
    public var organizationName: String
    public var departmentName: String
    public var jobTitle: String
    public var phoneNumbers: [String]
    public var emailAddresses: [String]
    public var postalAddresses: [String]
    public var imageData: Data?
    public var records: [RosterRecord]

    public init(
        id: String,
        displayName: String,
        organizationName: String,
        records: [RosterRecord],
        givenName: String = "",
        familyName: String = "",
        nickname: String = "",
        departmentName: String = "",
        jobTitle: String = "",
        phoneNumbers: [String] = [],
        emailAddresses: [String] = [],
        postalAddresses: [String] = [],
        imageData: Data? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.givenName = givenName
        self.familyName = familyName
        self.nickname = nickname
        self.organizationName = organizationName
        self.departmentName = departmentName
        self.jobTitle = jobTitle
        self.phoneNumbers = phoneNumbers
        self.emailAddresses = emailAddresses
        self.postalAddresses = postalAddresses
        self.imageData = imageData
        self.records = records
    }

    public var person: RosterPerson {
        RosterPerson(
            id: id,
            displayName: displayName,
            organizationName: organizationName,
            appleContactIdentifier: id,
            source: .appleImported
        )
    }

    public var dateSpecs: [RosterDateSpec] {
        records.map(\.dateSpec)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case givenName
        case familyName
        case nickname
        case organizationName
        case departmentName
        case jobTitle
        case phoneNumbers
        case emailAddresses
        case postalAddresses
        case imageData
        case records
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        givenName = try container.decodeIfPresent(String.self, forKey: .givenName) ?? ""
        familyName = try container.decodeIfPresent(String.self, forKey: .familyName) ?? ""
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname) ?? ""
        organizationName = try container.decodeIfPresent(String.self, forKey: .organizationName) ?? ""
        departmentName = try container.decodeIfPresent(String.self, forKey: .departmentName) ?? ""
        jobTitle = try container.decodeIfPresent(String.self, forKey: .jobTitle) ?? ""
        phoneNumbers = try container.decodeIfPresent([String].self, forKey: .phoneNumbers) ?? []
        emailAddresses = try container.decodeIfPresent([String].self, forKey: .emailAddresses) ?? []
        postalAddresses = try container.decodeIfPresent([String].self, forKey: .postalAddresses) ?? []
        imageData = try container.decodeIfPresent(Data.self, forKey: .imageData)
        records = try container.decodeIfPresent([RosterRecord].self, forKey: .records) ?? []
    }
}

public struct RosterOccurrence: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let record: RosterRecord
    public let date: Date
    public let age: Int?

    public init(record: RosterRecord, date: Date, age: Int?) {
        self.id = "\(record.id)-\(Int(date.timeIntervalSinceReferenceDate))"
        self.record = record
        self.date = date
        self.age = age
    }
}

public struct RosterEditPayload: Equatable, Sendable {
    public var gregorian: DateComponents?
    public var nonGregorianKind: RosterCalendarKind?
    public var nonGregorian: DateComponents?
    public var localOnlyDateSpecs: [RosterDateSpec]

    public init(
        gregorian: DateComponents?,
        nonGregorianKind: RosterCalendarKind?,
        nonGregorian: DateComponents?,
        localOnlyDateSpecs: [RosterDateSpec] = []
    ) {
        self.gregorian = gregorian?.normalized(for: .gregorian)
        self.nonGregorianKind = nonGregorianKind
        self.nonGregorian = {
            guard let kind = nonGregorianKind else { return nil }
            return nonGregorian?.normalized(for: kind)
        }()
        self.localOnlyDateSpecs = localOnlyDateSpecs
    }
}

extension DateComponents {
    public func normalized(for kind: RosterCalendarKind) -> DateComponents {
        var value = DateComponents()
        value.calendar = Calendar(identifier: kind.calendarIdentifier)
        value.year = year
        value.month = month
        value.day = day
        if kind.supportsLeapMonth {
            value.isLeapMonth = isLeapMonth
        }
        return value
    }
}
