import Foundation

struct User: Codable, Identifiable {
    var id: String = ""
    var email: String = ""
    var displayName: String = ""
    var photoUrl: String = ""
    var createdAt: Date = Date()
}
