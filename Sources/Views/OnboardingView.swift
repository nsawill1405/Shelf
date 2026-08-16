import SwiftUI

/// Three beats, no carousel: drag, shortcut, first drop. The empty panel is the demo.
struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 8)
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.pulse, options: .repeating)
                .accessibilityHidden(true)

            Text("Drag anything here.")
                .font(.title2.weight(.semibold))

            Text("Files, images, links, text or a colour. Shelf holds them until you need them again.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            HStack(spacing: 6) {
                KeyboardKey(ShortcutSettings.toggle.displayString)
                Text("summons this shelf")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Text("Drop your first thing to continue.")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Button("Skip for now") { appState.completeOnboarding() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}
