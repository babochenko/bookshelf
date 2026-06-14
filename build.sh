#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
SDK=$(xcrun --show-sdk-path --sdk macosx)
SRCDIR="$DIR/BookShelf/BookShelf"
APPDIR="$DIR/BookShelf.app"
ICNS="$APPDIR/Contents/Resources/BookShelf.icns"

# Icon (regenerate only when missing)
if [ ! -f "$ICNS" ]; then
    echo "Generating icon…"
    swift "$DIR/make_icon.swift"
fi

# Swift app
echo "Compiling…"
swiftc \
  -sdk "$SDK" \
  -target arm64-apple-macosx12.0 \
  -framework SwiftUI \
  -framework AppKit \
  -framework QuickLookThumbnailing \
  -framework PDFKit \
  -parse-as-library \
  -O \
  "$SRCDIR/BookShelfApp.swift" \
  "$SRCDIR/BookModel.swift" \
  "$SRCDIR/BooksDatabase.swift" \
  "$SRCDIR/ChaptersDatabase.swift" \
  "$SRCDIR/ChapterExtractor.swift" \
  "$SRCDIR/ContentView.swift" \
  "$SRCDIR/ChapterListView.swift" \
  -o "$APPDIR/Contents/MacOS/BookShelf"

echo "Built: $APPDIR"
