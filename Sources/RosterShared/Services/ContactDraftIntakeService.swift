import Foundation
import RosterCore

// MARK: - Intake outcome

package struct ContactDraftIntakeItem: Sendable, Hashable {
    package let index: Int
    package let draft: LocalContactDraft

    package init(index: Int, draft: LocalContactDraft) {
        self.index = index
        self.draft = draft
    }
}

package struct ContactDraftIntakeRejection: Sendable, Hashable {
    package let index: Int
    package let reason: String

    package init(index: Int, reason: String) {
        self.index = index
        self.reason = reason
    }
}

package struct ContactDraftIntakeOutcome: Sendable {
    package var requestError: String?
    package var accepted: [ContactDraftIntakeItem]
    package var conflicts: [ContactDraftIntakeItem]
    package var rejected: [ContactDraftIntakeRejection]

    package init(
        requestError: String? = nil,
        accepted: [ContactDraftIntakeItem] = [],
        conflicts: [ContactDraftIntakeItem] = [],
        rejected: [ContactDraftIntakeRejection] = []
    ) {
        self.requestError = requestError
        self.accepted = accepted
        self.conflicts = conflicts
        self.rejected = rejected
    }

    package var queuedCount: Int {
        accepted.count + conflicts.count
    }
}

// MARK: - Existing contact fingerprint

