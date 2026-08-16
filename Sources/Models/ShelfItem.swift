import Foundation
import SwiftData

/// A single reusable thing stored on a shelf.
@Model
final class ShelfItem {
    @Attribute(.unique) var id: UUID
    var typeRaw: String
    var title: String
    /// Original URL where appropriate (web link, or the source file URL).
    var sourceURL: String?
    /// Path inside Shelf's own Application Support container for copied binaries.
    var storedPath: String?
    /// Inline content for text / url / code / email / color items.
    var contentText: String?
    /// Hex colour value when the item is a colour.
    var colorHex: String?
    /// Full-text / OCR content used for search.
    var searchableText: String?
    var createdAt: Date
    var lastUsedAt: Date
    var originatingApp: String?
    var isPinned: Bool
    var isArchived: Bool = false
    var sortIndex: Int
    var contentHash: String? = nil
    var byteSize: Int64 = 0
    var pageTitle: String? = nil
    var faviconPath: String? = nil
    /// RTF or HTML bytes when the source provided formatted text.
    var richTextData: Data? = nil
    /// UTI of `richTextData` (`public.rtf` or `public.html`).
    var richTextType: String? = nil
    /// Items created in one drop share this so the panel can collapse them.
    var stackID: UUID? = nil
    /// When set, the item archives itself after this date instead of being deleted.
    var expiresAt: Date? = nil

    var shelf: Shelf?

    init(
        type: ItemType,
        title: String,
        sourceURL: String? = nil,
        storedPath: String? = nil,
        contentText: String? = nil,
        colorHex: String? = nil,
        searchableText: String? = nil,
        sortIndex: Int = 0
    ) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.title = title
        self.sourceURL = sourceURL
        self.storedPath = storedPath
        self.contentText = contentText
        self.colorHex = colorHex
        self.searchableText = searchableText
        self.createdAt = Date()
        self.lastUsedAt = Date()
        self.originatingApp = nil
        self.isPinned = false
        self.isArchived = false
        self.sortIndex = sortIndex
        self.contentHash = nil
        self.byteSize = 0
        self.pageTitle = nil
        self.faviconPath = nil
    }

    var type: ItemType {
        get { ItemType(rawValue: typeRaw) ?? .file }
        set { typeRaw = newValue.rawValue }
    }

    /// Resolved URL for items that have copied their content into Shelf's container.
    var storedFileURL: URL? {
        storedPath.map { URL(fileURLWithPath: $0) }
    }

    var hoverPreview: String? {
        if let hex = colorHex { return hex }
        if type == .url { return sourceURL ?? contentText }
        if let text = contentText?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            return String(text.prefix(180))
        }
        if type == .image, let ocr = searchableText, ocr != title, !ocr.isEmpty {
            return String(ocr.prefix(180))
        }
        return storedFileURL?.lastPathComponent
    }

    func matches(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return true }
        let haystack = [
            title, contentText, searchableText, sourceURL, colorHex,
            originatingApp, type.displayName, storedFileURL?.lastPathComponent,
            pageTitle
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        return haystack.localizedCaseInsensitiveContains(q)
    }

    var isExpiringSoon: Bool {
        guard let expiresAt, !isArchived else { return false }
        return expiresAt.timeIntervalSinceNow < 6 * 60 * 60
    }

    var expiryLabel: String? {
        guard let expiresAt, !isArchived else { return nil }
        if expiresAt.timeIntervalSinceNow <= 0 { return "Expired" }
        return "Until \(expiresAt.formatted(.dateTime.hour().minute()))"
    }
}
