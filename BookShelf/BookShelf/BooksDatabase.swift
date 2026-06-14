import Foundation
import SQLite3

enum BooksDatabase {
    static func loadBooks() -> [Book] {
        let dbPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Containers/com.apple.iBooksX/Data/Documents/BKLibrary/BKLibrary-1-091020131601.sqlite"
            )

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_close(db) }

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
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        var books: [Book] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            func col(_ i: Int32) -> String {
                guard let ptr = sqlite3_column_text(stmt, i) else { return "" }
                return String(cString: ptr)
            }
            books.append(Book(id: col(0), title: col(1), author: col(2), filePath: col(3)))
        }
        return books
    }
}
