import Foundation

/// Central configuration for Shelf. Fill in the RevenueCat API key before
/// shipping, or leave it empty to run in an unlicensed local-only mode.
enum AppConfig {
    /// Your RevenueCat SDK API key (Apple platform key).
    static let revenueCatAPIKey: String = ""

    /// Entitlement identifier that unlocks "Shelf Pro".
    static let revenueCatProEntitlement: String = "pro"

    /// Soft item cap for the free tier. Paywall is surfaced beyond this.
    static let freeTierItemLimit: Int = 100

    /// Free tier is the Inbox (Quick Shelf) only.
    static let freeTierShelfLimit: Int = 1

    /// Local testing unlock. Turn this off before shipping a store build.
    static let testingUnlockPro: Bool = true
}
