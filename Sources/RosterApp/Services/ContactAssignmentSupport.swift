import RosterCore
import CoreTransferable
import Foundation
import UniformTypeIdentifiers
import AppKit

struct ContactAssignmentDragPayload: Codable, Transferable, Sendable {
    let contactIDs: [String]

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .rosterContactAssignmentPayload)
    }
}

struct ContactGroupMovePlan: Equatable, Sendable {
    let contactIDsToAdd: Set<String>
    let contactIDsByGroupIDToRemove: [String: Set<String>]
}

enum ContactDragSelectionResolver {
    static func draggedContactIDs(
        draggedContactID: String,
        selectedContactIDs: Set<String>,
        isSelectionMode: Bool
    ) -> Set<String> {
        guard isSelectionMode else {
            return [draggedContactID]
        }
        guard selectedContactIDs.contains(draggedContactID) else {
            return [draggedContactID]
        }
        return selectedContactIDs
    }
}

enum ContactAssignmentTargetResolver {
    static func groupDropCollections(
        from sections: [ContactCollectionSectionModel]
    ) -> [ContactCollectionSummary] {
        sections
            .flatMap(\.collections)
            .filter { $0.kind == .group }
    }

    static func droppedContactIDs(
        from payloads: [ContactAssignmentDragPayload]
    ) -> Set<String> {
        Set(payloads.flatMap(\.contactIDs))
    }

    static func droppedContactIDs(fromText text: String) -> Set<String> {
        Set(text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
    }

    static func groupMovePlan(
        contactIDs: Set<String>,
        targetGroupID: String,
        grouping: ContactGroupingSnapshot
    ) -> ContactGroupMovePlan {
        let targetCollectionID = ContactCollectionIdentifier.group(targetGroupID)
        let contactsAlreadyInTarget = grouping.contactIDsByCollectionID[targetCollectionID] ?? []
        let targetContainerID = grouping.groups.first { $0.id == targetGroupID }?.containerID
        let groupsByID = Dictionary(uniqueKeysWithValues: grouping.groups.map { ($0.id, $0) })
        var removals: [String: Set<String>] = [:]

        for contactID in contactIDs {
            let oldGroupIDs = grouping.groupIDsByContactID[contactID] ?? []
            for oldGroupID in oldGroupIDs where oldGroupID != targetGroupID {
                guard groupsByID[oldGroupID]?.containerID == targetContainerID else { continue }
                removals[oldGroupID, default: []].insert(contactID)
            }
        }

        return ContactGroupMovePlan(
            contactIDsToAdd: contactIDs.subtracting(contactsAlreadyInTarget),
            contactIDsByGroupIDToRemove: removals
        )
    }

    @MainActor
    static func loadDroppedContactIDs(
        from providers: [NSItemProvider],
        completion: @escaping @MainActor (Set<String>) -> Void
    ) {
        let matchingProviders = providers.filter { provider in
            UTType.contactAssignmentDropTypes.contains {
                provider.hasItemConformingToTypeIdentifier($0.identifier)
            }
        }
        guard !matchingProviders.isEmpty else {
            completion([])
            return
        }

        let state = ContactDropLoadState(remaining: matchingProviders.count, completion: completion)
        for provider in matchingProviders {
            let type = provider.contactAssignmentType
            if type == .plainText || type == .text {
                _ = provider.loadObject(ofClass: NSString.self) { object, _ in
                    let contactIDs = droppedContactIDs(fromText: object as? String ?? "")
                    Task { @MainActor in
                        state.append(contactIDs)
                    }
                }
            } else {
                _ = provider.loadDataRepresentation(for: type) { data, _ in
                    let contactIDs = data.map { droppedContactIDs(from: $0, type: type) } ?? []
                    Task { @MainActor in
                        state.append(contactIDs)
                    }
                }
            }
        }
    }
}

@MainActor
private final class ContactDropLoadState {
    private var result = Set<String>()
    private var remaining: Int
    private let completion: @MainActor (Set<String>) -> Void

    init(remaining: Int, completion: @escaping @MainActor (Set<String>) -> Void) {
        self.remaining = remaining
        self.completion = completion
    }

    func append(_ contactIDs: Set<String>) {
        result.formUnion(contactIDs)
        remaining -= 1
        if remaining == 0 {
            completion(result)
        }
    }
}

extension UTType {
    static let rosterContactAssignmentPayload = UTType(exportedAs: "com.carlos.roster.contact-assignment")
    static let legacyContactAssignmentPayload = UTType(importedAs: "com.carlos.birthday.contact-assignment")
    static let contactAssignmentDropTypes: [UTType] = [
        .rosterContactAssignmentPayload,
        .legacyContactAssignmentPayload,
        .plainText,
        .text
    ]
}

private extension ContactAssignmentTargetResolver {
    static func droppedContactIDs(from data: Data, type: UTType) -> Set<String> {
        if type == .rosterContactAssignmentPayload || type == .legacyContactAssignmentPayload {
            return Set((try? JSONDecoder().decode(ContactAssignmentDragPayload.self, from: data))?.contactIDs ?? [])
        }
        return ContactAssignmentTargetResolver.droppedContactIDs(fromText: String(decoding: data, as: UTF8.self))
    }
}

private extension NSItemProvider {
    var contactAssignmentType: UTType {
        UTType.contactAssignmentDropTypes.first { hasItemConformingToTypeIdentifier($0.identifier) } ?? .plainText
    }
}
