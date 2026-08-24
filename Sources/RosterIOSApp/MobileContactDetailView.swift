import RosterCore
import SwiftUI

struct MobileContactDetailView: View {
    let profile: ContactRosterProfile

    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    MobileAvatar(name: profile.displayName, size: 76)
                    Text(profile.displayName)
                        .font(.title2.weight(.bold))
                    Text(profile.records.isEmpty ? "没有生日记录" : "\(profile.records.count) 个日期")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
        .navigationTitle(profile.displayName)
    }
}
