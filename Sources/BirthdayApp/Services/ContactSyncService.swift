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

    func cachedSnapshot(fieldAccessLevel: ContactFieldAccessLevel) async -> ContactDataSnapshot? {
        await cache.load(fieldAccessLevel: fieldAccessLevel)
    }

    func refreshSnapshot(fieldAccessLevel: ContactFieldAccessLevel) async throws -> ContactDataSnapshot {
        let snapshot = try await repository.fetchDataSnapshot(fieldAccessLevel: fieldAccessLevel)
        await cache.save(snapshot)
        return snapshot
    }

    func saveBirthdays(contactID: String, payload: BirthdayEditPayload) async throws {
        try await repository.saveBirthdays(contactID: contactID, payload: payload)
    }

    func deleteContacts(contactIDs: [String]) async throws {
        try await repository.deleteContacts(contactIDs: contactIDs)
    }
}
