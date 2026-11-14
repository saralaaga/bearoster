import Foundation
import Testing
@testable import RosterShared

@Suite("Calendar share access")
struct CalendarShareModelTests {
    @Test("Share tokens are URL-safe and sized for 128-bit entropy")
    func tokens() {
        let allowed = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")

        let token = CalendarShareModel.generateToken(byteCount: 16)

        #expect(token.count == 22)
        #expect(token.allSatisfy { allowed.contains($0) })
        #expect(CalendarShareModel.generateToken(byteCount: 16) != token)
    }

    @Test("Calendar sharing copy is localized")
    func localizedShareCopy() {
        let l10n = L10n(language: .en)
        #expect(l10n(.share) == "Calendar Sharing")
        #expect(l10n(.sharePrivacyHint).contains("Anyone who has it can subscribe"))
    }
}
