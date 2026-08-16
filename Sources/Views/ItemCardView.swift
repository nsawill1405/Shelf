import SwiftUI
import AppKit

struct ItemCardView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let item: ShelfItem
    var stackItems: [ShelfItem]? = nil
    var compact: Bool = false

    @State private var image: NSImage?
    @State private var favicon: NSImage?
    @State private var isHovering = false
    @State private var showDescription = false
    @State private var descriptionTask: Task<Void, Never>?

    private var isSelected: Bool { appState.selectedItemIDs.contains(item.id) }
    private var isSettling: Bool { appState.settlingItemIDs.contains(item.id) }
    private var groupCount: Int {
        if appState.selectedItemIDs.count > 1, appState.selectedItemIDs.contains(item.id) {
            return appState.selectedItemIDs.count
        }
        return 1
    }

    private var grouped: [ShelfItem] { stackItems ?? [item] }

    private var dragItems: [ShelfItem] {
        if groupCount > 1, let shelf = appState.activeShelf {
            let selected = shelf.sortedItems.filter { appState.selectedItemIDs.contains($0.id) }
            if selected.count > 1 { return selected }
        }
        return grouped
    }

    var body: some View {
        VStack(spacing: 6) {
            thumbnail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Text(item.title)
                .font(.caption)
                .foregroundStyle(Design.Ink.body)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .frame(width: compact ? 120 : Design.cardWidth, height: compact ? 128 : Design.cardHeight)
        .contentShape(Design.cardShape)
        .shelfCardChrome(isSelected: isSelected, isHovering: isHovering)
        .overlay { HoverSensor(isHovering: $isHovering) }
        .overlay {
            ItemDragHandle(
                payloads: dragItems.map(DragPayload.init),
                onClick: select,
                onDoubleClick: { ShelfActions.open(item) }
            )
        }
        .overlay(alignment: .topLeading) {
            if grouped.count > 1 {
                stackBadge
            } else if groupCount > 1 {
                selectionBadge
            }
        }
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 3) {
                if item.expiresAt != nil {
                    Image(systemName: "clock")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(item.isExpiringSoon ? Color.orange : Design.Ink.quiet)
                }
                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(7)
        }
        .opacity(item.isExpiringSoon ? 0.72 : 1)
        .overlay(alignment: .bottom) {
            if showDescription {
                ItemDescriptionCard(item: item)
                    .offset(y: Design.cardHeight / 2 + 4)
            }
        }
        .zIndex(isHovering || isSelected ? 10 : 0)
        .offset(y: isSettling && !reduceMotion ? -10 : 0)
        .animation(reduceMotion ? nil : Design.settle, value: isSettling)
        .onChange(of: isHovering) {
            handleHoverChange()
        }
        .contextMenu { contextMenu }
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

    private var stackBadge: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.08))
                .frame(width: 22, height: 16)
                .offset(x: 6, y: 4)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.accentColor)
                .frame(width: 22, height: 16)
            Text("\(grouped.count)")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(6)
        .accessibilityLabel("\(grouped.count) in stack")
    }

    private var selectionBadge: some View {
        ZStack(alignment: .topLeading) {
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
                if let favicon {
                    Image(nsImage: favicon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 22, height: 22)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                } else {
                    Image(systemName: "link")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                }
                Text(item.pageTitle ?? host ?? "Link")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Design.Ink.title)
                    .lineLimit(2)
                Text(host ?? item.sourceURL ?? "")
                    .font(.caption2)
                    .foregroundStyle(Design.Ink.body)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .task(id: item.faviconPath) { loadFavicon() }
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
                    .foregroundStyle(Design.Ink.quiet)
            }
        case .code:
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: item.type.systemImage)
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                Text(item.contentText ?? item.title)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Design.Ink.body)
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
                    .foregroundStyle(Design.Ink.body)
                Text(item.contentText ?? item.title)
                    .font(.caption)
                    .foregroundStyle(Design.Ink.title)
                    .lineLimit(5)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func handleHoverChange() {
        descriptionTask?.cancel()
        if isHovering {
            NSCursor.openHand.set()
            descriptionTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 280_000_000)
                guard !Task.isCancelled, isHovering else { return }
                withAnimation(.easeOut(duration: 0.12)) { showDescription = true }
            }
        } else {
            NSCursor.arrow.set()
            showDescription = false
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

    private func loadFavicon() {
        guard let path = item.faviconPath else { return }
        favicon = NSImage(contentsOf: URL(fileURLWithPath: path))
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
        showDescription = false
        if let stackID = item.stackID, grouped.count > 1 {
            appState.expandedStackIDs.insert(stackID)
            appState.selectedItemIDs = Set(grouped.map(\.id))
            return
        }
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
        } else if isSelected {
            appState.selectedItemIDs = []
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
        Button(item.isPinned ? "Unpin" : "Pin to top") { ShelfActions.pin(item) }
        Button(item.isArchived ? "Restore" : "Archive") { ShelfActions.archive(item) }
        Menu("Put this on") {
            ForEach(DataController.shared.allShelves) { shelf in
                Button(shelf.name) {
                    let moving = grouped
                    ShelfActions.move(moving, to: shelf)
                    AppState.shared.showToast("Moved to \(shelf.name)")
                }
            }
        }
        Menu("Keep until") {
            ForEach(ItemExpiryPreset.allCases, id: \.title) { preset in
                Button(preset.title) { ShelfActions.setExpiry(item, preset.date) }
            }
        }
        if grouped.count > 1, let stackID = item.stackID {
            Button("Expand stack") { appState.expandedStackIDs.insert(stackID) }
        } else if let stackID = item.stackID, appState.expandedStackIDs.contains(stackID) {
            Button("Collapse stack") { appState.expandedStackIDs.remove(stackID) }
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
