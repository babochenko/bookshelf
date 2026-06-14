import Foundation
import SQLite3

struct Chapter: Identifiable {
    let id: Int
    let assetId: String
    let chapterNum: Int
    let title: String
    let pageNum: Int?
    var done: Bool
}

enum ChaptersDatabase {
    private static var dbPath: String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("BookShelf")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("chapters.sqlite").path
    }

    // MARK: - DB helpers

    private static func openRW() -> OpaquePointer? {
        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else { return nil }
        sqlite3_exec(db, """
            CREATE TABLE IF NOT EXISTS chapters (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                asset_id TEXT NOT NULL,
                chapter_num INTEGER NOT NULL,
                title TEXT NOT NULL,
                page_num INTEGER,
                done INTEGER NOT NULL DEFAULT 0,
                UNIQUE(asset_id, chapter_num)
            );
            CREATE TABLE IF NOT EXISTS extracted (
                asset_id TEXT PRIMARY KEY
            );
            """, nil, nil, nil)
        return db
    }

    private static func openRO() -> OpaquePointer? {
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return nil }
        return db
    }

    private static func bind(_ stmt: OpaquePointer?, _ i: Int32, _ s: String) {
        sqlite3_bind_text(stmt, i, (s as NSString).utf8String, -1, nil)
    }

    // MARK: - Chapter read/write

    static func loadChapters(for assetId: String) -> [Chapter] {
        guard let db = openRO() else { return [] }
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db,
            "SELECT id,chapter_num,title,page_num,done FROM chapters WHERE asset_id=? ORDER BY chapter_num",
            -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        bind(stmt, 1, assetId)
        var result: [Chapter] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id   = Int(sqlite3_column_int(stmt, 0))
            let num  = Int(sqlite3_column_int(stmt, 1))
            let title = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? ""
            let page = sqlite3_column_type(stmt, 3) != SQLITE_NULL ? Int(sqlite3_column_int(stmt, 3)) : nil
            let done = sqlite3_column_int(stmt, 4) != 0
            result.append(Chapter(id: id, assetId: assetId, chapterNum: num, title: title, pageNum: page, done: done))
        }
        return result
    }

    static func setDone(_ done: Bool, chapterId: Int) {
        guard let db = openRW() else { return }
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "UPDATE chapters SET done=? WHERE id=?", -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, done ? 1 : 0)
        sqlite3_bind_int(stmt, 2, Int32(chapterId))
        sqlite3_step(stmt)
    }

    static func hasChapters(for assetId: String) -> Bool {
        guard let db = openRO() else { return false }
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT 1 FROM chapters WHERE asset_id=? LIMIT 1", -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        bind(stmt, 1, assetId)
        return sqlite3_step(stmt) == SQLITE_ROW
    }

    // MARK: - Extraction tracking

    static func hasBeenExtracted(for assetId: String) -> Bool {
        guard let db = openRO() else { return false }
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT 1 FROM extracted WHERE asset_id=? LIMIT 1", -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        bind(stmt, 1, assetId)
        return sqlite3_step(stmt) == SQLITE_ROW
    }

    static func markExtracted(for assetId: String) {
        guard let db = openRW() else { return }
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "INSERT OR IGNORE INTO extracted (asset_id) VALUES (?)", -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        bind(stmt, 1, assetId)
        sqlite3_step(stmt)
    }

    static func saveChapters(_ chapters: [(String, Int?)], for assetId: String) {
        guard let db = openRW() else { return }
        defer { sqlite3_close(db) }
        // Delete stale chapters first
        var del: OpaquePointer?
        sqlite3_prepare_v2(db, "DELETE FROM chapters WHERE asset_id=?", -1, &del, nil)
        bind(del, 1, assetId)
        sqlite3_step(del)
        sqlite3_finalize(del)
        // Insert new
        for (i, (title, page)) in chapters.enumerated() {
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db,
                "INSERT OR IGNORE INTO chapters (asset_id,chapter_num,title,page_num) VALUES (?,?,?,?)",
                -1, &stmt, nil)
            bind(stmt, 1, assetId)
            sqlite3_bind_int(stmt, 2, Int32(i))
            bind(stmt, 3, title)
            if let p = page { sqlite3_bind_int(stmt, 4, Int32(p)) } else { sqlite3_bind_null(stmt, 4) }
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }
    }
}
