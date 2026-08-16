import AppKit
import SwiftData
import UniformTypeIdentifiers

/// Deliberate clipboard capture (never a background clipboard logger).
@MainActor
enum ClipboardService {

    static func captureToActiveShelf() {
        guard StoreManager.shared.requireCapacity(for: 1) else { return }
        let context = DataController.shared.context
        let shelf = activeShelf(in: context)
        let pasteboard = NSPasteboard.general

        // Files first.
        if let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !objects.isEmpty {
            ItemImporter.importFileURLs(objects, into: shelf, context: context)
            PanelController.shared.flashSuccess()
            return
        }

        // Image data.
        if let image = NSImage(pasteboard: pasteboard),
           let tiff = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff),
           let png = bitmap.representation(using: .png, properties: [:]) {
            ItemImporter.importImageData(png, ext: "png", into: shelf, context: context)
            PanelController.shared.flashSuccess()
            return
        }

        if let rtf = pasteboard.data(forType: .rtf) {
            let plain = pasteboard.string(forType: .string)
                ?? NSAttributedString(rtf: rtf, documentAttributes: nil)?.string
                ?? "Text"
            let item = ItemImporter.importText(plain, into: shelf, context: context)
            item.richTextData = rtf
            item.richTextType = UTType.rtf.identifier
            try? context.save()
            PanelController.shared.flashSuccess()
            return
        }

        if let html = pasteboard.data(forType: .html) {
            let plain = pasteboard.string(forType: .string) ?? "Text"
            let item = ItemImporter.importText(plain, into: shelf, context: context)
            item.richTextData = html
            item.richTextType = UTType.html.identifier
            try? context.save()
            PanelController.shared.flashSuccess()
            return
        }

        // Text.
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            ItemImporter.importText(text, into: shelf, context: context)
            PanelController.shared.flashSuccess()
            return
        }
    }

    private static func activeShelf(in context: ModelContext) -> Shelf {
        if let id = AppState.shared.activeShelfID, let shelf = DataController.shared.shelf(id: id) {
            return shelf
        }
        return DataController.shared.inbox ?? DataController.shared.createShelf(named: "Inbox")
    }
}
