import RosterCore
import AppKit
import RosterShared
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Sidebar

struct SidebarView: View {
    @Environment(RosterAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isCollapsed: Bool
    @State private var tagPendingDeletion: ContactTag?
    @State private var tagPendingRename: ContactTag?
    @State private var childTagParent: ContactTag?
    @State private var isContactsExpanded = true
    @State private var collapsedContactCollectionIDs = Set<String>()

    var body: some View {
        @Bindable var model = model

        ZStack {
            RosterTheme.sidebarBackground(colorScheme)

            VStack(spacing: 0) {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 0) {
                        SidebarSectionTitle(model.l10n(.manage), isCollapsed: isCollapsed)
                        SidebarContactRootItem(isCollapsed: isCollapsed, isExpanded: $isContactsExpanded)
                        if !isCollapsed, isContactsExpanded {
                            Group {
                                ForEach(model.contactCollectionSections) { section in
                                    SidebarContactCollectionSection(
                                        section: section,
                                        title: contactCollectionSectionTitle(section),
                                        collapsedCollectionIDs: $collapsedContactCollectionIDs
                                    )
                                }
                            }
                            .transition(sidebarChildrenTransition)
                        }

                        SidebarTagRootItem(isCollapsed: isCollapsed)
                        if !isCollapsed, model.expandedTagIDs.contains(SidebarTagRootItem.rootID) {
                            Group {
                                ForEach(model.childTags(of: nil)) { tag in
                                    SidebarTagNodeItem(
                                        tag: tag,
                                        depth: 0,
                                        tagPendingDeletion: $tagPendingDeletion,
                                        tagPendingRename: $tagPendingRename,
                                        childTagParent: $childTagParent
                                    )
                                }

                                SidebarTagSpecialItem(
                                    title: model.l10n(.untaggedContacts),
                                    systemImage: "tag.slash.fill",
                                    badge: model.contactCount(for: .untagged),
                                    isSelected: model.selection == .tags && model.selectedTagsFilter == .untagged,
                                    depth: 0
                                ) {
                                    model.selectTagFilter(.untagged)
                                }
                            }
                            .transition(sidebarChildrenTransition)
                        }

                        SidebarItem(
                            title: "同步与历史",
                            systemImage: "clock.arrow.circlepath",
                            badge: model.pendingContactOperationCount + model.failedContactOperationCount + model.conflictedContactOperationCount,
                            isSelected: model.selection == .sync,
                            isCollapsed: isCollapsed
                        ) { model.selection = .sync }

                        SidebarSectionTitle(model.l10n(.browse), isCollapsed: isCollapsed)
                        SidebarItem(
                            title: model.l10n(.calendar),
                            systemImage: "calendar",
                            badge: nil,
                            isSelected: model.selection == .calendar,
                            isCollapsed: isCollapsed
                        ) { model.selection = .calendar }
                        SidebarItem(
                            title: model.l10n(.list),
                            systemImage: "gift.fill",
                            badge: model.allRecords.count,
                            isSelected: model.selection == .list,
                            isCollapsed: isCollapsed
                        ) { model.selection = .list }

                        SidebarSectionTitle(model.l10n(.settings), isCollapsed: isCollapsed)
                        SidebarItem(
                            title: model.l10n(.permissions),
                            systemImage: "gearshape",
                            badge: nil,
                            isSelected: model.selection == .permissions,
                            isCollapsed: isCollapsed
                        ) { model.selection = .permissions }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .overlayScrollIndicators()

                if !isCollapsed, let next = model.cachedUpcomingOccurrences.first {
                    NextRosterCard(occurrence: next)
                        .padding(.horizontal, 14)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                        .transition(.opacity)
                }
            }
        }
        .animation(RosterTheme.Motion.allowed(RosterTheme.Motion.stateChange, reduceMotion: reduceMotion), value: isCollapsed)
        .animation(RosterTheme.Motion.allowed(RosterTheme.Motion.sectionReveal, reduceMotion: reduceMotion), value: isContactsExpanded)
        .animation(RosterTheme.Motion.allowed(RosterTheme.Motion.sectionReveal, reduceMotion: reduceMotion), value: collapsedContactCollectionIDs)
        .animation(RosterTheme.Motion.allowed(RosterTheme.Motion.sectionReveal, reduceMotion: reduceMotion), value: model.expandedTagIDs)
        .onChange(of: model.isShowingContactAssignmentTargets) { _, isShowing in
            guard isShowing else { return }
            withAnimation(RosterTheme.Motion.allowed(RosterTheme.Motion.sectionReveal, reduceMotion: reduceMotion)) {
                isContactsExpanded = true
                collapsedContactCollectionIDs.removeAll()
                if !model.expandedTagIDs.contains(SidebarTagRootItem.rootID) {
                    model.toggleTagExpansion(SidebarTagRootItem.rootID)
                }
            }
        }
        .popover(item: $childTagParent, arrowEdge: .trailing) { parent in
            NewTagPopover(parentTagID: parent.id) {
                childTagParent = nil
            }
        }
        .popover(item: $tagPendingRename, arrowEdge: .trailing) { tag in
            RenameTagPopover(tag: tag) {
                tagPendingRename = nil
            }
        }
        .alert(
            deleteTitle,
            isPresented: Binding(
                get: { tagPendingDeletion != nil },
                set: { if !$0 { tagPendingDeletion = nil } }
            )
        ) {
            Button(model.l10n(.deleteTag), role: .destructive) {
                if let tagPendingDeletion {
                    Task { await model.deleteTagAndDescendants(tagPendingDeletion.id) }
                }
                tagPendingDeletion = nil
            }
            Button(model.l10n(.cancel), role: .cancel) {
                tagPendingDeletion = nil
            }
        } message: {
            Text(deleteMessage)
        }
    }

    private var deleteTitle: String {
        guard let tagPendingDeletion else { return model.l10n(.deleteTagTitle) }
        return "\(model.l10n(.deleteTagTitle)) \(tagPendingDeletion.name)"
    }

    private var deleteMessage: String {
        guard let tagPendingDeletion else { return model.l10n(.deleteTagMessage) }
        let count = model.contactCount(for: .tag(tagPendingDeletion.id))
        return "\(model.l10n(.deleteTagMessage)) \(count)"
    }

    private func contactCollectionSectionTitle(_ section: ContactCollectionSectionModel) -> String {
        if section.id == "all" {
            return model.l10n(.library)
        }
        return section.title
    }

    private var sidebarChildrenTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .opacity.combined(with: .offset(y: -4))
    }
}

