import Foundation
import AppKit
import CoreTransferable
import UniformTypeIdentifiers

enum TransferError: Error { case unavailable }

/// Exports the most useful native representation of shelf item(s) so they can
/// be dropped straight into Finder or another application without manual export.
struct ShelfItemTransferable: Transferable {
    struct Payload: Sendable {
        let id: UUID
        let kind: ItemType
        let text: String?
        let filePath: String?
    }

    let payloads: [Payload]

    init(item: ShelfItem) {
        payloads = [Self.payload(for: item)]
    }

    init(items: [ShelfItem]) {
        payloads = items.map(Self.payload(for:))
    }

    var isGroup: Bool { payloads.count > 1 }

    private static func payload(for item: ShelfItem) -> Payload {
        Payload(
            id: item.id,
            kind: item.type,
            text: item.contentText ?? item.sourceURL ?? item.colorHex ?? item.title,
            filePath: item.storedPath
        )
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .shelfInternalItem) { value in
            let ids = value.payloads.map(\.id.uuidString).joined(separator: ",")
            return Data(ids.utf8)
        }
        DataRepresentation(exportedContentType: .plainText) { value in
            let lines = value.payloads.map { $0.text ?? ($0.filePath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "") }
            let text = lines.filter { !$0.isEmpty }.joined(separator: "\n")
            guard !text.isEmpty else { throw TransferError.unavailable }
            return Data(text.utf8)
        }
        DataRepresentation(exportedContentType: .url) { value in
            guard value.payloads.count == 1, value.payloads[0].kind == .url, let text = value.payloads[0].text else {
                throw TransferError.unavailable
            }
            return Data(text.utf8)
        }
        DataRepresentation(exportedContentType: .png) { value in
            guard value.payloads.count == 1, value.payloads[0].kind == .image,
                  let path = value.payloads[0].filePath,
                  let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
                throw TransferError.unavailable
            }
            return data
        }
        FileRepresentation(exportedContentType: .item) { value in
            let files = value.payloads.compactMap(\.filePath)
            guard files.count == 1 else { throw TransferError.unavailable }
            return SentTransferredFile(URL(fileURLWithPath: files[0]))
        }
    }

    /// AppKit writers so a mixed multi-select can leave as native files + text.
    static func pasteboardWriters(for items: [ShelfItem]) -> [NSPasteboardWriting] {
        var writers: [NSPasteboardWriting] = []
        for item in items {
            if let path = item.storedPath {
                writers.append(URL(fileURLWithPath: path) as NSURL)
            }
        }
        let texts = items.compactMap { $0.contentText ?? $0.sourceURL ?? $0.colorHex }
        if !texts.isEmpty {
            writers.append(texts.joined(separator: "\n") as NSString)
        }
        return writers
    }
}

enum InternalItemDrop {
    static func itemIDs(from providers: [NSItemProvider]) async -> [UUID] {
        var ids: [UUID] = []
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.shelfInternalItem.identifier) {
            let value = await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
                provider.loadDataRepresentation(forTypeIdentifier: UTType.shelfInternalItem.identifier) { data, _ in
                    continuation.resume(returning: data.flatMap { String(data: $0, encoding: .utf8) })
                }
            }
            if let value {
                ids.append(contentsOf: value.split(separator: ",").compactMap { UUID(uuidString: String($0)) })
            }
        }
        return ids
    }
}
