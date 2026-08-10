import BirthdayCore
import Foundation
import SQLite3

actor ContactSnapshotCache {
    private let databaseURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        databaseURL: URL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Birthday", isDirectory: true)
            .appendingPathComponent("contacts-cache.sqlite3")
    ) {
        self.databaseURL = databaseURL
    }

    func load(fieldAccessLevel: ContactFieldAccessLevel) -> ContactDataSnapshot? {
        do {
            let database = try openDatabase()
            defer { sqlite3_close(database) }
            try prepareSchema(database)

            let sql = "SELECT payload FROM contact_snapshots WHERE id = ? LIMIT 1"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
                return nil
            }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_text(statement, 1, cacheID(for: fieldAccessLevel), -1, transientDestructor)
            guard sqlite3_step(statement) == SQLITE_ROW,
                  let bytes = sqlite3_column_blob(statement, 0)
            else {
                return nil
            }

            let byteCount = Int(sqlite3_column_bytes(statement, 0))
            let data = Data(bytes: bytes, count: byteCount)
            let snapshot = try decoder.decode(ContactDataSnapshot.self, from: data)
            guard snapshot.fieldAccessLevel == fieldAccessLevel else {
                return nil
            }
            return snapshot
        } catch {
            return nil
        }
    }

    func save(_ snapshot: ContactDataSnapshot) {
        do {
            let database = try openDatabase()
            defer { sqlite3_close(database) }
            try prepareSchema(database)
            let data = try encoder.encode(snapshot)

            let sql = """
            INSERT OR REPLACE INTO contact_snapshots (id, field_access, loaded_at, payload)
            VALUES (?, ?, ?, ?)
            """
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
                return
            }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_text(statement, 1, cacheID(for: snapshot.fieldAccessLevel), -1, transientDestructor)
            sqlite3_bind_text(statement, 2, snapshot.fieldAccessLevel.rawValue, -1, transientDestructor)
            sqlite3_bind_double(statement, 3, snapshot.loadedAt.timeIntervalSince1970)
            _ = data.withUnsafeBytes { buffer in
                sqlite3_bind_blob(statement, 4, buffer.baseAddress, Int32(buffer.count), transientDestructor)
            }
            sqlite3_step(statement)
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
            throw CacheError.openFailed
        }
        return database
    }

    private func prepareSchema(_ database: OpaquePointer?) throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS contact_snapshots (
            id TEXT PRIMARY KEY NOT NULL,
            field_access TEXT NOT NULL,
            loaded_at REAL NOT NULL,
            payload BLOB NOT NULL
        );
        """
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
            throw CacheError.schemaFailed
        }
    }

    private func cacheID(for fieldAccessLevel: ContactFieldAccessLevel) -> String {
        "latest:\(fieldAccessLevel.rawValue)"
    }
}

private enum CacheError: Error {
    case openFailed
    case schemaFailed
}

private let transientDestructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
