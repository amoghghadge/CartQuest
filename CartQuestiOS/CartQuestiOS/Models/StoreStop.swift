import Foundation

struct AssignedItem: Codable, Identifiable {
    var id: String { productId }
    var productId: String
    var name: String
    var brand: String
    var price: Double
}

struct StoreStop: Codable, Identifiable {
    var id: String { storeId }
    var storeId: String
    var storeName: String
    var address: String
    var lat: Double
    var lng: Double
    var items: [AssignedItem]
}
