import SwiftUI

/// Compact inspection card shown while the pointer is over an item.
struct ItemDescriptionCard: View {
    let item: ShelfItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(Design.Ink.title)
                .lineLimit(2)

            HStack(spacing: 6) {
                Text(item.type.displayName)
                if let app = item.originatingApp, !app.isEmpty {
                    Text("·")
                    Text(app)
                }
            }
            .font(.caption)
            .foregroundStyle(Design.Ink.body)

            if let preview = item.hoverPreview, preview != item.title {
                Text(preview)
                    .font(item.type == .code ? .system(size: 10, design: .monospaced) : .caption)
                    .foregroundStyle(Design.Ink.body)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Added \(item.createdAt.formatted(.relative(presentation: .named)))")
                .font(.caption2)
                .foregroundStyle(Design.Ink.quiet)
        }
        .padding(10)
        .frame(width: 220, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        .allowsHitTesting(false)
    }
}
