import RosterShared
import SwiftUI

@main
struct RosterIOSApp: App {
    @State private var model = RosterAppModel()

    var body: some Scene {
        WindowGroup {
            MobileRootView()
                .environment(model)
                .task {
                    await model.refreshContacts()
                }
        }
    }
}
