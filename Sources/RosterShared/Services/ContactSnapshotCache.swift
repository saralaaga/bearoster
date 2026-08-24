import RosterCore
import Foundation
import SQLite3

package actor ContactSnapshotCache {
    private let databaseURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    package init(
        databaseURL: URL = AppSupportPaths.database(named: "contacts-cache.sqlite3")
    ) {
        self.databaseURL = databaseURL
    }

    package func load(
        fieldAccessLevel: ContactFieldAccessLevel,
        accessScope: ContactAccessScope = .all
    ) -> ContactDataSnapshot? {
        do {
            let database = try openDatabase()
            defer { sqlite3_close(database) }
            try prepareSchema(database)

            guard let snapshot = loadSnapshot(
                database: database,
                cacheIDs: cacheIDs(for: fieldAccessLevel, accessScope: accessScope),
                fieldAccessLevel: fieldAccessLevel
            ) else {
                return nil
            }
            return snapshot
        } catch {
            return nil
        }
    }

    private func loadSnapshot(
        database: OpaquePointer?,
        cacheIDs: [String],
        fieldAccessLevel: ContactFieldAccessLevel
    ) -> ContactDataSnapshot? {
        let sql = "SELECT payload FROM contact_snapshots WHERE id = ? LIMIT 1"

        for cacheID in cacheIDs {
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
                continue
            }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_text(statement, 1, cacheID, -1, transientDestructor)
            guard sqlite3_step(statement) == SQLITE_ROW,
                  let bytes = sqlite3_column_blob(statement, 0)
            else {
                continue
            }

            let byteCount = Int(sqlite3_column_bytes(statement, 0))
            let data = Data(bytes: bytes, count: byteCount)
            guard let snapshot = try? decoder.decode(ContactDataSnapshot.self, from: data),
                  snapshot.fieldAccessLevel == fieldAccessLevel
            else {
                continue
            }
            return snapshot
        }

        return nil
    }

    package func save(_ snapshot: ContactDataSnapshot, accessScope: ContactAccessScope = .all) {
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

            sqlite3_bind_text(statement, 1, cacheID(for: snapshot.fieldAccessLevel, accessScope: accessScope), -1, transientDestructor)
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

    private func cacheID(
        for fieldAccessLevel: ContactFieldAccessLevel,
        accessScope: ContactAccessScope
    ) -> String {
        "latest:\(fieldAccessLevel.rawValue):\(accessScope.cacheKey)"
    }

    private func cacheIDs(
        for fieldAccessLevel: ContactFieldAccessLevel,
        accessScope: ContactAccessScope
    ) -> [String] {
        let scopedID = cacheID(for: fieldAccessLevel, accessScope: accessScope)
        guard accessScope == .all else { return [scopedID] }
        return [scopedID, "latest:\(fieldAccessLevel.rawValue)"]
    }
}

private enum CacheError: Error {
    case openFailed
    case schemaFailed
}

private let transientDestructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
