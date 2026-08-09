import BirthdayCore
import SwiftUI

@main
struct BirthdayApp: App {
    @State private var model = BirthdayAppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .frame(minWidth: BirthdayTheme.Layout.minWindowWidth, minHeight: BirthdayTheme.Layout.minWindowHeight)
                .task {
                    await model.refreshContacts()
                }
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
