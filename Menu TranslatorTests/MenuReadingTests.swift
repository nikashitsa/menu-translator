import Foundation
import Testing
@testable import Menu_Translator

/// Text recognition and price splitting on real menus: what the Translation screen does with the
/// part of the photo inside the selection frame. Runs in the Simulator too.
@Suite("Reading menus")
struct MenuReadingTests {
    @Test("Spanish menus", arguments: MenuDishCase.all(language: "es"))
    func spanish(_ dishCase: MenuDishCase) async throws { try await readsPrice(dishCase) }

    @Test("French menus", arguments: MenuDishCase.all(language: "fr"))
    func french(_ dishCase: MenuDishCase) async throws { try await readsPrice(dishCase) }

    @Test("Italian menus", arguments: MenuDishCase.all(language: "it"))
    func italian(_ dishCase: MenuDishCase) async throws { try await readsPrice(dishCase) }

    private func readsPrice(_ dishCase: MenuDishCase) async throws {
        let crop = try #require(dishCase.crop(), "Missing photo \(dishCase.menu.file)")
        let text = await MenuReader.recognizeText(in: crop, language: dishCase.locale)
        let (dishText, price) = MenuReader.splitPrice(from: text, currencyCode: dishCase.menu.currency)
        if let knownIssue = dishCase.dish.knownIssue {
            // Intermittent: recognition of these photos varies a little between iOS versions and devices.
            withKnownIssue(Comment(rawValue: knownIssue), isIntermittent: true) {
                #expect(price == dishCase.dish.price, "Read: \(text)")
            }
        } else {
            #expect(price == dishCase.dish.price, "Read: \(text)")
        }
        #expect(!dishText.isEmpty, "No dish text left after removing the price from: \(text)")
    }
}
