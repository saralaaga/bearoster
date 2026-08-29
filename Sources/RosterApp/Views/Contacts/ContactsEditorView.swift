import RosterCore
import AppKit
import SwiftUI

// MARK: - Contacts editor

struct ContactsEditorView: View {
    @Environment(RosterAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var model = model
        let selectedProfile = model.selectedProfile
        let selectedID = model.isContactSelectionMode ? nil : selectedProfile?.id

        VStack(spacing: 0) {
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    ContactListHeader(count: model.visibleContactCount)

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                            ForEach(model.contactListSections) { section in
                                Section {
                                    ForEach(section.rows) { row in
                                        ContactListRow(
                                            row: row,
                                            isSelected: selectedID == row.id,
                                            isSelectionMode: model.isContactSelectionMode,
                                            isMarkedForSelection: model.selectedContactIDs.contains(row.id)
                                        ) {
                                            model.recordE2EContactRowTap(row.id)
                                            if model.isContactSelectionMode {
                                                model.toggleContactSelection(row.id)
                                            } else {
                                                model.selectedContactID = row.id
                                            }
                                        }
                                    }
                                } header: {
                                    ContactSectionHeader(title: section.title)
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(ContactsNativeStyle.listBackground(colorScheme))
                }
                .fixedContactColumn(width: ContactsLayout.listWidth, priority: 2)

                KimiSeparator(axis: .vertical)

                ZStack {
                    ContactsNativeStyle.detailBackground(colorScheme)
                    VStack(spacing: 0) {
                        if model.isContactSelectionMode {
                            BulkContactSelectionView()
                                .transition(detailTransition)
                        } else if let profile = selectedProfile {
                            ContactRosterEditor(profile: profile)
                                .id(profile.id)
                                .transition(detailTransition)
                        } else {
                            ContentUnavailableView(model.l10n(.contacts), systemImage: "person.crop.circle")
                                .transition(detailTransition)
                        }
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(0)
                .clipped()
                .animation(RosterTheme.Motion.allowed(RosterTheme.Motion.stateChange, reduceMotion: reduceMotion), value: model.isContactSelectionMode)
                .animation(RosterTheme.Motion.allowed(RosterTheme.Motion.quickFade, reduceMotion: reduceMotion), value: selectedID)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(ContactsNativeStyle.windowBackground(colorScheme))
    }

    private var detailTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .opacity.combined(with: .offset(y: 4))
    }

}

private enum ContactsLayout {
    static let listWidth: CGFloat = 300
}

// MARK: - Toolbar

struct ContactsToolbar: View {
    @Environment(RosterAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isConfirmingDeletion = false
    @State private var isShowingBulkTagPopover = false

    var body: some View {
        @Bindable var model = model

        HStack(spacing: 12) {
            Text(model.l10n(.contacts))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 12)

            ZStack(alignment: .trailing) {
                if model.isContactSelectionMode {
                    selectionControls
                        .transition(toolbarModeTransition)
                } else {
                    normalControls
                        .transition(toolbarModeTransition)
                }
            }
            .animation(RosterTheme.Motion.allowed(RosterTheme.Motion.quickFade, reduceMotion: reduceMotion), value: model.isContactSelectionMode)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert(model.l10n(.deleteContactsTitle), isPresented: $isConfirmingDeletion) {
            Button(model.l10n(.deleteContacts), role: .destructive) {
                Task { await model.deleteSelectedContacts() }
            }
            Button(model.l10n(.cancel), role: .cancel) { }
        } message: {
            Text(model.l10n(.deleteContactsMessage))
        }
    }

    private var normalControls: some View {
        @Bindable var model = model

        return HStack(spacing: 12) {
            Button(model.l10n(.selectContacts)) {
                model.enterContactSelectionMode()
            }
            .font(.system(size: 12.5, weight: .medium))
            .buttonStyle(.bordered)

            ContactFiltersButton()

            SearchField(text: $model.contactSearchText, prompt: model.l10n(.search))
            .frame(width: 240)

            refreshButton
        }
    }

    private var selectionControls: some View {
        @Bindable var model = model

        return HStack(spacing: 10) {
            Text("\(model.l10n(.selectedContacts)) \(model.selectedContactSelectionCount)")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(RosterTheme.Motion.allowed(RosterTheme.Motion.quickFade, reduceMotion: reduceMotion), value: model.selectedContactSelectionCount)

            Button {
                isShowingBulkTagPopover = true
            } label: {
                Label(model.l10n(.tags), systemImage: "tag")
            }
            .font(.system(size: 12.5, weight: .semibold))
            .buttonStyle(.bordered)
            .disabled(model.selectedContactSelectionCount == 0 || model.isDeletingContacts)
            .popover(isPresented: $isShowingBulkTagPopover, arrowEdge: .bottom) {
                ContactTagPickerPopover(contactIDs: model.selectedContactIDs) {
                    isShowingBulkTagPopover = false
                }
            }

            Button(role: .destructive) {
                isConfirmingDeletion = true
            } label: {
                Label(model.l10n(.deleteContacts), systemImage: "trash")
            }
            .font(.system(size: 12.5, weight: .semibold))
            .buttonStyle(.bordered)
            .disabled(model.selectedContactSelectionCount == 0 || model.isDeletingContacts)

            Button(model.l10n(.cancel)) {
                model.exitContactSelectionMode()
            }
            .font(.system(size: 12.5, weight: .medium))
            .buttonStyle(.bordered)
            .disabled(model.isDeletingContacts)
        }
    }

    private var toolbarModeTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .opacity.combined(with: .offset(y: 3))
    }

    private var refreshButton: some View {
        Button {
            Task { await model.refreshContacts() }
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 15, height: 15)
                .rotationEffect(.degrees(model.isLoading && !reduceMotion ? 360 : 0))
                .animation(
                    model.isLoading && !reduceMotion
                        ? .linear(duration: 1).repeatForever(autoreverses: false)
                        : nil,
                    value: model.isLoading
                )
        }
        .help(model.l10n(.refreshContacts))
        .accessibilityLabel(model.l10n(.refreshContacts))
        .buttonStyle(.plain)
        .disabled(model.isLoading)
        .opacity(model.isLoading ? 0.5 : 1.0)
        .kimiToolbarButton()
    }
}

struct ContactFiltersButton: View {
    @Environment(RosterAppModel.self) private var model
    @State private var isShowingPopover = false

    var body: some View {
        Button {
            isShowingPopover.toggle()
        } label: {
            Label(label, systemImage: model.contactFilters.isEmpty ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
        }
        .font(.system(size: 12.5, weight: .medium))
        .buttonStyle(.bordered)
        .popover(isPresented: $isShowingPopover, arrowEdge: .bottom) {
            ContactFiltersPopover()
        }
        .accessibilityLabel(label)
    }

    private var label: String {
        if model.contactFilters.isEmpty { return model.l10n(.filterContacts) }
        return "\(model.l10n(.filterContacts)) \(model.contactFilters.count)"
    }
}

private struct ContactFiltersPopover: View {
    @Environment(RosterAppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(model.l10n(.filterContacts))
                    .font(.system(size: 14, weight: .semibold))
                Spacer(minLength: 0)
                Button(model.l10n(.clearFilters)) {
                    model.clearContactFilters()
                }
                .buttonStyle(.plain)
                .foregroundStyle(RosterTheme.accent)
                .disabled(model.contactFilters.isEmpty)
            }

            Picker("", selection: $model.contactFilterMatchMode) {
                Text(model.l10n(.matchAllConditions)).tag(ContactFilterMatchMode.all)
                Text(model.l10n(.matchAnyCondition)).tag(ContactFilterMatchMode.any)
            }
            .pickerStyle(.segmented)
            .disabled(model.contactFilters.count < 2)

            if model.contactFilters.isEmpty {
                Text(model.l10n(.addCondition))
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(model.contactFilters) { filter in
                        ContactFilterConditionRow(filter: filter)
                    }
                }
            }

            Menu {
                Button(model.l10n(.birthdayStatus)) {
                    model.addContactFilter(.birthday(.missingBirthday))
                }
                .disabled(hasFilter(.birthday(.missingBirthday)))

                Button(model.l10n(.missingField)) {
                    model.addContactFilter(.missingField(.email))
                }
                .disabled(hasFilter(.missingField(.email)))
            } label: {
                Label(model.l10n(.addCondition), systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .menuStyle(.borderlessButton)
            .buttonStyle(.bordered)
        }
        .padding(14)
        .frame(width: 320)
    }

    private func hasFilter(_ filter: ContactFilterCondition) -> Bool {
        model.contactFilters.contains { $0.id == filter.id }
    }
}

private struct ContactFilterConditionRow: View {
    @Environment(RosterAppModel.self) private var model
    let filter: ContactFilterCondition

    var body: some View {
        HStack(spacing: 8) {
            Text(kindTitle)
                .font(.system(size: 12.5, weight: .medium))
                .lineLimit(1)
                .frame(width: 78, alignment: .leading)

            valuePicker

            Spacer(minLength: 0)

            Button {
                model.removeContactFilter(filter)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(model.l10n(.clearFilters))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
    }

    @ViewBuilder
    private var valuePicker: some View {
        switch filter {
        case let .birthday(value):
            Picker("", selection: birthdayBinding(value)) {
                ForEach(ContactBirthdayFilter.allCases) { option in
                    Text(birthdayTitle(option)).tag(option)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        case let .missingField(value):
            Picker("", selection: missingFieldBinding(value)) {
                ForEach(ContactMissingField.allCases) { option in
                    Text(missingFieldTitle(option)).tag(option)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
    }

    private var kindTitle: String {
        switch filter {
        case .birthday: model.l10n(.birthdayStatus)
        case .missingField: model.l10n(.missingField)
        }
    }

    private func birthdayBinding(_ value: ContactBirthdayFilter) -> Binding<ContactBirthdayFilter> {
        Binding(
            get: { value },
            set: { model.updateContactFilter(.birthday($0)) }
        )
    }

    private func missingFieldBinding(_ value: ContactMissingField) -> Binding<ContactMissingField> {
        Binding(
            get: { value },
            set: { model.updateContactFilter(.missingField($0)) }
        )
    }

    private func birthdayTitle(_ value: ContactBirthdayFilter) -> String {
        switch value {
        case .hasBirthday: model.l10n(.hasBirthday)
        case .missingBirthday: model.l10n(.missingBirthday)
        case .upcomingBirthday: model.l10n(.upcomingBirthday)
        }
    }

    private func missingFieldTitle(_ value: ContactMissingField) -> String {
        switch value {
        case .phone: model.l10n(.missingPhone)
        case .email: model.l10n(.missingEmail)
        case .organization: model.l10n(.missingOrganization)
        }
    }
}

// MARK: - Contact list

struct ContactListHeader: View {
    @Environment(RosterAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(model.l10n(.contacts))
                .font(.system(size: 20, weight: .bold))
            Text(contactCountText(count, locale: model.language.coreLocale))
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) {
            ContactsNativeStyle.separator(colorScheme)
                .frame(height: 0.5)
        }
    }
}

struct ContactSectionHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ContactsNativeStyle.listBackground(colorScheme).opacity(0.96))
    }
}

struct ContactListRow: View {
    @Environment(RosterAppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let row: ContactListRowModel
    let isSelected: Bool
    let isSelectionMode: Bool
    let isMarkedForSelection: Bool
    let action: () -> Void

    var body: some View {
        let rowIsSelected = isSelectionMode ? isMarkedForSelection : isSelected

        HStack(spacing: 10) {
            AvatarView(
                name: row.displayName,
                color: row.kind.map(color(for:)) ?? Color(hex: 0x8E8E93),
                size: 34
            )
            .overlay(alignment: .bottomTrailing) {
                if isSelectionMode {
                    ContactSelectionMark(isSelected: isMarkedForSelection)
                        .offset(x: 3, y: 3)
                        .transition(selectionMarkTransition)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(row.displayName)
                        .font(.system(size: 13.5, weight: .medium))
                        .lineLimit(1)
                    ContactTagSummary(tags: row.tags, limit: 2, isCompact: true)
                }

                HStack(spacing: 5) {
                    if let kind = row.kind, let kindTitle = row.kindTitle {
                        StaticKindBadge(kind: kind, title: kindTitle)
                    }
                    Text(row.subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(rowIsSelected ? .white.opacity(0.75) : .secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if let text = row.daysUntilText, let days = row.daysUntil {
                Text(text)
                    .font(.system(size: 11, weight: days <= 7 ? .semibold : .regular))
                    .foregroundStyle(days <= 7 ? ContactsNativeStyle.red : (rowIsSelected ? .white.opacity(0.75) : Color.secondary.opacity(0.75)))
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .foregroundStyle(rowIsSelected ? .white : .primary)
        .background(rowIsSelected ? ContactsNativeStyle.accent : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            action()
        }
        .onDrag {
            model.beginContactDrag()
            return model.dragItemProvider(for: row.id)
        } preview: {
            ContactDragPreview(row: row, count: model.draggedContactIDs(for: row.id).count)
        }
        .accessibilityLabel(row.displayName)
        .accessibilityIdentifier("contact-row-\(row.id)")
        .e2eFrame(identifier: "contact-row-\(row.id)")
        .accessibilityAddTraits(rowIsSelected ? .isSelected : [])
        .accessibilityAction {
            action()
        }
        .animation(RosterTheme.Motion.allowed(RosterTheme.Motion.quickFade, reduceMotion: reduceMotion), value: isSelectionMode)
        .animation(RosterTheme.Motion.allowed(RosterTheme.Motion.press, reduceMotion: reduceMotion), value: isMarkedForSelection)
    }

    private var selectionMarkTransition: AnyTransition {
        if reduceMotion {
            .opacity
        } else {
            .scale(scale: 0.92).combined(with: .opacity)
        }
    }
}

private struct E2EFrameReporter: ViewModifier {
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
        else {
            return
        }
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

private extension View {
    func e2eFrame(identifier: String) -> some View {
        modifier(E2EFrameReporter(identifier: identifier))
    }
}

private struct ContactDragPreview: View {
    let row: ContactListRowModel
    let count: Int

    var body: some View {
        HStack(spacing: 9) {
            AvatarView(
                name: row.displayName,
                color: row.kind.map(color(for:)) ?? Color(hex: 0x8E8E93),
                size: 30
            )
            Text(row.displayName)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            if count > 1 {
                Text("\(count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(ContactsNativeStyle.accent, in: Capsule())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ContactSelectionMark: View {
    let isSelected: Bool

    var body: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 15, weight: .semibold))
            .symbolRenderingMode(.palette)
            .foregroundStyle(isSelected ? ContactsNativeStyle.accent : Color.secondary.opacity(0.75), Color.white)
            .background(Color.white, in: Circle())
            .shadow(color: .black.opacity(0.10), radius: 1, y: 0.5)
            .accessibilityHidden(true)
    }
}

// MARK: - Detail

struct BulkContactSelectionView: View {
    @Environment(RosterAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    @State private var isConfirmingDeletion = false
    @State private var draft = ContactBatchEditDraft()
    @State private var fillPolicy: ContactBatchFillPolicy = .onlyEmpty

    var body: some View {
        let selectedProfiles = model.selectedEditableProfiles
        let selectionKey = model.selectedContactIDs.sorted().joined(separator: ",")

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                selectionCard(selectedProfiles: selectedProfiles)
                dangerCard
                renameCard(selectedProfiles: selectedProfiles)
                commonFieldsCard(selectedProfiles: selectedProfiles)
                previewCard(selectedProfiles: selectedProfiles)
            }
            .padding(24)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(ContactsNativeStyle.detailBackground(colorScheme))
        .task(id: selectionKey) {
            syncDraft(from: selectedProfiles)
        }
        .alert(model.l10n(.deleteContactsTitle), isPresented: $isConfirmingDeletion) {
            Button(model.l10n(.deleteContacts), role: .destructive) {
                Task { await model.deleteSelectedContacts() }
            }
            Button(model.l10n(.cancel), role: .cancel) { }
        } message: {
            Text(model.l10n(.deleteContactsMessage))
        }
    }

    private func selectionCard(selectedProfiles: [ContactRosterProfile]) -> some View {
        NativeInfoCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checklist")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(ContactsNativeStyle.accent)
                        .frame(width: 34, height: 34)
                        .background(ContactsNativeStyle.accent.opacity(0.10), in: Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.l10n(.selectedContacts))
                            .font(.system(size: 13, weight: .semibold))
                        Text("\(model.selectedContactSelectionCount)")
                            .font(.system(size: 24, weight: .bold))
                            .monospacedDigit()
                    }

                    Spacer(minLength: 0)

                    Button(model.l10n(.cancel)) {
                        model.exitContactSelectionMode()
                    }
                    .buttonStyle(KimiActionButtonStyle(kind: .regular))
                }

                if !selectedProfiles.isEmpty {
                    FlowChipWrap(items: selectedProfiles.prefix(6).map { $0.displayName }) { name in
                        Text(name)
                            .font(.system(size: 11.5, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.10), in: Capsule())
                    }
                }

                Text("可批量整理这些联系人")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(18)
        }
    }

    private var dangerCard: some View {
        NativeInfoCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(model.l10n(.deleteContactsTitle))
                    .font(.system(size: 13, weight: .bold))

                HStack(spacing: 10) {
                    Text(model.l10n(.deleteContactsMessage))
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button(role: .destructive) {
                        isConfirmingDeletion = true
                    } label: {
                        Label(model.l10n(.deleteContacts), systemImage: "trash")
                    }
                    .buttonStyle(KimiActionButtonStyle(kind: .regular))
                    .disabled(model.selectedContactSelectionCount == 0 || model.isDeletingContacts)
                }
            }
            .padding(18)
        }
    }

    private func renameCard(selectedProfiles: [ContactRosterProfile]) -> some View {
        NativeInfoCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("批量重命名")
                    .font(.system(size: 13, weight: .bold))

                Picker("重命名方式", selection: $draft.renameMode) {
                    Text("替换").tag(ContactBatchRenameMode.replace)
                    Text("前缀").tag(ContactBatchRenameMode.prefix)
                    Text("后缀").tag(ContactBatchRenameMode.suffix)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)

                switch draft.renameMode {
                case .replace:
                    HStack(spacing: 10) {
                        BatchField(title: "查找", text: $draft.renameFind, placeholder: "原文本")
                        BatchField(title: "替换为", text: $draft.renameReplacement, placeholder: "新文本")
                    }
                case .prefix:
                    BatchField(title: "前缀", text: $draft.renamePrefix, placeholder: "例如：VIP - ")
                case .suffix:
                    BatchField(title: "后缀", text: $draft.renameSuffix, placeholder: "例如： (客户)")
                }

                Text("会先显示预览，再决定是仅补空还是覆盖已有值。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(18)
        }
    }

    private func commonFieldsCard(selectedProfiles: [ContactRosterProfile]) -> some View {
        NativeInfoCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("共同字段")
                        .font(.system(size: 13, weight: .bold))
                    Spacer(minLength: 0)
                    Picker("写入策略", selection: $fillPolicy) {
                        Text("仅补空").tag(ContactBatchFillPolicy.onlyEmpty)
                        Text("覆盖已有值").tag(ContactBatchFillPolicy.overwriteExisting)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 240)
                }

                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        BatchField(title: model.l10n(.name), text: $draft.givenName, placeholder: commonTextPlaceholder(selectedProfiles, value: \.givenName))
                        BatchField(title: "姓", text: $draft.familyName, placeholder: commonTextPlaceholder(selectedProfiles, value: \.familyName))
                        BatchField(title: "昵称", text: $draft.nickname, placeholder: commonTextPlaceholder(selectedProfiles, value: \.nickname))
                    }

                    HStack(spacing: 10) {
                        BatchField(title: model.l10n(.work), text: $draft.organizationName, placeholder: commonTextPlaceholder(selectedProfiles, value: \.organizationName))
                        BatchField(title: "部门", text: $draft.departmentName, placeholder: commonTextPlaceholder(selectedProfiles, value: \.departmentName))
                        BatchField(title: "职位", text: $draft.jobTitle, placeholder: commonTextPlaceholder(selectedProfiles, value: \.jobTitle))
                    }

                    BatchMultilineField(title: model.l10n(.phone), text: $draft.phoneNumbers, placeholder: commonListPlaceholder(selectedProfiles, value: \.phoneNumbers))
                    BatchMultilineField(title: model.l10n(.email), text: $draft.emailAddresses, placeholder: commonListPlaceholder(selectedProfiles, value: \.emailAddresses))
                    BatchMultilineField(title: model.l10n(.address), text: $draft.postalAddresses, placeholder: commonListPlaceholder(selectedProfiles, value: \.postalAddresses))
                }
            }
            .padding(18)
        }
    }

    private func previewCard(selectedProfiles: [ContactRosterProfile]) -> some View {
        NativeInfoCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("预览")
                    .font(.system(size: 13, weight: .bold))

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(previewLines(for: selectedProfiles), id: \.self) { line in
                        Text(line)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                    }
                }

                HStack {
                    Button(model.l10n(.apply)) {
                        Task {
                            await model.applyBatchContactEdits(draft, fillPolicy: fillPolicy, contactIDs: model.selectedContactIDs)
                        }
                    }
                    .buttonStyle(KimiActionButtonStyle(kind: .primary))
                    .disabled(model.selectedContactSelectionCount == 0 || model.isDeletingContacts)

                    Spacer(minLength: 0)
                }
            }
            .padding(18)
        }
    }

    private func syncDraft(from selectedProfiles: [ContactRosterProfile]) {
        draft = ContactBatchEditDraft(
            renameMode: .replace,
            renameFind: "",
            renameReplacement: "",
            renamePrefix: "",
            renameSuffix: "",
            givenName: commonTextValue(selectedProfiles, value: \.givenName),
            familyName: commonTextValue(selectedProfiles, value: \.familyName),
            nickname: commonTextValue(selectedProfiles, value: \.nickname),
            organizationName: commonTextValue(selectedProfiles, value: \.organizationName),
            departmentName: commonTextValue(selectedProfiles, value: \.departmentName),
            jobTitle: commonTextValue(selectedProfiles, value: \.jobTitle),
            phoneNumbers: commonListValue(selectedProfiles, value: \.phoneNumbers),
            emailAddresses: commonListValue(selectedProfiles, value: \.emailAddresses),
            postalAddresses: commonListValue(selectedProfiles, value: \.postalAddresses)
        )
    }

    private func previewLines(for selectedProfiles: [ContactRosterProfile]) -> [String] {
        let count = selectedProfiles.count
        guard count > 0 else { return ["未选择联系人"] }

        var lines: [String] = []
        let renameValue = previewRenameSummary()
        if !renameValue.isEmpty {
            lines.append(renameValue)
        }

        appendPreview(&lines, title: "姓名", value: draft.givenName, selectedProfiles: selectedProfiles, keyPath: \.givenName)
        appendPreview(&lines, title: "姓", value: draft.familyName, selectedProfiles: selectedProfiles, keyPath: \.familyName)
        appendPreview(&lines, title: "昵称", value: draft.nickname, selectedProfiles: selectedProfiles, keyPath: \.nickname)
        appendPreview(&lines, title: "公司", value: draft.organizationName, selectedProfiles: selectedProfiles, keyPath: \.organizationName)
        appendPreview(&lines, title: "部门", value: draft.departmentName, selectedProfiles: selectedProfiles, keyPath: \.departmentName)
        appendPreview(&lines, title: "职位", value: draft.jobTitle, selectedProfiles: selectedProfiles, keyPath: \.jobTitle)
        appendPreviewList(&lines, title: "电话", value: draft.phoneNumbers, selectedProfiles: selectedProfiles, keyPath: \.phoneNumbers)
        appendPreviewList(&lines, title: "邮箱", value: draft.emailAddresses, selectedProfiles: selectedProfiles, keyPath: \.emailAddresses)
        appendPreviewList(&lines, title: "地址", value: draft.postalAddresses, selectedProfiles: selectedProfiles, keyPath: \.postalAddresses)

        if lines.isEmpty {
            lines.append("未填写批量改动。")
        }
        return lines
    }

    private func previewRenameSummary() -> String {
        switch draft.renameMode {
        case .replace:
            let needle = draft.renameFind.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !needle.isEmpty else { return "" }
            let count = previewCount { $0.displayName.contains(needle) || $0.nickname.contains(needle) }
            return "替换「\(needle)」会影响 \(count) 人"
        case .prefix:
            let prefix = draft.renamePrefix.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !prefix.isEmpty else { return "" }
            return "前缀「\(prefix)」会影响 \(model.selectedContactSelectionCount) 人"
        case .suffix:
            let suffix = draft.renameSuffix.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !suffix.isEmpty else { return "" }
            return "后缀「\(suffix)」会影响 \(model.selectedContactSelectionCount) 人"
        }
    }

    private func appendPreview(
        _ lines: inout [String],
        title: String,
        value: String,
        selectedProfiles: [ContactRosterProfile],
        keyPath: KeyPath<ContactRosterProfile, String>
    ) {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let count = previewCount(selectedProfiles, keyPath: keyPath)
        guard count > 0 else { return }
        lines.append("\(title)：将\(fillPolicy == .onlyEmpty ? "补充" : "覆盖") \(count) 人")
    }

    private func appendPreviewList(
        _ lines: inout [String],
        title: String,
        value: String,
        selectedProfiles: [ContactRosterProfile],
        keyPath: KeyPath<ContactRosterProfile, [String]>
    ) {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let count = previewCount(selectedProfiles, keyPath: keyPath)
        guard count > 0 else { return }
        lines.append("\(title)：将\(fillPolicy == .onlyEmpty ? "补充" : "覆盖") \(count) 人")
    }

    private func previewCount(
        where predicate: (ContactRosterProfile) -> Bool
    ) -> Int {
        model.selectedEditableProfiles.filter(predicate).count
    }

    private func previewCount(
        _ selectedProfiles: [ContactRosterProfile],
        keyPath: KeyPath<ContactRosterProfile, String>
    ) -> Int {
        selectedProfiles.filter {
            if fillPolicy == .overwriteExisting { return true }
            return $0[keyPath: keyPath].isEmpty
        }.count
    }

    private func previewCount(
        _ selectedProfiles: [ContactRosterProfile],
        keyPath: KeyPath<ContactRosterProfile, [String]>
    ) -> Int {
        selectedProfiles.filter {
            if fillPolicy == .overwriteExisting { return true }
            return $0[keyPath: keyPath].isEmpty
        }.count
    }

    private func commonTextValue(
        _ selectedProfiles: [ContactRosterProfile],
        value: KeyPath<ContactRosterProfile, String>
    ) -> String {
        let values = selectedProfiles.map { $0[keyPath: value].trimmingCharacters(in: .whitespacesAndNewlines) }
        guard let first = values.first, values.allSatisfy({ $0 == first }) else { return "" }
        return first
    }

    private func commonListValue(
        _ selectedProfiles: [ContactRosterProfile],
        value: KeyPath<ContactRosterProfile, [String]>
    ) -> String {
        let values = selectedProfiles.map { $0[keyPath: value].joined(separator: "\n") }
        guard let first = values.first, values.allSatisfy({ $0 == first }) else { return "" }
        return first
    }

    private func commonTextPlaceholder(
        _ selectedProfiles: [ContactRosterProfile],
        value: KeyPath<ContactRosterProfile, String>
    ) -> String {
        commonTextValue(selectedProfiles, value: value).isEmpty ? "混合值" : commonTextValue(selectedProfiles, value: value)
    }

    private func commonListPlaceholder(
        _ selectedProfiles: [ContactRosterProfile],
        value: KeyPath<ContactRosterProfile, [String]>
    ) -> String {
        commonListValue(selectedProfiles, value: value).isEmpty ? "每行一个" : commonListValue(selectedProfiles, value: value)
    }
}

private struct BatchField: View {
    let title: String
    @Binding var text: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct BatchMultilineField: View {
    let title: String
    @Binding var text: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.secondary)
            TextEditor(text: $text)
                .font(.system(size: 12.5, weight: .medium))
                .frame(minHeight: 74)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .topLeading) {
                    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(placeholder)
                            .font(.system(size: 12.5))
                            .foregroundStyle(.secondary.opacity(0.7))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 15)
                            .allowsHitTesting(false)
                    }
                }
        }
    }
}

