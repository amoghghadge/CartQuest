import Foundation

struct KrogerProduct: Codable, Identifiable {
    var id: String { productId }
    var productId: String
    var description: String
    var brand: String?
    var images: [KrogerImage]?
    var items: [KrogerItemPrice]?

    var bestImageUrl: String? {
        let featured = images?.first(where: { $0.featured == true })
        return (featured ?? images?.first)?.bestUrl
    }
}

struct KrogerImage: Codable {
    var perspective: String?
    var sizes: [KrogerImageSize]?
    var featured: Bool?

    private static let sizePreference = ["xlarge", "large", "medium", "small", "thumbnail"]

    var bestUrl: String? {
        guard let sizes else { return nil }
        for preferred in Self.sizePreference {
            if let match = sizes.first(where: { $0.size == preferred }) {
                return match.url
            }
        }
        return sizes.last?.url
    }
}

struct KrogerImageSize: Codable {
    var size: String
    var url: String
}

struct KrogerItemPrice: Codable {
    var price: KrogerPrice?
    var fulfillment: KrogerFulfillment?
}

struct KrogerPrice: Codable {
    var regular: Double?
    var promo: Double?
}

struct KrogerFulfillment: Codable {
    var inStore: Bool
}
