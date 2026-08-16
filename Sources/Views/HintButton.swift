import SwiftUI

/// Header control with a hover description, matching item cards.
struct HintButton: View {
    let symbol: String
    let title: String
    let detail: String
    let action: () -> Void

    @State private var hovering = false
    @State private var showHint = false
    @State private var hintTask: Task<Void, Never>?

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Design.Ink.title)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.primary.opacity(hovering ? 0.10 : 0.05)))
        }
        .buttonStyle(.plain)
        .overlay { HoverSensor(isHovering: $hovering) }
        .popover(isPresented: $showHint, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Design.Ink.title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Design.Ink.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(width: 210, alignment: .leading)
        }
        .onChange(of: hovering) {
            hintTask?.cancel()
            if hovering {
                hintTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 280_000_000)
                    guard !Task.isCancelled, hovering else { return }
                    showHint = true
                }
            } else {
                showHint = false
            }
        }
        .accessibilityLabel(title)
        .accessibilityHint(detail)
        .help(title)
    }
}
