import RosterCore
import Foundation

package enum ContactTagFilter: Hashable, Sendable {
    case all
    case untagged
    case tag(String)

    package var selectedTagID: String? {
        guard case let .tag(id) = self else { return nil }
        return id
    }

    package var cacheKey: String {
        switch self {
        case .all: "all"
        case .untagged: "untagged"
        case let .tag(id): "tag:\(id)"
        }
    }

    package func contains(
        contactID: String,
        assignments: [String: Set<String>],
        matchingTagIDs: Set<String>? = nil
    ) -> Bool {
        let tagIDs = assignments[contactID] ?? []
        switch self {
        case .all:
            return true
        case .untagged:
            return tagIDs.isEmpty
        case let .tag(tagID):
            return tagIDs.contains { (matchingTagIDs ?? [tagID]).contains($0) }
        }
    }

    package func matchingTagIDs(in tags: [ContactTag]) -> Set<String>? {
        matchingTagIDs(in: ContactTagTree(tags: tags))
    }

    package func matchingTagIDs(in tree: ContactTagTree) -> Set<String>? {
        guard case let .tag(tagID) = self else { return nil }
        return tree.tagAndDescendantIDs(for: tagID)
    }
}

package struct ContactTagSelectionOption: Identifiable, Hashable, Sendable {
    package let id: String
    package let title: String
    package let filter: ContactTagFilter
    package let count: Int
    package let tag: ContactTag?
}

package struct ContactTagTreeNode: Identifiable, Hashable, Sendable {
    package let tag: ContactTag
    package let depth: Int

    package var id: String { tag.id }
}

package struct ContactTagTree: Sendable {
    package let tags: [ContactTag]
    private let tagsByID: [String: ContactTag]
    private let childrenByParentID: [String: [ContactTag]]

    package init(tags: [ContactTag]) {
        self.tags = tags
        self.tagsByID = Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0) })
        let grouped = Dictionary(grouping: tags) { tag in
            tag.parentTagID ?? ""
        }
        childrenByParentID = grouped.mapValues { children in
            children.sorted(by: Self.compareTags(_:_:))
        }
    }

    package var flattened: [ContactTagTreeNode] {
        flatten(parentID: nil, depth: 0)
    }

    package func children(of parentID: String?) -> [ContactTag] {
        childrenByParentID[parentID ?? ""] ?? []
    }

    package func tagAndDescendantIDs(for tagID: String) -> Set<String> {
        var result = Set([tagID])
        appendDescendants(of: tagID, into: &result)
        return result
    }

    package func displayPath(for tagID: String) -> String {
        var parts: [String] = []
        var current = tagsByID[tagID]
        var visited = Set<String>()
        while let tag = current, !visited.contains(tag.id) {
            visited.insert(tag.id)
            parts.append(tag.name)
            current = tag.parentTagID.flatMap { tagsByID[$0] }
        }
        return parts.reversed().joined(separator: " / ")
    }

    package func emptySubtreeTagIDs(assignmentsByContactID: [String: Set<String>]) -> Set<String> {
        let assignedTagIDs = Set(assignmentsByContactID.values.flatMap { $0 })
        return Set(tags.compactMap { tag in
            tagAndDescendantIDs(for: tag.id).isDisjoint(with: assignedTagIDs) ? tag.id : nil
        })
    }

    private func flatten(parentID: String?, depth: Int) -> [ContactTagTreeNode] {
        children(of: parentID).flatMap { tag in
            [ContactTagTreeNode(tag: tag, depth: depth)] + flatten(parentID: tag.id, depth: depth + 1)
        }
    }

    private func appendDescendants(of tagID: String, into result: inout Set<String>) {
        for child in children(of: tagID) {
            guard !result.contains(child.id) else { continue }
            result.insert(child.id)
            appendDescendants(of: child.id, into: &result)
        }
    }

    private static func compareTags(_ lhs: ContactTag, _ rhs: ContactTag) -> Bool {
        if lhs.sortOrder != rhs.sortOrder {
            return lhs.sortOrder < rhs.sortOrder
        }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
}