struct SidebarSectionTitle: View {
    let title: String
    let isCollapsed: Bool

    init(_ title: String, isCollapsed: Bool) {
        self.title = title
        self.isCollapsed = isCollapsed
    }

    var body: some View {
        Group {
            if isCollapsed {
                Color.clear
                    .frame(height: 12)
            } else {
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.top, 14)
                    .padding(.bottom, 5)
                    .transition(.opacity)
            }
        }
    }
}

struct SidebarItem: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let title: String
    let systemImage: String
    let badge: Int?
    let isSelected: Bool
    let isCollapsed: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: isCollapsed ? 0 : 9) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: isCollapsed ? 20 : 18)
                    .foregroundStyle(isSelected ? .white : .secondary)
                if !isCollapsed {
                    Text(title)
                        .font(.system(size: 13.5, weight: isSelected ? .semibold : .regular))
                        .lineLimit(1)
                        .transition(.opacity)
                    Spacer(minLength: 0)
                    if let badge {
                        SidebarBadgeText(badge, isSelected: isSelected, width: 34)
                            .transition(.opacity)
                        Color.clear
                            .frame(width: 12, height: 16)
                            .accessibilityHidden(true)
                    }
                }
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, isCollapsed ? 8 : 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: isCollapsed ? .center : .leading)
            .background(isSelected ? RosterTheme.selectedFill(colorScheme) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .animation(RosterTheme.Motion.allowed(RosterTheme.Motion.stateChange, reduceMotion: reduceMotion), value: isSelected)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .help(title)
    }
}

