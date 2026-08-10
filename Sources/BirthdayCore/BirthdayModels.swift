import Contacts
import Foundation

public enum BirthdayCalendarKind: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
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

    public static func contactsSupportedNonGregorian(_ identifier: Calendar.Identifier?) -> BirthdayCalendarKind? {
        switch identifier {
        case .some(.chinese): .chinese
        case .some(.hebrew): .hebrew
        case .some(.islamic): .islamic
        default: nil
        }
    }
}

public enum BirthdayPersonSource: String, Codable, Hashable, Sendable {
    case local
    case appleImported
    case merged
}

public enum BirthdayDateSpecSource: String, Codable, Hashable, Sendable {
    case local
    case appleBirthday
    case appleNonGregorianBirthday
}

public enum BirthdayDateSyncPolicy: String, Codable, Hashable, Sendable {
    case localOnly
    case writeBackToApple
}

public struct BirthdayPerson: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var displayName: String
    public var organizationName: String
    public var appleContactIdentifier: String?
    public var source: BirthdayPersonSource

    public init(
        id: String,
        displayName: String,
        organizationName: String = "",
        appleContactIdentifier: String? = nil,
        source: BirthdayPersonSource = .local
    ) {
        self.id = id
        self.displayName = displayName
        self.organizationName = organizationName
        self.appleContactIdentifier = appleContactIdentifier
        self.source = source
    }
}

public struct BirthdayDateSpec: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let personID: String
    public var kind: BirthdayCalendarKind
    public var components: DateComponents
    public var label: String?
    public var source: BirthdayDateSpecSource
    public var syncPolicy: BirthdayDateSyncPolicy

    public init(
        id: String? = nil,
        personID: String,
        kind: BirthdayCalendarKind,
        components: DateComponents,
        label: String? = nil,
        source: BirthdayDateSpecSource = .local,
        syncPolicy: BirthdayDateSyncPolicy = .localOnly
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
        kind: BirthdayCalendarKind,
        components: DateComponents,
        source: BirthdayDateSpecSource
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

public struct BirthdayRecord: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let contactID: String
    public let contactName: String
    public let organizationName: String
    public let kind: BirthdayCalendarKind
    public let components: DateComponents
    public let source: BirthdayDateSpecSource
    public let syncPolicy: BirthdayDateSyncPolicy

    public init(
        id: String? = nil,
        contactID: String,
        contactName: String,
        organizationName: String,
        kind: BirthdayCalendarKind,
        components: DateComponents,
        source: BirthdayDateSpecSource = .local,
        syncPolicy: BirthdayDateSyncPolicy = .localOnly
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

    public init(person: BirthdayPerson, dateSpec: BirthdayDateSpec) {
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

    public var dateSpec: BirthdayDateSpec {
        BirthdayDateSpec(
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
        kind = try container.decode(BirthdayCalendarKind.self, forKey: .kind)
        components = try container.decode(DateComponents.self, forKey: .components).normalized(for: kind)
        source = try container.decodeIfPresent(BirthdayDateSpecSource.self, forKey: .source)
            ?? Self.defaultSource(forID: id, kind: kind)
        syncPolicy = try container.decodeIfPresent(BirthdayDateSyncPolicy.self, forKey: .syncPolicy)
            ?? Self.defaultSyncPolicy(forID: id)
    }

    private static func defaultSource(forID id: String, kind: BirthdayCalendarKind) -> BirthdayDateSpecSource {
        guard !id.hasPrefix("local:") else { return .local }
        return kind == .gregorian ? .appleBirthday : .appleNonGregorianBirthday
    }

    private static func defaultSyncPolicy(forID id: String) -> BirthdayDateSyncPolicy {
        id.hasPrefix("local:") ? .localOnly : .writeBackToApple
    }
}

public struct ContactBirthdayProfile: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var displayName: String
    public var organizationName: String
    public var records: [BirthdayRecord]

    public init(id: String, displayName: String, organizationName: String, records: [BirthdayRecord]) {
        self.id = id
        self.displayName = displayName
        self.organizationName = organizationName
        self.records = records
    }

    public var person: BirthdayPerson {
        BirthdayPerson(
            id: id,
            displayName: displayName,
            organizationName: organizationName,
            appleContactIdentifier: id,
            source: .appleImported
        )
    }

    public var dateSpecs: [BirthdayDateSpec] {
        records.map(\.dateSpec)
    }
}

public struct BirthdayOccurrence: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let record: BirthdayRecord
    public let date: Date
    public let age: Int?

    public init(record: BirthdayRecord, date: Date, age: Int?) {
        self.id = "\(record.id)-\(Int(date.timeIntervalSinceReferenceDate))"
        self.record = record
        self.date = date
        self.age = age
    }
}

public struct BirthdayEditPayload: Equatable, Sendable {
    public var gregorian: DateComponents?
    public var nonGregorianKind: BirthdayCalendarKind?
    public var nonGregorian: DateComponents?
    public var localOnlyDateSpecs: [BirthdayDateSpec]

    public init(
        gregorian: DateComponents?,
        nonGregorianKind: BirthdayCalendarKind?,
        nonGregorian: DateComponents?,
        localOnlyDateSpecs: [BirthdayDateSpec] = []
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
    public func normalized(for kind: BirthdayCalendarKind) -> DateComponents {
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
