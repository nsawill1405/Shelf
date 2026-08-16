import Foundation
import UniformTypeIdentifiers

/// Fast, deterministic detection of item types. Deliberately no generative AI.
enum ItemClassifier {

    static func classify(text: String) -> ItemType {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .text }

        if detectColorHex(trimmed) != nil { return .color }
        if isEmail(trimmed) { return .email }
        if isURL(trimmed) { return .url }
        if looksLikeCode(text) { return .code }
        return .text
    }

    static func classify(fileExtension: String, utType: UTType?) -> ItemType {
        let ext = fileExtension.lowercased()
        if let utType {
            if utType.conforms(to: .image) { return .image }
            if utType.conforms(to: .pdf) { return .pdf }
            if utType.conforms(to: .folder) { return .folder }
            if utType.conforms(to: .sourceCode) { return .code }
            if utType.conforms(to: .text) { return .text }
        }
        switch ext {
        case "png", "jpg", "jpeg", "gif", "heic", "heif", "tiff", "webp", "bmp": return .image
        case "pdf": return .pdf
        case "txt", "md", "rtf", "rtfd": return .text
        case "swift", "c", "h", "cpp", "m", "mm", "py", "js", "ts", "tsx", "jsx", "go", "rs",
             "java", "kt", "rb", "sh", "zsh", "bash", "css", "scss", "html", "json", "yaml", "yml", "xml",
             "sql", "plist", "csv": return .code
        case "doc", "docx", "pages", "xls", "xlsx", "numbers", "ppt", "pptx", "key": return .document
        default: return .file
        }
    }

    // MARK: - Detectors

    static func detectColorHex(_ text: String) -> String? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let hexPatterns = ["^#[0-9A-Fa-f]{3}$", "^#[0-9A-Fa-f]{4}$", "^#[0-9A-Fa-f]{6}$", "^#[0-9A-Fa-f]{8}$"]
        for p in hexPatterns where t.range(of: p, options: .regularExpression) != nil {
            return t.uppercased()
        }
        // rgb(255, 87, 51)
        let rgb = "^rgb\\(\\s*(\\d{1,3})\\s*,\\s*(\\d{1,3})\\s*,\\s*(\\d{1,3})\\s*\\)$"
        if let match = t.range(of: rgb, options: [.regularExpression, .caseInsensitive]) {
            let nums = t[match].split { !$0.isNumber }.compactMap { Int($0) }
            if nums.count == 3, nums.allSatisfy({ $0 <= 255 }) {
                return String(format: "#%02X%02X%02X", nums[0], nums[1], nums[2])
            }
        }
        return nil
    }

    static func isEmail(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        return t.range(of: pattern, options: .regularExpression) != nil
    }

    static func isURL(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.contains("."), !t.contains(" ") else { return false }
        let lower = t.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") || lower.hasPrefix("www.") || lower.hasPrefix("ftp://") {
            return true
        }
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return false }
        let range = NSRange(t.startIndex..<t.endIndex, in: t)
        let matches = detector.matches(in: t, options: [], range: range)
        return matches.contains { $0.resultType == .link && $0.range == range }
    }

    static func looksLikeCode(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("\n") else { return false }
        let indicators = [
            "func ", "def ", "class ", "struct ", "enum ", "import ", "from ", "const ", "let ", "var ",
            "public ", "private ", "protected ", "static ", "void ", "int ", "return ", "async ", "await ",
            "=>", "===", "&&", "||", "#!/", "<html", "</", "<div", "<script", "console.log", "println",
            "package ", "use ", "require(", "export ", "interface ", "impl "
        ]
        let hits = indicators.filter { trimmed.localizedCaseInsensitiveContains($0) }.count
        return hits >= 2
    }
}
