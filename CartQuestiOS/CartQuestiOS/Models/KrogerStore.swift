import Foundation

struct KrogerStore: Codable, Identifiable {
    var id: String { locationId }
    var locationId: String
    var chain: String
    var name: String
    var address: KrogerAddress
    var geolocation: KrogerGeolocation
}

struct KrogerAddress: Codable {
    var addressLine1: String
    var city: String
    var state: String
    var zipCode: String
}

struct KrogerGeolocation: Codable {
    var latitude: Double
    var longitude: Double
}
