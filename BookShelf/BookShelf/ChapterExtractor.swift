import Foundation
import PDFKit

actor ChapterExtractor {
    static let shared = ChapterExtractor()
    private var inProgress = Set<String>()

    func extractIfNeeded(book: Book) async {
        guard !ChaptersDatabase.hasBeenExtracted(for: book.id) else { return }
        await extract(book: book)
    }

    func extract(book: Book) async {
        guard !inProgress.contains(book.id) else { return }
        inProgress.insert(book.id)
        defer { inProgress.remove(book.id) }

        guard let url = book.fileURL,
              FileManager.default.fileExists(atPath: url.path) else {
            ChaptersDatabase.markExtracted(for: book.id)
            return
        }

        let chapters: [(String, Int?)]
        switch url.pathExtension.lowercased() {
        case "pdf":  chapters = extractPDF(url: url)
        case "epub": chapters = extractEPUB(url: url)
        default:     chapters = []
        }

        ChaptersDatabase.saveChapters(chapters, for: book.id)
        ChaptersDatabase.markExtracted(for: book.id)
    }

    // MARK: - PDF

    private func extractPDF(url: URL) -> [(String, Int?)] {
        guard let doc = PDFDocument(url: url),
              let root = doc.outlineRoot else { return [] }
        var result: [(String, Int?)] = []
        for i in 0..<root.numberOfChildren {
            guard let child = root.child(at: i) else { continue }
            let title = child.label ?? ""
            guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            var pageNum: Int?
            if let dest = child.destination, let page = dest.page {
                pageNum = doc.index(for: page) + 1
            }
            result.append((title, pageNum))
        }
        return result
    }

    // MARK: - EPUB

    private func extractEPUB(url: URL) -> [(String, Int?)] {
        guard let containerData = unzipEntry("META-INF/container.xml", from: url),
              let opfPath = parseContainerXML(containerData),
              let opfData = unzipEntry(opfPath, from: url) else { return [] }

        let opfDir = (opfPath as NSString).deletingLastPathComponent
        let (ncxPath, navPath) = parseOPF(opfData, baseDir: opfDir)

        if let path = ncxPath, let data = unzipEntry(path, from: url) {
            let chapters = parseNCX(data)
            if !chapters.isEmpty { return chapters }
        }
        if let path = navPath, let data = unzipEntry(path, from: url) {
            let chapters = parseNAV(data)
            if !chapters.isEmpty { return chapters }
        }
        return []
    }

    private func unzipEntry(_ entry: String, from url: URL) -> Data? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        proc.arguments = ["-p", url.path, entry]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        guard (try? proc.run()) != nil else { return nil }
        proc.waitUntilExit()
        let d = pipe.fileHandleForReading.readDataToEndOfFile()
        return d.isEmpty ? nil : d
    }

    private func parseContainerXML(_ data: Data) -> String? {
        guard let doc = try? XMLDocument(data: data, options: .nodeLoadExternalEntitiesNever) else { return nil }
        return (try? doc.nodes(forXPath: "//*[local-name()='rootfile']/@full-path"))?.first?.stringValue
    }

    private func parseOPF(_ data: Data, baseDir: String) -> (String?, String?) {
        guard let doc = try? XMLDocument(data: data, options: .nodeLoadExternalEntitiesNever) else { return (nil, nil) }
        let pre = baseDir.isEmpty ? "" : baseDir + "/"
        let ncx = (try? doc.nodes(forXPath: "//*[local-name()='item'][@media-type='application/x-dtbncx+xml']/@href"))?.first?.stringValue
        let nav = (try? doc.nodes(forXPath: "//*[local-name()='item'][contains(@properties,'nav')]/@href"))?.first?.stringValue
        return (ncx.map { pre + $0 }, nav.map { pre + $0 })
    }

    private func parseNCX(_ data: Data) -> [(String, Int?)] {
        guard let doc = try? XMLDocument(data: data, options: .nodeLoadExternalEntitiesNever) else { return [] }
        let nodes = (try? doc.nodes(forXPath:
            "//*[local-name()='navMap']/*[local-name()='navPoint']/*[local-name()='navLabel']/*[local-name()='text']"
        )) ?? []
        return nodes.compactMap {
            guard let t = $0.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
            return (t, nil)
        }
    }

    private func parseNAV(_ data: Data) -> [(String, Int?)] {
        guard let doc = try? XMLDocument(data: data, options: .nodeLoadExternalEntitiesNever) else { return [] }
        let nodes = (try? doc.nodes(forXPath:
            "//*[local-name()='nav']//*[local-name()='ol'][1]/*[local-name()='li']/*[local-name()='a']"
        )) ?? []
        return nodes.compactMap {
            guard let t = $0.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
            return (t, nil)
        }
    }
}
