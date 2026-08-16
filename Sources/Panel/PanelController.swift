import AppKit
import SwiftUI
import SwiftData

/// Creates, positions and toggles the floating shelf panel.
@MainActor
final class PanelController {
    static let shared = PanelController()

    private var panel: FloatingPanel?
    private var hostingView: NonMovingHostingView<AnyView>?
    private var keyMonitor: Any?
    private var hideAfterDragMonitor: Any?

    private let frameKey = "Shelf.panel.frame"

    private init() {}

    var isVisible: Bool { panel?.isVisible == true }

    func prepare() {
        guard panel == nil else { return }

        let root = ShelfPanelView()
            .modelContainer(DataController.shared.container)
            .environmentObject(AppState.shared)
            .environmentObject(StoreManager.shared)
        let host = NonMovingHostingView(rootView: AnyView(root.alwaysActiveGlass()))
        host.wantsLayer = true
        host.layer?.isOpaque = false
        host.layer?.backgroundColor = NSColor.clear.cgColor
        host.layer?.cornerRadius = Design.panelRadius
        host.layer?.masksToBounds = true

        let glass = NSGlassEffectView()
        glass.style = .regular
        glass.cornerRadius = Design.panelRadius
        glass.contentView = host

        let panel = FloatingPanel(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 520, height: 620))
        )
        panel.contentView = glass
        panel.contentMinSize = NSSize(width: 380, height: 400)

        hostingView = host
        self.panel = panel
        panel.onBecomeKey = { [weak self] in
            self?.bringToFront()
        }
        positionPanel(initial: true)
        installKeyMonitor()
    }

    func bringToFront() {
        guard let panel else { return }
        panel.level = WindowStack.raised
        AppWindows.shared.recedeBehindPanel()
        panel.orderFrontRegardless()
    }

    func recedeBehindManagement() {
        panel?.level = WindowStack.base
    }

    func toggle() {
        guard let panel else { return }
        if panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        guard let panel else { return }
        positionPanel(initial: false)
        let target = panel.frame
        var start = target
        let offset: CGFloat = 18
        switch UserSettings.snapSide {
        case .left:
            start.origin.x -= offset
        case .right, .remember:
            start.origin.x += offset
        }
        panel.alphaValue = 0
        panel.setFrame(start, display: true)
        bringToFront()
        panel.makeKey()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(target, display: true)
        }
        AppState.shared.isPanelVisible = true
        NotificationCenter.default.post(name: .shelfPanelDidShow, object: nil)
    }

    func hide() {
        guard let panel, panel.isVisible else { return }
        saveFrame()
        let target = panel.frame
        var end = target
        end.origin.x += UserSettings.snapSide == .left ? -14 : 14
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.16
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
            panel.animator().setFrame(end, display: true)
        } completionHandler: {
            panel.orderOut(nil)
            panel.alphaValue = 1
            panel.setFrame(target, display: false)
        }
        AppState.shared.isPanelVisible = false
        QuickLookController.shared.dismiss()
    }

    func flashSuccess() {
        Haptics.perform(.alignment)
        AppState.shared.showToast("Added to \(AppState.shared.activeShelf?.name ?? "Inbox")")
        if !isVisible { show() }
    }

    func resizeBy(_ deltaWidth: CGFloat, _ deltaHeight: CGFloat) {
        guard let panel else { return }
        let anchorRight = panel.frame.maxX
        let anchorTop = panel.frame.maxY
        var size = panel.frame.size
        size.width = min(980, max(panel.contentMinSize.width, size.width + deltaWidth))
        size.height = min(980, max(panel.contentMinSize.height, size.height + deltaHeight))
        var frame = panel.frame
        frame.size = size
        frame.origin.x = anchorRight - size.width
        frame.origin.y = anchorTop - size.height
        panel.setFrame(frame, display: true, animate: false)
        saveFrame()
    }

    func snap(to side: PanelSnapSide) {
        guard side != .remember else { return }
        UserSettings.snapSide = side
        guard let panel, let screen = panel.screen ?? screenContainingCursor() ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let x = side == .left ? visible.minX + 16 : visible.maxX - size.width - 16
        let y = min(panel.frame.minY, visible.maxY - size.height - 16)
        let frame = NSRect(x: x, y: max(visible.minY + 16, y), width: size.width, height: size.height)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(frame, display: true)
        }
        saveFrame()
    }

    func itemDidBeginExternalDrag() {
        guard UserSettings.hideAfterDrag else { return }
        if hideAfterDragMonitor != nil { return }
        hideAfterDragMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
            Task { @MainActor in
                self?.finishHideAfterDrag()
            }
        }
    }

    private func finishHideAfterDrag() {
        if let hideAfterDragMonitor {
            NSEvent.removeMonitor(hideAfterDragMonitor)
            self.hideAfterDragMonitor = nil
        }
        let location = NSEvent.mouseLocation
        if let panel, panel.frame.contains(location) { return }
        hide()
    }

    // MARK: - Keyboard navigation

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel?.isKeyWindow == true else { return event }
            return self.handleKey(event) ? nil : event
        }
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        let appState = AppState.shared
        let searchFocused = (panel?.firstResponder as? NSTextView) != nil
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if flags.contains(.command) {
            switch event.keyCode {
            case 3: // ⌘F
                NotificationCenter.default.post(name: .focusSearch, object: nil)
                return true
            case 8: // ⌘C
                if !searchFocused { copySelection(); return true }
            case 35: // ⌘P
                if !searchFocused { pinSelection(); return true }
            case 45: // ⌘N
                ShelfActions.promptNewShelf()
                return true
            case 43: // ⌘,
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                return true
            case 18, 19, 20, 21, 23, 22, 26, 28, 25: // ⌘1–9
                let map: [UInt16: Int] = [18: 0, 19: 1, 20: 2, 21: 3, 23: 4, 22: 5, 26: 6, 28: 7, 25: 8]
                if let index = map[event.keyCode] {
                    ShelfActions.switchShelf(index: index)
                    return true
                }
            case 33: // ⌘[
                ShelfActions.switchShelf(delta: -1)
                return true
            case 30: // ⌘]
                ShelfActions.switchShelf(delta: 1)
                return true
            default:
                break
            }
        }

        switch event.keyCode {
        case 53:
            if !appState.searchQuery.isEmpty {
                appState.searchQuery = ""
            } else {
                hide()
            }
            return true

        case 51, 117:
            if searchFocused { return false }
            deleteSelection()
            return true

        case 36, 76:
            if searchFocused && appState.selectedItemIDs.isEmpty {
                moveSelection(delta: 1)
            }
            openSelection()
            return true

        case 49:
            if searchFocused { return false }
            if !appState.selectedItemIDs.isEmpty {
                quickLookSelection()
                return true
            }
            return false

        case 123, 126:
            if searchFocused { return false }
            moveSelection(delta: -1)
            return true

        case 124, 125:
            if searchFocused { return false }
            moveSelection(delta: 1)
            return true

        default:
            return false
        }
    }

    private func selectedItems() -> [ShelfItem] {
        visibleItems().filter { AppState.shared.selectedItemIDs.contains($0.id) }
    }

    private func visibleItems() -> [ShelfItem] {
        let query = AppState.shared.searchQuery
        if UserSettings.searchAllShelves, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let fetch = FetchDescriptor<ShelfItem>(sortBy: [SortDescriptor(\.sortIndex)])
            let all = (try? DataController.shared.context.fetch(fetch)) ?? []
            return all.filter { !$0.isArchived && $0.matches(query) }
        }
        guard let shelf = AppState.shared.activeShelf else { return [] }
        let base = shelf.sortedItems.filter { !$0.isArchived }
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return base }
        return base.filter { $0.matches(query) }
    }

    private func moveSelection(delta: Int) {
        let items = visibleItems()
        guard !items.isEmpty else { return }
        let current: Int
        if let selectedID = AppState.shared.selectedItemIDs.first,
           let index = items.firstIndex(where: { $0.id == selectedID }) {
            current = index
        } else {
            current = delta > 0 ? -1 : 0
        }
        let next = min(max(current + delta, 0), items.count - 1)
        AppState.shared.selectedItemIDs = [items[next].id]
    }

    private func deleteSelection() {
        let items = selectedItems()
        AppState.shared.selectedItemIDs.removeAll()
        for item in items {
            DataController.shared.deleteItem(item)
        }
    }

    private func openSelection() {
        if AppState.shared.selectedItemIDs.isEmpty {
            moveSelection(delta: 1)
        }
        for item in selectedItems() {
            ShelfActions.open(item)
        }
    }

    private func copySelection() {
        let items = selectedItems()
        if items.isEmpty { return }
        ShelfActions.copy(items: items)
    }

    private func pinSelection() {
        for item in selectedItems() {
            ShelfActions.pin(item)
        }
    }

    private func quickLookSelection() {
        let urls = selectedItems().compactMap(\.storedFileURL)
        if !urls.isEmpty {
            QuickLookController.shared.preview(urls)
        }
    }

    // MARK: - Positioning

    private func positionPanel(initial: Bool) {
        guard let panel else { return }
        let screen = screenContainingCursor() ?? panel.screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size

        // Utility zone: trailing edge, just under the menu bar — same place Yoink / Notification Center use.
        let margin: CGFloat = 12
        let topGap: CGFloat = 48
        switch UserSettings.snapSide {
        case .left:
            panel.setFrameOrigin(NSPoint(x: visible.minX + margin, y: visible.maxY - size.height - topGap))
        case .right:
            panel.setFrameOrigin(NSPoint(x: visible.maxX - size.width - margin, y: visible.maxY - size.height - topGap))
        case .remember:
            if initial, let saved = UserDefaults.standard.string(forKey: frameKey), !saved.isEmpty {
                let frame = NSRectFromString(saved)
                if !frame.isEmpty, frame.width >= 200, frame.height >= 200, screensContain(frame) {
                    panel.setFrame(frame, display: false)
                    return
                }
            }
            panel.setFrameOrigin(NSPoint(
                x: visible.maxX - size.width - margin,
                y: visible.maxY - size.height - topGap
            ))
        }
    }

    private func screensContain(_ frame: NSRect) -> Bool {
        NSScreen.screens.contains { $0.visibleFrame.intersects(frame) }
    }

    private func saveFrame() {
        guard let panel else { return }
        UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: frameKey)
    }

    private func screenContainingCursor() -> NSScreen? {
        let location = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(location, $0.frame, false) }
    }
}
