import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var store: StoreManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            features
                .padding(.top, 22)
            Spacer(minLength: 16)
            purchaseBlock
        }
        .padding(28)
        .frame(minWidth: 420, minHeight: 560)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
            Text("Shelf Pro")
                .font(.largeTitle.weight(.bold))
            Text("The same shelf. No limits. Everything still stays on this Mac.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: 12) {
            feature("square.stack", "Unlimited shelves", "Inbox plus as many work surfaces as you need.")
            feature("infinity", "Unlimited items", "The free shelf stops at \(AppConfig.freeTierItemLimit).")
            feature("text.viewfinder", "OCR search", "Find a screenshot by the words inside it.")
            feature("square.3.layers.3d", "Multi-item drag", "Select a group, drop a stack.")
            feature("keyboard", "Custom shortcuts", "Change how Shelf is summoned.")
        }
    }

    private func feature(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Color.accentColor)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var purchaseBlock: some View {
        VStack(spacing: 10) {
            if store.isPro {
                Label("Shelf Pro is active", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(Color.accentColor)
                    .font(.callout.weight(.semibold))
                Button("Done") { dismissWindow() }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
            } else if let package = store.offerings?.current?.availablePackages.first {
                Button {
                    Task { await store.purchase(package) }
                } label: {
                    if store.isPurchasing {
                        ProgressView().controlSize(.small)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Unlock Pro — \(package.storeProduct.localizedPriceString)")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .disabled(store.isPurchasing)

                Button("Restore Purchases") {
                    Task { await store.restore() }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(store.isPurchasing)
            } else {
                Text("Store unavailable right now.")
                    .foregroundStyle(.secondary)
                if !store.isConfigured {
                    Text("Add a RevenueCat API key in AppConfig.swift to enable purchases.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                Button("Restore Purchases") {
                    Task { await store.restore() }
                }
                .buttonStyle(.plain)
            }

            if let error = store.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Text("Normal Shelf content never leaves this Mac.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
        }
    }

    private func dismissWindow() {
        dismiss()
        NSApp.keyWindow?.close()
    }
}