package struct ContactIntakeFingerprint: Sendable, Hashable {
    package let displayName: String
    package let phoneDigits: Set<String>
    package let emails: Set<String>

    package init(displayName: String, phoneNumbers: [String], emailAddresses: [String]) {
        self.displayName = Self.normalizeName(displayName)
        self.phoneDigits = Set(phoneNumbers.map(Self.normalizePhone))
        self.emails = Set(emailAddresses.map(Self.normalizeEmail))
    }

    package init(profile: ContactRosterProfile) {
        self.init(
            displayName: profile.displayName,
            phoneNumbers: profile.phoneNumbers,
            emailAddresses: profile.emailAddresses
        )
    }

    package func matches(_ other: ContactIntakeFingerprint) -> Bool {
        guard displayName == other.displayName, !displayName.isEmpty else { return false }
        let sharesPhone = !phoneDigits.isEmpty && !phoneDigits.isDisjoint(with: other.phoneDigits)
        let sharesEmail = !emails.isEmpty && !emails.isDisjoint(with: other.emails)
        return sharesPhone || sharesEmail
    }

    static func normalizeName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .lowercased()
    }

    static func normalizePhone(_ value: String) -> String {
        String(value.filter(\.isNumber))
    }

    static func normalizeEmail(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

// MARK: - Intake service

/// Validates agent-submitted contact draft payloads against the intake contract
/// (schema version 1) and maps them to journal drafts. Pure logic: no IO, no Contacts access.
package enum ContactDraftIntakeService {
    package static let schemaVersion = 1
    package static let maxDraftCount = 500
    package static let maxPayloadBytes = 5 * 1024 * 1024

    private static let topLevelKeys: Set<String> = ["schemaVersion", "drafts"]
    private static let draftKeys: Set<String> = [
        "displayName", "givenName", "familyName", "nickname",
        "organizationName", "departmentName", "jobTitle",
        "phoneNumbers", "emailAddresses", "postalAddresses", "birthdays"
    ]
    private static let birthdayKeys: Set<String> = ["date", "label"]

    private static let phonePattern = "^[+0-9().\\-\\s]{3,32}$"
    private static let emailPattern = "^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$"
    private static let fullDatePattern = "^\\d{4}-\\d{2}-\\d{2}$"
    private static let monthDayPattern = "^\\d{2}-\\d{2}$"

    package static func fingerprints(profiles: [ContactRosterProfile]) -> [ContactIntakeFingerprint] {
        profiles.map(ContactIntakeFingerprint.init(profile:))
    }

    package static func process(
        payload: Data,
        existing: [ContactIntakeFingerprint],
        queued: [ContactIntakeFingerprint] = [],
        now: Date = Date()
    ) -> ContactDraftIntakeOutcome {
        guard payload.count <= maxPayloadBytes else {
            return ContactDraftIntakeOutcome(
                requestError: "payload exceeds \(maxPayloadBytes) bytes"
            )
        }

        guard let root = try? JSONSerialization.jsonObject(with: payload) as? [String: Any] else {
            return ContactDraftIntakeOutcome(requestError: "payload must be a UTF-8 JSON object")
        }

        let unknownRootKeys = Set(root.keys).subtracting(topLevelKeys)
        guard unknownRootKeys.isEmpty else {
            return ContactDraftIntakeOutcome(
                requestError: "unknown top-level field(s): \(unknownRootKeys.sorted().joined(separator: ", "))"
            )
        }

        guard let version = root["schemaVersion"] as? Int, version == schemaVersion else {
            return ContactDraftIntakeOutcome(
                requestError: "unsupported schemaVersion; this server supports \(schemaVersion)"
            )
        }

        guard let drafts = root["drafts"] as? [[String: Any]] else {
            return ContactDraftIntakeOutcome(requestError: "drafts must be a non-empty array")
        }
        guard (1...maxDraftCount).contains(drafts.count) else {
            return ContactDraftIntakeOutcome(
                requestError: "drafts count must be between 1 and \(maxDraftCount), got \(drafts.count)"
            )
        }

        var accepted: [ContactDraftIntakeItem] = []
        var conflicts: [ContactDraftIntakeItem] = []
        var rejected: [ContactDraftIntakeRejection] = []
        var batchFingerprints: [ContactIntakeFingerprint] = []

        for (index, entry) in drafts.enumerated() {
            switch buildDraft(entry: entry, index: index, now: now) {
            case .failure(let errors):
                rejected.append(ContactDraftIntakeRejection(index: index, reason: errors.messages.joined(separator: "; ")))
            case .success(let draft):
                let fingerprint = ContactIntakeFingerprint(
                    displayName: draft.displayName,
                    phoneNumbers: draft.phoneNumbers,
                    emailAddresses: draft.emailAddresses
                )
                if let matchIndex = batchFingerprints.firstIndex(where: { $0.matches(fingerprint) }) {
                    rejected.append(ContactDraftIntakeRejection(
                        index: index,
                        reason: "duplicate of draft #\(matchIndex) in this batch"
                    ))
                    continue
                }
                if queued.contains(where: { $0.matches(fingerprint) }) {
                    rejected.append(ContactDraftIntakeRejection(
                        index: index,
                        reason: "duplicate of an already-queued draft"
                    ))
                    continue
                }
                if existing.contains(where: { $0.matches(fingerprint) }) {
                    conflicts.append(ContactDraftIntakeItem(index: index, draft: draft))
                    continue
                }
                accepted.append(ContactDraftIntakeItem(index: index, draft: draft))
                batchFingerprints.append(fingerprint)
            }
        }

        return ContactDraftIntakeOutcome(
            accepted: accepted,
            conflicts: conflicts,
            rejected: rejected
        )
    }

    private struct DraftFieldErrors: Error {
        let messages: [String]
    }

    private static func buildDraft(
        entry: [String: Any],
        index: Int,
        now: Date
    ) -> Result<LocalContactDraft, DraftFieldErrors> {
        var errors: [String] = []

        let unknownKeys = Set(entry.keys).subtracting(draftKeys)
        if !unknownKeys.isEmpty {
            errors.append("unknown field(s): \(unknownKeys.sorted().joined(separator: ", "))")
        }

        let displayName = string(entry["displayName"], max: 128, field: "displayName", errors: &errors)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if displayName.isEmpty {
            errors.append("displayName is required")
        }

        let givenName = string(entry["givenName"], max: 64, field: "givenName", errors: &errors) ?? ""
        let familyName = string(entry["familyName"], max: 64, field: "familyName", errors: &errors) ?? ""
        let nickname = string(entry["nickname"], max: 64, field: "nickname", errors: &errors) ?? ""
        let organizationName = string(entry["organizationName"], max: 128, field: "organizationName", errors: &errors) ?? ""
        let departmentName = string(entry["departmentName"], max: 128, field: "departmentName", errors: &errors) ?? ""
        let jobTitle = string(entry["jobTitle"], max: 128, field: "jobTitle", errors: &errors) ?? ""

        let phoneNumbers = stringArray(
            entry["phoneNumbers"], field: "phoneNumbers", maxCount: 8, errors: &errors
        )?.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } ?? []
        for (position, phone) in phoneNumbers.enumerated() where !phone.matches(phonePattern) {
            errors.append("phoneNumbers[\(position)] is not a valid phone number")
        }

        let emailAddresses = stringArray(
            entry["emailAddresses"], field: "emailAddresses", maxCount: 8, errors: &errors
        )?.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } ?? []
        for (position, email) in emailAddresses.enumerated() where !email.isEmpty {
            if email.count > 254 {
                errors.append("emailAddresses[\(position)] exceeds 254 characters")
            } else if !email.matches(emailPattern) {
                errors.append("emailAddresses[\(position)] is not a valid email address")
            }
        }

        let postalAddresses = stringArray(
            entry["postalAddresses"], field: "postalAddresses", maxCount: 4, errors: &errors
        )?.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } ?? []

        guard let birthdayEntries = entry["birthdays"] as? [[String: Any]] else {
            if entry["birthdays"] != nil {
                errors.append("birthdays must be an array of objects")
            }
            return finish(
                errors: errors, now: now, displayName: displayName, givenName: givenName,
                familyName: familyName, nickname: nickname, organizationName: organizationName,
                departmentName: departmentName, jobTitle: jobTitle,
                phoneNumbers: phoneNumbers, emailAddresses: emailAddresses,
                postalAddresses: postalAddresses, birthdaySpecs: []
            )
        }
        guard birthdayEntries.count <= 1 else {
            errors.append("birthdays supports at most 1 entry in schema version \(schemaVersion)")
            return finish(
                errors: errors, now: now, displayName: displayName, givenName: givenName,
                familyName: familyName, nickname: nickname, organizationName: organizationName,
                departmentName: departmentName, jobTitle: jobTitle,
                phoneNumbers: phoneNumbers, emailAddresses: emailAddresses,
                postalAddresses: postalAddresses, birthdaySpecs: []
            )
        }

        var birthdaySpecs: [RosterDateSpec] = []
        for (position, birthdayEntry) in birthdayEntries.enumerated() {
            let unknownBirthdayKeys = Set(birthdayEntry.keys).subtracting(birthdayKeys)
            if !unknownBirthdayKeys.isEmpty {
                errors.append("birthdays[\(position)] unknown field(s): \(unknownBirthdayKeys.sorted().joined(separator: ", "))")
            }
            let label = string(birthdayEntry["label"], max: 32, field: "birthdays[\(position)].label", errors: &errors)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let labelValue = (label?.isEmpty ?? true) ? nil : label

            guard let dateText = birthdayEntry["date"] as? String else {
                errors.append("birthdays[\(position)].date is required (YYYY-MM-DD or MM-DD)")
                continue
            }
            guard let components = parseDate(dateText) else {
                errors.append("birthdays[\(position)].date '\(dateText)' is not a valid gregorian date")
                continue
            }
            birthdaySpecs.append(RosterDateSpec(
                personID: "pending",
                kind: .gregorian,
                components: components,
                label: labelValue,
                source: .appleRoster,
                syncPolicy: .writeBackToApple
            ))
        }

        return finish(
            errors: errors, now: now, displayName: displayName, givenName: givenName,
            familyName: familyName, nickname: nickname, organizationName: organizationName,
            departmentName: departmentName, jobTitle: jobTitle,
            phoneNumbers: phoneNumbers, emailAddresses: emailAddresses,
            postalAddresses: postalAddresses, birthdaySpecs: birthdaySpecs
        )
    }

    private static func finish(
        errors: [String],
        now: Date,
        displayName: String,
        givenName: String,
        familyName: String,
        nickname: String,
        organizationName: String,
        departmentName: String,
        jobTitle: String,
        phoneNumbers: [String],
        emailAddresses: [String],
        postalAddresses: [String],
        birthdaySpecs: [RosterDateSpec]
    ) -> Result<LocalContactDraft, DraftFieldErrors> {
        guard errors.isEmpty else {
            return .failure(DraftFieldErrors(messages: errors))
        }

        let draftID = "agent-\(UUID().uuidString)"
        let specs = birthdaySpecs.map { spec in
            RosterDateSpec(
                personID: draftID,
                kind: spec.kind,
                components: spec.components,
                label: spec.label,
                source: spec.source,
                syncPolicy: spec.syncPolicy
            )
        }

        let hasNameParts = !givenName.isEmpty || !familyName.isEmpty
            || !nickname.isEmpty || !organizationName.isEmpty
        let resolvedGivenName = hasNameParts ? givenName : displayName

        let draft = LocalContactDraft(
            id: draftID,
            appleContactID: nil,
            displayName: displayName,
            givenName: resolvedGivenName,
            familyName: familyName,
            nickname: nickname,
            organizationName: organizationName,
            departmentName: departmentName,
            jobTitle: jobTitle,
            phoneNumbers: phoneNumbers,
            emailAddresses: emailAddresses,
            postalAddresses: postalAddresses,
            birthdaySpecs: specs,
            baseSignature: 0,
            updatedAt: now
        )
        return .success(draft)
    }

    // MARK: Field helpers

    private static func string(_ value: Any?, max limit: Int, field: String, errors: inout [String]) -> String? {
        guard let value else { return nil }
        guard let text = value as? String else {
            errors.append("\(field) must be a string")
            return nil
        }
        guard text.count <= limit else {
            errors.append("\(field) exceeds \(limit) characters")
            return nil
        }
        return text
    }

    private static func stringArray(
        _ value: Any?,
        field: String,
        maxCount limit: Int,
        errors: inout [String]
    ) -> [String]? {
        guard let value else { return nil }
        guard let array = value as? [Any] else {
            errors.append("\(field) must be an array of strings")
            return nil
        }
        guard array.count <= limit else {
            errors.append("\(field) supports at most \(limit) entries")
            return nil
        }
        var result: [String] = []
        for (position, element) in array.enumerated() {
            guard let text = element as? String else {
                errors.append("\(field)[\(position)] must be a string")
                return nil
            }
            result.append(text)
        }
        return result
    }

    private static let utcGregorianCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? calendar.timeZone
        return calendar
    }()

    /// Validates that the date actually exists: Foundation's calendar wraps
    /// out-of-range components (Feb 31 becomes Mar 2/3), so the round-trip
    /// comparison is what catches impossible dates. Year-less MM-DD probes a
    /// leap year so Feb 29 stays valid.
    private static func validatedDateComponents(
        year: Int?, month: Int, day: Int
    ) -> DateComponents? {
        guard (1...12).contains(month) else { return nil }
        if let year {
            guard (1900...2100).contains(year) else { return nil }
        }
        var components = DateComponents()
        components.year = year ?? 2000
        components.month = month
        components.day = day
        guard let date = utcGregorianCalendar.date(from: components) else { return nil }
        let resolved = utcGregorianCalendar.dateComponents([.year, .month, .day], from: date)
        guard resolved.year == components.year, resolved.month == month, resolved.day == day else {
            return nil
        }

        if year != nil {
            return DateComponents(calendar: utcGregorianCalendar, year: year, month: month, day: day)
        }
        return DateComponents(calendar: utcGregorianCalendar, month: month, day: day)
    }

    private static func parseDate(_ text: String) -> DateComponents? {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        if text.matches(fullDatePattern), parts.count == 3 {
            return validatedDateComponents(year: parts[0], month: parts[1], day: parts[2])
        }
        if text.matches(monthDayPattern), parts.count == 2 {
            return validatedDateComponents(year: nil, month: parts[0], day: parts[1])
        }
        return nil
    }
}

private extension String {
    func matches(_ pattern: String) -> Bool {
        range(of: pattern, options: .regularExpression) != nil
    }
}
