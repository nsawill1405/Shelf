import AppKit
import UniformTypeIdentifiers

/// Invisible screen-edge drop targets so a drag from another app can summon Shelf.
/// Implemented with public NSPanel APIs — no private hot-corners.
@MainActor
final class EdgeDropController: NSObject, NSWindowDelegate {
    static let shared = EdgeDropController()

    private var strips: [EdgeStripPanel] = []
    private var screenObserver: NSObjectProtocol?

    private override init() {
        super.init()
    }

    func start() {
        rebuild()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.rebuild() }
        }
    }

    func stop() {
        strips.forEach { $0.orderOut(nil) }
        strips.removeAll()
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
            self.screenObserver = nil
        }
    }

    private func rebuild() {
        strips.forEach { $0.orderOut(nil) }
        strips.removeAll()
        for screen in NSScreen.screens {
            let frame = screen.frame
            let thickness: CGFloat = 16
            let right = EdgeStripPanel(contentRect: NSRect(x: frame.maxX - thickness, y: frame.minY, width: thickness, height: frame.height))
            let left = EdgeStripPanel(contentRect: NSRect(x: frame.minX, y: frame.minY, width: thickness, height: frame.height))
            strips.append(contentsOf: [right, left])
            right.orderFrontRegardless()
            left.orderFrontRegardless()
        }
    }
}

final class EdgeStripPanel: NSPanel {
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
    }

    convenience init(contentRect: NSRect) {
        self.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        contentView = EdgeStripView(frame: NSRect(origin: .zero, size: contentRect.size))
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class EdgeStripView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([
            .fileURL, .png, .tiff, .URL, .string, .rtf, .html,
            NSPasteboard.PasteboardType(UTType.image.identifier),
            NSPasteboard.PasteboardType(UTType.pdf.identifier),
            NSPasteboard.PasteboardType(UTType.rtf.identifier),
            NSPasteboard.PasteboardType(UTType.html.identifier)
        ])
    }

    required init?(coder: NSCoder) { nil }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        Task { @MainActor in
            if !PanelController.shared.isVisible {
                PanelController.shared.show()
            }
        }
        return .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pb = sender.draggingPasteboard
        let providers = pb.pasteboardItems?.compactMap { item -> NSItemProvider? in
            let provider = NSItemProvider()
            var registered = false
            for type in item.types {
                if let data = item.data(forType: type) {
                    provider.registerDataRepresentation(forTypeIdentifier: type.rawValue, visibility: .all) { completion in
                        completion(data, nil)
                        return nil
                    }
                    registered = true
                }
            }
            return registered ? provider : nil
        } ?? []

        Task { @MainActor in
            guard let shelf = AppState.shared.activeShelf else { return }
            let created = await ItemImporter.importProviders(providers, into: shelf, context: DataController.shared.context)
            if !created.isEmpty {
                Haptics.perform(.alignment)
                AppState.shared.showToast("Added to \(shelf.name)")
            }
        }
        return true
    }

}
