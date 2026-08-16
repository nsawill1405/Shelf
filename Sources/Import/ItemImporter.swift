import Foundation
import AppKit
import SwiftData
import UniformTypeIdentifiers

/// Turns drag-and-drop / clipboard payloads into `ShelfItem` records.
@MainActor
enum ItemImporter {

    static func importProviders(
        _ providers: [NSItemProvider],
        into shelf: Shelf,
        context: ModelContext
    ) async -> [ShelfItem] {
        guard StoreManager.shared.requireCapacity(for: max(providers.count, 1)) else { return [] }
        var created: [ShelfItem] = []
        for provider in providers {
            if !StoreManager.shared.canAddItems(1) {
                StoreManager.shared.requireCapacity(for: 1)
                break
            }
            let items = await importProvider(provider, into: shelf, context: context)
            created.append(contentsOf: items)
        }
        if !created.isEmpty {
            try? context.save()
            AppState.shared.markSettling(created.map(\.id))
            AppState.shared.completeOnboarding()
        }
        return created
    }

    static func importProvider(
        _ provider: NSItemProvider,
        into shelf: Shelf,
        context: ModelContext
    ) async -> [ShelfItem] {
        if let fileURLs = await loadFileURLs(from: provider), !fileURLs.isEmpty {
            return importFileURLs(fileURLs, into: shelf, context: context)
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier),
           let data = await loadData(from: provider, forType: UTType.image.identifier),
           let ext = imageExtension(for: provider) {
            return [importImageData(data, ext: ext, into: shelf, context: context)].compactMap { $0 }
        }

        if let urlString = await loadString(from: provider, types: [.url]) {
            return [importText(urlString, type: .url, into: shelf, context: context)]
        }

        if let text = await loadString(from: provider, types: [.plainText, .text, .utf8PlainText]) {
            return [importText(text, type: ItemClassifier.classify(text: text), into: shelf, context: context)]
        }

        if let color = await loadColor(from: provider) {
            return [importColor(color, into: shelf, context: context)]
        }

        return []
    }

