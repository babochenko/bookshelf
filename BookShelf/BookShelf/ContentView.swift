import SwiftUI
import QuickLookThumbnailing

struct ContentView: View {
    @State private var books: [Book] = []

    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 190), spacing: 20)]

    var body: some View {
        ScrollView {
            if books.isEmpty {
                ProgressView("Loading library…")
                    .padding(60)
            } else {
                LazyVGrid(columns: columns, spacing: 24) {
                    ForEach(books) { book in
                        BookCard(book: book)
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .task {
            books = BooksDatabase.loadBooks()
        }
    }
}

struct BookCard: View {
    let book: Book
    @State private var cover: NSImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            coverImage
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

            Text(book.title)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(2)
                .frame(width: 160, alignment: .leading)

            Text(book.author)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(width: 160, alignment: .leading)
        }
        .contentShape(Rectangle())
        .onTapGesture { openBook() }
        .task { await loadCover() }
    }

    @ViewBuilder
    private var coverImage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(NSColor.windowBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                )
                .frame(width: 160, height: 213)

            if let cover {
                Image(nsImage: cover)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 160, height: 213)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.secondary.opacity(0.4))
            }
        }
    }

    private func openBook() {
        guard let url = book.fileURL else { return }
        guard let booksURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iBooksX") else {
            NSWorkspace.shared.open(url)
            return
        }
        NSWorkspace.shared.open([url], withApplicationAt: booksURL, configuration: .init(), completionHandler: nil)
    }

    private func loadCover() async {
        guard let url = book.fileURL else { return }
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: 320, height: 426),
            scale: 2.0,
            representationTypes: .thumbnail
        )
        if let thumbnail = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) {
            cover = thumbnail.nsImage
        }
    }
}
