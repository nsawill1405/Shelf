import Foundation

enum ShelfDisplayItem: Identifiable {
    case single(ShelfItem)
    case stack(id: UUID, items: [ShelfItem])

    var id: UUID {
        switch self {
        case .single(let item): return item.id
        case .stack(let id, _): return id
        }
    }

    var representative: ShelfItem {
        switch self {
        case .single(let item): return item
        case .stack(_, let items): return items[0]
        }
    }

    var items: [ShelfItem] {
        switch self {
        case .single(let item): return [item]
        case .stack(_, let items): return items
        }
    }

    var count: Int { items.count }
}

enum ItemStacks {
    static func grouped(_ items: [ShelfItem], expanded: Set<UUID>) -> [ShelfDisplayItem] {
        var seen = Set<UUID>()
        var result: [ShelfDisplayItem] = []
        for item in items {
            if seen.contains(item.id) { continue }
            if let stackID = item.stackID,
               !expanded.contains(stackID) {
                let members = items.filter { $0.stackID == stackID }
                if members.count > 1 {
                    members.forEach { seen.insert($0.id) }
                    result.append(.stack(id: stackID, items: members))
                    continue
                }
            }
            seen.insert(item.id)
            result.append(.single(item))
        }
        return result
    }
}

enum ItemExpiryPreset: CaseIterable {
    case tonight
    case tomorrow
    case threeDays
    case clear

    var title: String {
        switch self {
        case .tonight: return "Keep until tonight"
        case .tomorrow: return "Keep until tomorrow"
        case .threeDays: return "Keep for 3 days"
        case .clear: return "No expiry"
        }
    }

    var date: Date? {
        let calendar = Calendar.current
        let now = Date()
        switch self {
        case .tonight:
            return calendar.date(bySettingHour: 23, minute: 59, second: 0, of: now)
        case .tomorrow:
            let next = calendar.date(byAdding: .day, value: 1, to: now) ?? now
            return calendar.date(bySettingHour: 18, minute: 0, second: 0, of: next)
        case .threeDays:
            return calendar.date(byAdding: .day, value: 3, to: now)
        case .clear:
            return nil
        }
    }
}
