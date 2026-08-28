import RosterCore
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

    var body: some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 0) {
            SidebarSectionTitle(model.l10n(.manage), isCollapsed: isCollapsed)
            SidebarItem(
                title: model.l10n(.contacts),
                systemImage: "person.crop.rectangle.stack",
                badge: model.profiles.count,
                isSelected: model.selection == .contacts,
                isCollapsed: isCollapsed
            ) { model.selection = .contacts }

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

            Spacer(minLength: 16)

            if !isCollapsed, let next = model.cachedUpcomingOccurrences.first {
                NextRosterCard(occurrence: next)
                    .padding(.horizontal, 2)
                    .transition(.opacity)
            }
        }
        .padding(12)
        .background(RosterTheme.sidebarBackground(colorScheme))
        .animation(RosterTheme.Motion.allowed(RosterTheme.Motion.stateChange, reduceMotion: reduceMotion), value: isCollapsed)
        .animation(RosterTheme.Motion.allowed(RosterTheme.Motion.sectionReveal, reduceMotion: reduceMotion), value: model.expandedTagIDs)
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
                        Text("\(badge)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(isSelected ? .white.opacity(0.78) : .secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(isSelected ? Color.white.opacity(0.16) : Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))
                            .transition(.opacity)
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
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .help(title)
    }
}

private struct SidebarTagRootItem: View {
    @Environment(RosterAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isCollapsed: Bool

    static let rootID = "__tags_root__"

    var body: some View {
        Button {
            if isCollapsed {
                model.selectTagFilter(.all)
            } else {
                withAnimation(RosterTheme.Motion.allowed(RosterTheme.Motion.sectionReveal, reduceMotion: reduceMotion)) {
                    model.toggleTagExpansion(Self.rootID)
                }
                model.selectTagFilter(.all)
            }
        } label: {
            HStack(spacing: isCollapsed ? 0 : 9) {
                Image(systemName: "tag")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: isCollapsed ? 20 : 18)
                    .foregroundStyle(isSelected ? .white : .secondary)
                if !isCollapsed {
                    Text(model.l10n(.tags))
                        .font(.system(size: 13.5, weight: isSelected ? .semibold : .regular))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text("\(model.profiles.count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isSelected ? .white.opacity(0.78) : .secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.16) : Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))
                    Image(systemName: reduceMotion && isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                        .rotationEffect(.degrees(reduceMotion ? 0 : (isExpanded ? 90 : 0)))
                        .animation(RosterTheme.Motion.allowed(RosterTheme.Motion.stateChange, reduceMotion: reduceMotion), value: isExpanded)
                }
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, isCollapsed ? 8 : 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: isCollapsed ? .center : .leading)
            .background(isSelected ? RosterTheme.selectedFill(colorScheme) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(model.l10n(.tags))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .help(model.l10n(.tags))
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
    let dropAction: (([NSItemProvider]) -> Bool)?
    let toggleExpansion: () -> Void
    let action: () -> Void

    var body: some View {
        HStack(spacing: 5) {
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

                    Text("\(badge)")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(isSelected ? .white.opacity(0.78) : .secondary)
                }
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(rowBackground, in: RoundedRectangle(cornerRadius: 7))
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(isDropTargeted ? color.opacity(0.85) : Color.clear, lineWidth: 1.1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, CGFloat(depth) * 12 + 8)
        .padding(.trailing, 2)
        .contentShape(Rectangle())
        .onDrop(of: [UTType.rosterContactAssignmentPayload, .legacyContactAssignmentPayload], isTargeted: $isDropTargeted) { providers in
            guard let dropAction else { return false }
            return dropAction(providers)
        }
    }

    private var rowBackground: Color {
        if isDropTargeted {
            return color.opacity(colorScheme == .dark ? 0.25 : 0.14)
        }
        return isSelected ? RosterTheme.selectedFill(colorScheme) : Color.clear
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
