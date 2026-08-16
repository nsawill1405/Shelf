import SwiftUI
import AppKit

struct ItemCardView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let item: ShelfItem
    var compact: Bool = false

    @State private var image: NSImage?
    @State private var isHovering = false

    private var isSelected: Bool { appState.selectedItemIDs.contains(item.id) }
    private var isSettling: Bool { appState.settlingItemIDs.contains(item.id) }
    private var groupCount: Int {
        if appState.selectedItemIDs.count > 1, appState.selectedItemIDs.contains(item.id) {
            return appState.selectedItemIDs.count
        }
        return 1
    }

    private var dragValue: ShelfItemTransferable {
        if groupCount > 1, let shelf = appState.activeShelf {
            let selected = shelf.sortedItems.filter { appState.selectedItemIDs.contains($0.id) }
            if selected.count > 1 { return ShelfItemTransferable(items: selected) }
        }
        return ShelfItemTransferable(item: item)
    }

    var body: some View {
        VStack(spacing: 6) {
            thumbnail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Text(item.title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .frame(width: compact ? 120 : Design.cardWidth, height: compact ? 128 : Design.cardHeight)
        .shelfCardChrome(isSelected: isSelected, isHovering: isHovering)
        .overlay(alignment: .topLeading) {
            if groupCount > 1 {
                stackBadge
            }
        }
        .overlay(alignment: .topTrailing) {
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                    .padding(7)
            }
        }
        .scaleEffect(scale)
        .offset(y: isSettling && !reduceMotion ? -10 : 0)
        .rotationEffect(.degrees(isHovering && groupCount > 1 && !reduceMotion ? -1.4 : 0))
        .animation(reduceMotion ? .easeOut(duration: 0.12) : Design.spring, value: isHovering)
        .animation(reduceMotion ? nil : Design.settle, value: isSettling)
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture { select() }
        .onTapGesture(count: 2) { ShelfActions.open(item) }
        .contextMenu { contextMenu }
        .draggable(dragValue) {
            dragPreview
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 6)
                .onChanged { _ in
                    PanelController.shared.itemDidBeginExternalDrag()
                }
        )
        .onDrop(of: [.shelfInternalItem], isTargeted: nil) { providers in
            handleReorder(providers)
            return true
        }
        .task(id: item.storedPath) { loadThumbnail() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title), \(item.type.displayName)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("Double-click to open. Space to Quick Look.")
    }

    private var scale: CGFloat {
        if isSettling && !reduceMotion { return 0.92 }
        if isHovering { return 1.03 }
        return 1
    }

    private var stackBadge: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.08))
                .frame(width: 22, height: 16)
                .offset(x: 6, y: 4)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.accentColor)
                .frame(width: 22, height: 16)
            Text("\(groupCount)")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(6)
        .accessibilityLabel("\(groupCount) selected")
    }

    @ViewBuilder
    private var dragPreview: some View {
        if groupCount > 1 {
            ZStack {
                ForEach(0..<min(groupCount, 3), id: \.self) { index in
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.regularMaterial)
                        .frame(width: 92, height: 100)
                        .rotationEffect(.degrees(Double(index) * 6 - 4))
                        .offset(x: CGFloat(index) * 6, y: CGFloat(index) * 4)
                }
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 120, height: 120)
        } else {
            thumbnail
                .frame(width: 96, height: 96)
                .padding(8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    // MARK: - Thumbnail

    @ViewBuilder
    private var thumbnail: some View {
        switch item.type {
        case .image:
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                placeholder("photo")
            }
        case .color:
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(hex: item.colorHex ?? "#FFFFFF"))
                .overlay(alignment: .bottom) {
                    Text(item.colorHex ?? "")
                        .font(.caption2.monospaced().weight(.semibold))
                        .foregroundStyle(.white)
                        .shadow(radius: 1)
                        .padding(.bottom, 6)
                }
        case .url:
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "link")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                Text(host ?? "Link")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(item.sourceURL ?? item.contentText ?? "")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        case .pdf, .file, .folder, .document:
            VStack(spacing: 6) {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 72)
                } else {
                    Image(systemName: item.type.systemImage)
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                }
                Text(item.type.displayName)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        case .code:
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: item.type.systemImage)
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                Text(item.contentText ?? item.title)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        case .text, .email:
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: item.type.systemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(item.contentText ?? item.title)
                    .font(.caption)
                    .foregroundStyle(.primary.opacity(0.85))
                    .lineLimit(5)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func placeholder(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 28))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var host: String? {
        let raw = item.sourceURL ?? item.contentText ?? ""
        let withScheme = raw.lowercased().hasPrefix("http") ? raw : "https://\(raw)"
        return URL(string: withScheme)?.host
    }

    private func loadThumbnail() {
        guard let url = item.storedFileURL else { return }
        switch item.type {
        case .image:
            image = NSImage(contentsOf: url)
        case .pdf:
            ThumbnailProvider.thumbnail(for: url, size: CGSize(width: 240, height: 240)) { image = $0 }
        case .file, .folder, .document:
            image = NSWorkspace.shared.icon(forFile: url.path)
        default:
            break
        }
    }

    // MARK: - Selection

    private func select() {
        let flags = NSEvent.modifierFlags
        if flags.contains(.command) || flags.contains(.shift) {
            if !StoreManager.shared.canMultiSelect, !appState.selectedItemIDs.isEmpty, !isSelected {
                StoreManager.shared.requirePro(reason: "Multi-item workflows are part of Shelf Pro.")
                return
            }
            if isSelected {
                appState.selectedItemIDs.remove(item.id)
            } else {
                appState.selectedItemIDs.insert(item.id)
            }
        } else {
            appState.selectedItemIDs = [item.id]
        }
    }

    private func handleReorder(_ providers: [NSItemProvider]) {
        Task { @MainActor in
            let ids = await InternalItemDrop.itemIDs(from: providers)
            guard let sourceID = ids.first,
                  sourceID != item.id,
                  let shelf = item.shelf else { return }
            let ordered = shelf.sortedItems.filter { !$0.isArchived }
            guard let source = ordered.first(where: { $0.id == sourceID }) else { return }
            DataController.shared.reorder(ordered, moving: source, before: item)
            Haptics.perform(.generic)
        }
    }

    // MARK: - Context menu

    @ViewBuilder
    private var contextMenu: some View {
        Button("Open") { ShelfActions.open(item) }
        Button("Copy") { ShelfActions.copy(item) }
        if let url = item.storedFileURL {
            Button("Quick Look") { QuickLookController.shared.preview([url]) }
        }
        Divider()
        Button(item.isPinned ? "Unpin" : "Pin") { ShelfActions.pin(item) }
        Button(item.isArchived ? "Restore" : "Archive") { ShelfActions.archive(item) }
        Menu("Move to") {
            ForEach(DataController.shared.allShelves) { shelf in
                Button(shelf.name) { ShelfActions.move(item, to: shelf) }
            }
        }
        Divider()
        if let url = item.storedFileURL {
            Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
        }
        if let app = item.originatingApp, !app.isEmpty {
            Text("From \(app)")
        }
        Divider()
        Button("Delete", role: .destructive) { DataController.shared.deleteItem(item) }
    }
}
