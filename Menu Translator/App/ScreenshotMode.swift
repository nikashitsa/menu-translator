import Foundation
import SwiftData
import UIKit

/// App Store screenshots (`fastlane snapshot`, see `Menu TranslatorUITests/ScreenshotTests.swift`).
///
/// Launched with `-screenshots`, the app runs on sample data in the Simulator, which has no camera
/// and can't run Apple Translation: orders live in memory (real ones are untouched), Scan shows a
/// menu photo instead of the camera, menu languages count as downloaded, and the demo dishes get
/// fixed English translations. Without the argument nothing here is used.
enum ScreenshotMode {
    static let isEnabled = ProcessInfo.processInfo.arguments.contains("-screenshots")

    /// The menu "photographed" on Scan: `fastlane/screenshot-menu.jpg`, a fictional Mexican menu
    /// rendered by `fastlane/menu/render.swift`. Its path comes from the UI test.
    static let menuPhoto: UIImage? = ProcessInfo.processInfo.environment["SCREENSHOT_MENU_PHOTO"]
        .flatMap { UIImage(contentsOfFile: $0) }

    /// The dish Translation selects, normalized to the photo (top-left origin), as printed by `render.swift`.
    static let featuredDish = dishRects["Enchiladas verdes de pollo"]!

    private static let dishRects: [String: CGRect] = [
        "Guacamole con totopos": CGRect(x: 0.1429, y: 0.2658, width: 0.7143, height: 0.0200),
        "Tacos al pastor con piña": CGRect(x: 0.1429, y: 0.3975, width: 0.7143, height: 0.0200),
        "Enchiladas verdes de pollo": CGRect(x: 0.1429, y: 0.5292, width: 0.7143, height: 0.0375),
        "Agua de horchata": CGRect(x: 0.1429, y: 0.8008, width: 0.7143, height: 0.0200),
    ]

    /// English for the demo menu's dishes, matched on words of the recognized text.
    static func translation(of text: String) -> String? {
        let words = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        return translations.first { $0.keywords.allSatisfy(words.contains) }?.english
    }

    private static let translations: [(keywords: [String], english: String)] = [
        (["guacamole"], "Guacamole with tortilla chips"),
        (["quesadillas"], "Squash blossom quesadillas"),
        (["elote"], "Grilled corn with mayo and chili"),
        (["pastor"], "Al pastor tacos with pineapple"),
        (["carnitas"], "Carnitas tacos"),
        (["pescado"], "Baja-style fish tacos"),
        (["enchiladas"], "Green chicken enchiladas, with cream, fresh cheese and rice"),
        (["mole"], "Mole poblano, chicken leg, rice and tortillas"),
        (["rellenos"], "Cheese-stuffed chiles"),
        (["cochinita"], "Cochinita pibil with red onion and tortillas"),
        (["churros"], "Churros with chocolate"),
        (["flan"], "Neapolitan flan"),
        (["horchata"], "Horchata (rice drink)"),
        (["jamaica"], "Hibiscus water"),
    ]

    /// In-memory orders from four trips, newest first on Home.
    @MainActor
    static let container: ModelContainer? = {
        guard isEnabled else { return nil }
        let container = try! ModelContainer(
            for: Order.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        container.mainContext.autosaveEnabled = false
        for (index, sample) in sampleOrders.enumerated() {
            let order = Order(date: .now.addingTimeInterval(-Double(index) * 3 * 86_400 - 3_600))
            order.restaurantName = sample.restaurant
            container.mainContext.insert(order)
            for (offset, dish) in sample.dishes.enumerated() {
                let item = Dish(
                    originalName: dish.original,
                    translatedName: dish.english,
                    // Unrounded, like dishes added in the app.
                    price: dish.price / sample.rate,
                    quantity: dish.quantity,
                    photo: dishRects[dish.original].flatMap { rect in menuPhoto.flatMap { crop($0, to: rect) } },
                    menuPrice: dish.price,
                    menuCurrencyCode: sample.currency
                )
                // Listed in the order written here.
                item.createdAt = order.date.addingTimeInterval(Double(offset))
                order.dishes.append(item)
            }
        }
        try? container.mainContext.save()
        return container
    }()

    private struct SampleDish {
        let original: String
        let english: String
        let price: Decimal
        var quantity = 1
    }

    /// Units per USD as in the bundled rates, so prices match what Translation shows.
    private static let mxnRate: Decimal = 18.475
    private static let eurRate: Decimal = 0.89059

    private static let sampleOrders: [(restaurant: String, currency: String, rate: Decimal, dishes: [SampleDish])] = [
        ("Taquería, Mexico City", "MXN", mxnRate, [
            SampleDish(original: "Tacos al pastor con piña", english: "Al pastor tacos with pineapple", price: 75, quantity: 2),
            SampleDish(original: "Guacamole con totopos", english: "Guacamole with tortilla chips", price: 95),
            SampleDish(original: "Enchiladas verdes de pollo", english: "Green chicken enchiladas", price: 145),
            SampleDish(original: "Agua de horchata", english: "Horchata (rice drink)", price: 40, quantity: 2),
        ]),
        ("Tapas bar, Madrid", "EUR", eurRate, [
            SampleDish(original: "Patatas bravas", english: "Fried potatoes with spicy sauce", price: 5.50, quantity: 2),
            SampleDish(original: "Croquetas de jamón", english: "Ham croquettes", price: 7.00),
            SampleDish(original: "Gambas al ajillo", english: "Garlic shrimp", price: 12.50),
        ]),
        ("Trattoria, Rome", "EUR", eurRate, [
            SampleDish(original: "Cacio e pepe", english: "Pasta with pecorino and black pepper", price: 12.00),
            SampleDish(original: "Saltimbocca alla romana", english: "Veal with prosciutto and sage", price: 18.00),
            SampleDish(original: "Tiramisù", english: "Tiramisu", price: 6.50, quantity: 2),
        ]),
        ("Crêperie, Paris", "EUR", eurRate, [
            SampleDish(original: "Crêpe banane - chocolat", english: "Banana & chocolate crêpe", price: 7.40, quantity: 2),
            SampleDish(original: "Croque-monsieur", english: "Grilled ham and cheese sandwich", price: 9.50),
        ]),
    ]

    /// `rect` (normalized) of `image` with a little margin, like a selection frame around a dish.
    private static func crop(_ image: UIImage, to rect: CGRect) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let width = CGFloat(cgImage.width), height = CGFloat(cgImage.height)
        let pixels = CGRect(x: rect.minX * width, y: rect.minY * height, width: rect.width * width, height: rect.height * height)
            .insetBy(dx: -8, dy: -8)
            .intersection(CGRect(x: 0, y: 0, width: width, height: height))
            .integral
        return cgImage.cropping(to: pixels).map { UIImage(cgImage: $0) }
    }
}
