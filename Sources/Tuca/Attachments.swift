import AppKit
import PDFKit
import Foundation

/// Arquivo solto no notch. É copiado para a pasta do chat, então toda CLI enxerga
/// o arquivo dentro do próprio diretório de trabalho.
struct Attachment: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let name: String
    let relativePath: String

    var isImage: Bool {
        ["png", "jpg", "jpeg", "gif", "webp", "heic", "tiff", "bmp"].contains(url.pathExtension.lowercased())
    }

    var symbol: String {
        switch url.pathExtension.lowercased() {
        case "pdf": "doc.richtext"
        case "csv", "xlsx", "xls", "numbers": "tablecells"
        case "md", "txt", "rtf", "docx", "doc": "doc.text"
        case "swift", "py", "js", "ts", "json", "sql", "qvs", "html", "css": "chevron.left.forwardslash.chevron.right"
        default: "doc"
        }
    }
}

enum AttachmentStore {
    static var dir: URL { HookServer.supportDir.appendingPathComponent("chat/attachments") }
    static let maxBytes = 50 * 1024 * 1024

    static func importFiles(_ urls: [URL]) -> (ok: [Attachment], skipped: [String]) {
        var ok: [Attachment] = []
        var skipped: [String] = []
        let fm = FileManager.default
        for src in urls where src.isFileURL {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: src.path, isDirectory: &isDir), !isDir.boolValue else {
                skipped.append(src.lastPathComponent + " (pasta)")
                continue
            }
            let size = (try? src.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            guard size <= maxBytes else {
                skipped.append(src.lastPathComponent + " (maior que 50 MB)")
                continue
            }
            let folderName = String(UUID().uuidString.prefix(8)).lowercased()
            let folder = dir.appendingPathComponent(folderName)
            let safe = sanitize(src.lastPathComponent)
            let dst = folder.appendingPathComponent(safe)
            do {
                try fm.createDirectory(at: folder, withIntermediateDirectories: true)
                try fm.copyItem(at: src, to: dst)
            } catch {
                skipped.append(src.lastPathComponent)
                continue
            }
            ok.append(Attachment(url: dst, name: src.lastPathComponent,
                                 relativePath: "attachments/\(folderName)/\(safe)"))
        }
        return (ok, skipped)
    }

    /// Nome sem espaços e acentos para funcionar com `@arquivo` nas CLIs.
    static func sanitize(_ name: String) -> String {
        let folded = name.folding(options: .diacriticInsensitive, locale: nil)
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        let s = String(String.UnicodeScalarView(folded.unicodeScalars.map { allowed.contains($0) ? $0 : "_" }))
        return s.isEmpty ? "arquivo" : s
    }

    /// Apaga anexos com mais de 7 dias.
    static func purgeOld(days: Double = 7) {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.creationDateKey]) else { return }
        let limit = Date().addingTimeInterval(-days * 86_400)
        for item in items {
            let created = (try? item.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
            if created < limit { try? fm.removeItem(at: item) }
        }
    }
}

extension Attachment {
    static let textExtensions: Set<String> = ["txt", "md", "csv", "tsv", "json", "xml", "yaml", "yml", "sql", "qvs",
                                              "swift", "py", "js", "ts", "tsx", "jsx", "html", "css", "sh", "log", "ini", "toml"]

    /// Conteúdo em texto para CLIs que não leem o arquivo sozinhas (PDF via PDFKit, texto direto).
    func inlineText(maxChars: Int = 60_000) -> String? {
        let ext = url.pathExtension.lowercased()
        var text: String?
        if ext == "pdf" {
            text = PDFDocument(url: url)?.string
        } else if Self.textExtensions.contains(ext) {
            text = (try? String(contentsOf: url, encoding: .utf8)) ?? (try? String(contentsOf: url, encoding: .isoLatin1))
        }
        guard var t = text?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
        if t.count > maxChars { t = String(t.prefix(maxChars)) + "\n[... cortado em \(maxChars) caracteres]" }
        return t
    }
}
