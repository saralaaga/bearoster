import RosterCore
import Foundation
import SQLite3

package actor ContactTagStore {
    private let databaseURL: URL

    package init(
        databaseURL: URL = AppSupportPaths.database(named: "contact-tags.sqlite3")
    ) {
        self.databaseURL = databaseURL
    }

    package func load() -> (tags: [ContactTag], assignmentsByContactID: [String: Set<String>]) {
        do {
            let database = try openDatabase()
            defer { sqlite3_close(database) }
            try prepareSchema(database)

            return (
                tags: loadTags(database),
                assignmentsByContactID: loadAssignments(database)
            )
        } catch {
            return ([], [:])
        }
    }

    package func saveTag(_ tag: ContactTag) {
        do {
            let database = try openDatabase()
            defer { sqlite3_close(database) }
            try prepareSchema(database)

            let sql = """
            INSERT OR REPLACE INTO contact_tags (id, name, color, parent_tag_id, sort_order, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_text(statement, 1, tag.id, -1, tagStoreTransientDestructor)
            sqlite3_bind_text(statement, 2, tag.name, -1, tagStoreTransientDestructor)
            sqlite3_bind_int64(statement, 3, sqlite3_int64(tag.color))
            if let parentTagID = tag.parentTagID {
                sqlite3_bind_text(statement, 4, parentTagID, -1, tagStoreTransientDestructor)
            } else {
                sqlite3_bind_null(statement, 4)
            }
            sqlite3_bind_int(statement, 5, Int32(tag.sortOrder))
            sqlite3_bind_double(statement, 6, tag.createdAt.timeIntervalSince1970)
            sqlite3_bind_double(statement, 7, tag.updatedAt.timeIntervalSince1970)
            sqlite3_step(statement)
        } catch {
            return
        }
    }

    package func assign(tagIDs: Set<String>, to contactIDs: Set<String>) {
        guard !tagIDs.isEmpty, !contactIDs.isEmpty else { return }
        do {
            let database = try openDatabase()
            defer { sqlite3_close(database) }
            try prepareSchema(database)

            let sql = """
            INSERT OR IGNORE INTO contact_tag_assignments (contact_id, tag_id, created_at)
            VALUES (?, ?, ?)
            """
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(statement) }

            let now = Date().timeIntervalSince1970
            for contactID in contactIDs {
                for tagID in tagIDs {
                    sqlite3_reset(statement)
                    sqlite3_clear_bindings(statement)
                    sqlite3_bind_text(statement, 1, contactID, -1, tagStoreTransientDestructor)
                    sqlite3_bind_text(statement, 2, tagID, -1, tagStoreTransientDestructor)
                    sqlite3_bind_double(statement, 3, now)
                    sqlite3_step(statement)
                }
            }
        } catch {
            return
        }
    }

    package func replaceAssignments(for contactID: String, tagIDs: Set<String>) {
        do {
            let database = try openDatabase()
            defer { sqlite3_close(database) }
            try prepareSchema(database)

            deleteAssignments(database, for: [contactID])
            insertAssignments(database, tagIDs: tagIDs, contactIDs: [contactID])
        } catch {
            return
        }
    }

    package func deleteAssignments(for contactIDs: Set<String>) {
        guard !contactIDs.isEmpty else { return }
        do {
            let database = try openDatabase()
            defer { sqlite3_close(database) }
            try prepareSchema(database)
            deleteAssignments(database, for: contactIDs)
        } catch {
            return
        }
    }

    package func deleteTags(tagIDs: Set<String>) {
        guard !tagIDs.isEmpty else { return }
        do {
            let database = try openDatabase()
            defer { sqlite3_close(database) }
            try prepareSchema(database)

            deleteAssignments(database, forTagIDs: tagIDs)
            let sql = "DELETE FROM contact_tags WHERE id = ?"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(statement) }

            for tagID in tagIDs {
                sqlite3_reset(statement)
                sqlite3_clear_bindings(statement)
                sqlite3_bind_text(statement, 1, tagID, -1, tagStoreTransientDestructor)
                sqlite3_step(statement)
            }
        } catch {
            return
        }
    }

    private func loadTags(_ database: OpaquePointer?) -> [ContactTag] {
        let sql = "SELECT id, name, color, parent_tag_id, sort_order, created_at, updated_at FROM contact_tags ORDER BY parent_tag_id, sort_order, name"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        var tags: [ContactTag] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let idCString = sqlite3_column_text(statement, 0),
                  let nameCString = sqlite3_column_text(statement, 1)
            else { continue }

            tags.append(ContactTag(
                id: String(cString: idCString),
                name: String(cString: nameCString),
                color: UInt(sqlite3_column_int64(statement, 2)),
                parentTagID: sqlite3_column_type(statement, 3) == SQLITE_NULL
                    ? nil
                    : sqlite3_column_text(statement, 3).map { String(cString: $0) },
                sortOrder: Int(sqlite3_column_int(statement, 4)),
                createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 5)),
                updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 6))
            ))
        }
        return tags
    }

    private func loadAssignments(_ database: OpaquePointer?) -> [String: Set<String>] {
        let sql = "SELECT contact_id, tag_id FROM contact_tag_assignments"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            return [:]
        }
        defer { sqlite3_finalize(statement) }

        var assignments: [String: Set<String>] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let contactIDCString = sqlite3_column_text(statement, 0),
                  let tagIDCString = sqlite3_column_text(statement, 1)
            else { continue }

            assignments[String(cString: contactIDCString), default: []].insert(String(cString: tagIDCString))
        }
        return assignments
    }

    private func deleteAssignments(_ database: OpaquePointer?, for contactIDs: Set<String>) {
        let sql = "DELETE FROM contact_tag_assignments WHERE contact_id = ?"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(statement) }

        for contactID in contactIDs {
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)
            sqlite3_bind_text(statement, 1, contactID, -1, tagStoreTransientDestructor)
            sqlite3_step(statement)
        }
    }

    private func deleteAssignments(_ database: OpaquePointer?, forTagIDs tagIDs: Set<String>) {
        let sql = "DELETE FROM contact_tag_assignments WHERE tag_id = ?"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(statement) }

        for tagID in tagIDs {
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)
            sqlite3_bind_text(statement, 1, tagID, -1, tagStoreTransientDestructor)
            sqlite3_step(statement)
        }
    }

    private func insertAssignments(_ database: OpaquePointer?, tagIDs: Set<String>, contactIDs: Set<String>) {
        guard !tagIDs.isEmpty, !contactIDs.isEmpty else { return }
        let sql = """
        INSERT OR IGNORE INTO contact_tag_assignments (contact_id, tag_id, created_at)
        VALUES (?, ?, ?)
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(statement) }

        let now = Date().timeIntervalSince1970
        for contactID in contactIDs {
            for tagID in tagIDs {
                sqlite3_reset(statement)
                sqlite3_clear_bindings(statement)
                sqlite3_bind_text(statement, 1, contactID, -1, tagStoreTransientDestructor)
                sqlite3_bind_text(statement, 2, tagID, -1, tagStoreTransientDestructor)
                sqlite3_bind_double(statement, 3, now)
                sqlite3_step(statement)
            }
        }
    }

    private func openDatabase() throws -> OpaquePointer? {
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var database: OpaquePointer?
        guard sqlite3_open(databaseURL.path, &database) == SQLITE_OK else {
            throw ContactTagStoreError.openFailed
        }
        return database
    }

    private func prepareSchema(_ database: OpaquePointer?) throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS contact_tags (
            id TEXT PRIMARY KEY NOT NULL,
            name TEXT NOT NULL COLLATE NOCASE UNIQUE,
            color INTEGER NOT NULL,
            parent_tag_id TEXT,
            sort_order INTEGER NOT NULL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL
        );

        CREATE TABLE IF NOT EXISTS contact_tag_assignments (
            contact_id TEXT NOT NULL,
            tag_id TEXT NOT NULL,
            created_at REAL NOT NULL,
            PRIMARY KEY (contact_id, tag_id),
            FOREIGN KEY (tag_id) REFERENCES contact_tags(id) ON DELETE CASCADE
        );

        CREATE INDEX IF NOT EXISTS contact_tag_assignments_contact_id_idx
        ON contact_tag_assignments(contact_id);
        """
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
            throw ContactTagStoreError.schemaFailed
        }
        try addColumnIfMissing(database, table: "contact_tags", column: "parent_tag_id", definition: "TEXT")
    }

    private func addColumnIfMissing(
        _ database: OpaquePointer?,
        table: String,
        column: String,
        definition: String
    ) throws {
        guard !columnExists(database, table: table, column: column) else { return }
        let sql = "ALTER TABLE \(table) ADD COLUMN \(column) \(definition)"
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
            throw ContactTagStoreError.schemaFailed
        }
    }

    private func columnExists(_ database: OpaquePointer?, table: String, column: String) -> Bool {
        let sql = "PRAGMA table_info(\(table))"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            return false
        }
        defer { sqlite3_finalize(statement) }

        while sqlite3_step(statement) == SQLITE_ROW {
            guard let nameCString = sqlite3_column_text(statement, 1) else { continue }
            if String(cString: nameCString) == column {
                return true
            }
        }
        return false
    }
}

private enum ContactTagStoreError: Error {
    case openFailed
    case schemaFailed
}

private let tagStoreTransientDestructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
