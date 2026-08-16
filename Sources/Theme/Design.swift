import SwiftUI
import UniformTypeIdentifiers

/// Visual tokens for Shelf. The panel is a single glass surface; cards are
/// solid objects that rest on a physical rail — not glass stacked on glass.
enum Design {
    static let panelRadius: CGFloat = 20
    static let cardRadius: CGFloat = 14
    static let cardWidth: CGFloat = 138
    static let cardHeight: CGFloat = 148
    static let railHeight: CGFloat = 7

    static let spring = Animation.spring(response: 0.38, dampingFraction: 0.72)
    static let snap = Animation.spring(response: 0.28, dampingFraction: 0.82)
    static let settle = Animation.spring(response: 0.46, dampingFraction: 0.68)

    static let accent = Color.accentColor

    static func cardFill(isSelected: Bool) -> Color {
        isSelected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04)
    }

    static func cardStroke(isSelected: Bool, isHovering: Bool) -> Color {
        if isSelected { return Color.accentColor.opacity(0.9) }
        if isHovering { return Color.primary.opacity(0.22) }
        return Color.primary.opacity(0.08)
    }
}

/// A physical ledge the cards sit on. The one memorable visual of the panel.
struct ShelfRail: View {
    var highlighted: Bool = false

    var body: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.primary.opacity(highlighted ? 0.28 : 0.16),
                        Color.primary.opacity(highlighted ? 0.10 : 0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.35))
                    .frame(height: 1)
                    .blendMode(.overlay)
            }
            .frame(height: Design.railHeight)
            .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
            .accessibilityHidden(true)
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
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.primary.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.16), lineWidth: 1)
            )
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
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08)))
            .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}