    @discardableResult
    static func importFileURLs(_ urls: [URL], into shelf: Shelf, context: ModelContext) -> [ShelfItem] {
        var items: [ShelfItem] = []
        for source in urls {
            let isDirectory = (try? source.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            let name = source.lastPathComponent
            let ext = source.pathExtension

            do {
                let stored = alreadyInStorage(source) ? source : try ItemStorage.copyIn(source)
                let hash = ContentHasher.hash(file: stored)
                if let existing = DuplicateDetector.existingItem(hash: hash, in: context) {
                    DuplicateDetector.reuse(existing, on: shelf)
                    continue
                }
                let type = isDirectory ? .folder : ItemClassifier.classify(fileExtension: ext, utType: source.utType)
                let item = ShelfItem(
                    type: type,
                    title: name,
                    sourceURL: source.absoluteString,
                    storedPath: stored.path,
                    searchableText: name,
                    sortIndex: nextIndex(in: shelf)
                )
                item.originatingApp = AppState.shared.lastExternalAppName
                item.contentHash = hash
                item.byteSize = ContentHasher.fileSize(at: stored)
                item.shelf = shelf
                context.insert(item)
                items.append(item)

                if type == .image, StoreManager.shared.canUseOCR {
                    OCRService.enqueue(imageFileAt: stored, for: item)
                }
            } catch {
                continue
            }
        }
        if !items.isEmpty {
            try? context.save()
            BackupService.schedule()
        }
        return items
    }

    @discardableResult
    static func importImageData(_ data: Data, ext: String, into shelf: Shelf, context: ModelContext) -> ShelfItem? {
        do {
            let stored = try ItemStorage.write(data, extension: ext)
            let hash = ContentHasher.hash(data: data)
            if let existing = DuplicateDetector.existingItem(hash: hash, in: context) {
                DuplicateDetector.reuse(existing, on: shelf)
                try? FileManager.default.removeItem(at: stored)
                return existing
            }
            let item = ShelfItem(
                type: .image,
                title: "Image.\(ext)",
                storedPath: stored.path,
                searchableText: "Image.\(ext)",
                sortIndex: nextIndex(in: shelf)
            )
            item.originatingApp = AppState.shared.lastExternalAppName
            item.contentHash = hash
            item.byteSize = Int64(data.count)
            item.shelf = shelf
            context.insert(item)
            try? context.save()
            if StoreManager.shared.canUseOCR {
                OCRService.enqueue(imageFileAt: stored, for: item)
            }
            return item
        } catch {
            return nil
        }
    }

    @discardableResult
    static func importText(_ text: String, type: ItemType? = nil, into shelf: Shelf, context: ModelContext) -> ShelfItem {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let detected = type ?? ItemClassifier.classify(text: trimmed)
        let hash = ContentHasher.hash(text: trimmed)
        let urlValue = detected == .url ? trimmed : nil
        if let existing = DuplicateDetector.existingItem(hash: hash, url: urlValue, in: context) {
            DuplicateDetector.reuse(existing, on: shelf)
            return existing
        }
        let title = (detected == .text || detected == .code) ? shortTitle(from: trimmed) : trimmed
        let item = ShelfItem(
            type: detected,
            title: title,
            sourceURL: urlValue,
            contentText: trimmed,
            colorHex: detected == .color ? ItemClassifier.detectColorHex(trimmed) : nil,
            searchableText: trimmed,
            sortIndex: nextIndex(in: shelf)
        )
        item.originatingApp = AppState.shared.lastExternalAppName
        item.contentHash = hash
        item.byteSize = Int64(trimmed.utf8.count)
        item.shelf = shelf
        context.insert(item)
        try? context.save()
        if detected == .url {
            URLPreviewService.enqueue(for: item)
        }
        BackupService.schedule()
        return item
    }

    @discardableResult
    static func importColor(_ color: NSColor, into shelf: Shelf, context: ModelContext) -> ShelfItem {
        let hex = color.hexString
        let hash = ContentHasher.hash(text: hex)
        if let existing = DuplicateDetector.existingItem(hash: hash, in: context) {
            DuplicateDetector.reuse(existing, on: shelf)
            return existing
        }
        let item = ShelfItem(
            type: .color,
            title: hex,
            colorHex: hex,
            searchableText: hex,
            sortIndex: nextIndex(in: shelf)
        )
        item.originatingApp = AppState.shared.lastExternalAppName
        item.contentHash = hash
        item.shelf = shelf
        context.insert(item)
        try? context.save()
        BackupService.schedule()
        return item
    }

    private static func shortTitle(from text: String) -> String {
        let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
        let clipped = String(trimmed.prefix(80))
        return clipped.isEmpty ? "Text" : clipped
    }

    private static func nextIndex(in shelf: Shelf) -> Int {
        (shelf.items.map(\.sortIndex).max() ?? -1) + 1
    }

    private static func alreadyInStorage(_ url: URL) -> Bool {
        url.path.hasPrefix(ItemStorage.storageDirectory.path)
    }

    private static func imageExtension(for provider: NSItemProvider) -> String? {
        if provider.hasItemConformingToTypeIdentifier(UTType.png.identifier) { return "png" }
        if provider.hasItemConformingToTypeIdentifier(UTType.jpeg.identifier) { return "jpg" }
        if provider.hasItemConformingToTypeIdentifier(UTType.tiff.identifier) { return "tiff" }
        if provider.hasItemConformingToTypeIdentifier(UTType.heic.identifier) { return "heic" }
        if provider.hasItemConformingToTypeIdentifier(UTType.gif.identifier) { return "gif" }
        return "png"
    }

    private static func loadFileURLs(from provider: NSItemProvider) async -> [URL]? {
        let identifier = UTType.fileURL.identifier
        guard provider.hasItemConformingToTypeIdentifier(identifier) else { return nil }
        return await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: identifier, options: nil) { item, _ in
                if let url = item as? URL {
                    continuation.resume(returning: [url])
                } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    continuation.resume(returning: [url])
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private static func loadData(from provider: NSItemProvider, forType identifier: String) async -> Data? {
        await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: identifier) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }

    private static func loadString(from provider: NSItemProvider, types: [UTType]) async -> String? {
        for type in types where provider.hasItemConformingToTypeIdentifier(type.identifier) {
            let value = await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
                provider.loadItem(forTypeIdentifier: type.identifier, options: nil) { item, _ in
                    if let string = item as? String {
                        continuation.resume(returning: string)
                    } else if let data = item as? Data {
                        continuation.resume(returning: String(data: data, encoding: .utf8))
                    } else if let url = item as? URL {
                        continuation.resume(returning: url.absoluteString)
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            }
            if let value, !value.isEmpty { return value }
        }
        return nil
    }

    private static func loadColor(from provider: NSItemProvider) async -> NSColor? {
        guard provider.hasItemConformingToTypeIdentifier(UTType.cocoaColor.identifier) else { return nil }
        return await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: UTType.cocoaColor.identifier) { data, _ in
                var color: NSColor?
                if let data {
                    color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
                }
                continuation.resume(returning: color)
            }
        }
    }
}

extension URL {
    var utType: UTType? {
        let values = try? resourceValues(forKeys: [.contentTypeKey])
        return values?.contentType
    }
}

extension NSColor {
    var hexString: String {
        let converted = usingColorSpace(.sRGB) ?? self
        let r = Int(round(converted.redComponent * 255))
        let g = Int(round(converted.greenComponent * 255))
        let b = Int(round(converted.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
