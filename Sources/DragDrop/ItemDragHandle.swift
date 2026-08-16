import AppKit
import SwiftUI

/// AppKit mouse source that owns the drag. SwiftUI gestures cannot start a
/// session that other apps will accept.
struct ItemDragHandle: NSViewRepresentable {
    var payloads: [DragPayload]
    var onClick: () -> Void
    var onDoubleClick: () -> Void

    func makeNSView(context: Context) -> ItemDragNSView {
        let view = ItemDragNSView()
        view.payloads = payloads
        view.onClick = onClick
        view.onDoubleClick = onDoubleClick
        return view
    }

    func updateNSView(_ view: ItemDragNSView, context: Context) {
        view.payloads = payloads
        view.onClick = onClick
        view.onDoubleClick = onDoubleClick
    }
}

final class ItemDragNSView: NSView {
    var payloads: [DragPayload] = []
    var onClick: (() -> Void)?
    var onDoubleClick: (() -> Void)?

    private var downEvent: NSEvent?
    private var isDragging = false

    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        downEvent = event
        isDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let downEvent, !isDragging else { return }
        let start = convert(downEvent.locationInWindow, from: nil)
        let now = convert(event.locationInWindow, from: nil)
        guard hypot(now.x - start.x, now.y - start.y) >= 6 else { return }
        isDragging = true
        OutgoingItemDrag.begin(payloads: payloads, event: event, view: self)
    }

    override func mouseUp(with event: NSEvent) {
        if !isDragging {
            if event.clickCount >= 2 {
                onDoubleClick?()
            } else {
                onClick?()
            }
        }
        downEvent = nil
        isDragging = false
    }
}
