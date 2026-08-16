import AppKit
import UniformTypeIdentifiers

/// macOS Services entry so other apps can send the current selection to Shelf
/// without Shelf reading clipboard history.
final class ServicesProvider: NSObject {
    static let shared = ServicesProvider()

    func register() {
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
    }

    @objc func sendToShelf(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        Task { @MainActor in
            await importPasteboard(pboard)
        }
    }

    @MainActor
    private func importPasteboard(_ pboard: NSPasteboard) async {
        guard let shelf = AppState.shared.activeShelf ?? DataController.shared.inbox else { return }
        let context = DataController.shared.context
        stampOriginatingApp()

        if let urls = pboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            let created = ItemImporter.importFileURLs(urls, into: shelf, context: context)
            finish(created)
            return
        }

        if let image = NSImage(pasteboard: pboard),
           let tiff = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff),
           let png = bitmap.representation(using: .png, properties: [:]) {
            let created = ItemImporter.importImageData(png, ext: "png", into: shelf, context: context)
            finish(created.map { [$0] } ?? [])
            return
        }

        if let rtf = pboard.data(forType: .rtf) {
            let plain = pboard.string(forType: .string) ?? String(data: rtf, encoding: .utf8) ?? "Text"
            let item = ItemImporter.importText(plain, into: shelf, context: context)
            item.richTextData = rtf
            item.richTextType = UTType.rtf.identifier
            try? context.save()
            finish([item])
            return
        }

        if let html = pboard.data(forType: .html) {
            let plain = pboard.string(forType: .string) ?? "Text"
            let item = ItemImporter.importText(plain, into: shelf, context: context)
            item.richTextData = html
            item.richTextType = UTType.html.identifier
            try? context.save()
            finish([item])
            return
        }

        if let urlString = pboard.string(forType: .URL), !urlString.isEmpty {
            let created = ItemImporter.importText(urlString, type: .url, into: shelf, context: context)
            finish([created])
            return
        }

        if let text = pboard.string(forType: .string), !text.isEmpty {
            let created = ItemImporter.importText(text, into: shelf, context: context)
            finish([created])
        }
    }

    @MainActor
    private func stampOriginatingApp() {
        if let name = NSWorkspace.shared.frontmostApplication?.localizedName, name != "Shelf" {
            AppState.shared.lastExternalAppName = name
        }
    }

    @MainActor
    private func finish(_ created: [ShelfItem]) {
        guard !created.isEmpty else { return }
        Haptics.perform(.alignment)
        PanelController.shared.flashSuccess()
        AppState.shared.markSettling(created.map(\.id))
    }
}