private struct SidebarBadgeText: View {
    let value: Int
    let isSelected: Bool
    let width: CGFloat
    let fontSize: CGFloat

    init(_ value: Int, isSelected: Bool, width: CGFloat, fontSize: CGFloat = 11) {
        self.value = value
        self.isSelected = isSelected
        self.width = width
        self.fontSize = fontSize
    }

    var body: some View {
        Text("\(value)")
            .font(.system(size: fontSize, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(isSelected ? .white.opacity(0.78) : .secondary)
            .frame(width: width, alignment: .trailing)
    }
}

private struct SidebarRootDisclosureRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let title: String
    let systemImage: String
    let badge: Int
    let isSelected: Bool
    let isCollapsed: Bool
    let isExpanded: Bool
    let selectAction: () -> Void
    let toggleAction: () -> Void

    var body: some View {
        HStack(spacing: isCollapsed ? 0 : 9) {
            Button(action: selectAction) {
                HStack(spacing: isCollapsed ? 0 : 9) {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: isCollapsed ? 20 : 18)
                        .foregroundStyle(isSelected ? .white : .secondary)
                    if !isCollapsed {
                        Text(title)
                            .font(.system(size: 13.5, weight: isSelected ? .semibold : .regular))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        SidebarBadgeText(badge, isSelected: isSelected, width: 34)
                    }
                }
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity, alignment: isCollapsed ? .center : .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !isCollapsed {
                Button {
                    withAnimation(RosterTheme.Motion.allowed(RosterTheme.Motion.sectionReveal, reduceMotion: reduceMotion)) {
                        toggleAction()
                    }
                } label: {
                    Image(systemName: reduceMotion && isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                        .frame(width: 12, height: 16)
                        .rotationEffect(.degrees(reduceMotion ? 0 : (isExpanded ? 90 : 0)))
                        .animation(RosterTheme.Motion.allowed(RosterTheme.Motion.stateChange, reduceMotion: reduceMotion), value: isExpanded)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, isCollapsed ? 8 : 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: isCollapsed ? .center : .leading)
        .background(isSelected ? RosterTheme.selectedFill(colorScheme) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        .animation(RosterTheme.Motion.allowed(RosterTheme.Motion.stateChange, reduceMotion: reduceMotion), value: isSelected)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .help(title)
    }
}

private struct SidebarContactRootItem: View {
    @Environment(RosterAppModel.self) private var model
    let isCollapsed: Bool
    @Binding var isExpanded: Bool

    var body: some View {
        SidebarRootDisclosureRow(
            title: model.l10n(.contacts),
            systemImage: "person.crop.rectangle.stack",
            badge: model.profiles.count,
            isSelected: isSelected,
            isCollapsed: isCollapsed,
            isExpanded: isExpanded,
            selectAction: { model.selectContactCollection(ContactCollectionIdentifier.all) },
            toggleAction: { isExpanded.toggle() }
        )
    }

    private var isSelected: Bool {
        model.selection == .contacts && model.selectedContactCollectionID == ContactCollectionIdentifier.all && (isCollapsed || !isExpanded)
    }
}

private struct SidebarContactCollectionSection: View {
    let section: ContactCollectionSectionModel
    let title: String
    @Binding var collapsedCollectionIDs: Set<String>

    var body: some View {
        if section.id == "all" {
            SidebarContactCollectionSectionTitle(title: title)
            ForEach(section.collections) { collection in
                SidebarContactCollectionItem(collection: collection)
            }
        } else {
            let containers = section.collections.filter { $0.kind == .container }
            let looseCollections = section.collections.filter { $0.kind != .container }
            if containers.isEmpty {
                SidebarContactCollectionSectionTitle(title: title)
                ForEach(looseCollections) { collection in
                    SidebarContactCollectionItem(collection: collection)
                }
            } else {
                ForEach(containers) { container in
                    let children = section.collections.filter { $0.parentContainerID == container.parentContainerID && $0.kind == .group }
                    SidebarContactCollectionNode(
                        collection: container,
                        children: children,
                        isExpanded: !collapsedCollectionIDs.contains(container.id),
                        toggleExpansion: { toggle(container.id) }
                    )
                }
                ForEach(looseCollections.filter { collection in
                    !containers.contains { $0.parentContainerID == collection.parentContainerID }
                }) { collection in
                    SidebarContactCollectionItem(collection: collection)
                }
            }
        }
    }

    private func toggle(_ id: String) {
        if collapsedCollectionIDs.contains(id) {
            collapsedCollectionIDs.remove(id)
        } else {
            collapsedCollectionIDs.insert(id)
        }
    }
}

private struct SidebarContactCollectionSectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.leading, 28)
            .padding(.trailing, 8)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }
}

private struct SidebarContactCollectionNode: View {
    let collection: ContactCollectionSummary
    let children: [ContactCollectionSummary]
    let isExpanded: Bool
    let toggleExpansion: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SidebarContactCollectionItem(
                collection: collection,
                depth: 0,
                hasChildren: !children.isEmpty,
                isExpanded: isExpanded,
                toggleExpansion: toggleExpansion
            )
            if isExpanded {
                ForEach(children) { child in
                    SidebarContactCollectionItem(collection: child, depth: 1)
                        .transition(.opacity.combined(with: .offset(y: -3)))
                }
            }
        }
    }
}

