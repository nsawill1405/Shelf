import SwiftUI
import UniformTypeIdentifiers

/// Visual tokens for Shelf. Surfaces use macOS 26 Liquid Glass.
enum Design {
    static let panelRadius: CGFloat = 22
    static let cardRadius: CGFloat = 16
    static let cardWidth: CGFloat = 138
    static let cardHeight: CGFloat = 148
    static let railHeight: CGFloat = 5

    static let spring = Animation.spring(response: 0.38, dampingFraction: 0.72)
    static let snap = Animation.spring(response: 0.28, dampingFraction: 0.82)
    static let settle = Animation.spring(response: 0.46, dampingFraction: 0.68)

    static let accent = Color.accentColor
    static let panelShape = RoundedRectangle(cornerRadius: panelRadius, style: .continuous)
    static let cardShape = RoundedRectangle(cornerRadius: cardRadius, style: .continuous)

    /// Label colors that stay readable on glass and never pick up the accent tint.
    enum Ink {
        static let title = Color(nsColor: .labelColor)
        static let body = Color(nsColor: .secondaryLabelColor)
        static let quiet = Color(nsColor: .tertiaryLabelColor)
    }
}

struct KeyboardKey: View {
    let label: String
    init(_ label: String) { self.label = label }

    var body: some View {
        Text(label)
            .font(.system(.caption, design: .rounded).weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .glassEffect(in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .accessibilityLabel(label)
    }
}

struct ToastBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.callout)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: .capsule)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}


