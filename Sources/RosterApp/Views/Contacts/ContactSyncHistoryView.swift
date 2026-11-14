import SwiftUI
import RosterShared

struct ContactSyncHistoryView: View {
    @Environment(RosterAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                NativeInfoCard {
                    NativeInfoRow(label: model.l10n(.writePolicy)) {
                        Picker(model.l10n(.writePolicy), selection: Binding(
                            get: { model.contactWritePolicy },
                            set: { model.setContactWritePolicy($0) }
                        )) {
                            Text(model.l10n(.writePolicyLocalOnly)).tag(ContactWritePolicy.localOnly)
                            Text(model.l10n(.writePolicyConfirm)).tag(ContactWritePolicy.confirmBeforeWrite)
                            Text(model.l10n(.writePolicyAutomatic)).tag(ContactWritePolicy.automatic)
                        }
                        .pickerStyle(.segmented)
                    }

                    NativeDivider()

                    NativeInfoRow(label: model.l10n(.queue)) {
                        HStack(spacing: 10) {
                            StatusPill(title: model.l10n(.statusPending), count: model.pendingContactOperationCount, color: ContactsNativeStyle.accent)
                            StatusPill(title: model.l10n(.statusConflict), count: model.conflictedContactOperationCount, color: ContactsNativeStyle.red)
                            StatusPill(title: model.l10n(.statusFailed), count: model.failedContactOperationCount, color: Color(hex: 0xFF9500))
                            Spacer(minLength: 0)
                            Button {
                                Task { await model.writeBackPendingContactOperations() }
                            } label: {
                                Label(model.l10n(.writePending), systemImage: "arrow.up.doc")
                            }
                            .buttonStyle(KimiActionButtonStyle(kind: .primary))
                            .disabled(model.pendingContactOperationCount == 0)
                        }
                    }
                }

                if !conflicts.isEmpty {
                    operationSection(title: model.l10n(.statusConflict), operations: conflicts, showsConflictActions: true)
                }

                if !failed.isEmpty {
                    operationSection(title: model.l10n(.statusFailed), operations: failed, showsConflictActions: false)
                }

                if !pending.isEmpty {
                    operationSection(title: model.l10n(.statusPending), operations: pending, showsConflictActions: false)
                }

                if !trashedDrafts.isEmpty {
                    trashSection
                }

                operationSection(title: model.l10n(.history), operations: history, showsConflictActions: false)
            }
            .padding(.horizontal, 32)
            .padding(.top, 30)
            .padding(.bottom, 60)
            .frame(maxWidth: .infinity)
        }
        .adaptivePaneWidth(floor: 760, cap: 880)
        .background(ContactsNativeStyle.detailBackground(colorScheme))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(model.l10n(.syncHistory))
                .font(.system(size: 24, weight: .bold))
            Text(model.l10n(.syncHistoryBody))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var pending: [ContactOperationLog] {
        model.contactOperationLog.filter { $0.status == .pending }
    }

    private var conflicts: [ContactOperationLog] {
        model.contactOperationLog.filter { $0.status == .conflict }
    }

    private var failed: [ContactOperationLog] {
        model.contactOperationLog.filter { $0.status == .failed }
    }

    private var history: [ContactOperationLog] {
        Array(model.contactOperationLog.prefix(20))
    }

    private var trashedDrafts: [LocalContactDraft] {
        model.contactDraftsByID.values
            .filter(\.isDeleted)
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private func operationSection(
        title: String,
        operations: [ContactOperationLog],
        showsConflictActions: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: title, count: operations.count)
            NativeInfoCard {
                if operations.isEmpty {
                    EmptyJournalRow(text: model.l10n(.noEntries))
                } else {
                    ForEach(Array(operations.enumerated()), id: \.element.id) { index, operation in
                        if index > 0 {
                            NativeDivider()
                        }
                        ContactOperationRow(operation: operation, showsConflictActions: showsConflictActions)
                    }
                }
            }
        }
    }

    private var trashSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: model.l10n(.trash), count: trashedDrafts.count)
            NativeInfoCard {
                ForEach(Array(trashedDrafts.enumerated()), id: \.element.id) { index, draft in
                    if index > 0 {
                        NativeDivider()
                    }
                    HStack(spacing: 12) {
                        AvatarView(name: draft.displayName, color: ContactsNativeStyle.red, size: 34)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(draft.displayName)
                                .font(.system(size: 13.5, weight: .semibold))
                            Text(draft.deletedAt.map(Self.dateFormatter.string(from:)) ?? model.l10n(.trashLocal))
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Button {
                            Task { await model.restoreContactFromTrash(draft.id) }
                        } label: {
                            Label(model.l10n(.restore), systemImage: "arrow.uturn.backward")
                        }
                        .buttonStyle(KimiActionButtonStyle(kind: .regular))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                }
            }
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct SectionTitle: View {
    let title: String
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
            Text("\(count)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))
            Spacer(minLength: 0)
        }
    }
}

private struct StatusPill: View {
    let title: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(title)
            Text("\(count)")
                .monospacedDigit()
        }
        .font(.system(size: 11.5, weight: .semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct ContactOperationRow: View {
    @Environment(RosterAppModel.self) private var model
    let operation: ContactOperationLog
    let showsConflictActions: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(statusColor)
                    .frame(width: 24, height: 24)
                    .background(statusColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(operation.displayName)
                            .font(.system(size: 13.5, weight: .semibold))
                        Text(statusText)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(statusColor)
                    }
                    Text(operation.summary)
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                    if let errorMessage = operation.errorMessage, !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.system(size: 12))
                            .foregroundStyle(ContactsNativeStyle.red)
                    }
                }

                Spacer(minLength: 0)

                Text(Self.dateFormatter.string(from: operation.createdAt))
                    .font(.system(size: 11.5))
                    .foregroundStyle(.tertiary)
            }

            if !operation.fieldChanges.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(operation.fieldChanges, id: \.self) { change in
                        Text("\(change.field): \(change.previousValue) → \(change.nextValue)")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(.leading, 36)
            }

            if showsConflictActions {
                HStack(spacing: 8) {
                    Spacer(minLength: 36)
                    Button(model.l10n(.keepMacOSVersion)) {
                        Task { await model.acceptMacOSVersion(for: operation.id) }
                    }
                    .buttonStyle(KimiActionButtonStyle(kind: .regular))

                    Button(model.l10n(.keepLocalVersion)) {
                        Task { await model.overwriteMacOSVersion(for: operation.id) }
                    }
                    .buttonStyle(KimiActionButtonStyle(kind: .primary))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private var iconName: String {
        switch operation.kind {
        case .create: "plus"
        case .update: "pencil"
        case .delete: "trash"
        case .restore: "arrow.uturn.backward"
        case .createGroup: "folder.badge.plus"
        case .deleteGroup: "folder.badge.minus"
        }
    }

    private var statusText: String {
        switch operation.status {
        case .pending: model.l10n(.statusPending)
        case .applied: model.l10n(.statusApplied)
        case .failed: model.l10n(.statusFailed)
        case .conflict: model.l10n(.statusConflict)
        case .reverted: model.l10n(.statusReverted)
        }
    }

    private var statusColor: Color {
        switch operation.status {
        case .pending: ContactsNativeStyle.accent
        case .applied: Color(hex: 0x34C759)
        case .failed: Color(hex: 0xFF9500)
        case .conflict: ContactsNativeStyle.red
        case .reverted: .secondary
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct EmptyJournalRow: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
    }
}