private struct SidebarContactCollectionItem: View {
    @Environment(RosterAppModel.self) private var model
    @State private var isShowingNewGroupPopover = false
    @State private var isConfirmingGroupDeletion = false
    let collection: ContactCollectionSummary
    var depth = 0
    var hasChildren = false
    var isExpanded = false
    var toggleExpansion: () -> Void = {}

    var body: some View {
        Group {
            if supportsGroupActions {
                row
                    .contextMenu { contextMenuContent }
                    .popover(isPresented: $isShowingNewGroupPopover, arrowEdge: .trailing) {
                        if let containerID {
                            NewContactGroupPopover(containerID: containerID) {
                                isShowingNewGroupPopover = false
                            }
                        }
                    }
                    .alert(model.l10n(.deleteContactGroup), isPresented: $isConfirmingGroupDeletion) {
                        Button(model.l10n(.deleteContactGroup), role: .destructive) {
                            if let groupID {
                                Task { await model.deleteContactGroup(groupID: groupID) }
                            }
                        }
                        Button(model.l10n(.cancel), role: .cancel) {}
                    } message: {
                        Text(model.l10n(.deleteContactGroupMessage))
                    }
            } else {
                row
            }
        }
    }

    private var row: some View {
        SidebarTagRow(
            title: collection.title,
            color: iconColor,
            systemImage: systemImage,
            badge: collection.contactCount,
            depth: depth,
            hasChildren: hasChildren,
            isExpanded: isExpanded,
            isSelected: model.selection == .contacts && model.selectedContactCollectionID == collection.id,
            accessibilityIdentifier: "contact-group-drop-\(collection.id)",
            e2eIdentifier: "contact-group-drop-\(collection.id)",
            dropAction: dropAction,
            toggleExpansion: toggleExpansion,
            action: { model.selectContactCollection(collection.id) }
        )
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        if containerID != nil {
            Button(model.l10n(.newContactGroup)) {
                isShowingNewGroupPopover = true
            }
        }
        if groupID != nil {
            Button(model.l10n(.deleteContactGroup), role: .destructive) {
                isConfirmingGroupDeletion = true
            }
        }
    }

