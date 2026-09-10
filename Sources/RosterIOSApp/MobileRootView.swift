import RosterShared
import SwiftUI

struct MobileRootView: View {
    enum Tab: Hashable {
        case contacts
        case tags
        case calendar
        case more
    }

    @Environment(RosterAppModel.self) private var model
    @State private var tab: Tab = .contacts

    var body: some View {
        TabView(selection: $tab) {
            MobileContactsView()
                .tabItem { Label(model.l10n(.contacts), systemImage: "person.crop.circle") }
                .tag(Tab.contacts)

            MobileTagsView()
                .tabItem { Label(model.l10n(.tags), systemImage: "tag") }
                .tag(Tab.tags)

            MobileCalendarView()
                .tabItem { Label(model.l10n(.calendar), systemImage: "calendar") }
                .tag(Tab.calendar)

            MobileMoreView()
                .tabItem { Label(model.l10n(.more), systemImage: "ellipsis.circle") }
                .tag(Tab.more)
        }
    }
}
