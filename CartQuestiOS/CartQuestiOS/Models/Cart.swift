import Foundation

struct Cart: Codable, Identifiable {
    var id: String = ""
    var status: String = "active"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var items: [CartItem] = []
}
