import SwiftUI
import AppKit
import SwiftData
import UniformTypeIdentifiers

/// Finder-style tabs. Accent-tinted glass made the names unreadable.
struct ShelfSwitcherView: View {
    @EnvironmentObject private var appState: AppState
    @Query(sort: \Shelf.sortIndex) private var shelves: [Shelf]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(shelves) { shelf in
                    tab(for: shelf)
                }
                Button {
                    ShelfActions.promptNewShelf()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Design.Ink.body)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .help("New Shelf")
                .accessibilityLabel("New Shelf")
            }
        }
    }

    private func tab(for shelf: Shelf) -> some View {
        let isActive = shelf.id == appState.activeShelf?.id
        return Button {
            withAnimation(Design.snap) {
                appState.setActiveShelf(shelf)
            }
        } label: {
            VStack(spacing: 5) {
                HStack(spacing: 5) {
                    Text(shelf.name)
                        .font(.callout.weight(isActive ? .semibold : .regular))
                        .foregroundStyle(isActive ? Design.Ink.title : Design.Ink.body)
                    Text("\(shelf.items.filter { !$0.isArchived }.count)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Design.Ink.quiet)
                }
                Capsule()
                    .fill(isActive ? Design.Ink.title : Color.clear)
                    .frame(height: 2)
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)
            .contentShape(Rectangle())
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
