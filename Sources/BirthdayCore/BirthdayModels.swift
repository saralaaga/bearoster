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

public struct BirthdayRecord: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let contactID: String
    public let contactName: String
    public let organizationName: String
    public let kind: BirthdayCalendarKind
    public let components: DateComponents

    public init(
        contactID: String,
        contactName: String,
        organizationName: String,
        kind: BirthdayCalendarKind,
        components: DateComponents
    ) {
        self.id = "\(contactID)-\(kind.rawValue)"
        self.contactID = contactID
        self.contactName = contactName
        self.organizationName = organizationName
        self.kind = kind
        self.components = components.normalized(for: kind)
    }

    public var year: Int? { components.year }
    public var month: Int? { components.month }
    public var day: Int? { components.day }
    public var isLeapMonth: Bool { components.isLeapMonth == true }
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

    public init(
        gregorian: DateComponents?,
        nonGregorianKind: BirthdayCalendarKind?,
        nonGregorian: DateComponents?
    ) {
        self.gregorian = gregorian?.normalized(for: .gregorian)
        self.nonGregorianKind = nonGregorianKind
        self.nonGregorian = {
            guard let kind = nonGregorianKind else { return nil }
            return nonGregorian?.normalized(for: kind)
        }()
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
