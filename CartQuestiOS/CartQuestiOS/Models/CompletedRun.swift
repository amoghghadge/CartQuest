import Foundation

struct CompletedRun: Codable, Identifiable {
    var id: String = ""
    var userId: String = ""
    var displayName: String = ""
    var photoUrl: String = ""
    var completedAt: Date = Date()
    var stores: [StoreStop] = []
    var totalDriveTimeMinutes: Int = 0
    var totalCost: Double = 0.0
}
