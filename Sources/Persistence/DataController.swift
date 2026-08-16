import Foundation
import SwiftData

/// Owns the SwiftData container and seeds the default Inbox shelf.
@MainActor
final class DataController {
    static let shared = DataController()

    let container: ModelContainer

    var context: ModelContext { container.mainContext }

    init(inMemory: Bool = false) {
        let schema = Schema([Shelf.self, ShelfItem.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Unable to create ModelContainer: \(error)")
        }
        seedIfNeeded()
    }

    private func seedIfNeeded() {
        let fetch = FetchDescriptor<Shelf>()
        let existing = (try? context.fetch(fetch)) ?? []
        guard existing.isEmpty else { return }
        let inbox = Shelf(name: "Inbox", sortIndex: 0, isInbox: true)
        context.insert(inbox)
        try? context.save()
    }

    var allShelves: [Shelf] {
        let fetch = FetchDescriptor<Shelf>(sortBy: [SortDescriptor(\.sortIndex)])
        return (try? context.fetch(fetch)) ?? []
    }

    var inbox: Shelf? {
        allShelves.first { $0.isInbox } ?? allShelves.first
    }

    var itemCount: Int {
        let fetch = FetchDescriptor<ShelfItem>()
        return (try? context.fetchCount(fetch)) ?? 0
    }

    func shelf(id: UUID) -> Shelf? {
        allShelves.first { $0.id == id }
    }

    func createShelf(named name: String) -> Shelf {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = trimmed.isEmpty ? "New Shelf" : trimmed
        let maxIndex = (allShelves.map(\.sortIndex).max() ?? -1) + 1
        let shelf = Shelf(name: title, sortIndex: maxIndex)
        context.insert(shelf)
        try? context.save()
        return shelf
    }

    func deleteShelf(_ shelf: Shelf) {
        for item in shelf.items {
            if let path = item.storedPath { ItemStorage.removeFile(atPath: path) }
        }
        context.delete(shelf)
        try? context.save()
    }

    func deleteItem(_ item: ShelfItem) {
        if let path = item.storedPath { ItemStorage.removeFile(atPath: path) }
        context.delete(item)
        try? context.save()
    }

    func nextSortIndex(in shelf: Shelf) -> Int {
        (shelf.items.map(\.sortIndex).max() ?? -1) + 1
    }

    func reorder(_ items: [ShelfItem], moving source: ShelfItem, before destination: ShelfItem?) {
        var ordered = items.sorted { $0.sortIndex < $1.sortIndex }
        guard let from = ordered.firstIndex(where: { $0.id == source.id }) else { return }
        ordered.remove(at: from)
        if let destination, let to = ordered.firstIndex(where: { $0.id == destination.id }) {
            ordered.insert(source, at: to)
        } else {
            ordered.append(source)
        }
        for (index, item) in ordered.enumerated() {
            item.sortIndex = index
        }
        try? context.save()
    }
}
