import Foundation
import SwiftData

@MainActor
enum ArchiveAdvisor {
    static func suggestions(from items: [ShelfItem]) -> [ShelfItem] {
        guard UserSettings.archiveSuggestionsEnabled else { return [] }
        let cutoff = Date().addingTimeInterval(-Double(UserSettings.archiveAfterDays) * 24 * 60 * 60)
        return items.filter { item in
            !item.isArchived && !item.isPinned && item.lastUsedAt < cutoff
        }
        .sorted { $0.lastUsedAt < $1.lastUsedAt }
    }

    static func archive(_ items: [ShelfItem]) {
        for item in items {
            item.isArchived = true
        }
        try? DataController.shared.context.save()
        AppState.shared.showToast(items.count == 1 ? "Archived 1 item" : "Archived \(items.count) items")
    }
}

enum ShelfSortMode: String, CaseIterable, Identifiable {
    case shelfOrder
    case recent
    case kind
    case unused

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shelfOrder: return "Shelf order"
        case .recent: return "Recently used"
        case .kind: return "Kind"
        case .unused: return "Least used"
        }
    }

    func sort(_ items: [ShelfItem]) -> [ShelfItem] {
        let pinned = items.filter(\.isPinned)
        let rest = items.filter { !$0.isPinned }
        let ordered: [ShelfItem]
        switch self {
        case .shelfOrder:
            ordered = rest.sorted { $0.sortIndex < $1.sortIndex }
        case .recent:
            ordered = rest.sorted { $0.lastUsedAt > $1.lastUsedAt }
        case .kind:
            ordered = rest.sorted {
                if $0.type.displayName == $1.type.displayName {
                    return $0.sortIndex < $1.sortIndex
                }
                return $0.type.displayName < $1.type.displayName
            }
        case .unused:
            ordered = rest.sorted { $0.lastUsedAt < $1.lastUsedAt }
        }
        return pinned.sorted { $0.sortIndex < $1.sortIndex } + ordered
    }
}
