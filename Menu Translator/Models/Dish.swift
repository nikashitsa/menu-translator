import SwiftData
import UIKit

@Model
final class Dish {
    var originalName: String
    var translatedName: String
    /// In US dollars.
    var price: Decimal
    var quantity: Int
    /// The price as written on the menu, and its currency (e.g. 550 MXN).
    var menuPrice: Decimal?
    var menuCurrencyCode: String?
    /// The dish's part of the menu photo as compressed JPEG, kept outside the database file.
    @Attribute(.externalStorage)
    var photoData: Data?
    /// Keeps dishes in the order they were added (relationships are unordered).
    var createdAt: Date
    var order: Order?

    init(
        originalName: String,
        translatedName: String,
        price: Decimal,
        quantity: Int = 1,
        photo: UIImage? = nil,
        menuPrice: Decimal? = nil,
        menuCurrencyCode: String? = nil
    ) {
        self.originalName = originalName
        self.translatedName = translatedName
        self.price = price
        self.quantity = quantity
        self.menuPrice = menuPrice
        self.menuCurrencyCode = menuCurrencyCode
        self.photoData = photo.flatMap(Self.compressed)
        self.createdAt = .now
    }

    var photo: UIImage? {
        photoData.flatMap(UIImage.init(data:))
    }

    var subtotal: Decimal {
        price * Decimal(quantity)
    }

    /// Longest side at most 1,000 px at 70% JPEG quality: plenty for a menu line, typically tens of KB.
    private static func compressed(_ image: UIImage) -> Data? {
        let maxSide: CGFloat = 1000
        let pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let factor = min(1, maxSide / max(pixelSize.width, pixelSize.height))
        let targetSize = CGSize(width: (pixelSize.width * factor).rounded(), height: (pixelSize.height * factor).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let resized = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: 0.7)
    }
}
