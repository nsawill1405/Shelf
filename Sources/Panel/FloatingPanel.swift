import AppKit
import SwiftUI

/// The floating, non-activating borderless panel that hosts the shelf UI.
/// Window dragging is limited to the header handle so item drags can leave the panel.
final class FloatingPanel: NSPanel {
    var onBecomeKey: (() -> Void)?
    fileprivate var allowWindowDrag = false

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isMovableByWindowBackground = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow
        acceptsMouseMovedEvents = true
        becomesKeyOnlyIfNeeded = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    /// Keep the focused glass/label treatment even when another app is frontmost.
    @objc var hasKeyAppearance: Bool { true }
    @objc var hasMainAppearance: Bool { true }
    @objc func _hasActiveAppearance() -> Bool { true }
    @objc func _hasActiveAppearanceIgnoringKeyFocus() -> Bool { true }

    override func becomeKey() {
        super.becomeKey()
        onBecomeKey?()
    }

    override func performDrag(with event: NSEvent) {
        guard allowWindowDrag else { return }
        super.performDrag(with: event)
    }
}

/// Header-only drag region. `isMovableByWindowBackground` stays off so cards can drag out.
struct PanelMoveHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> MoveHandleView {
        MoveHandleView()
    }

    func updateNSView(_ nsView: MoveHandleView, context: Context) {}
}

final class MoveHandleView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }

    override func mouseDown(with event: NSEvent) {
        let panel = window as? FloatingPanel
        panel?.allowWindowDrag = true
        window?.performDrag(with: event)
        panel?.allowWindowDrag = false
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }
}

enum WindowStack {
    static let raised = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 2)
    static let base = NSWindow.Level.floating
}

/// Titled windows (Inbox / Paywall) keep the key appearance when another app is frontmost.
final class AlwaysActiveWindow: NSWindow {
    @objc var hasKeyAppearance: Bool { true }
    @objc var hasMainAppearance: Bool { true }
    @objc func _hasActiveAppearance() -> Bool { true }
    @objc func _hasActiveAppearanceIgnoringKeyFocus() -> Bool { true }
}

/// NSHostingView reports `mouseDownCanMoveWindow == true` when it is not opaque,
/// which steals item drags and moves the whole panel instead.
final class NonMovingHostingView<Content: View>: NSHostingView<Content> {
    override var mouseDownCanMoveWindow: Bool { false }
}
