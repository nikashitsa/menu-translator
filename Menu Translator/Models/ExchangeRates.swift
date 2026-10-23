import Foundation
import Observation

/// Fiat exchange rates against USD from rates.suninvest.org.
///
/// Starts from the last saved response (or, on first launch, the copy bundled with the app), then
/// refreshes from the API. If the API is down or the device is offline, the older rates stay in use.
@Observable
final class ExchangeRates {
    /// Units of each currency per 1 USD, keyed by ISO code.
    private(set) var rates: [String: Decimal] = [:]
    private(set) var updatedAt: Date?

    /// Currencies to offer for menu prices: those used where the menu languages are spoken, alphabetically.
    /// `rates` keeps every currency, since USD and others are still needed for conversion.
    var currencies: [String] { rates.keys.filter(MenuLanguage.menuCurrencies.contains).sorted() }

    private static let url = URL(string: "https://rates.suninvest.org/api/v1/rates")!
    /// Precious metals and the IMF's SDR are in the feed but aren't currencies people pay with.
    private static let nonFiat: Set<String> = ["XAU", "XAG", "XPD", "XPT", "XDR"]
    private static var cacheURL: URL { URL.cachesDirectory.appending(path: "exchange-rates.json") }
    private static var bundledURL: URL? { Bundle.main.url(forResource: "exchange-rates", withExtension: "json") }

    func load() async {
        if rates.isEmpty {
            let saved = (try? Data(contentsOf: Self.cacheURL)) ?? Self.bundledURL.flatMap { try? Data(contentsOf: $0) }
            if let saved {
                apply(saved)
            }
        }
        do {
            var request = URLRequest(url: Self.url)
            request.timeoutInterval = 15
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200, apply(data) else { return }
            try? data.write(to: Self.cacheURL, options: .atomic)
        } catch {
            // API down or offline: keep using the rates loaded above.
        }
    }

    /// Applies a response if it parses and has rates; otherwise keeps the current ones.
    @discardableResult
    private func apply(_ data: Data) -> Bool {
        guard let response = try? Self.decoder.decode(Response.self, from: data) else { return false }
        var rates: [String: Decimal] = [:]
        for rate in response.rates where rate.base == "USD" && Self.isFiat(rate.quote) {
            rates[rate.quote] = rate.rate
        }
        guard !rates.isEmpty else { return false }
        self.rates = rates
        updatedAt = response.updatedAt
        return true
    }

    private static func isFiat(_ code: String) -> Bool {
        // Codes iOS can't name (e.g. "CMD") aren't real ISO currencies either.
        !nonFiat.contains(code) && Locale(identifier: "en").localizedString(forCurrencyCode: code) != nil
    }

    private struct Response: Decodable {
        let updatedAt: Date
        let rates: [Rate]
    }

    private struct Rate: Decodable {
        let base: String
        let quote: String
        let rate: Decimal
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let string = try decoder.singleValueContainer().decode(String.self)
            return try Date(string, strategy: .iso8601.year().month().day().time(includingFractionalSeconds: true))
        }
        return decoder
    }()
}
