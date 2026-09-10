import RosterShared
import SwiftUI

struct MobileMoreView: View {
    @Environment(RosterAppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            List {
                Section(model.l10n(.sync)) {
                    LabeledContent(model.l10n(.statusPending), value: "\(model.pendingContactOperationCount)")
                    LabeledContent(model.l10n(.statusFailed), value: "\(model.failedContactOperationCount)")
                    LabeledContent(model.l10n(.statusConflict), value: "\(model.conflictedContactOperationCount)")
                }

                Section(model.l10n(.settings)) {
                    Toggle(model.l10n(.displayAge), isOn: $model.showAge)

                    Picker(model.l10n(.appLanguage), selection: $model.language) {
                        Text(AppLanguage.system.displayName).tag(AppLanguage.system)
                        Text(AppLanguage.zhHans.displayName).tag(AppLanguage.zhHans)
                        Text(AppLanguage.zhHant.displayName).tag(AppLanguage.zhHant)
                        Text("English").tag(AppLanguage.en)
                    }
                }
            }
            .navigationTitle(model.l10n(.more))
        }
    }
}
