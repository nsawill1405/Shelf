import SwiftUI
import AppKit
import SwiftData
import UniformTypeIdentifiers

struct ShelfSwitcherView: View {
    @EnvironmentObject private var appState: AppState
    @Query(sort: \Shelf.sortIndex) private var shelves: [Shelf]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(shelves) { shelf in
                    chip(for: shelf)
                }
                Button {
                    ShelfActions.promptNewShelf()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .background(Circle().fill(Color.primary.opacity(0.06)))
                .help("New Shelf")
                .accessibilityLabel("New Shelf")
            }
            .padding(.vertical, 2)
        }
    }

    private func chip(for shelf: Shelf) -> some View {
        let isActive = shelf.id == appState.activeShelf?.id
        return Button {
            withAnimation(Design.snap) {
                appState.setActiveShelf(shelf)
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: shelf.isInbox ? "tray" : "square.stack")
                    .font(.system(size: 10, weight: .semibold))
                Text(shelf.name)
                    .font(.callout.weight(isActive ? .semibold : .regular))
                    .lineLimit(1)
                Text("\(shelf.items.filter { !$0.isArchived }.count)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(isActive ? Color.white.opacity(0.8) : Color.secondary)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .foregroundStyle(isActive ? Color.white : Color.primary)
            .background(
                Capsule().fill(isActive ? Color.accentColor : Color.primary.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
        .onDrop(of: [.shelfInternalItem, .fileURL, .image, .url, .plainText], isTargeted: nil) { providers in
            handleDrop(providers, onto: shelf)
            return true
        }
        .contextMenu {
            if !shelf.isInbox {
                Button("Rename") { ShelfActions.promptRename(shelf) }
                Button("Delete…", role: .destructive) { ShelfActions.confirmDelete(shelf) }
            }
        }
        .accessibilityLabel(shelf.name)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private func handleDrop(_ providers: [NSItemProvider], onto shelf: Shelf) {
        Task { @MainActor in
            let ids = await InternalItemDrop.itemIDs(from: providers)
            if !ids.isEmpty {
                let fetch = FetchDescriptor<ShelfItem>()
                let all = (try? DataController.shared.context.fetch(fetch)) ?? []
                for id in ids {
                    if let item = all.first(where: { $0.id == id }) {
                        ShelfActions.move(item, to: shelf)
                    }
                }
                appState.setActiveShelf(shelf)
                appState.showToast("Moved to \(shelf.name)")
                return
            }
            let created = await ItemImporter.importProviders(providers, into: shelf, context: DataController.shared.context)
            if !created.isEmpty {
                Haptics.perform(.alignment)
                appState.setActiveShelf(shelf)
                appState.showToast("Added to \(shelf.name)")
            }
        }
    }
}
