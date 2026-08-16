import Foundation

/// The kind of content a `ShelfItem` represents.
enum ItemType: String, Codable, CaseIterable, Identifiable, Sendable {
    case text
    case url
    case image
    case file
    case folder
    case pdf
    case color
    case code
    case email
    case document

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .text: return "Text"
        case .url: return "Link"
        case .image: return "Image"
        case .file: return "File"
        case .folder: return "Folder"
        case .pdf: return "PDF"
        case .color: return "Colour"
        case .code: return "Code"
        case .email: return "Email"
        case .document: return "Document"
        }
    }

    var systemImage: String {
        switch self {
        case .text: return "text.alignleft"
        case .url: return "link"
        case .image: return "photo"
        case .file: return "doc"
        case .folder: return "folder"
        case .pdf: return "doc.richtext"
        case .color: return "paintpalette"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .email: return "envelope"
        case .document: return "doc.text"
        }
    }
}
