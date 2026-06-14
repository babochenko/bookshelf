import Foundation

enum ReadingStatus: Int, CaseIterable {
    case reading = 0
    case nextUp = 1
    case toRead = 2
    case read = 3

    var label: String {
        switch self {
        case .reading: return "READING"
        case .nextUp:  return "NEXT UP"
        case .toRead:  return "TO READ"
        case .read:    return "READ"
        }
    }

    var color: String {
        switch self {
        case .reading: return "blue"
        case .nextUp:  return "orange"
        case .toRead:  return "gray"
        case .read:    return "green"
        }
    }
}

struct Book: Identifiable {
    let id: String
    let title: String
    let author: String
    let filePath: String
    var status: ReadingStatus

    var fileURL: URL? {
        guard !filePath.isEmpty else { return nil }
        return URL(fileURLWithPath: filePath)
    }
}
