import SwiftUI

struct SearchField: View {
    @EnvironmentObject private var appState: AppState
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Design.Ink.body)
                .font(.system(size: 13, weight: .medium))
            TextField(UserSettings.searchAllShelves ? "Search every shelf" : "Search this shelf", text: $appState.searchQuery)
                .textFieldStyle(.plain)
                .focused($focused)
                .font(.body)
                .foregroundStyle(Design.Ink.title)
            if !appState.searchQuery.isEmpty {
                Button {
                    appState.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Design.Ink.body)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            } else {
                Text("⌘F")
                    .font(.caption2.monospaced())
                    .foregroundStyle(Design.Ink.quiet)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .capsule)
        .onReceive(NotificationCenter.default.publisher(for: .focusSearch)) { _ in
            focused = true
        }
        .accessibilityLabel("Search")
    }
}
