import SwiftUI
import SwiftData

struct MenuBarView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: StoreManager
    @Query(sort: \Shelf.sortIndex) private var shelves: [Shelf]

    var body: some View {
        Button {
            PanelController.shared.show()
        } label: {
            Label("Open Shelf", systemImage: "tray.and.arrow.down.fill")
        }
        .keyboardShortcut(" ", modifiers: .option)

        Button("Capture Clipboard") {
            ClipboardService.captureToActiveShelf()
        }
        .keyboardShortcut(" ", modifiers: [.option, .shift])

        Divider()

        Menu("Active Shelf") {
            ForEach(shelves) { shelf in
                Button {
                    appState.setActiveShelf(shelf)
                } label: {
                    if shelf.id == appState.activeShelf?.id {
                        Label(shelf.name, systemImage: "checkmark")
                    } else {
                        Text(shelf.name)
                    }
                }
            }
        }

        Button("New Shelf…") {
            ShelfActions.promptNewShelf()
        }

        Divider()

        Button("Search Shelf") {
            PanelController.shared.show()
            NotificationCenter.default.post(name: .focusSearch, object: nil)
        }
        .keyboardShortcut("f", modifiers: [.command, .option])

        Button("Manage Shelves…") {
            AppWindows.shared.openManagement()
        }

        Divider()

        SettingsLink {
            Text("Preferences…")
        }

        if !store.isPro {
            Button("Upgrade to Shelf Pro") {
                AppWindows.shared.openPaywall()
            }
        }

        Divider()

        Button("Quit Shelf") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
