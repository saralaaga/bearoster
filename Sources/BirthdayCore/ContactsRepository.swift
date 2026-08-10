@preconcurrency import Contacts
import Foundation

public enum ContactsPermissionState: Equatable, Sendable {
    case notDetermined
    case authorized
    case limited
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

public final class ContactsRepository: @unchecked Sendable {
    private let store: CNContactStore

    public static var didChangeNotification: Notification.Name {
        .CNContactStoreDidChange
    }

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

    public func fetchProfiles() async throws -> [ContactBirthdayProfile] {
        try await fetchDataSnapshot(fieldAccessLevel: .birthdayOnly, accessScope: .all).profiles
    }

    public func fetchDataSnapshot(
        fieldAccessLevel: ContactFieldAccessLevel,
        accessScope: ContactAccessScope = .all
    ) async throws -> ContactDataSnapshot {
        let store = store
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    continuation.resume(returning: try Self.fetchDataSnapshotSync(
                        store: store,
                        fieldAccessLevel: fieldAccessLevel,
                        accessScope: accessScope
                    ))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func saveBirthdays(contactID: String, payload: BirthdayEditPayload) async throws {
        let store = store
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try Self.saveBirthdaysSync(store: store, contactID: contactID, payload: payload)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func deleteContacts(contactIDs: [String]) async throws {
        let store = store
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try Self.deleteContactsSync(store: store, contactIDs: contactIDs)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func mapAuthorization(_ status: CNAuthorizationStatus) -> ContactsPermissionState {
        switch status {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .unknown
        }
    }

    private static func fetchDataSnapshotSync(
        store: CNContactStore,
        fieldAccessLevel: ContactFieldAccessLevel,
        accessScope: ContactAccessScope
    ) throws -> ContactDataSnapshot {
        guard canReadContacts else {
            throw ContactsRepositoryError.permissionDenied
        }

        let request = CNContactFetchRequest(keysToFetch: readKeys(for: fieldAccessLevel))
        request.sortOrder = .userDefault
        var profiles: [ContactBirthdayProfile] = []
        var extendedProfilesByID: [String: ContactExtendedProfile] = [:]

        try store.enumerateContacts(with: request) { contact, _ in
            profiles.append(profile(from: contact))
            if fieldAccessLevel == .extended {
                let extended = extendedProfile(from: contact)
                if extended.hasVisibleFields {
                    extendedProfilesByID[contact.identifier] = extended
                }
            }
        }

        let sortedProfiles = profiles.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        let snapshot = ContactDataSnapshot(
            profiles: sortedProfiles,
            grouping: groupingSnapshot(store: store, allContactIDs: Set(sortedProfiles.map(\.id))),
            extendedProfilesByID: extendedProfilesByID,
            fieldAccessLevel: fieldAccessLevel
        )
        return snapshot.scoped(to: accessScope)
    }

    private static func saveBirthdaysSync(store: CNContactStore, contactID: String, payload: BirthdayEditPayload) throws {
        guard canReadContacts else {
            throw ContactsRepositoryError.permissionDenied
        }

        let contact = try store.unifiedContact(withIdentifier: contactID, keysToFetch: editKeys)
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

    private static func deleteContactsSync(store: CNContactStore, contactIDs: [String]) throws {
        guard canReadContacts else {
            throw ContactsRepositoryError.permissionDenied
        }
        guard !contactIDs.isEmpty else { return }

        let saveRequest = CNSaveRequest()
        for contactID in contactIDs {
            let contact = try store.unifiedContact(
                withIdentifier: contactID,
                keysToFetch: [CNContactIdentifierKey as CNKeyDescriptor]
            )
            guard let mutable = contact.mutableCopy() as? CNMutableContact else { continue }
            saveRequest.delete(mutable)
        }
        try store.execute(saveRequest)
    }

    private static func validate(_ components: DateComponents) throws {
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
                components: birthday,
                source: .appleBirthday,
                syncPolicy: .writeBackToApple
            ))
        }

        if let alternate = contact.nonGregorianBirthday,
           let kind = BirthdayCalendarKind.contactsSupportedNonGregorian(alternate.calendar?.identifier) {
            records.append(BirthdayRecord(
                contactID: contact.identifier,
                contactName: name,
                organizationName: contact.organizationName,
                kind: kind,
                components: alternate,
                source: .appleNonGregorianBirthday,
                syncPolicy: .writeBackToApple
            ))
        }

        return ContactBirthdayProfile(
            id: contact.identifier,
            displayName: name,
            organizationName: contact.organizationName,
            records: records
        )
    }

    private static var canReadContacts: Bool {
        let status = mapAuthorization(CNContactStore.authorizationStatus(for: .contacts))
        return status == .authorized || status == .limited
    }

    private static func readKeys(for fieldAccessLevel: ContactFieldAccessLevel) -> [CNKeyDescriptor] {
        var keys: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactNicknameKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactBirthdayKey as CNKeyDescriptor,
            CNContactNonGregorianBirthdayKey as CNKeyDescriptor
        ]

        if fieldAccessLevel == .extended {
            keys += [
                CNContactPhoneNumbersKey as CNKeyDescriptor,
                CNContactEmailAddressesKey as CNKeyDescriptor,
                CNContactPostalAddressesKey as CNKeyDescriptor,
                CNContactUrlAddressesKey as CNKeyDescriptor,
                CNContactSocialProfilesKey as CNKeyDescriptor,
                CNContactInstantMessageAddressesKey as CNKeyDescriptor,
                CNContactRelationsKey as CNKeyDescriptor,
                CNContactDatesKey as CNKeyDescriptor,
                CNContactDepartmentNameKey as CNKeyDescriptor,
                CNContactJobTitleKey as CNKeyDescriptor
            ]
        }

        return keys
    }

