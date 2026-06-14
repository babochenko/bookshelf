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
                    ForEach($books) { $book in
                        BookCard(book: $book)
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 640, minHeight: 400)
        .task {
            books = BooksDatabase.loadBooks()
        }
    }
}

struct BookCard: View {
    @Binding var book: Book
    @State private var cover: NSImage?
    @State private var showChapters = false
    @State private var hasChapters = false

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

            HStack(spacing: 6) {
                statusButton
                if hasChapters {
                    Button {
                        showChapters = true
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Show chapters")
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { openBook() }
        .task {
            await loadCover()
            hasChapters = ChaptersDatabase.hasChapters(for: book.id)
        }
        .sheet(isPresented: $showChapters) {
            ChapterListView(book: book)
        }
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

    private var statusButton: some View {
        Menu {
            ForEach(ReadingStatus.allCases, id: \.rawValue) { s in
                Button {
                    book.status = s
                    BooksDatabase.saveStatus(s, for: book.id)
                } label: {
                    if s == book.status {
                        Label(s.label, systemImage: "checkmark")
                    } else {
                        Text(s.label)
                    }
                }
            }
        } label: {
            statusBadge(book.status)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .onTapGesture {} // absorb so card tap-to-open doesn't fire
    }

    private func statusBadge(_ status: ReadingStatus) -> some View {
        Text(status.label)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(statusColor(status).opacity(0.15))
            .foregroundColor(statusColor(status))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(statusColor(status).opacity(0.4), lineWidth: 0.5))
    }

    private func statusColor(_ status: ReadingStatus) -> Color {
        switch status {
        case .reading: return .blue
        case .nextUp:  return .orange
        case .toRead:  return .secondary
        case .read:    return .green
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
