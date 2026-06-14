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
        return appSupport.appendingPathComponent("BookShelf/chapters.sqlite").path
    }

    static func loadChapters(for assetId: String) -> [Chapter] {
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_close(db) }

        let sql = """
            SELECT id, chapter_num, title, page_num, done
            FROM chapters WHERE asset_id = ?
            ORDER BY chapter_num
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (assetId as NSString).utf8String, -1, nil)

        var chapters: [Chapter] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(stmt, 0))
            let num = Int(sqlite3_column_int(stmt, 1))
            let title = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? ""
            let page = sqlite3_column_type(stmt, 3) != SQLITE_NULL ? Int(sqlite3_column_int(stmt, 3)) : nil
            let done = sqlite3_column_int(stmt, 4) != 0
            chapters.append(Chapter(id: id, assetId: assetId, chapterNum: num, title: title, pageNum: page, done: done))
        }
        return chapters
    }

    static func setDone(_ done: Bool, chapterId: Int) {
        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else { return }
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "UPDATE chapters SET done=? WHERE id=?", -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, done ? 1 : 0)
        sqlite3_bind_int(stmt, 2, Int32(chapterId))
        sqlite3_step(stmt)
    }

    static func hasChapters(for assetId: String) -> Bool {
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return false }
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT 1 FROM chapters WHERE asset_id=? LIMIT 1", -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (assetId as NSString).utf8String, -1, nil)
        return sqlite3_step(stmt) == SQLITE_ROW
    }
}