private struct FlowChipWrap<Content: View>: View {
    let items: [String]
    let content: (String) -> Content

    init(items: [String], @ViewBuilder content: @escaping (String) -> Content) {
        self.items = items
        self.content = content
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(Array(items), id: \.self) { item in
                content(item)
            }
        }
    }
}

struct ContactRosterEditor: View {
    @Environment(RosterAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let profile: ContactRosterProfile
    @State private var draft: RosterEditDraft
    @State private var isEditing = false
    @State private var isSaving = false
    @State private var isShowingTagEditor = false

    init(profile: ContactRosterProfile) {
        self.profile = profile
        _draft = State(initialValue: RosterEditDraft(profile: profile))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                hero
                countdownBanner

                editableCards

                actionBar
            }
            .padding(.horizontal, 32)
            .padding(.top, 34)
            .padding(.bottom, 60)
            .frame(maxWidth: 624)
            .frame(maxWidth: .infinity, alignment: isEditing ? .leading : .center)
        }
        .background(ContactsNativeStyle.detailBackground(colorScheme))
    }

    @ViewBuilder
    private var editableCards: some View {
        Group {
            if isEditing {
                editCards
            } else {
                readCards
            }
        }
        .transition(editableCardsTransition)
        .animation(RosterTheme.Motion.allowed(RosterTheme.Motion.quickFade, reduceMotion: reduceMotion), value: isEditing)
    }

    private var editableCardsTransition: AnyTransition {
        if reduceMotion {
            .opacity
        } else {
            .asymmetric(
                insertion: .scale(scale: 0.985, anchor: .top).combined(with: .opacity),
                removal: .opacity
            )
        }
    }

    private var hero: some View {
        VStack(spacing: 10) {
            Button {
                chooseAndQueueAvatarImage()
            } label: {
                ContactAvatarImageView(name: profile.displayName, imageData: profile.imageData, color: heroColor, size: 96)
            }
            .buttonStyle(.plain)
            .help(model.l10n(.chooseImage))
            .accessibilityLabel(model.l10n(.chooseImage))

            VStack(spacing: 3) {
                Text(isEditing ? model.l10n(.editContact) : profile.displayName)
                    .font(.system(size: 24, weight: .bold))
                    .multilineTextAlignment(.center)
                if !isEditing {
                    Text(detailTagline)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            if !isEditing {
                ContactQuickActionBar(profile: profile)
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .draggable(model.dragPayload(for: profile.id))
    }

    @ViewBuilder
    private var countdownBanner: some View {
        if let occurrence = nextOccurrence {
            let days = model.resolver.daysUntil(occurrence.date)
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    if days == 0 {
                        Text(model.l10n(.today))
                            .font(.system(size: 24, weight: .bold))
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text("\(days)")
                                .font(.system(size: 24, weight: .bold))
                                .monospacedDigit()
                            Text(daysSuffix)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(days == 0 ? .white.opacity(0.82) : .secondary)
                        }
                    }

                    Text(countdownSubtitle(for: occurrence))
                        .font(.system(size: 12))
                        .foregroundStyle(days == 0 ? .white.opacity(0.82) : .secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "birthday.cake")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(days == 0 ? .white.opacity(0.76) : .secondary.opacity(0.72))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .foregroundStyle(days == 0 ? .white : .primary)
            .background(days == 0 ? ContactsNativeStyle.red : ContactsNativeStyle.cardBackground(colorScheme), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(days == 0 ? Color.clear : ContactsNativeStyle.separator(colorScheme))
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.06), radius: 2, y: 0.5)
        }
    }

    private var readCards: some View {
        VStack(spacing: 18) {
            NativeInfoCard {
                if profile.records.isEmpty {
                    Text(model.l10n(.noRosters))
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                } else {
                    ForEach(Array(profile.records.enumerated()), id: \.element.id) { index, record in
                        if index > 0 {
                            NativeDivider()
                        }
                        RosterRecordSummaryRow(record: record)
                    }
                }

                NativeDivider()
                tagInfoRow
            }

            if model.extendedContactFieldsEnabled,
               let extended = model.extendedProfilesByID[profile.id],
               extended.hasVisibleFields {
                ExtendedContactDetailsView(extended: extended)
            }
        }
    }

    private var editCards: some View {
        VStack(spacing: 18) {
            NativeInfoCard {
                tagInfoRow
            }

            NativeInfoCard {
                contactNameRows
            }

            NativeInfoCard {
                contactWorkRows
            }

            NativeInfoCard {
                if draft.entries.isEmpty {
                    NativeInfoRow(label: model.l10n(.birthDate)) {
                        Text(model.l10n(.noRosters))
                            .foregroundStyle(.tertiary)
                    }
                } else {
                    ForEach(Array($draft.entries.enumerated()), id: \.element.id) { index, $entry in
                        if index > 0 {
                            NativeDivider()
                        }
                        RosterEditEntryView(entry: $entry, profile: profile) {
                            draft.removeEntry(id: entry.id)
                        }
                    }
                }

                if !draft.entries.isEmpty {
                    NativeDivider()
                }
                NativeInfoRow(label: "") {
                    Button {
                        draft.addEntry(personID: profile.id, kind: .gregorian)
                    } label: {
                        Label(model.l10n(.addRoster), systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(KimiActionButtonStyle(kind: .regular))
                }
            }

            NativeInfoCard {
                contactMethodRows
            }

            if model.extendedContactFieldsEnabled,
               let extended = model.extendedProfilesByID[profile.id],
               extended.hasVisibleFields {
                ExtendedContactDetailsView(extended: extended, includesEditableFields: false)
                Text(model.l10n(.readOnlyExtendedFields))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 3)
            }
        }
    }

    @ViewBuilder
    private var contactNameRows: some View {
        NativeInfoRow(label: model.l10n(.avatar)) {
            HStack(spacing: 10) {
                Button {
                    chooseAvatarImage()
                } label: {
                    ContactAvatarImageView(name: draft.displayNamePreview, imageData: draft.imageData, color: heroColor, size: 36)
                }
                .buttonStyle(.plain)
                .help(model.l10n(.chooseImage))
                .accessibilityLabel(model.l10n(.chooseImage))

                Spacer(minLength: 0)
            }
        }

        NativeDivider()

        NativeInfoRow(label: model.l10n(.familyName)) {
            NativeContactTextField(text: $draft.familyName, placeholder: model.l10n(.familyName))
        }

        NativeDivider()

        NativeInfoRow(label: model.l10n(.givenName)) {
            NativeContactTextField(text: $draft.givenName, placeholder: model.l10n(.givenName))
        }

        NativeDivider()

        NativeInfoRow(label: model.l10n(.nickname)) {
            NativeContactTextField(text: $draft.nickname, placeholder: model.l10n(.nickname))
        }
    }

    @ViewBuilder
    private var contactWorkRows: some View {
        NativeInfoRow(label: model.l10n(.organization)) {
            NativeContactTextField(text: $draft.organizationName, placeholder: model.l10n(.organization))
        }

        NativeDivider()

        NativeInfoRow(label: model.l10n(.department)) {
            NativeContactTextField(text: $draft.departmentName, placeholder: model.l10n(.department))
        }

        NativeDivider()

        NativeInfoRow(label: model.l10n(.jobTitle)) {
            NativeContactTextField(text: $draft.jobTitle, placeholder: model.l10n(.jobTitle))
        }
    }

    @ViewBuilder
    private var contactMethodRows: some View {
        NativeInfoRow(label: model.l10n(.phone)) {
            NativeContactMultilineField(text: $draft.phoneNumbersText, placeholder: model.l10n(.onePerLine))
        }

        NativeDivider()

        NativeInfoRow(label: model.l10n(.email)) {
            NativeContactMultilineField(text: $draft.emailAddressesText, placeholder: model.l10n(.onePerLine))
        }

        NativeDivider()

        NativeInfoRow(label: model.l10n(.address)) {
            NativeContactMultilineField(text: $draft.postalAddressesText, placeholder: model.l10n(.onePerLine))
        }
    }

    private var tagInfoRow: some View {
        NativeInfoRow(label: model.l10n(.tags)) {
            HStack(spacing: 8) {
                let tags = model.tags(for: profile.id)
                if tags.isEmpty {
                    Text(model.l10n(.noTags))
                        .foregroundStyle(.tertiary)
                } else {
                    ContactTagSummary(tags: tags, limit: 4)
                }
                Spacer(minLength: 0)
                Button {
                    isShowingTagEditor = true
                } label: {
                    Image(systemName: "tag")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .help(model.l10n(.editTags))
                .accessibilityLabel(model.l10n(.editTags))
                .popover(isPresented: $isShowingTagEditor, arrowEdge: .trailing) {
                    ContactTagPickerPopover(
                        contactIDs: [profile.id],
                        initialTagIDs: model.contactTagAssignmentsByContactID[profile.id] ?? [],
                        replacesExistingTags: true
                    ) {
                        isShowingTagEditor = false
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            if isEditing {
                Button {
                    saveDraft()
                } label: {
                    if isSaving {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 42)
                    } else {
                        Text(model.l10n(.done))
                    }
                }
                .buttonStyle(KimiActionButtonStyle(kind: .primary))
                .disabled(draft.payload(personID: profile.id) == nil || isSaving)

                Button {
                    draft = RosterEditDraft(profile: profile)
                    isEditing = false
                } label: {
                    Text(model.l10n(.cancel))
                }
                .buttonStyle(KimiActionButtonStyle(kind: .regular))
                .disabled(isSaving)
            } else {
                Button {
                    draft = RosterEditDraft(profile: profile)
                    isEditing = true
                } label: {
                    Text(model.l10n(.edit))
                }
                .buttonStyle(KimiActionButtonStyle(kind: .primary))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
    }

    private var nextOccurrence: RosterOccurrence? {
        profile.records
            .compactMap { model.resolver.nextOccurrence(for: $0, after: Date()) }
            .sorted { lhs, rhs in
                if lhs.date != rhs.date {
                    return lhs.date < rhs.date
                }
                return lhs.record.kind.rawValue < rhs.record.kind.rawValue
            }
            .first
    }

    private var groupText: String {
        let groupIDs = model.contactGrouping.groupIDsByContactID[profile.id] ?? []
        let titles = model.contactGrouping.groups
            .filter { groupIDs.contains($0.id) }
            .map(\.name)
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        return titles.isEmpty ? model.l10n(.notFilled) : titles.joined(separator: ", ")
    }

    private var detailTagline: String {
        if !groupText.isEmpty, groupText != model.l10n(.notFilled) {
            return groupText
        }
        if !profile.organizationName.isEmpty {
            return profile.organizationName
        }
        return model.l10n(.contactsSource)
    }

    private var heroColor: Color {
        profile.records.first.map { color(for: $0.kind) } ?? ContactsNativeStyle.accent
    }

    private var daysSuffix: String {
        switch model.language.coreLocale {
        case .english: "days"
        case .simplifiedChinese: "天后"
        case .traditionalChinese: "天後"
        }
    }

    private func countdownSubtitle(for occurrence: RosterOccurrence) -> String {
        let date = model.formatter.occurrenceDate(occurrence.date, locale: model.language.coreLocale)
        guard let age = occurrence.age else { return date }
        return "\(date) · \(ageValueText(age))"
    }

    private func ageValueText(_ age: Int) -> String {
        switch model.language.coreLocale {
        case .english: "Turns \(age)"
        case .simplifiedChinese: "满 \(age) 岁"
        case .traditionalChinese: "滿 \(age) 歲"
        }
    }

    private func saveDraft() {
        guard draft.payload(personID: profile.id) != nil else { return }
        Task { @MainActor in
            isSaving = true
            await model.save(contactID: profile.id, draft: draft)
            isSaving = false
            isEditing = false
        }
    }

    private func chooseAvatarImage() {
        guard let data = selectedAvatarImageData() else { return }
        draft.imageData = data
    }

    private func chooseAndQueueAvatarImage() {
        guard let data = selectedAvatarImageData() else { return }
        var avatarDraft = RosterEditDraft(profile: profile)
        avatarDraft.imageData = data
        Task { await model.save(contactID: profile.id, draft: avatarDraft) }
    }

    private func selectedAvatarImageData() -> Data? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK,
              let url = panel.url
        else { return nil }
        return try? Data(contentsOf: url)
    }
}

private struct ContactQuickActionBar: View {
    @Environment(RosterAppModel.self) private var model
    let profile: ContactRosterProfile

    var body: some View {
        HStack(spacing: 14) {
            ContactQuickActionButton(
                action: .message,
                title: model.l10n(.message),
                systemImage: "message.fill",
                profile: profile
            )
            ContactQuickActionButton(
                action: .call,
                title: model.l10n(.phone),
                systemImage: "phone.fill",
                profile: profile
            )
            ContactQuickActionButton(
                action: .video,
                title: model.l10n(.videoCall),
                systemImage: "video.fill",
                profile: profile
            )
            ContactQuickActionButton(
                action: .email,
                title: model.l10n(.email),
                systemImage: "envelope.fill",
                profile: profile
            )
        }
        .padding(.top, 2)
    }
}

private struct ContactQuickActionButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let action: ContactQuickAction
    let title: String
    let systemImage: String
    let profile: ContactRosterProfile

    var body: some View {
        Button {
            if let url {
                NSWorkspace.shared.open(url)
            }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 34, height: 34)
                .foregroundStyle(url == nil ? .secondary.opacity(0.55) : ContactsNativeStyle.accent)
                .background(buttonBackground, in: Circle())
                .overlay(
                    Circle()
                        .strokeBorder(ContactsNativeStyle.separator(colorScheme), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .disabled(url == nil)
        .help(title)
        .accessibilityLabel(title)
    }

    private var url: URL? {
        ContactActionURLFactory.url(
            for: action,
            phoneNumbers: profile.phoneNumbers,
            emailAddresses: profile.emailAddresses
        )
    }

    private var buttonBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.82)
    }
}

struct RosterValues: View {
    @Environment(RosterAppModel.self) private var model
    let records: [RosterRecord]

    var body: some View {
        if records.isEmpty {
            Text(model.l10n(.noRosters))
                .foregroundStyle(.tertiary)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(records) { record in
                    HStack(spacing: 7) {
                        StaticKindBadge(kind: record.kind, title: shortKindName(record.kind, model: model))
                        Text(model.formatter.originalDate(record, locale: model.language.coreLocale))
                            .lineLimit(1)
                    }
                }
            }
        }
    }
}

struct RosterRecordSummaryRow: View {
    @Environment(RosterAppModel.self) private var model
    let record: RosterRecord

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(model.formatter.calendarName(record.kind, locale: model.language.coreLocale))
                        .font(.system(size: 13, weight: .semibold))
                    Text(sourceText)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Text(model.formatter.originalDate(record, locale: model.language.coreLocale))
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)

                Text(thisYearText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var sourceText: String {
        record.source == .local ? model.l10n(.localOnly) : model.l10n(.appleSynced)
    }

    private var thisYearText: String {
        let year = Calendar(identifier: .gregorian).component(.year, from: Date())
        guard let date = model.resolver.occurrence(for: record, inGregorianYear: year) else {
            return model.l10n(.notFilled)
        }
        let dateText = model.formatter.occurrenceDate(date, locale: model.language.coreLocale)
        guard let age = model.resolver.age(for: record, on: date) else {
            return "\(model.l10n(.thisYearDate)) \(dateText)"
        }
        return "\(model.l10n(.thisYearDate)) \(dateText) · \(ageText(age))"
    }

    private func ageText(_ age: Int) -> String {
        switch model.language.coreLocale {
        case .english: "Turns \(age)"
        case .simplifiedChinese: "满 \(age) 岁"
        case .traditionalChinese: "滿 \(age) 歲"
        }
    }
}

struct RosterEditEntryView: View {
    @Environment(RosterAppModel.self) private var model
    @Binding var entry: RosterEditEntry
    let profile: ContactRosterProfile
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            NativeInfoRow(label: model.l10n(.calendarKind)) {
                HStack(spacing: 12) {
                    Picker("", selection: $entry.kind) {
                        ForEach(RosterCalendarKind.allCases) { kind in
                            Text(model.formatter.calendarName(kind, locale: model.language.coreLocale)).tag(kind)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 168, alignment: .leading)

                    Text(sourceText)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 0)

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .help(model.l10n(.deleteRoster))
                    .accessibilityLabel(model.l10n(.deleteRoster))
                }
            }

            NativeDivider()

            NativeInfoRow(label: model.l10n(.birthDate)) {
                ViewThatFits(in: .horizontal) {
                    birthdayDateControls

                    VStack(alignment: .leading, spacing: 8) {
                        birthdayDateFields
                        leapMonthToggle
                    }
                }
            }

            NativeDivider()

            NativeInfoRow(label: model.l10n(.thisYearDate)) {
                Text(thisYearText)
                    .foregroundStyle(thisYearText == model.l10n(.notFilled) ? .tertiary : .primary)
            }
        }
    }

    private var sourceText: String {
        entry.source == .local ? model.l10n(.localOnly) : model.l10n(.appleSynced)
    }

    private var birthdayDateControls: some View {
        HStack(spacing: 8) {
            birthdayDateFields
            leapMonthToggle
        }
    }

    private var birthdayDateFields: some View {
        HStack(spacing: 8) {
            NativeDateField("YYYY", text: $entry.year, width: 72)
            NativeDateField("MM", text: $entry.month, width: 58)
            NativeDateField("DD", text: $entry.day, width: 58)
        }
    }

    @ViewBuilder
    private var leapMonthToggle: some View {
        if entry.kind == .chinese {
            Toggle(model.l10n(.leapMonth), isOn: $entry.isLeapMonth)
                .toggleStyle(.switch)
                .font(.system(size: 12))
        }
    }

    private var thisYearText: String {
        guard let spec = entry.dateSpec(personID: profile.id) else {
            return model.l10n(.notFilled)
        }
        let record = RosterRecord(person: profile.person, dateSpec: spec)
        let year = Calendar(identifier: .gregorian).component(.year, from: Date())
        guard let date = model.resolver.occurrence(for: record, inGregorianYear: year) else {
            return model.l10n(.notFilled)
        }
        let dateText = model.formatter.occurrenceDate(date, locale: model.language.coreLocale)
        guard let age = model.resolver.age(for: record, on: date) else {
            return dateText
        }
        return "\(dateText) · \(ageText(age))"
    }

    private func ageText(_ age: Int) -> String {
        switch model.language.coreLocale {
        case .english: "Turns \(age)"
        case .simplifiedChinese: "满 \(age) 岁"
        case .traditionalChinese: "滿 \(age) 歲"
        }
    }
}

// MARK: - Extended details

struct ExtendedContactDetailsView: View {
    @Environment(RosterAppModel.self) private var model
    let extended: ContactExtendedProfile
    var includesEditableFields = true

    var body: some View {
        NativeInfoCard {
            ForEach(Array(infoGroups.enumerated()), id: \.element.id) { index, group in
                if index > 0 {
                    NativeDivider()
                }
                NativeInfoRow(label: group.title) {
                    InfoValueStack(values: group.values)
                }
            }
        }
    }

    private var infoGroups: [ExtendedInfoGroup] {
        var groups = [
            ExtendedInfoGroup(id: "links", title: model.l10n(.links), values: extended.urlAddresses + extended.socialProfiles + extended.instantMessageAddresses),
            ExtendedInfoGroup(id: "dates", title: model.l10n(.dates), values: extended.dates),
            ExtendedInfoGroup(id: "relations", title: model.l10n(.relations), values: extended.contactRelations)
        ]
        if includesEditableFields {
            groups.insert(contentsOf: [
                ExtendedInfoGroup(id: "work", title: model.l10n(.work), values: [extended.jobTitle, extended.departmentName]),
                ExtendedInfoGroup(id: "phone", title: model.l10n(.phone), values: extended.phoneNumbers),
                ExtendedInfoGroup(id: "email", title: model.l10n(.email), values: extended.emailAddresses),
                ExtendedInfoGroup(id: "address", title: model.l10n(.address), values: extended.postalAddresses)
            ], at: 0)
        }
        return groups
        .map { group in
            ExtendedInfoGroup(
                id: group.id,
                title: group.title,
                values: group.values.filter { !$0.isEmpty }
            )
        }
        .filter { !$0.values.isEmpty }
    }
}

private struct ExtendedInfoGroup: Identifiable {
    let id: String
    let title: String
    let values: [String]
}

struct InfoValueStack: View {
    let values: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(values.prefix(4), id: \.self) { value in
                Text(value)
                    .lineLimit(2)
            }
        }
    }
}

