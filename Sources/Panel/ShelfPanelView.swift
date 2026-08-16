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
                .padding(.top, 10)
            ShelfRail(highlighted: isDropTargeted)
                .padding(.top, 10)
            footer
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: Design.panelRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay(
            RoundedRectangle(cornerRadius: Design.panelRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Design.panelRadius, style: .continuous))
        .shadow(color: .black.opacity(0.22), radius: 28, y: 10)
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
                    Text("Hold this for me.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 8)
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 6) {
                        headerButton("doc.on.clipboard", help: "Capture Clipboard (\(ShortcutSettings.capture.displayString))") {
                            ClipboardService.captureToActiveShelf()
                        }
                        headerButton("sidebar.left", help: "Snap left") {
                            PanelController.shared.snap(to: .left)
                        }
                        headerButton("sidebar.right", help: "Snap right") {
                            PanelController.shared.snap(to: .right)
                        }
                        headerButton("rectangle.grid.2x2", help: "Manage Shelves") {
                            AppWindows.shared.openManagement()
                        }
                    }
                }
            }
            SearchField()
            ShelfSwitcherView()
        }
    }

    private func headerButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.glass)
        .help(help)
        .accessibilityLabel(help)
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
                    .foregroundStyle(.secondary)
                Text("No results")
                    .foregroundStyle(.secondary)
                Text("Search titles, text, URLs and OCR.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
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
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9).combined(with: .opacity),
                            removal: .opacity
                        ))
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
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text(footerLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
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
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.top, 10)
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
        RoundedRectangle(cornerRadius: Design.panelRadius, style: .continuous)
            .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2.5, dash: [7, 5]))
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 30))
                    Text("Add to \(activeShelf?.name ?? "Shelf")")
                        .font(.headline)
                }
                .foregroundStyle(Color.accentColor)
                .padding(18)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
