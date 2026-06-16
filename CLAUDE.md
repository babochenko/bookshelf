# BookShelf

macOS SwiftUI app that reads the Apple Books library and adds chapter tracking.

## Build

```bash
./build.sh          # compile app (regenerates icon if missing)
swift make_icon.swift  # regenerate icon only
```

No Xcode installed — compiled with `swiftc` from Command Line Tools only.
Target: `arm64-apple-macosx12.0`, Swift 6.3.

After rebuilding, open with: `open BookShelf.app`

To refresh the Dock icon after icon changes:
```bash
rm -f ~/Library/Caches/com.apple.dock.iconcache && killall Dock
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f BookShelf.app
```

## Source files

All under `BookShelf/BookShelf/`:

| File | Purpose |
|------|---------|
| `BookShelfApp.swift` | `@main` entry point; sets `NSApplication.shared.applicationIconImage` on init |
| `BookModel.swift` | `Book` struct, `ReadingStatus` enum (reading=0/nextUp=1/toRead=2/read=3) |
| `BooksDatabase.swift` | Reads Apple Books SQLite (read-only) + `statuses.sqlite` for reading status |
| `ChaptersDatabase.swift` | `chapters.sqlite` — chapters, done state, progress, extraction tracking |
| `ChapterExtractor.swift` | `actor ChapterExtractor` — PDF (PDFKit outline) + EPUB (unzip + XMLDocument) |
| `ContentView.swift` | Main view: grid/list toggle, search, section headers, rescan button |
| `ChapterListView.swift` | Chapter sheet with checkboxes and read progress |

## Data

- Apple Books DB (read-only): `~/Library/Containers/com.apple.iBooksX/Data/Documents/BKLibrary/BKLibrary-1-091020131601.sqlite`, table `ZBKLIBRARYASSET`
- Reading statuses: `~/Library/Application Support/BookShelf/statuses.sqlite`
- Chapters: `~/Library/Application Support/BookShelf/chapters.sqlite`
- SQLite accessed via C API directly (`sqlite3_open_v2`, `sqlite3_prepare_v2`, etc.) — no ORM

## Frameworks

`SwiftUI`, `AppKit`, `QuickLookThumbnailing` (cover thumbnails), `PDFKit` (chapter extraction), `SQLite3`.

## Key design notes

- No Xcode project used for building — `build.sh` calls `swiftc` directly with all source files listed explicitly
- `BookShelf.app/` bundle is hand-crafted (Info.plist, icns) and committed to git, **except** the binary (`Contents/MacOS/BookShelf`) which is in `.gitignore`
- `icon_gen/` is also gitignored (generated output from `make_icon.swift`)
- Icon is drawn with CoreGraphics/AppKit in `make_icon.swift` (no external deps). Has 100px transparent margin at 1024px scale to match system icon visual size in Dock
- `@AppStorage("isListView")` persists grid/list toggle across launches
- `bookBinding(id:)` creates stable `Binding<Book>` keyed on book ID (not array index) for safe use inside `ForEach` sections
- Chapter extraction: `extract()` forces re-extraction; `extractIfNeeded()` skips books already in the `extracted` table. UI triggers via `Task.detached(priority: .background)` + `_ = await MainActor.run { ... }` for UI updates
- `BookCard` and `BookListRow` receive `onChaptersFound: () -> Void` callback; on success they call it so `ContentView` inserts the id into `booksWithChapters`, swapping the wand button for the chapter list button
- Cover thumbnails: `QLThumbnailGenerator` — 320×426 for grid cards, 72×96 for list rows
- Opening books: `NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iBooksX")` + `open(_:withApplicationAt:configuration:completionHandler:)` (the old `open(_:withAppBundleIdentifier:...)` API is deprecated)

## Chapter extraction internals

**PDF**: `PDFDocument(url:).outlineRoot` → iterate top-level children for title + page number.

**EPUB**: `Process` + `/usr/bin/unzip -p` to read entries without extracting, then `XMLDocument` XPath:
1. `META-INF/container.xml` → OPF path
2. OPF → NCX path (EPUB2) or NAV path (EPUB3)
3. NCX: `navMap > navPoint > navLabel > text`
4. NAV: `nav > ol[1] > li > a`

## Read progress calculation

Page-span weighted: each chapter's "weight" is the page gap to the next chapter; last chapter gets the average span of all preceding ones. Falls back to chapter-count ratio when page numbers are unavailable (common with EPUBs).

## Known constraints

- `windowResizability` / `defaultSize` modifiers require macOS 13+ — not used (target is 12.0)
- Apple Books DB path is hardcoded and specific to the standard iBooks container — may need updating if Apple changes it
- iOS port is not feasible: Apple Books DB is sandboxed on iOS and there's no URL scheme to open a specific owned book