struct ContactAvatarImageView: View {
    let name: String
    let imageData: Data?
    var color: Color = RosterTheme.accent
    var size: CGFloat = 38

    var body: some View {
        if let imageData, let image = NSImage(data: imageData) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                .accessibilityHidden(true)
        } else {
            AvatarView(name: name, color: color, size: size)
        }
    }
}

struct NativeContactTextField: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var text: String
    let placeholder: String

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 13.5))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(ContactsNativeStyle.inputFocusBackground(colorScheme), in: RoundedRectangle(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(ContactsNativeStyle.separator(colorScheme))
            )
    }
}

struct NativeContactMultilineField: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var text: String
    let placeholder: String

    var body: some View {
        TextEditor(text: $text)
            .font(.system(size: 13.5))
            .frame(minHeight: 64)
            .scrollContentBackground(.hidden)
            .padding(8)
            .background(ContactsNativeStyle.inputFocusBackground(colorScheme), in: RoundedRectangle(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(ContactsNativeStyle.separator(colorScheme))
            )
            .overlay(alignment: .topLeading) {
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(placeholder)
                        .font(.system(size: 13.5))
                        .foregroundStyle(.secondary.opacity(0.7))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 15)
                        .allowsHitTesting(false)
                }
            }
    }
}

// MARK: - Tag picker

