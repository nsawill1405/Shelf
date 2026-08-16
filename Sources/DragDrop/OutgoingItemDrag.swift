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

        for (index, payload) in payloads.enumerated() {
            let frame = NSRect(x: origin.x - 32 + CGFloat(index) * 6, y: origin.y - 32 - CGFloat(index) * 6, width: 64, height: 64)

            if let path = payload.filePath {
                let source = URL(fileURLWithPath: path)
                let type = UTType(filenameExtension: source.pathExtension) ?? .data
                let promise = NSFilePromiseProvider(fileType: type.identifier, delegate: sessionHolder)
                promise.userInfo = source
                sessionHolder.sources.append(source)
                let dragItem = NSDraggingItem(pasteboardWriter: promise)
                let icon = NSWorkspace.shared.icon(forFile: path)
                icon.size = NSSize(width: 56, height: 56)
                dragItem.setDraggingFrame(frame, contents: icon)
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
