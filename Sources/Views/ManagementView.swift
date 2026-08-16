import SwiftUI
import SwiftData

struct ManagementView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: StoreManager
    @Query(sort: \Shelf.sortIndex) private var shelves: [Shelf]
    @Query(sort: \ShelfItem.sortIndex) private var allItems: [ShelfItem]

    @State private var selection: UUID?
    @State private var search = ""
    @State private var showArchived = false
    @State private var isGrid = true

    private var selectedShelf: Shelf? {
        if selection == nil { return nil }
        return shelves.first { $0.id == selection }
    }

    private var items: [ShelfItem] {
        let base: [ShelfItem]
        if let selectedShelf {
            base = allItems.filter { $0.shelf?.id == selectedShelf.id }
        } else {
            base = allItems
        }
        let visible = showArchived ? base : base.filter { !$0.isArchived }
        let filtered = search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? visible
            : visible.filter { $0.matches(search) }
        return appState.sortMode.sort(filtered)
    }

    var body: some View {
        NavigationSplitView {
            shelfSidebar
        } detail: {
            shelfDetail
        }
        .frame(minWidth: 860, minHeight: 540)
        .alwaysActiveGlass()
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Toggle(isOn: $showArchived) {
                    Label("Archived", systemImage: "archivebox")
                }
                .help("Show archived items")

                Picker("Layout", selection: $isGrid) {
                    Image(systemName: "square.grid.2x2").tag(true)
                    Image(systemName: "list.bullet").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(width: 90)
            }
            ToolbarItem(placement: .primaryAction) {
                if !store.isPro {
                    Button {
                        AppWindows.shared.openPaywall()
                    } label: {
                        Label("Shelf Pro", systemImage: "sparkles")
                    }
                }
            }
        }
        .onAppear {
            if selection == nil { selection = shelves.first?.id }
        }
    }

    private var shelfSidebar: some View {
        List(selection: $selection) {
            Section("Shelves") {
                ForEach(shelves) { shelf in
                    Label {
                        HStack {
                            Text(shelf.name)
                            Spacer()
                            Text("\(shelf.items.filter { !$0.isArchived }.count)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Design.Ink.quiet)
                        }
                    } icon: {
                        Image(systemName: shelf.isInbox ? "tray" : "square.stack")
                    }
                    .tag(Optional(shelf.id))
                    .onDrop(of: [.shelfInternalItem, .fileURL, .image, .url, .plainText], isTargeted: nil) { providers in
                        drop(providers, onto: shelf)
                        return true
                    }
                    .contextMenu {
                        if !shelf.isInbox {
                            Button("Rename") { ShelfActions.promptRename(shelf) }
                            Button("Delete…", role: .destructive) { ShelfActions.confirmDelete(shelf) }
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Divider()
                Button {
                    ShelfActions.promptNewShelf()
                } label: {
                    Label("New Shelf", systemImage: "plus")
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(allItems.count) items · \(ItemStorage.formattedUsage)")
                        .font(.caption2)
                        .foregroundStyle(Design.Ink.quiet)
                    ProgressView(value: storageFraction)
                        .controlSize(.small)
                        .tint(Color.accentColor)
                }
            }
            .padding(12)
        }
        .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 280)
    }

    private var storageFraction: Double {
        let bytes = Double(ItemStorage.usageBytes)
        let cap = 500_000_000.0
        return min(1, bytes / cap)
    }

    private var shelfDetail: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedShelf?.name ?? "All items")
                        .font(.title2.weight(.semibold))
                    Text(detailSubtitle)
                        .font(.caption)
                        .foregroundStyle(Design.Ink.body)
                }
                Spacer()
                Picker("Sort", selection: $appState.sortMode) {
                    ForEach(ShelfSortMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .labelsHidden()
                .frame(width: 150)
                searchBar
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)

            if !suggested.isEmpty {
                suggestionBanner
            }

            Divider()

            if items.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: search.isEmpty ? "tray" : "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundStyle(Design.Ink.body)
                    Text(search.isEmpty ? "This shelf is empty." : "No results.")
                        .foregroundStyle(Design.Ink.body)
                    if search.isEmpty {
                        Text("Drop things onto the floating shelf, or paste with \(ShortcutSettings.capture.displayString).")
                            .font(.caption)
                            .foregroundStyle(Design.Ink.quiet)
                    }
                }
                Spacer()
            } else if isGrid {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 138), spacing: 14)], spacing: 14) {
                        ForEach(items) { item in
                            ItemCardView(item: item)
                        }
                    }
                    .padding(18)
                }
            } else {
                List {
                    ForEach(items) { item in
                        ItemRow(item: item)
                    }
                    .onMove(perform: moveItems)
                    .onDelete(perform: deleteItems)
                }
                .listStyle(.inset)
            }
        }
    }

    private var suggested: [ShelfItem] {
        ArchiveAdvisor.suggestions(from: allItems.filter { selectedShelf == nil || $0.shelf?.id == selectedShelf?.id })
    }

    private var suggestionBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "archivebox")
                .foregroundStyle(Design.Ink.body)
            Text("\(suggested.count) unused for \(UserSettings.archiveAfterDays)+ days")
                .font(.callout)
                .foregroundStyle(Design.Ink.title)
            Spacer()
            Button("Archive suggested") {
                ArchiveAdvisor.archive(suggested)
            }
            .buttonStyle(.plain)
            .font(.callout.weight(.semibold))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.05))
    }

    private var detailSubtitle: String {
        let count = items.count
        let noun = count == 1 ? "item" : "items"
        if let app = items.compactMap(\.originatingApp).first {
            return "\(count) \(noun) · last from \(app)"
        }
        return "\(count) \(noun)"
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(Design.Ink.body)
            TextField(selectedShelf == nil ? "Search everything" : "Search this shelf", text: $search)
                .textFieldStyle(.plain)
                .foregroundStyle(Design.Ink.title)
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Design.Ink.body)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(width: 260)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        var arr = items
        arr.move(fromOffsets: source, toOffset: destination)
        for (index, item) in arr.enumerated() {
            item.sortIndex = index
        }
        try? DataController.shared.context.save()
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            DataController.shared.deleteItem(items[index])
        }
    }

    private func drop(_ providers: [NSItemProvider], onto shelf: Shelf) {
        Task { @MainActor in
            let ids = await InternalItemDrop.itemIDs(from: providers)
            if !ids.isEmpty {
                for id in ids {
                    if let item = allItems.first(where: { $0.id == id }) {
                        ShelfActions.move(item, to: shelf)
                    }
                }
                return
            }
            _ = await ItemImporter.importProviders(providers, into: shelf, context: DataController.shared.context)
        }
    }
}

private struct ItemRow: View {
    let item: ShelfItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.type.systemImage)
                .foregroundStyle(item.isPinned ? Color.accentColor : Design.Ink.body)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .foregroundStyle(Design.Ink.title)
                    .lineLimit(1)
                    .strikethrough(item.isArchived)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Design.Ink.body)
            }
            Spacer()
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button("Open") { ShelfActions.open(item) }
            Button("Copy") { ShelfActions.copy(item) }
            Button(item.isPinned ? "Unpin" : "Pin") { ShelfActions.pin(item) }
            Button(item.isArchived ? "Restore" : "Archive") { ShelfActions.archive(item) }
            Divider()
            Button("Delete", role: .destructive) { DataController.shared.deleteItem(item) }
        }
    }

    private var subtitle: String {
        var parts = [item.type.displayName, item.lastUsedAt.formatted(.relative(presentation: .named))]
        if let app = item.originatingApp { parts.append(app) }
        if item.isArchived { parts.append("Archived") }
        return parts.joined(separator: " · ")
    }
}
