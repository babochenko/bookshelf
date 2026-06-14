import sqlite3
from pathlib import Path

db_path = (
    Path.home()
    / "Library/Containers/com.apple.iBooksX/Data/Documents/BKLibrary/BKLibrary-1-091020131601.sqlite"
)

with sqlite3.connect(db_path) as conn:
    cursor = conn.execute("""
        SELECT
            COALESCE(ZTITLE, ''),
            COALESCE(ZAUTHOR, ''),
            COALESCE(ZPATH, '')
        FROM ZBKLIBRARYASSET
        WHERE ZTITLE IS NOT NULL
        ORDER BY ZTITLE
    """)

    for title, author, path in cursor:
        print(f"Title : {title}")
        print(f"Author: {author}")
        print(f"Path  : {path}")
        print("-" * 80)

