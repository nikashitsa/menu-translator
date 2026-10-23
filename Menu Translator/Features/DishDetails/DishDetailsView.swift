import SwiftData
import SwiftUI

struct DishDetailsView: View {
    @Environment(Router.self) private var router
    @Environment(ExchangeRates.self) private var rates
    let dish: Dish

    @State private var isEditingPrice = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                BackHeader(onBack: { router.pop() }) {
                    Text(dish.translatedName)
                }

                section("Translation") {
                    Text(dish.translatedName)
                        .setFontStyleMultiline(Fonts.textMd)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Text("Price")
                            .setFontStyle(Fonts.textLgBold)
                        Button {
                            isEditingPrice = true
                        } label: {
                            Text("(edit)")
                                .setFontStyle(Fonts.textLgBold)
                                .foregroundStyle(Colors.primary)
                        }
                    }
                    Text(CurrencyInfo.priceDescription(
                        usd: dish.price,
                        menuPrice: dish.menuPrice,
                        currencyCode: dish.menuCurrencyCode
                    ))
                    .setFontStyleMultiline(Fonts.textMd)
                }

                section("Origin") {
                    Text(dish.originalName)
                        .setFontStyleMultiline(Fonts.textMd)
                    if let photo = dish.photo {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .foregroundStyle(Colors.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 24)
        }
        .background(Colors.white)
        .toolbar(.hidden, for: .navigationBar)
        // Like on Translation: keep the layout still while the alert's keyboard is up.
        .ignoresSafeArea(.keyboard)
        .priceEditor(isPresented: $isEditingPrice, currencyCode: priceCurrencyCode, onSave: savePrice)
    }

    /// The price is edited in the menu's currency; dishes without one (e.g. samples) in dollars.
    private var priceCurrencyCode: String {
        dish.menuCurrencyCode ?? "USD"
    }

    private func savePrice(_ price: Decimal) {
        guard let currencyCode = dish.menuCurrencyCode else {
            dish.price = price
            return
        }
        dish.menuPrice = price
        if let rate = rates.rates[currencyCode], rate > 0 {
            dish.price = price / rate
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .setFontStyle(Fonts.textLgBold)
            content()
        }
    }
}

#Preview {
    let container = ModelContainer.preview
    NavigationStack {
        DishDetailsView(dish: container.previewOrder.sortedDishes[0])
    }
    .environment(Router())
    .environment(ExchangeRates())
    .modelContainer(container)
}
