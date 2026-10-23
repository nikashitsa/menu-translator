import Foundation

extension FormatStyle where Self == Decimal.FormatStyle.Currency {
    /// US dollars in US formatting ("$13.85") on every device — the app is for US users, so a
    /// European region setting shouldn't turn amounts into "13,85 US$".
    /// Use via `value.formatted(.usd)`: `Text(value, format:)` swaps in the environment's locale.
    static var usd: Self {
        .currency(code: "USD").locale(Locale(identifier: "en_US"))
    }
}

/// Display names for ISO currency codes, and price texts.
enum CurrencyInfo {
    /// "$29.77 (550 MXN)", or whichever part is known ("$29.77", "550 MXN"); "?" when neither is.
    static func priceDescription(usd: Decimal?, menuPrice: Decimal?, currencyCode: String?) -> String {
        let local = menuPrice.flatMap { price in currencyCode.map { menuPriceText(price, currencyCode: $0) } }
        switch (usd, local) {
        case let (usd?, local?): return "\(usd.formatted(.usd)) (\(local))"
        case let (usd?, nil): return usd.formatted(.usd)
        case let (nil, local?): return local
        case (nil, nil): return "?"
        }
    }

    /// "550 MXN" for whole amounts, "45.50 MXN" otherwise, in US number formatting.
    static func menuPriceText(_ price: Decimal, currencyCode: String) -> String {
        let isWhole = price == Decimal(Int(truncating: NSDecimalNumber(decimal: price)))
        let precision: NumberFormatStyleConfiguration.Precision = isWhole ? .fractionLength(0) : .fractionLength(2)
        return "\(price.formatted(.number.precision(precision).locale(Locale(identifier: "en_US")))) \(currencyCode)"
    }

    /// How prices in the currency are written on menus, besides its code ("MXN"): "$", "S/", "€"…
    /// Single-letter symbols (Q, L, G) are left out: they'd catch measurements like "1 L".
    static func priceSymbols(of code: String) -> [String] {
        let symbols: [String: [String]] = [
            "ARS": ["$"], "CAD": ["$"], "CLP": ["$"], "COP": ["$"], "CUP": ["$"], "MXN": ["$"], "UYU": ["$"],
            "DOP": ["RD$", "$"], "NIO": ["C$"], "PAB": ["B/.", "$"], "CRC": ["₡"], "PEN": ["S/.", "S/"],
            "PYG": ["Gs.", "Gs", "₲"], "BOB": ["Bs.", "Bs"], "VES": ["Bs.", "Bs"], "EUR": ["€"], "CHF": ["Fr."],
            "MAD": ["DH", "Dhs"], "DZD": ["DA"], "TND": ["DT"], "XOF": ["F CFA", "FCFA", "CFA"],
            "XAF": ["FCFA", "CFA"], "XPF": ["FCFP"], "BIF": ["FBu"], "CDF": ["FC"], "DJF": ["Fdj"], "GNF": ["FG"],
            "KMF": ["CF"], "MGA": ["Ar"], "RWF": ["FRw", "RF"], "SCR": ["SR"], "VUV": ["VT"],
        ]
        return symbols[code, default: []] + [code]
    }

    static func name(of code: String) -> String {
        Locale.current.localizedString(forCurrencyCode: code) ?? code
    }

    /// Menu-language countries using the currency, alphabetically, e.g. "Mexico" or "Belgium, France, …".
    static func countries(of code: String) -> String {
        (MenuLanguage.currencyRegions[code] ?? [])
            .compactMap { Locale.current.localizedString(forRegionCode: $0) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .joined(separator: ", ")
    }
}
