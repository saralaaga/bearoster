import RosterCore
import Foundation
import SQLite3

enum ContactWritePolicy: String, Codable, CaseIterable, Identifiable, Sendable {
    case localOnly
    case confirmBeforeWrite
    case automatic

    var id: String { rawValue }
}

enum ContactOperationKind: String, Codable, Sendable {
    case create
    case update
    case delete
    case restore
}

enum ContactOperationStatus: String, Codable, Sendable {
    case pending
    case applied
    case failed
    case conflict
    case reverted
}

struct ContactFieldChange: Codable, Hashable, Sendable {
    var field: String
    var previousValue: String
    var nextValue: String
}

struct LocalContactDraft: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var appleContactID: String?
    var displayName: String
    var givenName: String
    var familyName: String
    var nickname: String
    var organizationName: String
    var departmentName: String
    var jobTitle: String
    var note: String
    var phoneNumbers: [String]
    var emailAddresses: [String]
    var postalAddresses: [String]
    var birthdaySpecs: [RosterDateSpec]
    var imageData: Data?
    var isDeleted: Bool
    var deletedAt: Date?
    var baseSignature: Int
    var updatedAt: Date

    init(
        id: String,
        appleContactID: String?,
        displayName: String,
        givenName: String = "",
        familyName: String = "",
        nickname: String = "",
        organizationName: String = "",
        departmentName: String = "",
        jobTitle: String = "",
        note: String = "",
        phoneNumbers: [String] = [],
        emailAddresses: [String] = [],
        postalAddresses: [String] = [],
        birthdaySpecs: [RosterDateSpec] = [],
        imageData: Data? = nil,
        isDeleted: Bool = false,
        deletedAt: Date? = nil,
        baseSignature: Int,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.appleContactID = appleContactID
        self.displayName = displayName
        self.givenName = givenName
        self.familyName = familyName
        self.nickname = nickname
        self.organizationName = organizationName
        self.departmentName = departmentName
        self.jobTitle = jobTitle
        self.note = note
        self.phoneNumbers = phoneNumbers
        self.emailAddresses = emailAddresses
        self.postalAddresses = postalAddresses
        self.birthdaySpecs = birthdaySpecs
        self.imageData = imageData
        self.isDeleted = isDeleted
        self.deletedAt = deletedAt
        self.baseSignature = baseSignature
        self.updatedAt = updatedAt
    }

    init(profile: ContactRosterProfile, extended: ContactExtendedProfile?, birthdaySpecs: [RosterDateSpec]) {
        self.init(
            id: profile.id,
            appleContactID: profile.id,
            displayName: profile.displayName,
            givenName: profile.givenName,
            familyName: profile.familyName,
            nickname: profile.nickname,
            organizationName: profile.organizationName,
            departmentName: profile.departmentName.isEmpty ? extended?.departmentName ?? "" : profile.departmentName,
            jobTitle: profile.jobTitle.isEmpty ? extended?.jobTitle ?? "" : profile.jobTitle,
            phoneNumbers: profile.phoneNumbers.isEmpty ? extended?.phoneNumbers ?? [] : profile.phoneNumbers,
            emailAddresses: profile.emailAddresses.isEmpty ? extended?.emailAddresses ?? [] : profile.emailAddresses,
            postalAddresses: profile.postalAddresses.isEmpty ? extended?.postalAddresses ?? [] : profile.postalAddresses,
            birthdaySpecs: birthdaySpecs,
            imageData: profile.imageData,
            baseSignature: Self.signature(profile: profile, extended: extended)
        )
    }

    var profile: ContactRosterProfile {
        let person = RosterPerson(
            id: id,
            displayName: displayName,
            organizationName: organizationName,
            appleContactIdentifier: appleContactID,
            source: appleContactID == nil ? .local : .merged
        )
        return ContactRosterProfile(
            id: id,
            displayName: displayName,
            organizationName: organizationName,
            records: birthdaySpecs.map { RosterRecord(person: person, dateSpec: $0) },
            givenName: givenName,
            familyName: familyName,
            nickname: nickname,
            departmentName: departmentName,
            jobTitle: jobTitle,
            phoneNumbers: phoneNumbers,
            emailAddresses: emailAddresses,
            postalAddresses: postalAddresses,
            imageData: imageData
        )
    }

    static func signature(profile: ContactRosterProfile, extended: ContactExtendedProfile?) -> Int {
        var hasher = Hasher()
        hasher.combine(profile.id)
        hasher.combine(profile.displayName)
        hasher.combine(profile.givenName)
        hasher.combine(profile.familyName)
        hasher.combine(profile.nickname)
        hasher.combine(profile.organizationName)
        hasher.combine(profile.departmentName)
        hasher.combine(profile.jobTitle)
        hasher.combine(profile.phoneNumbers)
        hasher.combine(profile.emailAddresses)
        hasher.combine(profile.postalAddresses)
        hasher.combine(profile.imageData)
        hasher.combine(profile.dateSpecs)
        hasher.combine(extended)
        return hasher.finalize()
    }
}

