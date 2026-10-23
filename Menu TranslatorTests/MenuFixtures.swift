import Foundation
import Testing
import UIKit

/// Real menu photos with dishes whose price and translation are checked (`Menus/menus-*.json`).
///
/// Each dish has the frame a user would draw over it (`rect`, normalized to the photo, origin at
/// the top left), the price printed on the menu, and English words its translation should contain.
struct MenuFixture: Decodable, Sendable {
    let file: String
    /// "es", "fr" or "it".
    let language: String
    /// The currency picked in the app for this menu.
    let currency: String
    let source: String
    let license: String
    let dishes: [Dish]

    struct Dish: Decodable, Sendable {
        /// The dish as written on the menu (correctly spelled), the input of the translation tests.
        let name: String
        let price: Decimal
        /// Any of these, lowercased, makes a translation correct.
        let english: [String]
        let rect: [Double]
        /// Text recognition reads this price wrong today; the test records it as a known issue.
        var knownIssue: String?
        /// Apple Translation gets this dish wrong today (e.g. "Pêche Melba" → "melba fishing").
        var translationIssue: String?
    }

    static let all: [MenuFixture] = ["es", "fr", "it"].flatMap { language -> [MenuFixture] in
        guard let url = bundle.url(forResource: "menus-\(language)", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([MenuFixture].self, from: data)) ?? []
    }

    static func image(named file: String) -> UIImage? {
        bundle.url(forResource: file, withExtension: nil).flatMap { UIImage(contentsOfFile: $0.path) }
    }

    private static var bundle: Bundle { Bundle(for: BundleToken.self) }
    private final class BundleToken {}
}

/// One dish of one menu, the argument of the parameterized tests.
struct MenuDishCase: Sendable, CustomTestStringConvertible {
    let menu: MenuFixture
    let dish: MenuFixture.Dish

    var testDescription: String { "\(menu.file): \(dish.name)" }

    static func all(language: String) -> [MenuDishCase] {
        MenuFixture.all
            .filter { $0.language == language }
            .flatMap { menu in menu.dishes.map { MenuDishCase(menu: menu, dish: $0) } }
    }

    var locale: Locale.Language { Locale.Language(identifier: menu.language) }

    /// The part of the photo under the dish's frame, like `MenuReader.crop` produces in the app.
    func crop() -> UIImage? {
        guard let cgImage = MenuFixture.image(named: menu.file)?.cgImage, dish.rect.count == 4 else { return nil }
        let width = Double(cgImage.width), height = Double(cgImage.height)
        let rect = CGRect(
            x: dish.rect[0] * width,
            y: dish.rect[1] * height,
            width: dish.rect[2] * width,
            height: dish.rect[3] * height
        ).integral
        return cgImage.cropping(to: rect).map { UIImage(cgImage: $0) }
    }
}
