import SwiftUI

@main
struct ShelfApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState.shared
    @StateObject private var store = StoreManager.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .modelContainer(DataController.shared.container)
                .environmentObject(appState)
                .environmentObject(store)
        } label: {
            Image(systemName: "tray.and.arrow.down.fill")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            PreferencesView()
                .modelContainer(DataController.shared.container)
                .environmentObject(appState)
                .environmentObject(store)
        }
    }
}
