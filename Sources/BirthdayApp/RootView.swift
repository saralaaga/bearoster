import SwiftUI

// MARK: - Root

struct RootView: View {
    @Environment(BirthdayAppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        @Bindable var model = model

        HStack(spacing: 0) {
            SidebarView()
                .frame(width: BirthdayTheme.Layout.sidebarWidth)

            Rectangle()
                .fill(BirthdayTheme.separator(colorScheme))
                .frame(width: 1)

            ZStack {
                BirthdayTheme.windowBackground(colorScheme)

                Group {
                    switch model.selection {
                    case .calendar:
                        CalendarDashboardView()
                    case .list:
                        BirthdayRecordsView()
                    case .contacts:
                        ContactsEditorView()
                    case .permissions:
                        PermissionsSettingsView()
                    }
                }
                .id(model.selection)
                .transition(.opacity)
            }
            .animation(.easeOut(duration: 0.22), value: model.selection)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(BirthdayTheme.windowBackground(colorScheme))
        .overlay(alignment: .bottom) {
            if let toast = model.toastMessage {
                ToastView(message: toast)
                    .padding(.bottom, 22)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.2), value: model.toastMessage)
        .tint(BirthdayTheme.accent)
        .alert("Birthday", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}
