import SwiftUI

extension Notification.Name {
    static let shelfPanelDidShow = Notification.Name("Shelf.panelDidShow")
    static let focusSearch = Notification.Name("Shelf.focusSearch")
}

/// Shared UI state injected as an environment object throughout the app.
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var activeShelfID: UUID? {
        didSet { UserDefaults.standard.set(activeShelfID?.uuidString, forKey: "activeShelfID") }
    }
    @Published var searchQuery = ""
    @Published var selectedItemIDs: Set<UUID> = []
    @Published var isPanelVisible = false
    @Published var toast: String?
    @Published var settlingItemIDs: Set<UUID> = []
    @Published var isDropTargeted = false

    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }

    /// Name of the app that was frontmost before Shelf became active.
    var lastExternalAppName: String?

    private var toastTask: Task<Void, Never>?
    private var settleTask: Task<Void, Never>?

    private init() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        if let raw = UserDefaults.standard.string(forKey: "activeShelfID"),
           let id = UUID(uuidString: raw) {
            activeShelfID = id
        }
    }

    var activeShelf: Shelf? {
        if let id = activeShelfID, let shelf = DataController.shared.shelf(id: id) {
            return shelf
        }
        return DataController.shared.inbox
    }

    func setActiveShelf(_ shelf: Shelf) {
        activeShelfID = shelf.id
        selectedItemIDs = []
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
    }

    func showToast(_ message: String) {
        toast = message
        toastTask?.cancel()
        toastTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_700_000_000)
            if !Task.isCancelled { self.toast = nil }
        }
    }

    func markSettling(_ ids: [UUID]) {
        settlingItemIDs.formUnion(ids)
        settleTask?.cancel()
        settleTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 520_000_000)
            if !Task.isCancelled { settlingItemIDs.removeAll() }
        }
    }
}
