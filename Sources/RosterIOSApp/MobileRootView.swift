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

struct MobileTagsView: View {
    var body: some View {
        NavigationStack {
            Text("标签")
                .navigationTitle("标签")
        }
    }
}

struct MobileCalendarView: View {
    var body: some View {
        NavigationStack {
            Text("日历")
                .navigationTitle("日历")
        }
    }
}

struct MobileMoreView: View {
    var body: some View {
        NavigationStack {
            Text("更多")
                .navigationTitle("更多")
        }
    }
}