    private static var editKeys: [CNKeyDescriptor] {
        readKeys(for: .birthdayOnly) + [
            CNContactDatesKey as CNKeyDescriptor
        ]
    }

    private static func groupingSnapshot(store: CNContactStore, allContactIDs: Set<String>) -> ContactGroupingSnapshot {
        let identifierKeys = [CNContactIdentifierKey as CNKeyDescriptor]
        let containers = (try? store.containers(matching: nil)) ?? []
        var containerSummaries: [ContactContainerSummary] = []
        var groupSummaries: [ContactGroupSummary] = []
        var collections: [ContactCollectionSummary] = [
            ContactCollectionSummary(
                id: ContactCollectionIdentifier.all,
                title: "All Contacts",
                kind: .all,
                parentContainerID: nil,
                contactCount: allContactIDs.count
            )
        ]
        var contactIDsByCollectionID: [String: Set<String>] = [
            ContactCollectionIdentifier.all: allContactIDs
        ]
        var groupIDsByContactID: [String: Set<String>] = [:]
        var groupedContactIDs = Set<String>()

        for container in containers {
            let containerID = ContactCollectionIdentifier.container(container.identifier)
            let containerContactIDs = contactIDs(
                store: store,
                predicate: CNContact.predicateForContactsInContainer(withIdentifier: container.identifier),
                keysToFetch: identifierKeys
            )
            containerSummaries.append(ContactContainerSummary(
                id: container.identifier,
                name: container.name,
                typeName: typeName(for: container.type)
            ))
            collections.append(ContactCollectionSummary(
                id: containerID,
                title: "\(container.name) All",
                kind: .container,
                parentContainerID: container.identifier,
                contactCount: containerContactIDs.count
            ))
            contactIDsByCollectionID[containerID] = containerContactIDs

            let groups = (try? store.groups(matching: CNGroup.predicateForGroupsInContainer(withIdentifier: container.identifier))) ?? []
            for group in groups.sorted(by: { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) {
                let groupID = ContactCollectionIdentifier.group(group.identifier)
                let groupContactIDs = contactIDs(
                    store: store,
                    predicate: CNContact.predicateForContactsInGroup(withIdentifier: group.identifier),
                    keysToFetch: identifierKeys
                )
                groupSummaries.append(ContactGroupSummary(
                    id: group.identifier,
                    containerID: container.identifier,
                    name: group.name,
                    contactCount: groupContactIDs.count
                ))
                collections.append(ContactCollectionSummary(
                    id: groupID,
                    title: group.name,
                    kind: .group,
                    parentContainerID: container.identifier,
                    contactCount: groupContactIDs.count
                ))
                contactIDsByCollectionID[groupID] = groupContactIDs
                groupedContactIDs.formUnion(groupContactIDs)
                for contactID in groupContactIDs {
                    groupIDsByContactID[contactID, default: []].insert(group.identifier)
                }
            }
        }

        let ungroupedContactIDs = allContactIDs.subtracting(groupedContactIDs)
        collections.append(ContactCollectionSummary(
            id: ContactCollectionIdentifier.ungrouped,
            title: "Ungrouped",
            kind: .ungrouped,
            parentContainerID: nil,
            contactCount: ungroupedContactIDs.count
        ))
        contactIDsByCollectionID[ContactCollectionIdentifier.ungrouped] = ungroupedContactIDs

        return ContactGroupingSnapshot(
            containers: containerSummaries,
            groups: groupSummaries,
            collections: collections,
            contactIDsByCollectionID: contactIDsByCollectionID,
            groupIDsByContactID: groupIDsByContactID
        )
    }

    private static func contactIDs(
        store: CNContactStore,
        predicate: NSPredicate,
        keysToFetch: [CNKeyDescriptor]
    ) -> Set<String> {
        let contacts = (try? store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)) ?? []
        return Set(contacts.map(\.identifier))
    }

    private static func extendedProfile(from contact: CNContact) -> ContactExtendedProfile {
        ContactExtendedProfile(
            phoneNumbers: contact.phoneNumbers.map { $0.value.stringValue },
            emailAddresses: contact.emailAddresses.map { String($0.value) },
            postalAddresses: contact.postalAddresses.map { CNPostalAddressFormatter.string(from: $0.value, style: .mailingAddress) },
            urlAddresses: contact.urlAddresses.map { String($0.value) },
            socialProfiles: contact.socialProfiles.map { $0.value.username },
            instantMessageAddresses: contact.instantMessageAddresses.map { $0.value.username },
            contactRelations: contact.contactRelations.map { $0.value.name },
            dates: contact.dates.map { componentsText($0.value as DateComponents) },
            departmentName: contact.departmentName,
            jobTitle: contact.jobTitle
        )
    }

    private static func componentsText(_ components: DateComponents) -> String {
        [
            components.year.map(String.init),
            components.month.map { String(format: "%02d", $0) },
            components.day.map { String(format: "%02d", $0) }
        ]
        .compactMap { $0 }
        .joined(separator: "-")
    }

    private static func typeName(for type: CNContainerType) -> String {
        switch type {
        case .local: "Local"
        case .exchange: "Exchange"
        case .cardDAV: "CardDAV"
        case .unassigned: "Unassigned"
        @unknown default: "Unknown"
        }
    }
}


private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