struct ContactTagPickerPopover: View {
    @Environment(RosterAppModel.self) private var model
    let contactIDs: Set<String>
    let replacesExistingTags: Bool
    let onDone: () -> Void
    @State private var selectedTagIDs: Set<String>
    @State private var newTagName = ""

    init(
        contactIDs: Set<String>,
        initialTagIDs: Set<String> = [],
        replacesExistingTags: Bool = false,
        onDone: @escaping () -> Void
    ) {
        self.contactIDs = contactIDs
        self.replacesExistingTags = replacesExistingTags
        self.onDone = onDone
        _selectedTagIDs = State(initialValue: initialTagIDs)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))

            TextField(model.l10n(.newTagPathPlaceholder), text: $newTagName)
                .textFieldStyle(.roundedBorder)

            if replacesExistingTags, !selectedTags.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 82), spacing: 6)], alignment: .leading, spacing: 6) {
                    ForEach(selectedTags) { tag in
                        RemovableContactTagChip(tag: tag) {
                            selectedTagIDs.remove(tag.id)
                        }
                    }
                }
            }

            if model.contactTags.isEmpty {
                Text(model.l10n(.noTags))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(model.contactTagTreeNodes) { node in
                        let tag = node.tag
                        Button {
                            toggle(tag.id)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: selectedTagIDs.contains(tag.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedTagIDs.contains(tag.id) ? ContactsNativeStyle.accent : .secondary)
                                    .frame(width: 16)
                                ContactTagChip(tag: tag)
                                Spacer(minLength: 0)
                            }
                            .padding(.leading, CGFloat(node.depth) * 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(model.tagPath(for: tag.id))
                    }
                }
            }

            HStack(spacing: 10) {
                Spacer(minLength: 0)
                Button(model.l10n(.cancel)) {
                    onDone()
                }
                .buttonStyle(KimiActionButtonStyle(kind: .regular))

                Button(model.l10n(.apply)) {
                    apply()
                }
                .buttonStyle(KimiActionButtonStyle(kind: .primary))
                .disabled(!canApply)
            }
        }
        .padding(16)
        .frame(width: 280)
    }

    private var title: String {
        replacesExistingTags ? model.l10n(.editTags) : model.l10n(.addTags)
    }

    private var canApply: Bool {
        if replacesExistingTags { return true }
        return !selectedTagIDs.isEmpty || !newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var selectedTags: [ContactTag] {
        model.contactTagTreeNodes
            .map(\.tag)
            .filter { selectedTagIDs.contains($0.id) }
    }

    private func toggle(_ tagID: String) {
        if selectedTagIDs.contains(tagID) {
            selectedTagIDs.remove(tagID)
        } else {
            selectedTagIDs.insert(tagID)
        }
    }

    private func apply() {
        Task { @MainActor in
            if replacesExistingTags, let contactID = contactIDs.first {
                await model.replaceTags(for: contactID, tagIDs: selectedTagIDs, newTagName: newTagName)
            } else {
                await model.assignTags(tagIDs: selectedTagIDs, newTagName: newTagName, to: contactIDs)
            }
            onDone()
        }
    }
}