    private var systemImage: String {
        switch collection.kind {
        case .all: "person.2.fill"
        case .container: "tray.full.fill"
        case .group: "folder.fill"
        case .ungrouped: "person.crop.circle.badge.questionmark"
        case .tag: "tag.fill"
        case .untagged: "tag.slash.fill"
        }
    }

    private var iconColor: Color {
        switch collection.kind {
        case .all: RosterTheme.accent
        case .container, .ungrouped, .untagged: RosterTheme.walnut
        case .group: RosterTheme.mustard
        case .tag: RosterTheme.blue
        }
    }

    private var dropAction: (([NSItemProvider]) -> Bool)? {
        guard collection.kind == .group, let groupID else { return nil }
        return { providers in
            model.assignDroppedContacts(from: providers, toGroupID: groupID)
        }
    }

    private var supportsGroupActions: Bool {
        containerID != nil || groupID != nil
    }

    private var containerID: String? {
        if let id = ContactCollectionIdentifier.containerID(from: collection.id) {
            return id
        }
        guard collection.kind == .group else { return nil }
        return collection.parentContainerID
    }

    private var groupID: String? {
        ContactCollectionIdentifier.groupID(from: collection.id)
    }
}

private struct NewContactGroupPopover: View {
    @Environment(RosterAppModel.self) private var model
    let containerID: String
    let onDone: () -> Void
    @State private var name = ""
    @State private var isCreating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.l10n(.newContactGroup))
                .font(.system(size: 14, weight: .semibold))

            TextField(model.l10n(.contactGroupName), text: $name)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 10) {
                Spacer(minLength: 0)
                Button(model.l10n(.cancel)) {
                    onDone()
                }
                .buttonStyle(.bordered)

                Button(model.l10n(.apply)) {
                    createGroup()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
            }
        }
        .padding(16)
        .frame(width: 260)
    }

    private func createGroup() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        isCreating = true
        Task {
            await model.createContactGroup(named: trimmedName, inContainerID: containerID)
            isCreating = false
            onDone()
        }
    }
}

private struct SidebarTagRootItem: View {
    @Environment(RosterAppModel.self) private var model
    let isCollapsed: Bool

    static let rootID = "__tags_root__"

    var body: some View {
        SidebarRootDisclosureRow(
            title: model.l10n(.tags),
            systemImage: "tag",
            badge: model.taggedContactCount,
            isSelected: isSelected,
            isCollapsed: isCollapsed,
            isExpanded: isExpanded,
            selectAction: { model.selectTagFilter(.all) },
            toggleAction: { model.toggleTagExpansion(Self.rootID) }
        )
    }

    private var isSelected: Bool {
        model.selection == .tags && model.selectedTagsFilter == .all
    }

    private var isExpanded: Bool {
        model.expandedTagIDs.contains(Self.rootID)
    }
}

private struct SidebarTagNodeItem: View {
    @Environment(RosterAppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let tag: ContactTag
    let depth: Int
    @Binding var tagPendingDeletion: ContactTag?
    @Binding var tagPendingRename: ContactTag?
    @Binding var childTagParent: ContactTag?

    var body: some View {
        let children = model.childTags(of: tag.id)
        VStack(alignment: .leading, spacing: 0) {
            SidebarTagRow(
                title: tag.name,
                color: Color(hex: tag.color),
                badge: model.contactCount(for: .tag(tag.id)),
                depth: depth,
                hasChildren: !children.isEmpty,
                isExpanded: model.expandedTagIDs.contains(tag.id),
                isSelected: model.selection == .tags && model.selectedTagsFilter == .tag(tag.id),
                accessibilityIdentifier: "contact-tag-drop-\(tag.id)",
                e2eIdentifier: "contact-tag-drop-\(tag.id)",
                dropAction: { providers in
                    model.assignDroppedContacts(from: providers, toTagID: tag.id)
                },
                toggleExpansion: { model.toggleTagExpansion(tag.id) },
                action: { model.selectTagFilter(.tag(tag.id)) }
            )
            .contextMenu {
                Button(model.l10n(.renameTag)) {
                    tagPendingRename = tag
                }
                Button(model.l10n(.changeColor)) {
                    Task { await model.cycleTagColor(tag.id) }
                }
                Button(model.l10n(.newChildTag)) {
                    childTagParent = tag
                }
                Button(model.l10n(.deleteTag), role: .destructive) {
                    tagPendingDeletion = tag
                }
            }

            if model.expandedTagIDs.contains(tag.id) {
                ForEach(children) { child in
                    SidebarTagNodeItem(
                        tag: child,
                        depth: depth + 1,
                        tagPendingDeletion: $tagPendingDeletion,
                        tagPendingRename: $tagPendingRename,
                        childTagParent: $childTagParent
                    )
                    .transition(tagChildrenTransition)
                }
            }
        }
        .animation(RosterTheme.Motion.allowed(RosterTheme.Motion.sectionReveal, reduceMotion: reduceMotion), value: model.expandedTagIDs)
    }

    private var tagChildrenTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .opacity.combined(with: .offset(y: -3))
    }
}

