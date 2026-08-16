import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var activationObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        StoreManager.shared.configure()
        PanelController.shared.prepare()
        GlobalShortcutController.shared.register()
        EdgeDropController.shared.start()
        observeAppActivation()
    }

    func applicationWillTerminate(_ notification: Notification) {
        GlobalShortcutController.shared.unregister()
        EdgeDropController.shared.stop()
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func observeAppActivation() {
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            let name = app.localizedName ?? ""
            if name != "Shelf", app.bundleIdentifier != Bundle.main.bundleIdentifier {
                Task { @MainActor in
                    AppState.shared.lastExternalAppName = name
                }
            }
        }
    }
}