private struct RemovableContactTagChip: View {
    @Environment(RosterAppModel.self) private var model
    let tag: ContactTag
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(tag.name)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8.5, weight: .bold))
                    .frame(width: 13, height: 13)
            }
            .buttonStyle(.plain)
            .help(model.l10n(.removeTag))
            .accessibilityLabel("\(model.l10n(.removeTag)): \(tag.name)")
        }
        .padding(.leading, 7)
        .padding(.trailing, 4)
        .padding(.vertical, 3)
        .foregroundStyle(Color(hex: tag.color))
        .background(Color(hex: tag.color).opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(Color(hex: tag.color).opacity(0.16))
        )
    }
}

// MARK: - Native cards

struct NativeInfoCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(ContactsNativeStyle.cardBackground(colorScheme), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(ContactsNativeStyle.separator(colorScheme))
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.06), radius: 2, y: 0.5)
    }
}

struct NativeInfoRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 76, alignment: .trailing)

            content
                .font(.system(size: 14))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 44)
    }
}

struct NativeDivider: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ContactsNativeStyle.separator(colorScheme)
            .frame(height: 0.5)
            .padding(.leading, 108)
    }
}

struct NativeDateField: View {
    @Environment(\.colorScheme) private var colorScheme
    let placeholder: String
    @Binding var text: String
    let width: CGFloat

