import SwiftUI

/// Bottom panel for choosing the menu's currency, styled like `LanguagePicker`.
/// Only the header can be dragged down to close, so the long list stays scrollable.
struct CurrencyPicker: View {
    @Binding var selection: String
    let rates: ExchangeRates
    let onClose: () -> Void

    @State private var query = ""
    /// Kept when a swipe closes the panel, so it slides away from where the finger let go.
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Choose currency")
                    .setFontStyle(Fonts.textXlBold)
                searchField
            }
            .padding(.horizontal, 16)
            .padding(.top, 40)
            .contentShape(.rect)
            .gesture(swipeDown)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredCurrencies, id: \.self) { code in
                        row(for: code)
                    }
                    if filteredCurrencies.isEmpty {
                        Text(rates.currencies.isEmpty ? "Currencies couldn't be loaded." : "No currencies found.")
                            .setFontStyleMultiline(Fonts.textMd)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .foregroundStyle(Colors.text)
        .frame(maxWidth: .infinity)
        .frame(height: 620)
        .background(Colors.white, in: UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32))
        .offset(y: dragOffset)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, onClose)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
            TextField("Search", text: $query)
                .autocorrectionDisabled()
        }
        .font(.system(size: Fonts.textMd.size))
        .padding(.horizontal, 16)
        .frame(height: 40)
        .background(Colors.secondary, in: .capsule)
    }

    private var filteredCurrencies: [String] {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            // Current choice first, so it's visible without scrolling a ~150-item list.
            let others = rates.currencies.filter { $0 != selection }
            return rates.currencies.contains(selection) ? [selection] + others : others
        }
        return rates.currencies.filter {
            $0.localizedCaseInsensitiveContains(query)
                || CurrencyInfo.countries(of: $0).localizedCaseInsensitiveContains(query)
                || CurrencyInfo.name(of: $0).localizedCaseInsensitiveContains(query)
        }
    }

    private func row(for code: String) -> some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            selection = code
            onClose()
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(code)
                        .setFontStyle(Fonts.textLgBold)
                    if let rate = rateText(for: code) {
                        Text(rate)
                            .setFontStyle(Fonts.textMd)
                            .foregroundStyle(Colors.text)
                    }
                    Text(CurrencyInfo.countries(of: code))
                        .setFontStyleMultiline(Fonts.textMd)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: code == selection ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(Colors.primary)
            }
            .card()
        }
        .buttonStyle(.plain)
    }

    /// "$1 = 18.48 MXN": how much of the currency 1 USD buys, in US number formatting.
    private func rateText(for code: String) -> String? {
        guard let rate = rates.rates[code] else { return nil }
        let formattedRate = rate.formatted(.number.precision(.fractionLength(2)).locale(Locale(identifier: "en_US")))
        return "$1 = \(formattedRate) \(code)"
    }

    /// Swipe down on the header to close, like a system sheet.
    private var swipeDown: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                dragOffset = max(value.translation.height, 0)
            }
            .onEnded { value in
                if value.translation.height > 120 || value.predictedEndTranslation.height > 300 {
                    onClose()
                } else {
                    withAnimation(.smooth(duration: 0.25)) {
                        dragOffset = 0
                    }
                }
            }
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        Colors.black.ignoresSafeArea()
        CurrencyPicker(selection: .constant("MXN"), rates: ExchangeRates(), onClose: {})
    }
    .ignoresSafeArea()
}
