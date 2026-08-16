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
}
