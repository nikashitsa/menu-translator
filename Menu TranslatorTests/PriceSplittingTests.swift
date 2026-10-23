import Foundation
import Testing
@testable import Menu_Translator

/// `MenuReader.splitPrice` on typical menu lines (as text recognition returns them).
struct PriceSplittingTests {
    struct Case: Sendable, CustomTestStringConvertible {
        let text: String
        let currency: String
        let price: Decimal?
        let dish: String
        var testDescription: String { "\(text) (\(currency))" }
    }

    @Test(arguments: [
        Case(text: "Bò Bún (crudités, vermicelles, nems, 9 € 80", currency: "EUR", price: 9.8, dish: "Bò Bún (crudités, vermicelles, nems"),
        Case(text: "Maxi Bò Bún (formule + 4€00) 14€90", currency: "EUR", price: 14.9, dish: "Maxi Bò Bún (formule + 4€00)"),
        Case(text: "Salade Rizpai (Porc et Poulet)\n5€50", currency: "EUR", price: 5.5, dish: "Salade Rizpai (Porc et Poulet)"),
        Case(text: "Plat du jour 9€20", currency: "EUR", price: 9.2, dish: "Plat du jour"),
        Case(text: "Vin rouge 12,50 € 20 cl", currency: "EUR", price: 12.5, dish: "Vin rouge 20 cl"),
        Case(text: "Croissant 12,50 € avec 2 oeufs", currency: "EUR", price: 12.5, dish: "Croissant avec 2 oeufs"),
        Case(text: "Tacos al pastor ..... $45,50", currency: "MXN", price: 45.5, dish: "Tacos al pastor"),
        Case(text: "Torta de pastor S95", currency: "MXN", price: 95, dish: "Torta de pastor"),
        Case(text: "Ceviche S/.25 x 2", currency: "PEN", price: 25, dish: "Ceviche x 2"),
        Case(text: "Bandeja 25.000 COP 2 personas", currency: "COP", price: 25000, dish: "Bandeja 2 personas"),
        Case(text: "Sopa de 3 setas 12", currency: "EUR", price: 12, dish: "Sopa de 3 setas"),
        Case(text: "Agua 1 L 20", currency: "GTQ", price: 20, dish: "Agua 1 L"),
        Case(text: "Ensalada verde", currency: "EUR", price: nil, dish: "Ensalada verde"),
    ])
    func splitsPrice(_ testCase: Case) {
        let (dish, price) = MenuReader.splitPrice(from: testCase.text, currencyCode: testCase.currency)
        #expect(price == testCase.price)
        #expect(dish == testCase.dish)
    }
}
