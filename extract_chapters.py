#!/usr/bin/env python3
"""
Extract chapters from EPUB/PDF books in the Apple Books library and store
them in ~/Library/Application Support/BookShelf/chapters.sqlite.
Run this script once (or re-run to refresh). Already-extracted books are
skipped unless --force is passed.
"""

import sqlite3
import sys
import os
from pathlib import Path

BOOKS_DB = (
    Path.home()
    / "Library/Containers/com.apple.iBooksX/Data/Documents/BKLibrary/BKLibrary-1-091020131601.sqlite"
)
APP_SUPPORT = Path.home() / "Library/Application Support/BookShelf"
CHAPTERS_DB = APP_SUPPORT / "chapters.sqlite"


def open_chapters_db():
    APP_SUPPORT.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(CHAPTERS_DB)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS chapters (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            asset_id TEXT NOT NULL,
            chapter_num INTEGER NOT NULL,
            title TEXT NOT NULL,
            page_num INTEGER,
            done INTEGER NOT NULL DEFAULT 0,
            UNIQUE(asset_id, chapter_num)
        )
    """)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS extracted (
            asset_id TEXT PRIMARY KEY
        )
    """)
    conn.commit()
    return conn


def already_extracted(conn, asset_id):
    row = conn.execute("SELECT 1 FROM extracted WHERE asset_id=?", (asset_id,)).fetchone()
    return row is not None


def mark_extracted(conn, asset_id):
    conn.execute("INSERT OR IGNORE INTO extracted (asset_id) VALUES (?)", (asset_id,))
    conn.commit()


def save_chapters(conn, asset_id, chapters):
    for num, (title, page) in enumerate(chapters):
        conn.execute(
            "INSERT OR IGNORE INTO chapters (asset_id, chapter_num, title, page_num) VALUES (?,?,?,?)",
            (asset_id, num, title, page),
        )
    conn.commit()


def extract_epub_chapters(path):
    import ebooklib
    from ebooklib import epub

    try:
        book = epub.read_epub(path, options={"ignore_ncx": False})
    except Exception as e:
        print(f"  EPUB error: {e}")
        return []

    chapters = []

    def walk_toc(items, depth=0):
        for item in items:
            if isinstance(item, epub.Link):
                chapters.append((item.title or "Chapter", None))
            elif isinstance(item, tuple):
                section, children = item
                if hasattr(section, "title") and section.title:
                    chapters.append((section.title, None))
                walk_toc(children, depth + 1)

    walk_toc(book.toc)

    if not chapters:
        for item in book.get_items_of_type(ebooklib.ITEM_DOCUMENT):
            name = item.get_name()
            title = os.path.splitext(os.path.basename(name))[0].replace("-", " ").replace("_", " ").title()
            if title.lower() not in ("cover", "title", "copyright", "contents", "toc", "index"):
                chapters.append((title, None))

    return chapters


def extract_pdf_chapters(path):
    import fitz

    try:
        doc = fitz.open(path)
    except Exception as e:
        print(f"  PDF error: {e}")
        return []

    toc = doc.get_toc(simple=True)
    if toc:
        return [(title, page) for level, title, page in toc if level == 1 and title.strip()]

    # Fallback: no outline — return empty so we don't pollute with fake chapters
    return []


def load_books():
    with sqlite3.connect(BOOKS_DB) as conn:
        return conn.execute(
            "SELECT COALESCE(ZASSETID,''), COALESCE(ZTITLE,''), COALESCE(ZPATH,'') "
            "FROM ZBKLIBRARYASSET WHERE ZTITLE IS NOT NULL ORDER BY ZTITLE"
        ).fetchall()


def main():
    force = "--force" in sys.argv
    books = load_books()
    conn = open_chapters_db()

    skipped = 0
    for asset_id, title, path in books:
        if not asset_id or not path:
            continue
        if not force and already_extracted(conn, asset_id):
            skipped += 1
            continue
        if not os.path.exists(path):
            print(f"[skip] {title!r} — file not local")
            mark_extracted(conn, asset_id)
            continue

        ext = os.path.splitext(path)[1].lower()
        print(f"[{ext}] {title!r}")

        if ext == ".epub":
            chapters = extract_epub_chapters(path)
        elif ext == ".pdf":
            chapters = extract_pdf_chapters(path)
        else:
            chapters = []

        if chapters:
            print(f"  → {len(chapters)} chapters")
            # Remove old chapters if re-extracting
            conn.execute("DELETE FROM chapters WHERE asset_id=?", (asset_id,))
            conn.commit()
            save_chapters(conn, asset_id, chapters)
        else:
            print(f"  → no chapters found")

        mark_extracted(conn, asset_id)

    conn.close()
    if skipped:
        print(f"\n{skipped} books already extracted (use --force to re-run)")
    print("Done.")


if __name__ == "__main__":
    main()
