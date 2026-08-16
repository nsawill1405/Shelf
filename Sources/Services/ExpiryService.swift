import Foundation
import SwiftData

/// Archives items whose `expiresAt` has passed. Never deletes.
@MainActor
enum ExpiryService {
    private static var timer: Timer?

    static func start() {
        sweep()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor in sweep() }
        }
    }

    static func sweep() {
        let fetch = FetchDescriptor<ShelfItem>()
        let items = (try? DataController.shared.context.fetch(fetch)) ?? []
        let now = Date()
        var archived = 0
        for item in items where !item.isArchived {
            if let expires = item.expiresAt, expires <= now {
                item.isArchived = true
                archived += 1
            }
        }
        if archived > 0 {
            try? DataController.shared.context.save()
            AppState.shared.showToast(archived == 1 ? "Expired item archived" : "\(archived) expired items archived")
        }
    }
}
