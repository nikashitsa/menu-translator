import SwiftUI

extension View {
    /// The "Edit price" alert: a number field for a price in `currencyCode`. `onSave` gets a valid
    /// amount above zero; anything else is ignored.
    func priceEditor(
        isPresented: Binding<Bool>,
        currencyCode: String,
        onSave: @escaping (Decimal) -> Void
    ) -> some View {
        modifier(PriceEditor(isPresented: isPresented, currencyCode: currencyCode, onSave: onSave))
    }
}

private struct PriceEditor: ViewModifier {
    @Binding var isPresented: Bool
    let currencyCode: String
    let onSave: (Decimal) -> Void

    @State private var text = ""

    func body(content: Content) -> some View {
        content
            .alert("Edit price", isPresented: $isPresented) {
                TextField("Price in \(currencyCode)", text: $text)
                    // The decimal key follows the phone's region ("," or "."); both are accepted.
                    .keyboardType(.decimalPad)
                    .onChange(of: text) { _, newText in
                        let digitsAndSeparators = newText.filter { $0.isNumber || $0 == "," || $0 == "." }
                        if digitsAndSeparators != newText {
                            text = digitsAndSeparators
                        }
                    }
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    if let price = MenuReader.parsePrice(text), price > 0 {
                        onSave(price)
                    }
                }
                // Preferred action: highlighted like in the design.
                .keyboardShortcut(.defaultAction)
            } message: {
                Text("Enter the price in \(currencyCode).")
            }
            .onChange(of: isPresented) { _, presented in
                if presented {
                    text = ""
                }
            }
    }
}
