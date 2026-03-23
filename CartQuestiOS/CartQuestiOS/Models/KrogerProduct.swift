import Foundation

struct KrogerProduct: Codable, Identifiable {
    var id: String { productId }
    var productId: String
    var description: String
    var brand: String
    var images: [KrogerImage]
    var items: [KrogerItemPrice]
}

struct KrogerImage: Codable {
    var perspective: String
    var sizes: [KrogerImageSize]
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
    var regular: Double
    var promo: Double
}

struct KrogerFulfillment: Codable {
    var inStore: Bool
}
