import AppKit
import Foundation
import SwiftData
import UniformTypeIdentifiers

/// Folder backup that can live in iCloud Drive. Content stays in files the user owns.
enum BackupService {
    private static let bookmarkKey = "backup.folderBookmark"

    static var folderURL: URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var stale = false
        let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )
        return url
    }

    static func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Use Folder"
        panel.message = "Choose an iCloud Drive folder (or any folder) for Shelf backups."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let data = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }
        UserDefaults.standard.set(data, forKey: bookmarkKey)
        Task { await exportNow() }
    }

    static func clearFolder() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
    }

    static func schedule() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            await exportNow()
        }
    }

    @MainActor
    static func exportNow() async {
        guard let folder = folderURL else { return }
        let started = folder.startAccessingSecurityScopedResource()
        defer { if started { folder.stopAccessingSecurityScopedResource() } }

        let root = folder.appendingPathComponent("ShelfBackup", isDirectory: true)
        let files = root.appendingPathComponent("files", isDirectory: true)
        try? FileManager.default.createDirectory(at: files, withIntermediateDirectories: true)

        let shelves = DataController.shared.allShelves
        guard let data = try? JSONSerialization.data(
            withJSONObject: [
                "version": 1,
                "exportedAt": ISO8601DateFormatter().string(from: Date()),
                "shelves": shelves.map { shelfJSON($0, filesDir: files) }
            ],
            options: [.prettyPrinted, .sortedKeys]
        ) else { return }
        try? data.write(to: root.appendingPathComponent("manifest.json"), options: .atomic)
    }

    private static func shelfJSON(_ shelf: Shelf, filesDir: URL) -> [String: Any] {
        [
            "id": shelf.id.uuidString,
            "name": shelf.name,
            "sortIndex": shelf.sortIndex,
            "isInbox": shelf.isInbox,
            "items": shelf.sortedItems.map { itemJSON($0, filesDir: filesDir) }
        ]
    }

    private static func itemJSON(_ item: ShelfItem, filesDir: URL) -> [String: Any] {
        var fileName: String?
        if let path = item.storedPath {
            let name = URL(fileURLWithPath: path).lastPathComponent
            let dest = filesDir.appendingPathComponent(name)
            if !FileManager.default.fileExists(atPath: dest.path) {
                try? FileManager.default.copyItem(at: URL(fileURLWithPath: path), to: dest)
            }
            fileName = name
        }
        return [
            "id": item.id.uuidString,
            "type": item.typeRaw,
            "title": item.title,
            "sourceURL": item.sourceURL as Any,
            "contentText": item.contentText as Any,
            "colorHex": item.colorHex as Any,
            "searchableText": item.searchableText as Any,
            "createdAt": item.createdAt.timeIntervalSince1970,
            "lastUsedAt": item.lastUsedAt.timeIntervalSince1970,
            "originatingApp": item.originatingApp as Any,
            "isPinned": item.isPinned,
            "isArchived": item.isArchived,
            "sortIndex": item.sortIndex,
            "contentHash": item.contentHash as Any,
            "byteSize": item.byteSize,
            "pageTitle": item.pageTitle as Any,
            "file": fileName as Any
        ]
    }

    @MainActor
    static func restore() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.json]
        panel.prompt = "Restore"
        panel.message = "Choose a ShelfBackup manifest.json"
        guard panel.runModal() == .OK, let url = panel.url,
              let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let shelves = root["shelves"] as? [[String: Any]]
        else { return }

        let filesDir = url.deletingLastPathComponent().appendingPathComponent("files", isDirectory: true)
        let context = DataController.shared.context
        for shelfJSON in shelves {
            let name = shelfJSON["name"] as? String ?? "Restored"
            let isInbox = shelfJSON["isInbox"] as? Bool ?? false
            let shelf: Shelf
            if isInbox, let inbox = DataController.shared.inbox {
                shelf = inbox
            } else {
                shelf = DataController.shared.createShelf(named: name)
            }
            for itemJSON in (shelfJSON["items"] as? [[String: Any]]) ?? [] {
                let type = ItemType(rawValue: itemJSON["type"] as? String ?? "") ?? .file
                let title = itemJSON["title"] as? String ?? "Item"
                var storedPath: String?
                if let file = itemJSON["file"] as? String {
                    let source = filesDir.appendingPathComponent(file)
                    if let copied = try? ItemStorage.copyIn(source) {
                        storedPath = copied.path
                    }
                }
                let item = ShelfItem(
                    type: type,
                    title: title,
                    sourceURL: itemJSON["sourceURL"] as? String,
                    storedPath: storedPath,
                    contentText: itemJSON["contentText"] as? String,
                    colorHex: itemJSON["colorHex"] as? String,
                    searchableText: itemJSON["searchableText"] as? String,
                    sortIndex: itemJSON["sortIndex"] as? Int ?? 0
                )
                item.pageTitle = itemJSON["pageTitle"] as? String
                item.contentHash = itemJSON["contentHash"] as? String
                item.originatingApp = itemJSON["originatingApp"] as? String
                item.isPinned = itemJSON["isPinned"] as? Bool ?? false
                item.isArchived = itemJSON["isArchived"] as? Bool ?? false
                item.shelf = shelf
                context.insert(item)
            }
        }
        try? context.save()
        AppState.shared.showToast("Backup restored")
    }
}