    init(_ placeholder: String, text: Binding<String>, width: CGFloat) {
        self.placeholder = placeholder
        _text = text
        self.width = width
    }

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 13.5))
            .multilineTextAlignment(.center)
            .monospacedDigit()
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(width: width)
            .background(ContactsNativeStyle.inputFocusBackground(colorScheme), in: RoundedRectangle(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(ContactsNativeStyle.separator(colorScheme))
            )
    }
}

// MARK: - Styles

private enum KimiSeparatorAxis {
    case horizontal
    case vertical
}

private struct KimiSeparator: View {
    @Environment(\.colorScheme) private var colorScheme
    let axis: KimiSeparatorAxis

    var body: some View {
        ContactsNativeStyle.separator(colorScheme)
            .frame(width: axis == .vertical ? 0.5 : nil, height: axis == .horizontal ? 0.5 : nil)
    }
}

enum KimiActionButtonKind {
    case regular
    case primary
}

struct KimiActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let kind: KimiActionButtonKind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(foreground)
            .padding(.horizontal, 18)
            .padding(.vertical, 7)
            .frame(minWidth: 76)
            .background(background(configuration: configuration), in: RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(kind == .primary ? Color.clear : ContactsNativeStyle.strongSeparator(colorScheme))
            )
            .shadow(color: .black.opacity(kind == .primary || colorScheme == .dark ? 0 : 0.08), radius: 1.5, y: 0.5)
            .opacity(isEnabled ? 1 : 0.52)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(RosterTheme.Motion.allowed(RosterTheme.Motion.press, reduceMotion: reduceMotion), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch kind {
        case .regular: .primary
        case .primary: .white
        }
    }

    private func background(configuration: Configuration) -> Color {
        switch kind {
        case .regular:
            return configuration.isPressed ? ContactsNativeStyle.pressedBackground(colorScheme) : ContactsNativeStyle.cardBackground(colorScheme)
        case .primary:
            return configuration.isPressed ? Color(hex: 0x0062CC) : ContactsNativeStyle.accent
        }
    }
}

