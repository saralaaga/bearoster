import BirthdayCore
import Foundation

actor ContactSyncService {
    private let repository: ContactsRepository
    private let cache: ContactSnapshotCache

    init(
        repository: ContactsRepository = ContactsRepository(),
        cache: ContactSnapshotCache = ContactSnapshotCache()
    ) {
        self.repository = repository
        self.cache = cache
    }

    nonisolated var authorizationStatus: ContactsPermissionState {
        repository.authorizationStatus
    }

    nonisolated static var didChangeNotification: Notification.Name {
        ContactsRepository.didChangeNotification
    }

    func requestAccess() async throws -> Bool {
        try await repository.requestAccess()
    }

    func cachedSnapshot(
        fieldAccessLevel: ContactFieldAccessLevel,
        accessScope: ContactAccessScope
    ) async -> ContactDataSnapshot? {
        await cache.load(fieldAccessLevel: fieldAccessLevel, accessScope: accessScope)
    }

    func refreshSnapshot(
        fieldAccessLevel: ContactFieldAccessLevel,
        accessScope: ContactAccessScope
    ) async throws -> ContactDataSnapshot {
        let snapshot = try await repository.fetchDataSnapshot(
            fieldAccessLevel: fieldAccessLevel,
            accessScope: accessScope
        )
        await cache.save(snapshot, accessScope: accessScope)
        return snapshot
    }

    func saveBirthdays(contactID: String, payload: BirthdayEditPayload) async throws {
        try await repository.saveBirthdays(contactID: contactID, payload: payload)
    }

    func deleteContacts(contactIDs: [String]) async throws {
        try await repository.deleteContacts(contactIDs: contactIDs)
    }
}