private struct SidebarTagSpecialItem: View {
    let title: String
    let systemImage: String
    let badge: Int
    let isSelected: Bool
    let depth: Int
    let action: () -> Void

    var body: some View {
        SidebarTagRow(
            title: title,
            color: RosterTheme.walnut,
            systemImage: systemImage,
            badge: badge,
            depth: depth,
            hasChildren: false,
            isExpanded: false,
            isSelected: isSelected,
            dropAction: nil,
            toggleExpansion: {},
            action: action
        )
    }
}

private struct SidebarTagRow: View {
    @Environment(RosterAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDropTargeted = false
    let title: String
    let color: Color
    var systemImage: String?
    let badge: Int
    let depth: Int
    let hasChildren: Bool
    let isExpanded: Bool
    let isSelected: Bool
    var accessibilityIdentifier: String? = nil
    var e2eIdentifier: String? = nil
    let dropAction: (([NSItemProvider]) -> Bool)?
    let toggleExpansion: () -> Void
    let action: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            Button(action: action) {
                HStack(spacing: 7) {
                    Image(systemName: systemImage ?? "tag.fill")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : color)
                        .frame(width: 14)

                    Text(title)
                        .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    SidebarBadgeText(badge, isSelected: isSelected, width: 30, fontSize: 10.5)
                }
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.leading, 8)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if hasChildren {
                Button {
                    withAnimation(RosterTheme.Motion.allowed(RosterTheme.Motion.sectionReveal, reduceMotion: reduceMotion)) {
                        toggleExpansion()
                    }
                } label: {
                    Image(systemName: reduceMotion && isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .frame(width: 12, height: 16)
                        .rotationEffect(.degrees(reduceMotion ? 0 : (isExpanded ? 90 : 0)))
                        .animation(RosterTheme.Motion.allowed(RosterTheme.Motion.stateChange, reduceMotion: reduceMotion), value: isExpanded)
                }
                .buttonStyle(.plain)
                .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
            } else {
                Color.clear.frame(width: 12, height: 16)
            }
        }
        .padding(.leading, CGFloat(depth) * 12 + 25)
        .padding(.trailing, 8)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(isDropTargeted ? color.opacity(0.85) : Color.clear, lineWidth: 1.1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 7))
        .optionalAccessibilityIdentifier(accessibilityIdentifier)
        .optionalE2EFrame(identifier: e2eIdentifier)
        .onDrop(of: UTType.contactAssignmentDropTypes, isTargeted: $isDropTargeted) { providers in
            guard let dropAction else { return false }
            return dropAction(providers)
        }
        .animation(RosterTheme.Motion.allowed(RosterTheme.Motion.quickFade, reduceMotion: reduceMotion), value: isDropTargeted)
        .animation(RosterTheme.Motion.allowed(RosterTheme.Motion.stateChange, reduceMotion: reduceMotion), value: isSelected)
    }

    private var rowBackground: Color {
        if isDropTargeted {
            return color.opacity(colorScheme == .dark ? 0.25 : 0.14)
        }
        if isSelected {
            return RosterTheme.selectedFill(colorScheme)
        }
        if dropAction != nil && model.isShowingContactAssignmentTargets {
            return color.opacity(colorScheme == .dark ? 0.14 : 0.08)
        }
        return Color.clear
    }
}

