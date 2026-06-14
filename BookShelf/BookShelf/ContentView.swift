import SwiftUI
import QuickLookThumbnailing

struct ContentView: View {
    @State private var books: [Book] = []
    @State private var booksWithChapters: Set<String> = []

    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 190), spacing: 20)]

    private var sections: [(ReadingStatus, [String])] {
        var grouped = [ReadingStatus: [String]]()
        for book in books { grouped[book.status, default: []].append(book.id) }
        return ReadingStatus.allCases.compactMap { status in
            guard let ids = grouped[status], !ids.isEmpty else { return nil }
            return (status, ids)
        }
    }

    var body: some View {
        ScrollView {
            if books.isEmpty {
                ProgressView("Loading library…").padding(60)
            } else {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(sections, id: \.0.rawValue) { status, ids in
                        Section {
                            LazyVGrid(columns: columns, spacing: 24) {
                                ForEach(ids, id: \.self) { id in
                                    BookCard(
                                        book: bookBinding(id: id),
                                        hasChapters: booksWithChapters.contains(id)
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 32)
                        } header: {
                            SectionHeader(status: status, count: ids.count)
                        }
                    }
                }
            }
        }
        .frame(minWidth: 640, minHeight: 400)
        .task {
            books = BooksDatabase.loadBooks()
            booksWithChapters = Set(books.filter { ChaptersDatabase.hasChapters(for: $0.id) }.map(\.id))
            await extractChapters()
        }
    }

    private func bookBinding(id: String) -> Binding<Book> {
        Binding(
            get: { books.first { $0.id == id } ?? Book(id: "", title: "", author: "", filePath: "", status: .toRead) },
            set: { new in
                if let i = books.firstIndex(where: { $0.id == id }) { books[i] = new }
            }
        )
    }

    private func extractChapters() async {
        for book in books where !booksWithChapters.contains(book.id) {
            let b = book
            Task.detached(priority: .background) {
                await ChapterExtractor.shared.extractIfNeeded(book: b)
                if ChaptersDatabase.hasChapters(for: b.id) {
                    _ = await MainActor.run { booksWithChapters.insert(b.id) }
                }
            }
        }
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let status: ReadingStatus
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 7, height: 7)
                Text(status.label)
                    .font(.system(size: 11, weight: .bold))
                    .kerning(0.8)
                    .foregroundColor(.secondary)
                Text("· \(count)")
                    .font(.system(size: 11))
                    .foregroundColor(Color.secondary.opacity(0.65))
            }
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 10)
            Divider()
        }
        .background(.regularMaterial)
    }

    private var statusColor: Color {
        switch status {
        case .reading: return .blue
        case .nextUp:  return .orange
        case .toRead:  return .secondary
        case .read:    return .green
        }
    }
}

// MARK: - Book card

struct BookCard: View {
    @Binding var book: Book
    let hasChapters: Bool
    @State private var cover: NSImage?
    @State private var showChapters = false
    @State private var readFraction: Double = 0

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

            HStack(spacing: 4) {
                statusMenu
                if hasChapters {
                    Button { showChapters = true } label: {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Show chapters")
                }
                if readFraction > 0 {
                    Spacer()
                    Text("\(Int(readFraction * 100))%")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
            }
            .frame(width: 160)
        }
        .contentShape(Rectangle())
        .onTapGesture { openBook() }
        .task {
            await loadCover()
            readFraction = ChaptersDatabase.readProgress(for: book.id)
        }
        .sheet(isPresented: $showChapters, onDismiss: {
            readFraction = ChaptersDatabase.readProgress(for: book.id)
        }) {
            ChapterListView(book: book)
        }
    }

    @ViewBuilder
    private var coverImage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(NSColor.windowBackgroundColor))
                .overlay(RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1))
            if let cover {
                Image(nsImage: cover)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.secondary.opacity(0.4))
            }
            // Progress bar pinned to the bottom edge
            if readFraction > 0 {
                VStack(spacing: 0) {
                    Spacer()
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(.black.opacity(0.22))
                        Rectangle()
                            .fill(.white.opacity(0.82))
                            .frame(width: 160 * readFraction)
                    }
                    .frame(height: 5)
                }
            }
        }
        .frame(width: 160, height: 213)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var statusMenu: some View {
        Menu {
            ForEach(ReadingStatus.allCases, id: \.rawValue) { s in
                Button {
                    book.status = s
                    BooksDatabase.saveStatus(s, for: book.id)
                } label: {
                    if s == book.status { Label(s.label, systemImage: "checkmark") }
                    else { Text(s.label) }
                }
            }
        } label: {
            statusBadge(book.status)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .onTapGesture {}
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
            NSWorkspace.shared.open(url); return
        }
        NSWorkspace.shared.open([url], withApplicationAt: booksURL, configuration: .init(), completionHandler: nil)
    }

    private func loadCover() async {
        guard let url = book.fileURL else { return }
        let req = QLThumbnailGenerator.Request(
            fileAt: url, size: CGSize(width: 320, height: 426), scale: 2.0, representationTypes: .thumbnail)
        if let thumb = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: req) {
            cover = thumb.nsImage
        }
    }
}
