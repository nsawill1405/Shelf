import AppKit
import Carbon.HIToolbox

/// System-wide keyboard shortcuts using the Carbon hotkey API (public API, no
/// accessibility permission required). Shortcuts are user-configurable and
/// re-registered whenever they change.
final class GlobalShortcutController {
    static let shared = GlobalShortcutController()

    struct HotKeyID {
        static let toggle: UInt32 = 1
        static let capture: UInt32 = 2
        static let signature: OSType = 0x53484631 // "SHF1"
    }

    private var handlerRef: EventHandlerRef?
    private var toggleRef: EventHotKeyRef?
    private var captureRef: EventHotKeyRef?

    private init() {}

    func register() {
        unregister()
        installHandler()

        let toggle = ShortcutSettings.toggle
        let capture = ShortcutSettings.capture

        if !toggle.isEmpty {
            RegisterEventHotKey(
                toggle.keyCode,
                toggle.modifiers,
                EventHotKeyID(signature: HotKeyID.signature, id: HotKeyID.toggle),
                GetEventDispatcherTarget(),
                0,
                &toggleRef
            )
        }
        if !capture.isEmpty {
            RegisterEventHotKey(
                capture.keyCode,
                capture.modifiers,
                EventHotKeyID(signature: HotKeyID.signature, id: HotKeyID.capture),
                GetEventDispatcherTarget(),
                0,
                &captureRef
            )
        }
    }

    func unregister() {
        if let ref = toggleRef {
            UnregisterEventHotKey(ref)
            toggleRef = nil
        }
        if let ref = captureRef {
            UnregisterEventHotKey(ref)
            captureRef = nil
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
    }

    private func installHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetEventDispatcherTarget(),
            shelfHotKeyHandler,
            1,
            &eventType,
            nil,
            &handlerRef
        )
    }
}

/// C-compatible event handler; routes on the main queue.
private func shelfHotKeyHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event else { return noErr }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else { return noErr }
    let id = hotKeyID.id
    DispatchQueue.main.async {
        if id == GlobalShortcutController.HotKeyID.toggle {
            PanelController.shared.toggle()
        } else if id == GlobalShortcutController.HotKeyID.capture {
            ClipboardService.captureToActiveShelf()
        }
    }
    return noErr
}
