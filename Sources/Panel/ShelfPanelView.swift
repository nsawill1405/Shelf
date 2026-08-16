import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ShelfPanelView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: StoreManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \ShelfItem.sortIndex) private var allItems: [ShelfItem]
    @Query(sort: \Shelf.sortIndex) private var shelves: [Shelf]

    @State private var isDropTargeted = false

    private let dropTypes: [UTType] = [
        .fileURL, .image, .url, .text, .plainText, .utf8PlainText, .png, .jpeg, .pdf, .cocoaColor
    ]

    private var activeShelf: Shelf? { appState.activeShelf }

    private var items: [ShelfItem] {
        let q = appState.searchQuery
        let searching = !q.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if searching && UserSettings.searchAllShelves {
            return allItems.filter { !$0.isArchived && $0.matches(q) }
        }
        let base = allItems.filter { $0.shelf?.id == activeShelf?.id && !$0.isArchived }
        let pinned = base.filter(\.isPinned).sorted { $0.sortIndex < $1.sortIndex }
        let rest = base.filter { !$0.isPinned }.sorted { $0.sortIndex < $1.sortIndex }
        let ordered = pinned + rest
        if searching { return ordered.filter { $0.matches(q) } }
        return ordered
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            content
                .padding(.top, 12)
            footer
        }
        .padding(18)
        .alwaysActiveGlass()
        .overlay {
            if isDropTargeted { dropHighlight }
        }
        .overlay(alignment: .bottom) {
            if let toast = appState.toast {
                ToastBanner(message: toast)
                    .padding(.bottom, 36)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            ResizeGrip()
                .padding(8)
        }
        .onDrop(of: dropTypes, isTargeted: $isDropTargeted) { providers, _ in
            handleDrop(providers)
            return true
        }
        .animation(reduceMotion ? .default : Design.spring, value: isDropTargeted)
        .animation(reduceMotion ? .default : Design.spring, value: appState.toast)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(activeShelf?.name ?? "Inbox")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Design.Ink.title)
                    Text("Hold this for me.")
                        .font(.caption)
                        .foregroundStyle(Design.Ink.quiet)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .background(PanelMoveHandle())
                HStack(spacing: 6) {
                    HintButton(
                        symbol: "doc.on.clipboard",
                        title: "Capture Clipboard",
                        detail: "Puts whatever is on the clipboard onto this shelf. Shortcut: \(ShortcutSettings.capture.displayString)."
                    ) {
                        ClipboardService.captureToActiveShelf()
                    }
                    HintButton(
                        symbol: "sidebar.left",
                        title: "Snap Left",
                        detail: "Pins the shelf to the left edge of this display."
                    ) {
                        PanelController.shared.snap(to: .left)
                    }
                    HintButton(
                        symbol: "sidebar.right",
                        title: "Snap Right",
                        detail: "Pins the shelf to the right edge of this display."
                    ) {
                        PanelController.shared.snap(to: .right)
                    }
                    HintButton(
                        symbol: "rectangle.grid.2x2",
                        title: "Open Inbox",
                        detail: "Opens the large window to manage every shelf, search everything, and see storage."
                    ) {
                        AppWindows.shared.openManagement()
                    }
                }
            }
            SearchField()
            ShelfSwitcherView()
        }
    }

    @ViewBuilder
    private var content: some View {
        let emptyShelf = (activeShelf?.items.filter { !$0.isArchived }.isEmpty ?? true)
        if emptyShelf, appState.searchQuery.isEmpty {
            if appState.hasCompletedOnboarding {
                emptyState
            } else {
                OnboardingView()
            }
        } else if items.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.title2)
                    .foregroundStyle(Design.Ink.body)
                Text("No results")
                    .foregroundStyle(Design.Ink.body)
                Text("Search titles, text, URLs and OCR.")
                    .font(.caption)
                    .foregroundStyle(Design.Ink.quiet)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            grid
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: Design.cardWidth), spacing: 12)], alignment: .leading, spacing: 12) {
                ForEach(items) { item in
                    ItemCardView(item: item)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.to.line.compact")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(Color.accentColor)
            Text("Drop anything here")
                .font(.title3.weight(.semibold))
            Text("Files, images, links, text, colours.")
                .font(.callout)
                .foregroundStyle(Design.Ink.body)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !appState.selectedItemIDs.isEmpty {
                selectionBar
            }
            HStack(spacing: 10) {
                Text(footerLabel)
                    .font(.caption)
                    .foregroundStyle(Design.Ink.body)
                Spacer()
                if !store.isPro {
                    Button {
                        AppWindows.shared.openPaywall()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                            Text("Shelf Pro")
                        }
                        .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.small)
                }
                HStack(spacing: 4) {
                    KeyboardKey(ShortcutSettings.toggle.displayString)
                    Text("hide")
                        .font(.caption2)
                        .foregroundStyle(Design.Ink.quiet)
                }
            }
        }
        .padding(.top, 10)
    }

    private var selectionBar: some View {
        let selected = items.filter { appState.selectedItemIDs.contains($0.id) }
        return HStack(spacing: 8) {
            Text(selected.count == 1 ? selected[0].title : "\(selected.count) selected")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Design.Ink.title)
                .lineLimit(1)
            Spacer(minLength: 8)
            if let item = selected.first {
                footerAction("Open") { selected.forEach(ShelfActions.open) }
                footerAction("Copy") { ShelfActions.copy(items: selected) }
                if item.storedFileURL != nil {
                    footerAction("Preview") {
                        QuickLookController.shared.preview(selected.compactMap(\.storedFileURL))
                    }
                }
            }
            footerAction("Clear") { appState.selectedItemIDs.removeAll() }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func footerAction(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Design.Ink.title)
    }

    private var footerLabel: String {
        let count = items.count
        let noun = count == 1 ? "item" : "items"
        if !appState.searchQuery.isEmpty, UserSettings.searchAllShelves {
            return "\(count) \(noun) across \(shelves.count) shelves"
        }
        return "\(count) \(noun)"
    }

    private var dropHighlight: some View {
        Design.panelShape
            .strokeBorder(Color.accentColor.opacity(0.85), style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 30))
                    Text("Add to \(activeShelf?.name ?? "Shelf")")
                        .font(.headline)
                }
                .foregroundStyle(Color.accentColor)
                .padding(18)
                .glassEffect(.regular.tint(Color.accentColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .allowsHitTesting(false)
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        guard let shelf = activeShelf else { return }
        Task { @MainActor in
            let created = await ItemImporter.importProviders(providers, into: shelf, context: DataController.shared.context)
            if !created.isEmpty {
                Haptics.perform(.alignment)
                appState.showToast(created.count == 1 ? "Added \(created[0].title)" : "Added \(created.count) items")
            }
        }
    }
}

private struct ResizeGrip: View {
    @State private var lastTranslation: CGSize = .zero

    var body: some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.tertiary)
            .padding(4)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        let dx = value.translation.width - lastTranslation.width
                        let dy = value.translation.height - lastTranslation.height
                        PanelController.shared.resizeBy(dx, dy)
                        lastTranslation = value.translation
                    }
                    .onEnded { _ in lastTranslation = .zero }
            )
            .help("Drag to resize")
            .accessibilityHidden(true)
    }
}
