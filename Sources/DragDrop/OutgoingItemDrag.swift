import AppKit
import UniformTypeIdentifiers

struct DragPayload {
    let title: String
    let filePath: String?
    let text: String?

    init(item: ShelfItem) {
        title = item.title
        filePath = item.storedPath
        text = item.contentText ?? item.sourceURL ?? item.colorHex
    }
}

/// Sandboxed file-promise drag so items actually land in Finder and other apps.
@MainActor
enum OutgoingItemDrag {
    private static var session: Session?

    static func begin(payloads: [DragPayload], event: NSEvent, view: NSView) {
        session = nil

        var draggingItems: [NSDraggingItem] = []
        let sessionHolder = Session()
        let origin = view.convert(event.locationInWindow, from: nil)
        let stackPreview = stackImage(for: payloads)

        for (index, payload) in payloads.enumerated() {
            let frame = NSRect(x: origin.x - 36 + CGFloat(index) * 8, y: origin.y - 36 - CGFloat(index) * 8, width: 72, height: 72)

            if let path = payload.filePath {
                let source = URL(fileURLWithPath: path)
                let type = UTType(filenameExtension: source.pathExtension) ?? .data
                let promise = NSFilePromiseProvider(fileType: type.identifier, delegate: sessionHolder)
                promise.userInfo = source
                sessionHolder.sources.append(source)
                let dragItem = NSDraggingItem(pasteboardWriter: promise)
                let preview = index == 0 ? stackPreview : nil
                dragItem.setDraggingFrame(frame, contents: preview ?? NSWorkspace.shared.icon(forFile: path))
                draggingItems.append(dragItem)
            } else if let text = payload.text, !text.isEmpty {
                let dragItem = NSDraggingItem(pasteboardWriter: text as NSString)
                dragItem.setDraggingFrame(frame, contents: nil)
                draggingItems.append(dragItem)
            }
        }

        guard !draggingItems.isEmpty else { return }
        session = sessionHolder
        view.beginDraggingSession(with: draggingItems, event: event, source: sessionHolder)
        PanelController.shared.itemDidBeginExternalDrag()
    }

    private static func stackImage(for payloads: [DragPayload]) -> NSImage {
        let size = NSSize(width: 88, height: 88)
        let image = NSImage(size: size)
        image.lockFocus()
        let count = min(payloads.count, 3)
        for index in (0..<count).reversed() {
            let inset = CGFloat(index) * 6
            let rect = NSRect(x: 8 + inset, y: 8 + inset, width: 64, height: 64)
            NSColor.white.withAlphaComponent(0.92).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10).fill()
            if let path = payloads[index].filePath {
                let icon = NSWorkspace.shared.icon(forFile: path)
                icon.draw(in: rect.insetBy(dx: 8, dy: 8))
            } else {
                let text = (payloads[index].title as NSString)
                text.draw(in: rect.insetBy(dx: 8, dy: 24), withAttributes: [
                    .font: NSFont.systemFont(ofSize: 9),
                    .foregroundColor: NSColor.labelColor
                ])
            }
        }
        if payloads.count > 1 {
            let badge = NSRect(x: 58, y: 58, width: 22, height: 16)
            NSColor.controlAccentColor.setFill()
            NSBezierPath(roundedRect: badge, xRadius: 6, yRadius: 6).fill()
            ("\(payloads.count)" as NSString).draw(in: badge.insetBy(dx: 4, dy: 1), withAttributes: [
                .font: NSFont.boldSystemFont(ofSize: 10),
                .foregroundColor: NSColor.white
            ])
        }
        image.unlockFocus()
        return image
    }

    final class Session: NSObject, NSDraggingSource, NSFilePromiseProviderDelegate {
        var sources: [URL] = []

        func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
            .copy
        }

        func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
            OutgoingItemDrag.session = nil
        }

        func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
            (filePromiseProvider.userInfo as? URL)?.lastPathComponent ?? "Shelf Item"
        }

        func filePromiseProvider(
            _ filePromiseProvider: NSFilePromiseProvider,
            writePromiseTo url: URL,
            completionHandler: @escaping (Error?) -> Void
        ) {
            guard let source = filePromiseProvider.userInfo as? URL else {
                completionHandler(NSError(domain: "Shelf", code: 1))
                return
            }
            do {
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                }
                try FileManager.default.copyItem(at: source, to: url)
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }

        func operationQueue(for filePromiseProvider: NSFilePromiseProvider) -> OperationQueue {
            .main
        }
    }
}
