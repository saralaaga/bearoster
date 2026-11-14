import Foundation
import Observation
import RosterCore
import Security

/// Drives the calendar-share feature: one share link per user, served from
/// bearoster.com/c/{readToken}. The subscription URL is the only credential
/// subscribers get; the matching write secret stays in the Keychain and
/// authorizes content updates. Free feature, no purchase or trial gating.
@MainActor
@Observable
package final class CalendarShareModel {
    package private(set) var isEnabled = false
    package private(set) var readToken = ""
    package private(set) var isSyncing = false
    package private(set) var lastSyncedAt: Date?
    package private(set) var errorMessage: String?

    private var writeSecret = ""
    private var lastUploadedICS: String?
    private var syncDebounceTask: Task<Void, Never>?
    private let service = CalendarShareService()
    private let defaults: UserDefaults

    package init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    package var shareURL: URL? {
        guard isEnabled, !readToken.isEmpty else { return nil }
        return URL(string: "\(CalendarShareService.baseURL.absoluteString)/\(readToken)")
    }

    /// URL-safe random token. The read token doubles as the subscription
    /// credential, so it must carry real entropy (128 bits by default).
    package nonisolated static func generateToken(byteCount: Int = 16) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let status = bytes.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, byteCount, buffer.baseAddress!)
        }
        let data = status == errSecSuccess ? Data(bytes) : Data(UUID().uuidString.utf8)
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    package func restore() async {
        readToken = defaults.string(forKey: "calendarShare.readToken") ?? ""
        writeSecret = CalendarShareKeychain.readSecret() ?? ""
        isEnabled = defaults.bool(forKey: "calendarShare.isEnabled")
            && !readToken.isEmpty
            && !writeSecret.isEmpty
    }

    package func setEnabled(_ enabled: Bool, records: [RosterRecord], calendarName: String) async {
        errorMessage = nil
        if enabled {
            if readToken.isEmpty || writeSecret.isEmpty {
                issueTokens()
            }
            isEnabled = true
            defaults.set(readToken, forKey: "calendarShare.readToken")
            defaults.set(true, forKey: "calendarShare.isEnabled")
            await upload(records: records, calendarName: calendarName)
        } else {
            // Best effort: local state goes away even if the relay is
            // unreachable; the orphaned token simply serves stale content
            // until the user rotates it.
            try? await service.delete(readToken: readToken, writeSecret: writeSecret)
            clearLocalState()
        }
    }

    package func regenerate(records: [RosterRecord], calendarName: String) async {
        guard isEnabled else { return }
        try? await service.delete(readToken: readToken, writeSecret: writeSecret)
        issueTokens()
        lastUploadedICS = nil
        defaults.set(readToken, forKey: "calendarShare.readToken")
        await upload(records: records, calendarName: calendarName)
    }

    /// Roster content changed: debounce, rebuild, and push only when the
    /// feed text actually differs.
    package func scheduleSync(records: [RosterRecord], calendarName: String) {
        guard isEnabled else { return }
        syncDebounceTask?.cancel()
        syncDebounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled, let self else { return }
            await self.upload(records: records, calendarName: calendarName)
        }
    }

    private func issueTokens() {
        readToken = Self.generateToken(byteCount: 16)
        writeSecret = Self.generateToken(byteCount: 32)
        CalendarShareKeychain.saveSecret(writeSecret)
    }

    private func clearLocalState() {
        isEnabled = false
        readToken = ""
        writeSecret = ""
        lastUploadedICS = nil
        lastSyncedAt = nil
        syncDebounceTask?.cancel()
        defaults.removeObject(forKey: "calendarShare.readToken")
        defaults.removeObject(forKey: "calendarShare.isEnabled")
        CalendarShareKeychain.deleteSecret()
    }

    private func upload(records: [RosterRecord], calendarName: String) async {
        let stamp = Date()
        let ics = await Task.detached(priority: .utility) {
            let events = CalendarShareFeedBuilder.events(from: records, today: stamp)
            return CalendarShareFeedBuilder.ics(for: events, calendarName: calendarName, stamp: stamp)
        }.value
        guard ics != lastUploadedICS else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            try await service.upload(readToken: readToken, writeSecret: writeSecret, ics: ics)
            lastUploadedICS = ics
            lastSyncedAt = Date()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
