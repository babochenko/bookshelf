import SwiftUI

struct ChapterListView: View {
    let book: Book
    @State private var chapters: [Chapter] = []
    @Environment(\.dismiss) private var dismiss

    var doneCount: Int { chapters.filter(\.done).count }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if chapters.isEmpty {
                Spacer()
                Text("No chapters found for this book.")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                List($chapters) { $chapter in
                    ChapterRow(chapter: $chapter)
                }
                .listStyle(.plain)
            }
        }
        .frame(width: 420, height: 540)
        .task {
            chapters = ChaptersDatabase.loadChapters(for: book.id)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(book.author)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                if !chapters.isEmpty {
                    Text("\(doneCount) / \(chapters.count) chapters read")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
}

struct ChapterRow: View {
    @Binding var chapter: Chapter

    var body: some View {
        HStack(spacing: 10) {
            Button {
                chapter.done.toggle()
                ChaptersDatabase.setDone(chapter.done, chapterId: chapter.id)
            } label: {
                Image(systemName: chapter.done ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(chapter.done ? .green : .secondary)
                    .font(.system(size: 18))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text(chapter.title)
                    .font(.body)
                    .foregroundColor(chapter.done ? .secondary : .primary)
                    .strikethrough(chapter.done, color: .secondary)
                if let page = chapter.pageNum {
                    Text("p. \(page)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
