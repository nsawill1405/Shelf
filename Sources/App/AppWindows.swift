import AppKit
import SwiftUI

/// Owns the larger management and paywall windows (managed with AppKit so they
/// can be opened from the floating panel, which is hosted outside a SwiftUI scene).
@MainActor
final class AppWindows {
    static let shared = AppWindows()

    private var managementWindow: NSWindow?
    private var paywallWindow: NSWindow?

    private init() {}

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

    private func makeWindow<V: View>(root: V, title: String, size: NSSize) -> NSWindow {
        let host = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: host)
        window.title = title
        window.setContentSize(size)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }

    private func present(_ window: NSWindow?) {
        guard let window else { return }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