private struct KimiToolbarButtonChrome: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .padding(6)
            .background(isHovering ? ContactsNativeStyle.sourceRowHover(colorScheme) : Color.clear, in: RoundedRectangle(cornerRadius: 7))
            .onHover { isHovering = $0 }
            .animation(RosterTheme.Motion.hover, value: isHovering)
    }
}

private extension View {
    func fixedContactColumn(width: CGFloat, priority: Double) -> some View {
        frame(minWidth: width, idealWidth: width, maxWidth: width)
            .layoutPriority(priority)
            .clipped()
    }

    func kimiToolbarButton() -> some View {
        modifier(KimiToolbarButtonChrome())
    }
}

enum ContactsNativeStyle {
    static let accent = Color(hex: 0x007AFF)
    static let red = Color(hex: 0xFF3B30)

    static func toolbarBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(nsColor: .windowBackgroundColor) : Color(hex: 0xF5F5F7)
    }

    static func sourceListBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(nsColor: .underPageBackgroundColor) : Color(hex: 0xF2F2F7)
    }

    static func windowBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(nsColor: .windowBackgroundColor) : Color.white
    }

    static func listBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(nsColor: .windowBackgroundColor) : Color.white
    }

    static func detailBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(nsColor: .underPageBackgroundColor) : Color(hex: 0xF5F5F7)
    }

    static func cardBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(nsColor: .controlBackgroundColor) : Color.white
    }

    static func searchBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.86)
    }

    static func sourceRowHover(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.07) : Color.black.opacity(0.0001)
    }

    static func inputFocusBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.06) : accent.opacity(0.06)
    }

    static func pressedBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.10) : Color(hex: 0xE8E8E8)
    }

    static func separator(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.13) : Color.black.opacity(0.10)
    }

    static func strongSeparator(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.20) : Color.black.opacity(0.18)
    }
}

private func contactCountText(_ count: Int, locale: CalendarFormattingService.AppLocale) -> String {
    switch locale {
    case .english: count == 1 ? "1 contact" : "\(count) contacts"
    case .simplifiedChinese: "\(count) 位联系人"
    case .traditionalChinese: "\(count) 位聯絡人"
    }
}
