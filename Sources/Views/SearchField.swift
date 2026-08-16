import SwiftUI

struct SearchField: View {
    @EnvironmentObject private var appState: AppState
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 13, weight: .medium))
            TextField(UserSettings.searchAllShelves ? "Search every shelf" : "Search this shelf", text: $appState.searchQuery)
                .textFieldStyle(.plain)
                .focused($focused)
                .font(.body)
            if !appState.searchQuery.isEmpty {
                Button {
                    appState.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            } else {
                Text("⌘F")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.primary.opacity(focused ? 0.22 : 0.08)))
        .onReceive(NotificationCenter.default.publisher(for: .shelfPanelDidShow)) { _ in
            if NSEvent.pressedMouseButtons == 0 {
                focused = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusSearch)) { _ in
            focused = true
        }
        .accessibilityLabel("Search")
    }
}
