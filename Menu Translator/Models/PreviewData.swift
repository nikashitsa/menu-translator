import Foundation
import SwiftData

extension ModelContainer {
    /// In-memory store with sample orders, for SwiftUI previews; the app itself starts empty.
    @MainActor
    static var preview: ModelContainer {
        let container = try! ModelContainer(
            for: Order.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let samples: [(String, Double, [(String, String, Decimal)])] = [
            ("Bangkok street food", 0, [
                ("Pad Thai", "Stir-fried rice noodles", 4.50),
                ("Tom Yum Goong", "Hot and sour shrimp soup", 6.25),
            ]),
            ("Chiang Mai dinner", -86_400, [("Som Tam", "Green papaya salad", 3.10)]),
        ]
        for (index, sample) in samples.enumerated() {
            let order = Order(title: sample.0, date: .now.addingTimeInterval(sample.1), isDraft: index == 0)
            container.mainContext.insert(order)
            for dish in sample.2 {
                order.dishes.append(Dish(originalName: dish.0, translatedName: dish.1, price: dish.2))
            }
        }
        return container
    }

    /// The first sample order, for previews of screens that show one order.
    @MainActor
    var previewOrder: Order {
        try! mainContext.fetch(FetchDescriptor<Order>(sortBy: [SortDescriptor(\.date, order: .reverse)])).first!
    }
}
