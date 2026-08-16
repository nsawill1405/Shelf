import Foundation

enum PanelSnapSide: String, CaseIterable, Identifiable {
    case remember
    case left
    case right

    var id: String { rawValue }

    var title: String {
        switch self {
        case .remember: return "Remember last position"
        case .left: return "Snap left"
        case .right: return "Snap right"
        }
    }
}

/// Persisted preferences that are not keyboard shortcuts.
enum UserSettings {
    private static let hideAfterDragKey = "settings.hideAfterDrag"
    private static let snapSideKey = "settings.snapSide"
    private static let searchAllKey = "settings.searchAllShelves"
    private static let archiveEnabledKey = "settings.archiveSuggestions"
    private static let archiveDaysKey = "settings.archiveAfterDays"
    private static let sortModeKey = "settings.sortMode"

    static var hideAfterDrag: Bool {
        get { UserDefaults.standard.bool(forKey: hideAfterDragKey) }
        set { UserDefaults.standard.set(newValue, forKey: hideAfterDragKey) }
    }

    static var snapSide: PanelSnapSide {
        get {
            let raw = UserDefaults.standard.string(forKey: snapSideKey) ?? PanelSnapSide.remember.rawValue
            return PanelSnapSide(rawValue: raw) ?? .remember
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: snapSideKey) }
    }

    static var searchAllShelves: Bool {
        get { UserDefaults.standard.bool(forKey: searchAllKey) }
        set { UserDefaults.standard.set(newValue, forKey: searchAllKey) }
    }

    static var archiveSuggestionsEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: archiveEnabledKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: archiveEnabledKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: archiveEnabledKey) }
    }

    static var archiveAfterDays: Int {
        get {
            let value = UserDefaults.standard.integer(forKey: archiveDaysKey)
            return value == 0 ? 14 : value
        }
        set { UserDefaults.standard.set(newValue, forKey: archiveDaysKey) }
    }

    static var sortMode: ShelfSortMode {
        get { ShelfSortMode(rawValue: UserDefaults.standard.string(forKey: sortModeKey) ?? "") ?? .shelfOrder }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: sortModeKey) }
    }
}
