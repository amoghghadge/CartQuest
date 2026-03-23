import Foundation

struct Substitute: Codable, Identifiable {
    var id: String { productId }
    var productId: String = ""
    var name: String = ""
    var brand: String = ""
}

struct CartItem: Codable, Identifiable {
    var id: String { productId }
    var productId: String = ""
    var name: String = ""
    var brand: String = ""
    var imageUrl: String = ""
    var quantity: Int = 1
    var substitutes: [Substitute] = []
}
