import RosterCore
import Foundation
import SQLite3

package actor LocalRosterStore {
    private let databaseURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    package init(
        databaseURL: URL = AppSupportPaths.database(named: "local-birthdays.sqlite3")
    ) {
        self.databaseURL = databaseURL
    }

    package func loadAll() -> [String: [RosterDateSpec]] {
        do {
            let database = try openDatabase()
            defer { sqlite3_close(database) }
            try prepareSchema(database)

            let sql = "SELECT person_id, payload FROM local_birthday_specs"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
                return [:]
            }
            defer { sqlite3_finalize(statement) }

            var result: [String: [RosterDateSpec]] = [:]
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let personIDCString = sqlite3_column_text(statement, 0),
                      let bytes = sqlite3_column_blob(statement, 1)
                else { continue }

                let personID = String(cString: personIDCString)
                let byteCount = Int(sqlite3_column_bytes(statement, 1))
                let data = Data(bytes: bytes, count: byteCount)
                if let specs = try? decoder.decode([RosterDateSpec].self, from: data) {
                    result[personID] = specs
                }
            }
            return result
        } catch {
            return [:]
        }
    }

    package func saveLocalOnlySpecs(_ specs: [RosterDateSpec], for personID: String) {
        do {
            let database = try openDatabase()
            defer { sqlite3_close(database) }
            try prepareSchema(database)

            if specs.isEmpty {
                let sql = "DELETE FROM local_birthday_specs WHERE person_id = ?"
                var statement: OpaquePointer?
                guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return }
                defer { sqlite3_finalize(statement) }
                sqlite3_bind_text(statement, 1, personID, -1, localRosterTransientDestructor)
                sqlite3_step(statement)
                return
            }

            let data = try encoder.encode(specs)
            let sql = """
            INSERT OR REPLACE INTO local_birthday_specs (person_id, updated_at, payload)
            VALUES (?, ?, ?)
            """
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
                return
            }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_text(statement, 1, personID, -1, localRosterTransientDestructor)
            sqlite3_bind_double(statement, 2, Date().timeIntervalSince1970)
            _ = data.withUnsafeBytes { buffer in
                sqlite3_bind_blob(statement, 3, buffer.baseAddress, Int32(buffer.count), localRosterTransientDestructor)
            }
            sqlite3_step(statement)
        } catch {
            return
        }
    }

    package func deleteLocalOnlySpecs(for personIDs: Set<String>) {
        guard !personIDs.isEmpty else { return }
        do {
            let database = try openDatabase()
            defer { sqlite3_close(database) }
            try prepareSchema(database)

            let sql = "DELETE FROM local_birthday_specs WHERE person_id = ?"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(statement) }

            for personID in personIDs {
                sqlite3_reset(statement)
                sqlite3_clear_bindings(statement)
                sqlite3_bind_text(statement, 1, personID, -1, localRosterTransientDestructor)
                sqlite3_step(statement)
            }
        } catch {
            return
        }
    }

    private func openDatabase() throws -> OpaquePointer? {
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var database: OpaquePointer?
        guard sqlite3_open(databaseURL.path, &database) == SQLITE_OK else {
            throw StoreError.openFailed
        }
        return database
    }

    private func prepareSchema(_ database: OpaquePointer?) throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS local_birthday_specs (
            person_id TEXT PRIMARY KEY NOT NULL,
            updated_at REAL NOT NULL,
            payload BLOB NOT NULL
        );
        """
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
            throw StoreError.schemaFailed
        }
    }
}

private enum StoreError: Error {
    case openFailed
    case schemaFailed
}

private let localRosterTransientDestructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
