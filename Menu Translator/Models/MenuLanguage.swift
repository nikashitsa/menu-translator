import Foundation

struct MenuLanguage: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let details: String
    /// Language identifier used by Apple Translation.
    let locale: Locale.Language
    /// ISO region codes of countries where menus are in this language (official or widely used).
    var regions: [String] = []
}

extension MenuLanguage {
    static let english = MenuLanguage(name: "English", details: "Translation language (required)", locale: Locale.Language(identifier: "en"))
    static let spanish = MenuLanguage(name: "Spanish", details: "Mexico, Spain, Dominican Republic, Costa Rica, Puerto Rico, Colombia, Peru, Argentina, and others.", locale: Locale.Language(identifier: "es"), regions: [
        "ES", "MX", "GT", "HN", "SV", "NI", "CR", "PA", "CU", "DO", "PR",
        "CO", "VE", "EC", "PE", "BO", "CL", "AR", "PY", "UY", "GQ",
    ])
    static let french = MenuLanguage(name: "French", details: "France, Canada, Haiti, Martinique, Switzerland, Belgium, Seychelles, Morocco, and others.", locale: Locale.Language(identifier: "fr"), regions: [
        "FR", "BE", "LU", "MC", "CH", "CA", "HT", "MQ", "GP", "GF", "RE",
        "MA", "DZ", "TN", "SN", "CI", "ML", "BF", "NE", "TG", "BJ", "CM", "GA", "TD", "CF", "CG", "CD",
        "MG", "RW", "BI", "DJ", "KM", "GN", "SC", "NC", "PF", "VU",
    ])
    static let italian = MenuLanguage(name: "Italian", details: "Italy, San Marino, Vatican City, Switzerland.", locale: Locale.Language(identifier: "it"), regions: [
        "IT", "SM", "VA", "CH",
    ])

    /// Language menus are translated into.
    static let translationTarget = english
    /// Languages a menu can be translated from.
    static let menuLanguages: [MenuLanguage] = [.spanish, .french, .italian]

    /// Countries (region codes) of all menu languages, grouped by the currency they use.
    /// USD is left out on purpose, so dollarized countries (Ecuador, El Salvador, Puerto Rico) add nothing.
    static let currencyRegions: [String: [String]] = {
        // iOS reports Venezuela's newer code; the rates feed uses VES for the same bolívar.
        let aliases = ["VED": "VES"]
        var result: [String: [String]] = [:]
        for region in Set(menuLanguages.flatMap(\.regions)) {
            guard let currency = Locale(identifier: "und_\(region)").currency?.identifier, currency != "USD" else { continue }
            result[aliases[currency] ?? currency, default: []].append(region)
        }
        return result
    }()

    /// Currencies a menu can be priced in.
    static var menuCurrencies: Set<String> { Set(currencyRegions.keys) }
    /// Used when nothing valid is stored.
    static let defaultCurrency = "MXN"

    /// Short, stable code for storage, e.g. "es".
    var code: String { locale.minimalIdentifier }

    /// The menu language for a stored `code`, falling back to Spanish.
    static func menuLanguage(code: String) -> MenuLanguage {
        menuLanguages.first { $0.code == code } ?? .spanish
    }
}
