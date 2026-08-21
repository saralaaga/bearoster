import SwiftUI

struct ContactSyncHistoryView: View {
    @Environment(RosterAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                NativeInfoCard {
                    NativeInfoRow(label: "写入模式") {
                        Picker("写入模式", selection: Binding(
                            get: { model.contactWritePolicy },
                            set: { model.setContactWritePolicy($0) }
                        )) {
                            Text("仅本地").tag(ContactWritePolicy.localOnly)
                            Text("确认后写入").tag(ContactWritePolicy.confirmBeforeWrite)
                            Text("自动写入").tag(ContactWritePolicy.automatic)
                        }
                        .pickerStyle(.segmented)
                    }

                    NativeDivider()

                    NativeInfoRow(label: "队列") {
                        HStack(spacing: 10) {
                            StatusPill(title: "待写入", count: model.pendingContactOperationCount, color: ContactsNativeStyle.accent)
                            StatusPill(title: "冲突", count: model.conflictedContactOperationCount, color: ContactsNativeStyle.red)
                            StatusPill(title: "失败", count: model.failedContactOperationCount, color: Color(hex: 0xFF9500))
                            Spacer(minLength: 0)
                            Button {
                                Task { await model.writeBackPendingContactOperations() }
                            } label: {
                                Label("写入待处理", systemImage: "arrow.up.doc")
                            }
                            .buttonStyle(KimiActionButtonStyle(kind: .primary))
                            .disabled(model.pendingContactOperationCount == 0)
                        }
                    }
                }

                if !conflicts.isEmpty {
                    operationSection(title: "冲突", operations: conflicts, showsConflictActions: true)
                }

                if !failed.isEmpty {
                    operationSection(title: "失败", operations: failed, showsConflictActions: false)
                }

                if !pending.isEmpty {
                    operationSection(title: "待写入", operations: pending, showsConflictActions: false)
                }

                if !trashedDrafts.isEmpty {
                    trashSection
                }

                operationSection(title: "历史记录", operations: history, showsConflictActions: false)
            }
            .padding(.horizontal, 32)
            .padding(.top, 30)
            .padding(.bottom, 60)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(ContactsNativeStyle.detailBackground(colorScheme))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("同步与历史")
                .font(.system(size: 24, weight: .bold))
            Text("联系人修改先保存在名册，本页负责确认写回、冲突处理、失败重试和回收站恢复。")
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
                    EmptyJournalRow(text: "没有记录")
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
            SectionTitle(title: "回收站", count: trashedDrafts.count)
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
                            Text(draft.deletedAt.map(Self.dateFormatter.string(from:)) ?? "本地回收站")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Button {
                            Task { await model.restoreContactFromTrash(draft.id) }
                        } label: {
                            Label("恢复", systemImage: "arrow.uturn.backward")
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
                        Text("\(change.field): \(change.previousValue) -> \(change.nextValue)")
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
                    Button("使用 macOS 版本") {
                        Task { await model.acceptMacOSVersion(for: operation.id) }
                    }
                    .buttonStyle(KimiActionButtonStyle(kind: .regular))

                    Button("用本地覆盖") {
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
        }
    }

    private var statusText: String {
        switch operation.status {
        case .pending: "待写入"
        case .applied: "已写入"
        case .failed: "失败"
        case .conflict: "冲突"
        case .reverted: "已放弃"
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
