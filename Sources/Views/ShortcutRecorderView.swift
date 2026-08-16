import SwiftUI
import AppKit

/// A control that captures a keyboard shortcut when clicked.
struct ShortcutRecorderView: View {
    @Binding var shortcut: Shortcut
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            beginRecording()
        } label: {
            Text(isRecording ? "Press keys…" : shortcut.displayString)
                .font(.system(.callout, design: .monospaced))
                .frame(minWidth: 110)
                .contentTransition(.numericText())
        }
        .buttonStyle(.bordered)
        .tint(isRecording ? Color.orange : Color.accentColor)
        .help(isRecording ? "Press a key combination, or Esc to cancel" : "Click to change shortcut")
    }

    private func beginRecording() {
        isRecording = true
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Esc cancels
                endRecording()
                return nil
            }
            let candidate = Shortcut(event: event)
            if candidate.modifiers != 0 {
                shortcut = candidate
            }
            endRecording()
            return nil
        }
    }

    private func endRecording() {
        isRecording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