private struct SidebarE2EFrameReporter: ViewModifier {
    @Environment(RosterAppModel.self) private var model
    let identifier: String

    func body(content: Content) -> some View {
        content.background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { report(proxy) }
                    .onChange(of: proxy.frame(in: .global)) { _, _ in report(proxy) }
            }
        )
    }

    private func report(_ proxy: GeometryProxy) {
        guard model.isE2EEnabled,
              let window = NSApp.keyWindow ?? NSApp.windows.first
        else { return }
        let frame = proxy.frame(in: .global)
        let windowHeight = window.contentView?.bounds.height ?? 0
        let contentOrigin = window.contentRect(forFrameRect: window.frame).origin
        let screenHeight = window.screen?.frame.height ?? NSScreen.main?.frame.height ?? windowHeight
        let screenRect = CGRect(
            x: contentOrigin.x + frame.minX,
            y: screenHeight - (contentOrigin.y + windowHeight - frame.maxY) - frame.height,
            width: frame.width,
            height: frame.height
        )
        model.recordE2EFrame(identifier: identifier, screenRect: screenRect)
    }
}

private struct OverlayScrollIndicators: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { configure(from: view) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { configure(from: view) }
    }

    private func configure(from view: NSView) {
        guard let scrollView = sequence(first: view.superview, next: { $0?.superview })
            .compactMap({ $0 as? NSScrollView })
            .first
        else { return }
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
    }
}

private extension View {
    func overlayScrollIndicators() -> some View {
        background(OverlayScrollIndicators().frame(width: 0, height: 0))
    }

    @ViewBuilder
    func optionalAccessibilityIdentifier(_ identifier: String?) -> some View {
        if let identifier {
            accessibilityIdentifier(identifier)
        } else {
            self
        }
    }

    @ViewBuilder
    func optionalE2EFrame(identifier: String?) -> some View {
        if let identifier {
            modifier(SidebarE2EFrameReporter(identifier: identifier))
        } else {
            self
        }
    }
}

private struct RenameTagPopover: View {
    @Environment(RosterAppModel.self) private var model
    let tag: ContactTag
    let onDone: () -> Void
    @State private var name: String

    init(tag: ContactTag, onDone: @escaping () -> Void) {
        self.tag = tag
        self.onDone = onDone
        _name = State(initialValue: tag.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.l10n(.renameTag))
                .font(.system(size: 14, weight: .semibold))
            TextField(model.l10n(.renameTag), text: $name)
                .textFieldStyle(.roundedBorder)
            HStack(spacing: 10) {
                Spacer(minLength: 0)
                Button(model.l10n(.cancel)) {
                    onDone()
                }
                .buttonStyle(.bordered)
                Button(model.l10n(.apply)) {
                    Task { @MainActor in
                        await model.renameTag(tag.id, name: name)
                        onDone()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 260)
    }
}

struct NextRosterCard: View {
    @Environment(RosterAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    let occurrence: RosterOccurrence

    var body: some View {
        Button {
            model.focusContact(occurrence.record.contactID)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Label(model.l10n(.upcoming), systemImage: "clock")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(occurrence.record.contactName)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text(model.formatter.occurrenceDate(occurrence.date, locale: model.language.coreLocale))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .foregroundStyle(.primary)
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(model.l10n(.openContact)): \(occurrence.record.contactName)")
        .background(RosterTheme.cardBackground(colorScheme), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(RosterTheme.separator(colorScheme))
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.06), radius: 2, y: 0.5)
    }
}
