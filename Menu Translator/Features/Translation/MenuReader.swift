import OSLog
import SwiftUI
import Translation
import Vision

/// What `ZoomablePhoto` does to the photo on screen, needed to crop exactly what the user sees.
struct PhotoTransform: Equatable {
    var scale: CGFloat = 1
    var offset: CGSize = .zero
}

/// A dish read from the part of the menu photo inside the selection frame.
struct MenuItem: Equatable {
    /// Recognized text without the price, in the menu's language.
    var originalText: String
    /// `originalText` in English, once translated.
    var translatedText: String?
    /// In the menu's currency.
    var price: Decimal?
    /// The cropped part of the photo.
    var photo: UIImage
}

/// Crops, reads and translates the selected part of a menu photo.
enum MenuReader {
    /// Renders the part of `image` under `rect` exactly as it appears on screen.
    ///
    /// Mirrors `ZoomablePhoto`: aspect-fill into `containerSize`, then scale and rotate around the
    /// center, then offset. `rect` is in the photo container's coordinates.
    static func crop(
        _ image: UIImage,
        containerSize: CGSize,
        transform: PhotoTransform,
        rotation: Angle,
        rect: CGRect
    ) -> UIImage? {
        guard image.size.width > 0, image.size.height > 0, rect.width > 0, rect.height > 0 else { return nil }
        let fill = max(containerSize.width / image.size.width, containerSize.height / image.size.height)
        let pointsPerPixel = fill * transform.scale
        let format = UIGraphicsImageRendererFormat()
        // Roughly the photo's own resolution, so small menu text stays readable.
        format.scale = min(max(1 / pointsPerPixel, 1), 4)
        format.opaque = true
        return UIGraphicsImageRenderer(size: rect.size, format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: rect.size))
            let cg = context.cgContext
            cg.translateBy(
                x: containerSize.width / 2 + transform.offset.width - rect.minX,
                y: containerSize.height / 2 + transform.offset.height - rect.minY
            )
            cg.rotate(by: rotation.radians)
            cg.scaleBy(x: pointsPerPixel, y: pointsPerPixel)
            image.draw(in: CGRect(
                x: -image.size.width / 2,
                y: -image.size.height / 2,
                width: image.size.width,
                height: image.size.height
            ))
        }
    }

    /// On-device text recognition; lines are joined with newlines. Empty when nothing is found.
    static func recognizeText(in image: UIImage, language: Locale.Language) async -> String {
        guard let cgImage = image.cgImage else { return "" }
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = [language]
        request.usesLanguageCorrection = true
        let observations = (try? await request.perform(on: cgImage)) ?? []
        return observations
            .map(\.transcript)
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    /// Translates with Apple Translation; `nil` if the languages aren't installed or it fails.
    static func translate(_ text: String, from source: Locale.Language, to target: Locale.Language) async -> String? {
        // Translated as one comma-separated line: reads better than line by line (which also
        // produced empty lines), and the commas carry over into the translation.
        let sentence = text.split(whereSeparator: \.isNewline).joined(separator: ", ")
        var translated: String?
        // Retried: right after the translation service restarts (e.g. after being idle), translating
        // fails as "not installed" for a second or two.
        for attempt in 1...3 {
            do {
                let session = TranslationSession(installedSource: source, target: target)
                translated = try await session.translate(sentence).targetText
                break
            } catch {
                Logger(subsystem: "com.nikashitsa.Menu-Translator", category: "LanguageDownloads")
                    .error("Translating failed (attempt \(attempt)): \(String(reflecting: error), privacy: .public)")
                guard attempt < 3, (try? await Task.sleep(for: .seconds(1))) != nil else { return nil }
            }
        }
        guard let translated else { return nil }
        // One compact line for the tooltip.
        return translated
            .split(whereSeparator: \.isNewline)
            // Trailing commas dropped, so joining doesn't double them.
            .map { $0.trimmingCharacters(in: .whitespaces.union(CharacterSet(charactersIn: ",;"))) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    /// Splits a menu entry into its text and price (e.g. "Tacos al pastor ..... $45,50" →
    /// "Tacos al pastor", 45.50). The price is the last number next to a symbol of the menu's currency
    /// ("$80", "12,50 €", "S/ 25", "100 MXN"; see `CurrencyInfo.priceSymbols(of:)`), or the last
    /// number when none has one — so "Chapata $80, … con 4 quesos" is 80.
    static func splitPrice(from text: String, currencyCode: String) -> (text: String, price: Decimal?) {
        // Longest first, so "RD$" wins over "$".
        let symbols = CurrencyInfo.priceSymbols(of: currencyCode).sorted { $0.count > $1.count }
        // How text recognition misreads "$" ("S95", "s95", "§95") and "€" ("E12", "e12").
        var misreads: Set<Character> = []
        if symbols.contains(where: { $0.contains("$") }) { misreads.formUnion(["S", "s", "§"]) }
        if symbols.contains("€") { misreads.formUnion(["E", "e"]) }
        // Space-grouped thousands first ("1 234,00", common in French menus), then plain numbers.
        let number = /\d{1,3}(?:[ \u{00A0}\u{202F}]\d{3})+(?:[.,]\d{1,2})?|\d[\d.,]*\d|\d/
        let matches = text.matches(of: number)
        // The number is parsed alone (a symbol like "S/." would add a decimal point); the symbol is
        // removed with it.
        let withSymbol = matches.compactMap { match in
            symbolRange(around: match.range, in: text, symbols: symbols, misreads: misreads)
                .map { (number: match.range, removed: $0) }
        }
        let symbolPrice = withSymbol.last.flatMap { chosen in
            parsePrice(String(text[chosen.number])).map { (removed: chosen.removed, price: $0) }
        }
        // "9€80" (French chalkboards): the euro sign is the decimal separator. Preferred over a
        // symbol price before it, as the price usually ends the entry.
        let euroDecimal = symbols.contains("€") ? lastEuroDecimalPrice(in: text) : nil
        let chosen: (removed: Range<String.Index>, price: Decimal)?
        if let euroDecimal, symbolPrice.map({ euroDecimal.removed.lowerBound >= $0.removed.lowerBound }) ?? true {
            chosen = euroDecimal
        } else if let symbolPrice {
            chosen = symbolPrice
        } else {
            chosen = matches.last.flatMap { match in
                parsePrice(String(text[match.range])).map { (removed: match.range, price: $0) }
            }
        }
        guard let chosen else { return (cleaned(text), nil) }
        var remaining = text
        remaining.removeSubrange(chosen.removed)
        return (cleaned(remaining), chosen.price)
    }

    /// The last "9€80" / "12 € 50" price: whole euros, "€", then exactly two digits of cents. Not
    /// "12,50 € 20 cl" (the number before "€" already has decimals) nor "€ 300".
    private static func lastEuroDecimalPrice(in text: String) -> (removed: Range<String.Index>, price: Decimal)? {
        let pattern = /(\d{1,4})[ \u{00A0}]?€[ \u{00A0}]?(\d{2})(?!\d)/
        return text.matches(of: pattern).reversed().lazy.compactMap { match -> (removed: Range<String.Index>, price: Decimal)? in
            let start = match.range.lowerBound
            if start > text.startIndex {
                let before = text[text.index(before: start)]
                guard !before.isNumber, before != ".", before != "," else { return nil }
            }
            guard let euros = Decimal(string: String(match.output.1)),
                  let cents = Decimal(string: String(match.output.2)) else { return nil }
            return (match.range, euros + cents / 100)
        }.first
    }

    /// Symbols written before the price ("$80", "S/ 25"); the rest usually follow it ("12 €",
    /// "100 MXN"). Decides which number a symbol between two belongs to ("25.000 COP 2 personas").
    private static let prefixSymbols: Set<String> = [
        "$", "₡", "₲", "S/.", "S/", "RD$", "C$", "B/.", "Bs.", "Bs", "Gs.", "Gs",
    ]

    /// `range` extended over one of `symbols` right before or after it (spaces allowed between),
    /// so it's removed with the number; `nil` without one. A symbol must not be part of a word.
    /// `misreads` (e.g. "S" for "$") only count right before the number, with no space: on their
    /// own they're too often ordinary text.
    private static func symbolRange(
        around range: Range<String.Index>,
        in text: String,
        symbols: [String],
        misreads: Set<Character>
    ) -> Range<String.Index>? {
        let spaces: Set<Character> = [" ", "\u{00A0}", "\u{202F}"]
        func isWordBoundary(_ index: String.Index, before: Bool) -> Bool {
            if before {
                return index == text.startIndex || !text[text.index(before: index)].isLetter
            }
            return index == text.endIndex || !text[index].isLetter
        }

        // Misread symbol stuck to the number.
        if range.lowerBound > text.startIndex {
            let symbol = text.index(before: range.lowerBound)
            if misreads.contains(text[symbol]), isWordBoundary(symbol, before: true) {
                return symbol..<range.upperBound
            }
        }
        // Symbol before the number.
        var start = range.lowerBound
        while start > text.startIndex, spaces.contains(text[text.index(before: start)]) {
            start = text.index(before: start)
        }
        let textBefore = text[..<start]
        if let symbol = symbols.first(where: { textBefore.hasSuffix($0) }) {
            let symbolStart = text.index(start, offsetBy: -symbol.count)
            let followsNumber = text[..<symbolStart]
                .trimmingCharacters(in: .whitespaces).last?.isNumber ?? false
            if isWordBoundary(symbolStart, before: true), prefixSymbols.contains(symbol) || !followsNumber {
                return symbolStart..<range.upperBound
            }
        }
        // Symbol after the number.
        var end = range.upperBound
        while end < text.endIndex, spaces.contains(text[end]) {
            end = text.index(after: end)
        }
        let textAfter = text[end...]
        if let symbol = symbols.first(where: { textAfter.hasPrefix($0) }) {
            let symbolEnd = text.index(end, offsetBy: symbol.count)
            let precedesNumber = text[symbolEnd...]
                .trimmingCharacters(in: .whitespaces).first?.isNumber ?? false
            if isWordBoundary(symbolEnd, before: false), !prefixSymbols.contains(symbol) || !precedesNumber {
                return range.lowerBound..<symbolEnd
            }
        }
        return nil
    }

    /// Parses "1.234,56", "1,234.56", "1 234,56", "12,50", "1.500" (thousands) and similar.
    /// Also used for prices typed into Edit price.
    static func parsePrice(_ token: String) -> Decimal? {
        var token = token
        let lastDot = token.lastIndex(of: ".")
        let lastComma = token.lastIndex(of: ",")
        var decimalSeparator: Character?
        if let lastDot, let lastComma {
            decimalSeparator = lastDot > lastComma ? "." : ","
        } else if let separatorIndex = lastDot ?? lastComma {
            // A single kind of separator followed by exactly 3 digits groups thousands ("1.500").
            let digitsAfter = token.distance(from: separatorIndex, to: token.endIndex) - 1
            decimalSeparator = digitsAfter == 3 ? nil : token[separatorIndex]
        }
        if let decimalSeparator, let index = token.lastIndex(of: decimalSeparator) {
            token.replaceSubrange(index...index, with: "#")
        }
        token = token.filter { $0.isNumber || $0 == "#" }.replacingOccurrences(of: "#", with: ".")
        return Decimal(string: token, locale: Locale(identifier: "en_US"))
    }

    /// Trims leader dots, dashes and currency symbols left around the removed price, and commas
    /// ending a line (which would be doubled by the join), and joins the
    /// lines into one compact, comma-separated line. Splits on every kind of line break
    /// ("\r\n", U+2028…), not just "\n".
    private static func cleaned(_ text: String) -> String {
        let trimmed = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".…·-–—:,;$€₡₲"))
        return text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: trimmed) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
            // A price removed mid-line ("Croissant 12 € avec…") leaves two spaces.
            .replacing(/\ {2,}/, with: " ")
    }
}
