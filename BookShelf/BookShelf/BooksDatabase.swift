import Foundation
import SQLite3

enum BooksDatabase {
    private static var statusDb: OpaquePointer?

    private static var statusDbPath: String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("BookShelf")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("statuses.sqlite").path
    }

    static func openStatusDb() -> OpaquePointer? {
        var db: OpaquePointer?
        guard sqlite3_open(statusDbPath, &db) == SQLITE_OK else { return nil }
        sqlite3_exec(db, """
            CREATE TABLE IF NOT EXISTS statuses (
                asset_id TEXT PRIMARY KEY,
                status INTEGER NOT NULL DEFAULT 2
            )
            """, nil, nil, nil)
        return db
    }

    static func loadBooks() -> [Book] {
        let appleDbPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Containers/com.apple.iBooksX/Data/Documents/BKLibrary/BKLibrary-1-091020131601.sqlite"
            )

        var appleDb: OpaquePointer?
        guard sqlite3_open_v2(appleDbPath.path, &appleDb, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_close(appleDb) }

        let statusDb = openStatusDb()
        defer { sqlite3_close(statusDb) }

        let sql = """
            SELECT
                COALESCE(ZASSETID, ''),
                COALESCE(ZTITLE, ''),
                COALESCE(ZAUTHOR, ''),
                COALESCE(ZPATH, '')
            FROM ZBKLIBRARYASSET
            WHERE ZTITLE IS NOT NULL
            ORDER BY ZTITLE
            """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(appleDb, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        var books: [Book] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            func col(_ i: Int32) -> String {
                guard let ptr = sqlite3_column_text(stmt, i) else { return "" }
                return String(cString: ptr)
            }
            let id = col(0)
            let rawStatus = loadStatus(for: id, db: statusDb)
            let status = ReadingStatus(rawValue: rawStatus) ?? .toRead
            books.append(Book(id: id, title: col(1), author: col(2), filePath: col(3), status: status))
        }

        return books.sorted { $0.status.rawValue < $1.status.rawValue }
    }

    private static func loadStatus(for assetId: String, db: OpaquePointer?) -> Int {
        guard let db else { return ReadingStatus.toRead.rawValue }
        var stmt: OpaquePointer?
        let sql = "SELECT status FROM statuses WHERE asset_id = ?"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return ReadingStatus.toRead.rawValue }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (assetId as NSString).utf8String, -1, nil)
        if sqlite3_step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int(stmt, 0))
        }
        return ReadingStatus.toRead.rawValue
    }

    static func saveStatus(_ status: ReadingStatus, for assetId: String) {
        let db = openStatusDb()
        defer { sqlite3_close(db) }
        let sql = "INSERT OR REPLACE INTO statuses (asset_id, status) VALUES (?, ?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (assetId as NSString).utf8String, -1, nil)
        sqlite3_bind_int(stmt, 2, Int32(status.rawValue))
        sqlite3_step(stmt)
    }
}
