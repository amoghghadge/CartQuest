import Foundation
import CoreLocation

struct DirectionsResult {
    let totalDurationSeconds: Int
    let encodedPolyline: String
    let waypointOrder: [Int]
}

class DirectionsService {
    private let apiKey: String

    init(apiKey: String) { self.apiKey = apiKey }

    func getDirections(
        origin: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D,
        waypoints: [CLLocationCoordinate2D] = []
    ) async throws -> DirectionsResult {
        var urlString = "https://maps.googleapis.com/maps/api/directions/json?"
        urlString += "origin=\(origin.latitude),\(origin.longitude)"
        urlString += "&destination=\(destination.latitude),\(destination.longitude)"
        if !waypoints.isEmpty {
            let wp = waypoints.map { "\($0.latitude),\($0.longitude)" }.joined(separator: "|")
            urlString += "&waypoints=optimize:true|\(wp)"
        }
        urlString += "&key=\(apiKey)"

        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        guard let routes = json["routes"] as? [[String: Any]], let route = routes.first else {
            let status = json["status"] as? String ?? "UNKNOWN"
            throw NSError(domain: "DirectionsService", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Directions API returned status: \(status)"
            ])
        }

        let legs = route["legs"] as! [[String: Any]]
        var totalSeconds = 0
        for leg in legs {
            let duration = leg["duration"] as! [String: Any]
            totalSeconds += duration["value"] as! Int
        }

        let overviewPolyline = route["overview_polyline"] as! [String: Any]
        let polyline = overviewPolyline["points"] as! String

        var waypointOrder: [Int] = []
        if let order = route["waypoint_order"] as? [Int] {
            waypointOrder = order
        }

        return DirectionsResult(
            totalDurationSeconds: totalSeconds,
            encodedPolyline: polyline,
            waypointOrder: waypointOrder
        )
    }
}
