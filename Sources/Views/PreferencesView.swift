import SwiftUI
import SwiftData

struct PreferencesView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: StoreManager
    @Query(sort: \Shelf.sortIndex) private var shelves: [Shelf]

    @State private var toggleShortcut = ShortcutSettings.toggle
    @State private var captureShortcut = ShortcutSettings.capture
    @State private var hideAfterDrag = UserSettings.hideAfterDrag
    @State private var snapSide = UserSettings.snapSide
    @State private var searchAll = UserSettings.searchAllShelves

    var body: some View {
        TabView {
            general
                .tabItem { Label("General", systemImage: "gear") }
            shortcuts
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
            privacy
                .tabItem { Label("Privacy", systemImage: "lock.shield") }
            subscription
                .tabItem { Label("Subscription", systemImage: "sparkles") }
        }
        .frame(width: 520, height: 460)
        .onChange(of: toggleShortcut) {
            guard store.canCustomizeShortcuts else {
                toggleShortcut = ShortcutSettings.toggle
                store.requirePro(reason: "Custom shortcuts are part of Shelf Pro.")
                return
            }
            ShortcutSettings.toggle = toggleShortcut
            GlobalShortcutController.shared.register()
        }
        .onChange(of: captureShortcut) {
            guard store.canCustomizeShortcuts else {
                captureShortcut = ShortcutSettings.capture
                store.requirePro(reason: "Custom shortcuts are part of Shelf Pro.")
                return
            }
            ShortcutSettings.capture = captureShortcut
            GlobalShortcutController.shared.register()
        }
        .onChange(of: hideAfterDrag) { UserSettings.hideAfterDrag = hideAfterDrag }
        .onChange(of: snapSide) { UserSettings.snapSide = snapSide }
        .onChange(of: searchAll) { UserSettings.searchAllShelves = searchAll }
    }

    private var general: some View {
        Form {
            Section("Shelf") {
                Picker("New items go to", selection: Binding(
                    get: { appState.activeShelfID ?? DataController.shared.inbox?.id },
                    set: { if let id = $0 { appState.activeShelfID = id } }
                )) {
                    ForEach(shelves) { shelf in
                        Text(shelf.name).tag(Optional(shelf.id))
                    }
                }
                Picker("Position", selection: $snapSide) {
                    ForEach(PanelSnapSide.allCases) { side in
                        Text(side.title).tag(side)
                    }
                }
                Toggle("Hide after dragging an item out", isOn: $hideAfterDrag)
                Toggle("Search every shelf from the panel", isOn: $searchAll)
            }
            Section("Storage") {
                LabeledContent("On disk", value: ItemStorage.formattedUsage)
                LabeledContent("Items", value: "\(DataController.shared.itemCount)")
            }
        }
        .formStyle(.grouped)
    }

    private var shortcuts: some View {
        Form {
            Section("Global") {
                LabeledContent("Open Shelf") {
                    ShortcutRecorderView(shortcut: $toggleShortcut)
                        .disabled(!store.canCustomizeShortcuts && !store.isPro)
                }
                LabeledContent("Capture Clipboard") {
                    ShortcutRecorderView(shortcut: $captureShortcut)
                        .disabled(!store.canCustomizeShortcuts && !store.isPro)
                }
                if !store.isPro {
                    Text("Custom shortcuts unlock with Shelf Pro. Defaults stay available.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Section("While Shelf is open") {
                labeled("Search", "⌘F")
                labeled("New Shelf", "⌘N")
                labeled("Copy", "⌘C")
                labeled("Pin", "⌘P")
                labeled("Switch shelf", "⌘[  ⌘]  or  ⌘1–9")
                labeled("Quick Look", "Space")
                labeled("Open", "Return")
                labeled("Delete", "⌫")
                labeled("Preferences", "⌘,")
            }
        }
        .formStyle(.grouped)
    }

    private func labeled(_ title: String, _ keys: String) -> some View {
        LabeledContent(title) {
            Text(keys)
                .font(.callout.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    private var privacy: some View {
        Form {
            Section {
                Label("Everything stays on this Mac", systemImage: "lock.shield.fill")
                    .foregroundStyle(Color.accentColor)
                Text("Shelf is local-first. Clipboard contents, documents, screenshots and extracted OCR text are stored on-device and are never uploaded for normal Shelf functionality.")
                    .foregroundStyle(.secondary)
            }
            Section("RevenueCat") {
                Text("Shelf uses RevenueCat solely to verify your Shelf Pro subscription. No shelf content is sent to RevenueCat.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Section("Clipboard") {
                Text("Shelf never records clipboard history. Capture is always a deliberate shortcut or menu command.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var subscription: some View {
        Form {
            Section("Shelf Pro") {
                if store.isPro {
                    Label("Shelf Pro is active", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(Color.accentColor)
                } else {
                    Text("Unlock unlimited shelves, OCR search, multi-item drag and custom shortcuts.")
                        .foregroundStyle(.secondary)
                    Button("Upgrade to Shelf Pro") { AppWindows.shared.openPaywall() }
                    Button("Restore Purchases") { Task { await store.restore() } }
                }
            }
        }
        .formStyle(.grouped)
    }
}
