import RosterShared
import SwiftUI

struct MobileMoreView: View {
    @Environment(RosterAppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            List {
                Section("同步") {
                    LabeledContent("待写回", value: "\(model.pendingContactOperationCount)")
                    LabeledContent("失败", value: "\(model.failedContactOperationCount)")
                    LabeledContent("冲突", value: "\(model.conflictedContactOperationCount)")
                }

                Section("设置") {
                    Toggle("显示年龄", isOn: $model.showAge)

                    Picker("语言", selection: $model.language) {
                        Text("跟随系统").tag(AppLanguage.system)
                        Text("简体中文").tag(AppLanguage.zhHans)
                        Text("繁體中文").tag(AppLanguage.zhHant)
                        Text("English").tag(AppLanguage.en)
                    }
                }
            }
            .navigationTitle("更多")
        }
    }
}
