import AppKit

/// A global keyboard shortcut: a Carbon key code plus modifier mask.
struct Shortcut: Codable, Equatable, Hashable {
    var keyCode: UInt32
    var modifiers: UInt32

    static let defaultToggle = Shortcut(keyCode: 49, modifiers: 0x0800)             // ⌥ Space
    static let defaultCapture = Shortcut(keyCode: 49, modifiers: 0x0800 | 0x0200)   // ⌥ ⇧ Space

    var isEmpty: Bool { modifiers == 0 }

    /// Human-readable form, e.g. "⌥ Space".
    var displayString: String {
        var out = ""
        if modifiers & 0x1000 != 0 { out += "⌃" }
        if modifiers & 0x0800 != 0 { out += "⌥" }
        if modifiers & 0x0200 != 0 { out += "⇧" }
        if modifiers & 0x0100 != 0 { out += "⌘" }
        out += keyName
        return out
    }

    var keyName: String {
        Self.keyNames[Int(keyCode)] ?? "Key \(keyCode)"
    }

    init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    init(event: NSEvent) {
        keyCode = UInt32(event.keyCode)
        var mods: UInt32 = 0
        let flags = event.modifierFlags
        if flags.contains(.control) { mods |= 0x1000 }
        if flags.contains(.option)  { mods |= 0x0800 }
        if flags.contains(.shift)   { mods |= 0x0200 }
        if flags.contains(.command) { mods |= 0x0100 }
        modifiers = mods
    }

    // macOS virtual key codes for the keys users typically pick.
    static let keyNames: [Int: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "Return",
        37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
        44: "/", 45: "N", 46: "M", 47: ".", 48: "Tab", 49: "Space",
        50: "`", 51: "Delete", 53: "Esc",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9",
        103: "F11", 105: "F13", 107: "F14", 109: "F10", 111: "F12",
        113: "F15", 114: "Help", 115: "Home", 116: "Page Up",
        117: "Fwd Delete", 118: "F4", 119: "End", 120: "F2",
        121: "Page Down", 122: "F1", 123: "←", 124: "→", 125: "↓", 126: "↑"
    ]
}

/// Persists the configurable global shortcuts.
enum ShortcutSettings {
    private static let toggleKey = "shortcut.toggle"
    private static let captureKey = "shortcut.capture"

    static var toggle: Shortcut {
        get { load(toggleKey, default: .defaultToggle) }
        set { save(newValue, for: toggleKey) }
    }

    static var capture: Shortcut {
        get { load(captureKey, default: .defaultCapture) }
        set { save(newValue, for: captureKey) }
    }

    private static func load(_ key: String, default fallback: Shortcut) -> Shortcut {
        guard let data = UserDefaults.standard.data(forKey: key),
              let shortcut = try? JSONDecoder().decode(Shortcut.self, from: data) else {
            return fallback
        }
        return shortcut
    }

    private static func save(_ shortcut: Shortcut, for key: String) {
        if let data = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
