import Foundation
import Observation
import SwiftData

/// The order being worked on: a new order started with "Scan menu", or a saved order opened from
/// Home. It's edited in its own scratch `ModelContext`, so leaving without "Save" simply drops the
/// changes; `rollback()` can't be used for that, as it leaves already-loaded objects showing them.
@Observable
final class OrderSession {
    /// The order Scan and Translation add dishes to, and the Order screen edits.
    private(set) var order: Order?
    private var context: ModelContext?

    /// Starts a new, unsaved order ("Scan menu").
    func startNewOrder(in container: ModelContainer) {
        let context = Self.makeContext(container)
        let order = Order(isDraft: true)
        context.insert(order)
        self.context = context
        self.order = order
    }

    /// Opens a saved order for editing and returns the editable copy.
    func edit(_ savedOrder: Order, in container: ModelContainer) -> Order? {
        let context = Self.makeContext(container)
        guard let order = context.model(for: savedOrder.persistentModelID) as? Order else { return nil }
        self.context = context
        self.order = order
        return order
    }

    /// The current order, starting a new one if there's none.
    func currentOrder(in container: ModelContainer) -> Order {
        if let order { return order }
        startNewOrder(in: container)
        return order!
    }

    /// Adding the same dish again (same menu text and price) raises its quantity instead of
    /// listing it twice.
    func add(_ dish: Dish, in container: ModelContainer) {
        let order = currentOrder(in: container)
        if let existing = order.dishes.first(where: {
            $0.originalName == dish.originalName
                && $0.menuPrice == dish.menuPrice
                && $0.menuCurrencyCode == dish.menuCurrencyCode
                && $0.price == dish.price
        }) {
            existing.quantity += 1
            return
        }
        context?.insert(dish)
        order.dishes.append(dish)
    }

    /// Swipe-to-delete on the Order screen; like other changes, kept only when the order is saved.
    func remove(_ dish: Dish) {
        order?.dishes.removeAll { $0 == dish }
        context?.delete(dish)
    }

    /// "Save" on the Order screen: drops dishes whose quantity was set to 0, then writes the order
    /// (a new one becomes a saved order dated now) and ends the session. An order left without
    /// dishes isn't kept: a new one isn't saved, a saved one is deleted.
    func save() {
        if let order, let context {
            for dish in order.dishes where dish.quantity == 0 {
                context.delete(dish)
            }
            let hasDishes = order.dishes.contains { $0.quantity > 0 }
            if hasDishes {
                if order.isDraft {
                    order.isDraft = false
                    order.date = .now
                }
                try? context.save()
            } else if !order.isDraft {
                context.delete(order)
                try? context.save()
            }
        }
        end()
    }

    /// Leaves without saving: all changes are dropped.
    func end() {
        order = nil
        context = nil
    }

    private static func makeContext(_ container: ModelContainer) -> ModelContext {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }
}
