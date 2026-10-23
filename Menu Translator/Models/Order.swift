import Foundation
import SwiftData

/// A saved order. Each order is its own SwiftData record; deleting it deletes its dishes.
@Model
final class Order {
    var title: String
    /// Typed by the user on the Order screen; empty when not set.
    var restaurantName: String = ""
    var date: Date
    /// A new order that hasn't been saved yet (see `OrderSession`); saving clears it.
    var isDraft: Bool = false
    @Relationship(deleteRule: .cascade, inverse: \Dish.order)
    var dishes: [Dish] = []

    init(title: String = "New order", date: Date = .now, isDraft: Bool = false) {
        self.title = title
        self.date = date
        self.isDraft = isDraft
    }

    /// SwiftData doesn't keep relationship order, so dishes are sorted by when they were added.
    var sortedDishes: [Dish] {
        dishes.sorted { $0.createdAt < $1.createdAt }
    }

    /// In US dollars, like all amounts in the app.
    var total: Decimal {
        dishes.reduce(0) { $0 + $1.subtotal }
    }
}

extension ModelContext {
    /// Removes unsaved orders that earlier versions wrote to disk (they autosaved drafts).
    func discardDraft() {
        let drafts = (try? fetch(FetchDescriptor<Order>(predicate: #Predicate { $0.isDraft }))) ?? []
        guard !drafts.isEmpty else { return }
        drafts.forEach(delete)
        try? save()
    }
}