struct ContactOperationLog: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var contactID: String
    var appleContactID: String?
    var displayName: String
    var kind: ContactOperationKind
    var status: ContactOperationStatus
    var summary: String
    var fieldChanges: [ContactFieldChange]
    var draft: LocalContactDraft?
    var errorMessage: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        contactID: String,
        appleContactID: String?,
        displayName: String,
        kind: ContactOperationKind,
        status: ContactOperationStatus = .pending,
        summary: String,
        fieldChanges: [ContactFieldChange] = [],
        draft: LocalContactDraft? = nil,
        errorMessage: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.contactID = contactID
        self.appleContactID = appleContactID
        self.displayName = displayName
        self.kind = kind
        self.status = status
        self.summary = summary
        self.fieldChanges = fieldChanges
        self.draft = draft
        self.errorMessage = errorMessage
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct ContactJournalSnapshot: Sendable {
    var draftsByContactID: [String: LocalContactDraft]
    var operations: [ContactOperationLog]
    var writePolicy: ContactWritePolicy
}

actor ContactOperationJournalStore {
    private let databaseURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        databaseURL: URL = AppSupportPaths.database(named: "contact-journal.sqlite3")
    ) {
        self.databaseURL = databaseURL
    }

    func load() -> ContactJournalSnapshot {
        do {
            let database = try openDatabase()
            defer { sqlite3_close(database) }
            try prepareSchema(database)

            return ContactJournalSnapshot(
                draftsByContactID: loadDrafts(database),
                operations: loadOperations(database),
                writePolicy: loadWritePolicy(database)
            )
        } catch {
            return ContactJournalSnapshot(draftsByContactID: [:], operations: [], writePolicy: .confirmBeforeWrite)
        }
    }

    func setWritePolicy(_ policy: ContactWritePolicy) {
        do {
            let database = try openDatabase()
            defer { sqlite3_close(database) }
            try prepareSchema(database)
            try saveSetting(database, key: "writePolicy", value: policy.rawValue)
        } catch {
            return
        }
    }

    func saveDraft(_ draft: LocalContactDraft) {
        do {
            let database = try openDatabase()
            defer { sqlite3_close(database) }
            try prepareSchema(database)
            try upsertDraft(database, draft)
        } catch {
            return
        }
    }

    func deleteDraft(contactID: String) {
        do {
            let database = try openDatabase()
            defer { sqlite3_close(database) }
            try prepareSchema(database)
            let sql = "DELETE FROM contact_local_drafts WHERE contact_id = ?"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_text(statement, 1, contactID, -1, contactJournalTransientDestructor)
            sqlite3_step(statement)
        } catch {
            return
        }
    }

    func appendOperation(_ operation: ContactOperationLog) {
        do {
            let database = try openDatabase()
            defer { sqlite3_close(database) }
            try prepareSchema(database)
            try upsertOperation(database, operation)
        } catch {
            return
        }
    }

    func updateOperation(_ operation: ContactOperationLog) {
        appendOperation(operation)
    }

    func updateOperations(_ operations: [ContactOperationLog]) {
        guard !operations.isEmpty else { return }
        do {
            let database = try openDatabase()
            defer { sqlite3_close(database) }
            try prepareSchema(database)
            for operation in operations {
                try upsertOperation(database, operation)
            }
        } catch {
            return
        }
    }

    private func loadDrafts(_ database: OpaquePointer?) -> [String: LocalContactDraft] {
        let sql = "SELECT payload FROM contact_local_drafts ORDER BY updated_at DESC"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return [:] }
        defer { sqlite3_finalize(statement) }

        var drafts: [String: LocalContactDraft] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let bytes = sqlite3_column_blob(statement, 0) else { continue }
            let byteCount = Int(sqlite3_column_bytes(statement, 0))
            let data = Data(bytes: bytes, count: byteCount)
            guard let draft = try? decoder.decode(LocalContactDraft.self, from: data) else { continue }
            drafts[draft.id] = draft
        }
        return drafts
    }

    private func loadOperations(_ database: OpaquePointer?) -> [ContactOperationLog] {
        let sql = "SELECT payload FROM contact_operation_log ORDER BY created_at DESC"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(statement) }

        var operations: [ContactOperationLog] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let bytes = sqlite3_column_blob(statement, 0) else { continue }
            let byteCount = Int(sqlite3_column_bytes(statement, 0))
            let data = Data(bytes: bytes, count: byteCount)
            if let operation = try? decoder.decode(ContactOperationLog.self, from: data) {
                operations.append(operation)
            }
        }
        return operations
    }

    private func loadWritePolicy(_ database: OpaquePointer?) -> ContactWritePolicy {
        let sql = "SELECT value FROM contact_journal_settings WHERE key = ?"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return .confirmBeforeWrite }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, "writePolicy", -1, contactJournalTransientDestructor)
        guard sqlite3_step(statement) == SQLITE_ROW,
              let value = sqlite3_column_text(statement, 0)
        else { return .confirmBeforeWrite }
        return ContactWritePolicy(rawValue: String(cString: value)) ?? .confirmBeforeWrite
    }

    private func saveSetting(_ database: OpaquePointer?, key: String, value: String) throws {
        let sql = """
        INSERT OR REPLACE INTO contact_journal_settings (key, value)
        VALUES (?, ?)
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw ContactOperationJournalStoreError.statementFailed
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, key, -1, contactJournalTransientDestructor)
        sqlite3_bind_text(statement, 2, value, -1, contactJournalTransientDestructor)
        sqlite3_step(statement)
    }

    private func upsertDraft(_ database: OpaquePointer?, _ draft: LocalContactDraft) throws {
        let data = try encoder.encode(draft)
        let sql = """
        INSERT OR REPLACE INTO contact_local_drafts (contact_id, updated_at, is_deleted, payload)
        VALUES (?, ?, ?, ?)
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw ContactOperationJournalStoreError.statementFailed
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, draft.id, -1, contactJournalTransientDestructor)
        sqlite3_bind_double(statement, 2, draft.updatedAt.timeIntervalSince1970)
        sqlite3_bind_int(statement, 3, draft.isDeleted ? 1 : 0)
        try bind(data, to: statement, index: 4)
        sqlite3_step(statement)
    }

    private func upsertOperation(_ database: OpaquePointer?, _ operation: ContactOperationLog) throws {
        let data = try encoder.encode(operation)
        let sql = """
        INSERT OR REPLACE INTO contact_operation_log
        (id, contact_id, created_at, updated_at, status, kind, payload)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw ContactOperationJournalStoreError.statementFailed
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, operation.id, -1, contactJournalTransientDestructor)
        sqlite3_bind_text(statement, 2, operation.contactID, -1, contactJournalTransientDestructor)
        sqlite3_bind_double(statement, 3, operation.createdAt.timeIntervalSince1970)
        sqlite3_bind_double(statement, 4, operation.updatedAt.timeIntervalSince1970)
        sqlite3_bind_text(statement, 5, operation.status.rawValue, -1, contactJournalTransientDestructor)
        sqlite3_bind_text(statement, 6, operation.kind.rawValue, -1, contactJournalTransientDestructor)
        try bind(data, to: statement, index: 7)
        sqlite3_step(statement)
    }

    private func bind(_ data: Data, to statement: OpaquePointer?, index: Int32) throws {
        let result = data.withUnsafeBytes { buffer in
            sqlite3_bind_blob(statement, index, buffer.baseAddress, Int32(buffer.count), contactJournalTransientDestructor)
        }
        guard result == SQLITE_OK else {
            throw ContactOperationJournalStoreError.statementFailed
        }
    }

    private func openDatabase() throws -> OpaquePointer? {
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var database: OpaquePointer?
        guard sqlite3_open(databaseURL.path, &database) == SQLITE_OK else {
            throw ContactOperationJournalStoreError.openFailed
        }
        return database
    }

    private func prepareSchema(_ database: OpaquePointer?) throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS contact_local_drafts (
            contact_id TEXT PRIMARY KEY NOT NULL,
            updated_at REAL NOT NULL,
            is_deleted INTEGER NOT NULL DEFAULT 0,
            payload BLOB NOT NULL
        );

        CREATE TABLE IF NOT EXISTS contact_operation_log (
            id TEXT PRIMARY KEY NOT NULL,
            contact_id TEXT NOT NULL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL,
            status TEXT NOT NULL,
            kind TEXT NOT NULL,
            payload BLOB NOT NULL
        );

        CREATE INDEX IF NOT EXISTS contact_operation_log_status_idx
        ON contact_operation_log(status, created_at);

        CREATE TABLE IF NOT EXISTS contact_journal_settings (
            key TEXT PRIMARY KEY NOT NULL,
            value TEXT NOT NULL
        );
        """
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
            throw ContactOperationJournalStoreError.schemaFailed
        }
    }
}

private enum ContactOperationJournalStoreError: Error {
    case openFailed
    case schemaFailed
    case statementFailed
}

private let contactJournalTransientDestructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
