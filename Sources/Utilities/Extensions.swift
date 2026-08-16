import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// In-app identifier used for reordering and moving items between shelves.
    static let shelfInternalItem = UTType(exportedAs: "com.shelf.internal-item")

    static var cocoaColor: UTType { UTType("com.apple.cocoa.pasteboard.color") ?? .data }
}

extension Color {
    /// Builds a Color from a hex string like `#FF5733` or `FF5733`.
    init(hex: String) {
        var hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 3:
            (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (1, 1, 1)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: 1)
    }
}

extension View {
    func shelfCardChrome(isSelected: Bool, isHovering: Bool) -> some View {
        self
            .background(
                Design.cardShape.fill(Color.primary.opacity(isHovering && !isSelected ? 0.06 : 0))
            )
            .overlay(
                Design.cardShape
                    .strokeBorder(Color.accentColor, lineWidth: isSelected ? 1.5 : 0)
            )
    }

    /// Force the focused window treatment. Glass and controls read these.
    func alwaysActiveGlass() -> some View {
        self
            .environment(\.controlActiveState, .key)
            .environment(\.backgroundProminence, .standard)
    }
}
