import Contacts
import Foundation

public enum ContactsPermissionState: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
    case unknown
}

public enum ContactsRepositoryError: LocalizedError, Sendable {
    case permissionDenied
    case invalidNonGregorianCalendar
    case invalidDateComponents

    public var errorDescription: String? {
        switch self {
        case .permissionDenied: "Contacts permission is not granted."
        case .invalidNonGregorianCalendar: "Contacts only supports Chinese, Hebrew, or Islamic alternate birthdays."
        case .invalidDateComponents: "Birthday dates need at least a valid month and day."
        }
    }
}

@MainActor
public final class ContactsRepository {
    private let store: CNContactStore

    public init(store: CNContactStore = CNContactStore()) {
        self.store = store
    }

    public var authorizationStatus: ContactsPermissionState {
        Self.mapAuthorization(CNContactStore.authorizationStatus(for: .contacts))
    }

    public func requestAccess() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            store.requestAccess(for: .contacts) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    public func fetchProfiles() throws -> [ContactBirthdayProfile] {
        guard authorizationStatus == .authorized else {
            throw ContactsRepositoryError.permissionDenied
        }

        let request = CNContactFetchRequest(keysToFetch: Self.readKeys)
        request.sortOrder = .userDefault
        var profiles: [ContactBirthdayProfile] = []

        try store.enumerateContacts(with: request) { contact, _ in
            profiles.append(Self.profile(from: contact))
        }

        return profiles.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    public func saveBirthdays(contactID: String, payload: BirthdayEditPayload) throws {
        guard authorizationStatus == .authorized else {
            throw ContactsRepositoryError.permissionDenied
        }

        let contact = try store.unifiedContact(withIdentifier: contactID, keysToFetch: Self.editKeys)
        guard let mutable = contact.mutableCopy() as? CNMutableContact else { return }

        if let gregorian = payload.gregorian {
            try validate(gregorian)
            mutable.birthday = gregorian.normalized(for: .gregorian)
        } else {
            mutable.birthday = nil
        }

        if let kind = payload.nonGregorianKind, let nonGregorian = payload.nonGregorian {
            guard [.chinese, .hebrew, .islamic].contains(kind) else {
                throw ContactsRepositoryError.invalidNonGregorianCalendar
            }
            try validate(nonGregorian)
            mutable.nonGregorianBirthday = nonGregorian.normalized(for: kind)
        } else {
            mutable.nonGregorianBirthday = nil
        }

        let saveRequest = CNSaveRequest()
        saveRequest.update(mutable)
        try store.execute(saveRequest)
    }

    private static func mapAuthorization(_ status: CNAuthorizationStatus) -> ContactsPermissionState {
        switch status {
        case .notDetermined: .notDetermined
        case .authorized: .authorized
        case .denied: .denied
        case .restricted: .restricted
        @unknown default: .unknown
        }
    }

    private func validate(_ components: DateComponents) throws {
        guard let month = components.month, let day = components.day,
              (1...13).contains(month), (1...31).contains(day)
        else {
            throw ContactsRepositoryError.invalidDateComponents
        }
    }

    private static func profile(from contact: CNContact) -> ContactBirthdayProfile {
        let name = CNContactFormatter.string(from: contact, style: .fullName)
            ?? [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
            .nilIfEmpty
            ?? contact.nickname.nilIfEmpty
            ?? "Unnamed"

        var records: [BirthdayRecord] = []
        if let birthday = contact.birthday {
            records.append(BirthdayRecord(
                contactID: contact.identifier,
                contactName: name,
                organizationName: contact.organizationName,
                kind: .gregorian,
                components: birthday
            ))
        }

        if let alternate = contact.nonGregorianBirthday,
           let kind = BirthdayCalendarKind.contactsSupportedNonGregorian(alternate.calendar?.identifier) {
            records.append(BirthdayRecord(
                contactID: contact.identifier,
                contactName: name,
                organizationName: contact.organizationName,
                kind: kind,
                components: alternate
            ))
        }

        return ContactBirthdayProfile(
            id: contact.identifier,
            displayName: name,
            organizationName: contact.organizationName,
            records: records
        )
    }

    private static let readKeys: [CNKeyDescriptor] = [
        CNContactIdentifierKey as CNKeyDescriptor,
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactNicknameKey as CNKeyDescriptor,
        CNContactOrganizationNameKey as CNKeyDescriptor,
        CNContactBirthdayKey as CNKeyDescriptor,
        CNContactNonGregorianBirthdayKey as CNKeyDescriptor
    ]

    private static let editKeys: [CNKeyDescriptor] = readKeys + [
        CNContactDatesKey as CNKeyDescriptor
    ]
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
