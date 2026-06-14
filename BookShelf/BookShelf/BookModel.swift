import Foundation

struct Book: Identifiable {
    let id: String
    let title: String
    let author: String
    let filePath: String

    var fileURL: URL? {
        guard !filePath.isEmpty else { return nil }
        return URL(fileURLWithPath: filePath)
    }
}
