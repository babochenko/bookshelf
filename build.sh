#!/bin/bash
set -e

SDK=$(xcrun --show-sdk-path --sdk macosx)
SRCDIR="$(dirname "$0")/BookShelf/BookShelf"
APPDIR="$(dirname "$0")/BookShelf.app"

swiftc \
  -sdk "$SDK" \
  -target arm64-apple-macosx12.0 \
  -framework SwiftUI \
  -framework AppKit \
  -framework QuickLookThumbnailing \
  -parse-as-library \
  -O \
  "$SRCDIR/BookShelfApp.swift" \
  "$SRCDIR/BookModel.swift" \
  "$SRCDIR/BooksDatabase.swift" \
  "$SRCDIR/ChaptersDatabase.swift" \
  "$SRCDIR/ContentView.swift" \
  "$SRCDIR/ChapterListView.swift" \
  -o "$APPDIR/Contents/MacOS/BookShelf"

echo "Built: $APPDIR"
