import AppKit
import SwiftUI

/// AppKit tracking area. SwiftUI `onHover` misses enter/exit on glass and during drags.
struct HoverSensor: NSViewRepresentable {
    @Binding var isHovering: Bool

    func makeNSView(context: Context) -> HoverSensorView {
        let view = HoverSensorView()
        view.onChange = { hovering in
            if isHovering != hovering {
                isHovering = hovering
            }
        }
        return view
    }

    func updateNSView(_ nsView: HoverSensorView, context: Context) {
        nsView.onChange = { hovering in
            if isHovering != hovering {
                isHovering = hovering
            }
        }
    }
}

final class HoverSensorView: NSView {
    var onChange: ((Bool) -> Void)?
    private var tracking: NSTrackingArea?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) {
        onChange?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onChange?(false)
    }
}
