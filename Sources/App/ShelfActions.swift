import AppKit

/// Shared actions used across the panel, menu bar and management window.
@MainActor
enum ShelfActions {

    static func open(_ item: ShelfItem) {
        item.lastUsedAt = Date()
        try? item.modelContext?.save()
        switch item.type {
        case .url:
            let raw = item.sourceURL ?? item.contentText ?? ""
            if let url = webURL(from: raw) {
                NSWorkspace.shared.open(url)
                return
            }
            copy(item)
        case .color, .email, .text, .code:
            copy(item)
        default:
            if let url = item.storedFileURL {
                NSWorkspace.shared.open(url)
            } else {
                copy(item)
            }
        }
    }

    static func copy(_ item: ShelfItem) {
        copy(items: [item])
    }

    static func copy(items: [ShelfItem]) {
        guard !items.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        var writers: [NSPasteboardWriting] = []
        var texts: [String] = []
        for item in items {
            item.lastUsedAt = Date()
            if let path = item.storedPath {
                writers.append(URL(fileURLWithPath: path) as NSURL)
            }
            let text = item.contentText ?? item.colorHex ?? item.sourceURL ?? item.title
            if !text.isEmpty { texts.append(text) }
        }
        if !writers.isEmpty {
            pasteboard.writeObjects(writers)
        }
        if !texts.isEmpty {
            pasteboard.setString(texts.joined(separator: "\n"), forType: .string)
        }
        try? items.first?.modelContext?.save()
        let label = items.count == 1 ? "Copied \(items[0].title)" : "Copied \(items.count) items"
        AppState.shared.showToast(label)
    }

    static func pin(_ item: ShelfItem) {
        item.isPinned.toggle()
        try? item.modelContext?.save()
    }

    static func archive(_ item: ShelfItem) {
        item.isArchived.toggle()
        try? item.modelContext?.save()
        AppState.shared.selectedItemIDs.remove(item.id)
        AppState.shared.showToast(item.isArchived ? "Archived" : "Restored")
    }

    static func move(_ item: ShelfItem, to shelf: Shelf) {
        item.shelf = shelf
        item.sortIndex = DataController.shared.nextSortIndex(in: shelf)
        try? item.modelContext?.save()
    }

    static func move(_ items: [ShelfItem], to shelf: Shelf) {
        for item in items {
            move(item, to: shelf)
        }
    }

    static func promptNewShelf() {
        if !StoreManager.shared.canCreateShelf {
            StoreManager.shared.requirePro(reason: "Unlimited shelves are part of Shelf Pro.")
            return
        }
        let alert = NSAlert()
        alert.messageText = "New Shelf"
        alert.informativeText = "Name this work surface."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.placeholderString = "Shelf name"
        alert.accessoryView = field
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        if alert.runModal() == .alertFirstButtonReturn {
            let shelf = DataController.shared.createShelf(named: field.stringValue)
            AppState.shared.setActiveShelf(shelf)
        }
    }

    static func promptRename(_ shelf: Shelf) {
        guard !shelf.isInbox else { return }
        let alert = NSAlert()
        alert.messageText = "Rename Shelf"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.stringValue = shelf.name
        alert.accessoryView = field
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        if alert.runModal() == .alertFirstButtonReturn {
            let trimmed = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                shelf.name = trimmed
                try? shelf.modelContext?.save()
            }
        }
    }

    static func confirmDelete(_ shelf: Shelf) {
        guard !shelf.isInbox else { return }
        let alert = NSAlert()
        alert.messageText = "Delete “\(shelf.name)”?"
        alert.informativeText = "Items on this shelf will be removed from Shelf."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            if AppState.shared.activeShelfID == shelf.id {
                AppState.shared.activeShelfID = DataController.shared.inbox?.id
            }
            DataController.shared.deleteShelf(shelf)
        }
    }

    static func switchShelf(delta: Int) {
        let shelves = DataController.shared.allShelves
        guard !shelves.isEmpty else { return }
        let currentID = AppState.shared.activeShelf?.id
        let current = shelves.firstIndex(where: { $0.id == currentID }) ?? 0
        var next = current + delta
        if next < 0 { next = shelves.count - 1 }
        if next >= shelves.count { next = 0 }
        AppState.shared.setActiveShelf(shelves[next])
    }

    static func switchShelf(index: Int) {
        let shelves = DataController.shared.allShelves
        guard shelves.indices.contains(index) else { return }
        AppState.shared.setActiveShelf(shelves[index])
    }

    static func webURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), url.scheme != nil { return url }
        if let url = URL(string: "https://\(trimmed)") { return url }
        return nil
    }
}
