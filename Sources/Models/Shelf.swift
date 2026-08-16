import Foundation
import SwiftData

/// A named collection of ordered items. Shelves feel like small physical
/// work surfaces rather than folders.
@Model
final class Shelf: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var sortIndex: Int
    var createdAt: Date
    var isInbox: Bool

    @Relationship(deleteRule: .cascade, inverse: \ShelfItem.shelf)
    var items: [ShelfItem] = []

    init(name: String, sortIndex: Int = 0, isInbox: Bool = false) {
        self.id = UUID()
        self.name = name
        self.sortIndex = sortIndex
        self.createdAt = Date()
        self.isInbox = isInbox
    }

    var sortedItems: [ShelfItem] {
        items.sorted { $0.sortIndex < $1.sortIndex }
    }
}
