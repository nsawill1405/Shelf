import Foundation
import RevenueCat

/// Manages the "Shelf Pro" entitlement via RevenueCat. Entitlement state is
/// never hard-coded — it always comes from the customer info.
@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()

    @Published var isPro = false
    @Published var offerings: Offerings?
    @Published var isPurchasing = false
    @Published var errorMessage: String?
    @Published private(set) var isConfigured = false

    private init() {}

    func configure() {
        if AppConfig.testingUnlockPro {
            isPro = true
        }
        let key = AppConfig.revenueCatAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, key.count > 10, !key.hasPrefix("YOUR_") else { return }
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: key)
        isConfigured = true
        Task { await refresh() }
    }

    func refresh() async {
        guard isConfigured else { return }
        do {
            let info = try await Purchases.shared.customerInfo()
            isPro = AppConfig.testingUnlockPro
                || info.entitlements[AppConfig.revenueCatProEntitlement]?.isActive == true
            let offers = try await Purchases.shared.offerings()
            offerings = offers
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func purchase(_ package: Package) async {
        guard isConfigured else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            isPro = AppConfig.testingUnlockPro
                || result.customerInfo.entitlements[AppConfig.revenueCatProEntitlement]?.isActive == true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restore() async {
        guard isConfigured else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let info = try await Purchases.shared.restorePurchases()
            isPro = AppConfig.testingUnlockPro
                || info.entitlements[AppConfig.revenueCatProEntitlement]?.isActive == true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Feature gates (always derived from entitlement + local counts)

    var canCreateShelf: Bool { isPro }

    var canCustomizeShortcuts: Bool { isPro }

    var canUseOCR: Bool { isPro }

    var canMultiSelect: Bool { isPro }

    var remainingFreeItems: Int {
        max(0, AppConfig.freeTierItemLimit - DataController.shared.itemCount)
    }

    func canAddItems(_ count: Int) -> Bool {
        if isPro { return true }
        return DataController.shared.itemCount + count <= AppConfig.freeTierItemLimit
    }

    /// Returns false and opens the paywall when the requested action is gated.
    @discardableResult
    func requirePro(reason: String? = nil) -> Bool {
        if isPro { return true }
        if let reason {
            AppState.shared.showToast(reason)
        }
        AppWindows.shared.openPaywall()
        return false
    }

    @discardableResult
    func requireCapacity(for count: Int) -> Bool {
        if canAddItems(count) { return true }
        AppState.shared.showToast("Free shelf is full — \(AppConfig.freeTierItemLimit) items.")
        AppWindows.shared.openPaywall()
        return false
    }
}
