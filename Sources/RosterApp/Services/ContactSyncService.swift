import RosterCore
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

    func saveRosters(contactID: String, payload: RosterEditPayload) async throws {
        try await repository.saveRosters(contactID: contactID, payload: payload)
    }

    func saveContact(contactID: String, profile: ContactRosterProfile) async throws {
        try await repository.saveContact(contactID: contactID, profile: profile)
    }

    func deleteContacts(contactIDs: [String]) async throws {
        try await repository.deleteContacts(contactIDs: contactIDs)
    }

    func addContacts(contactIDs: [String], toGroupID groupID: String) async throws {
        try await repository.addContacts(contactIDs: contactIDs, toGroupID: groupID)
    }

    func moveContacts(
        contactIDsToAdd: [String],
        toGroupID groupID: String,
        contactIDsByGroupIDToRemove: [String: [String]]
    ) async throws {
        try await repository.moveContacts(
            contactIDsToAdd: contactIDsToAdd,
            toGroupID: groupID,
            contactIDsByGroupIDToRemove: contactIDsByGroupIDToRemove
        )
    }

    func createGroup(named name: String, inContainerID containerID: String) async throws {
        try await repository.createGroup(named: name, inContainerID: containerID)
    }

    func deleteGroup(groupID: String) async throws {
        try await repository.deleteGroup(groupID: groupID)
    }
}
