import AppKit
import SwiftUI

/// Owns the larger management and paywall windows (managed with AppKit so they
/// can be opened from the floating panel, which is hosted outside a SwiftUI scene).
@MainActor
final class AppWindows: NSObject, NSWindowDelegate {
    static let shared = AppWindows()

    private var managementWindow: NSWindow?
    private var paywallWindow: NSWindow?

    private override init() {
        super.init()
    }

    func openManagement() {
        if managementWindow == nil {
            let root = ManagementView()
                .modelContainer(DataController.shared.container)
                .environmentObject(AppState.shared)
                .environmentObject(StoreManager.shared)
            managementWindow = makeWindow(root: root, title: "Shelf", size: NSSize(width: 980, height: 660))
        }
        present(managementWindow)
    }

    func openPaywall() {
        if paywallWindow == nil {
            let root = PaywallView()
                .environmentObject(StoreManager.shared)
            paywallWindow = makeWindow(root: root, title: "Shelf Pro", size: NSSize(width: 440, height: 600))
        }
        present(paywallWindow)
    }

    func recedeBehindPanel() {
        managementWindow?.level = WindowStack.base
        paywallWindow?.level = WindowStack.base
    }

    func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        window.level = WindowStack.raised
        PanelController.shared.recedeBehindManagement()
        if window !== managementWindow {
            managementWindow?.level = WindowStack.base
        }
        if window !== paywallWindow {
            paywallWindow?.level = WindowStack.base
        }
    }

    private func makeWindow<V: View>(root: V, title: String, size: NSSize) -> NSWindow {
        let host = NSHostingController(rootView: AnyView(root.alwaysActiveGlass()))
        let window = AlwaysActiveWindow(contentViewController: host)
        window.title = title
        window.setContentSize(size)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .visible
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        return window
    }

    private func present(_ window: NSWindow?) {
        guard let window else { return }
        window.level = WindowStack.raised
        PanelController.shared.recedeBehindManagement()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
