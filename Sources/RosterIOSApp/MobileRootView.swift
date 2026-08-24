import SwiftUI

struct MobileRootView: View {
    enum Tab: Hashable {
        case contacts
        case tags
        case calendar
        case more
    }

    @State private var tab: Tab = .contacts

    var body: some View {
        TabView(selection: $tab) {
            MobileContactsView()
                .tabItem { Label("通讯录", systemImage: "person.crop.circle") }
                .tag(Tab.contacts)

            MobileTagsView()
                .tabItem { Label("标签", systemImage: "tag") }
                .tag(Tab.tags)

            MobileCalendarView()
                .tabItem { Label("日历", systemImage: "calendar") }
                .tag(Tab.calendar)

            MobileMoreView()
                .tabItem { Label("更多", systemImage: "ellipsis.circle") }
                .tag(Tab.more)
        }
    }
}

