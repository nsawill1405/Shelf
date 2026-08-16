import Foundation
import SwiftData

@MainActor
enum DuplicateDetector {
    static func existingItem(hash: String?, url: String? = nil, in context: ModelContext) -> ShelfItem? {
        let fetch = FetchDescriptor<ShelfItem>()
        let all = (try? context.fetch(fetch)) ?? []
        if let hash, !hash.isEmpty, let match = all.first(where: { $0.contentHash == hash }) {
            return match
        }
        if let url {
            let normalized = normalizeURL(url)
            if let match = all.first(where: {
                guard let existing = $0.sourceURL ?? ($0.type == .url ? $0.contentText : nil) else { return false }
                return normalizeURL(existing) == normalized
            }) {
                return match
            }
        }
        return nil
    }

    static func reuse(_ item: ShelfItem, on shelf: Shelf) {
        item.lastUsedAt = Date()
        item.isArchived = false
        if item.shelf?.id != shelf.id {
            item.shelf = shelf
            item.sortIndex = DataController.shared.nextSortIndex(in: shelf)
        }
        try? item.modelContext?.save()
        AppState.shared.showToast("Already on \(shelf.name) — brought it forward")
        AppState.shared.selectedItemIDs = [item.id]
    }

    static func normalizeURL(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasSuffix("/") { value.removeLast() }
        if let url = URL(string: value), let host = url.host {
            let path = url.path == "/" ? "" : url.path
            return "\(host.lowercased())\(path)"
        }
        return value.lowercased()
    }
}
