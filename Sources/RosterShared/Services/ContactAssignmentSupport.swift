import RosterCore
import CoreTransferable
import Foundation
import UniformTypeIdentifiers

package struct ContactAssignmentDragPayload: Codable, Transferable, Sendable {
    package let contactIDs: [String]

    package static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .rosterContactAssignmentPayload)
    }
}

package enum ContactDragSelectionResolver {
    package static func draggedContactIDs(
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

package enum ContactAssignmentTargetResolver {
    package static func groupDropCollections(
        from sections: [ContactCollectionSectionModel]
    ) -> [ContactCollectionSummary] {
        sections
            .flatMap(\.collections)
            .filter { $0.kind == .group }
    }

    package static func droppedContactIDs(
        from payloads: [ContactAssignmentDragPayload]
    ) -> Set<String> {
        Set(payloads.flatMap(\.contactIDs))
    }

    @MainActor
    package static func loadDroppedContactIDs(
        from providers: [NSItemProvider],
        completion: @escaping @MainActor (Set<String>) -> Void
    ) {
        let matchingProviders = providers.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.rosterContactAssignmentPayload.identifier)
            || $0.hasItemConformingToTypeIdentifier(UTType.legacyContactAssignmentPayload.identifier)
        }
        guard !matchingProviders.isEmpty else {
            completion([])
            return
        }

        let state = ContactDropLoadState(remaining: matchingProviders.count, completion: completion)
        for provider in matchingProviders {
            let type: UTType = provider.hasItemConformingToTypeIdentifier(UTType.rosterContactAssignmentPayload.identifier)
                ? .rosterContactAssignmentPayload
                : .legacyContactAssignmentPayload
            _ = provider.loadDataRepresentation(for: type) { data, _ in
                let payload = data.flatMap {
                    try? JSONDecoder().decode(ContactAssignmentDragPayload.self, from: $0)
                }
                let contactIDs = Set(payload?.contactIDs ?? [])
                Task { @MainActor in
                    state.append(contactIDs)
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

    package init(remaining: Int, completion: @escaping @MainActor (Set<String>) -> Void) {
        self.remaining = remaining
        self.completion = completion
    }

    package func append(_ contactIDs: Set<String>) {
        result.formUnion(contactIDs)
        remaining -= 1
        if remaining == 0 {
            completion(result)
        }
    }
}

package extension UTType {
    static let rosterContactAssignmentPayload = UTType(exportedAs: "com.carlos.roster.contact-assignment")
    static let legacyContactAssignmentPayload = UTType(importedAs: "com.carlos.birthday.contact-assignment")
}
