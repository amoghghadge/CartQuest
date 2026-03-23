import Foundation

class KrogerService {
    private let clientId: String
    private let clientSecret: String
    private var token: String?
    private var tokenExpiry: Date = .distantPast
    private let session = URLSession.shared
    private let baseURL = "https://api.kroger.com"

    // Use an actor or serial queue for thread-safe token refresh
    private let tokenLock = NSLock()

    init(clientId: String, clientSecret: String) {
        self.clientId = clientId
        self.clientSecret = clientSecret
    }

    // MARK: - Public API

    func searchProducts(term: String, locationId: String? = nil, limit: Int = 20) async throws -> [KrogerProduct] {
        let token = try await getToken()
        var components = URLComponents(string: "\(baseURL)/v1/products")!
        var queryItems = [
            URLQueryItem(name: "filter.term", value: term),
            URLQueryItem(name: "filter.limit", value: "\(limit)")
        ]
        if let locationId = locationId {
            queryItems.append(URLQueryItem(name: "filter.locationId", value: locationId))
        }
        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(KrogerProductResponse.self, from: data)
        return response.data
    }

    func searchLocations(lat: Double, lon: Double, radiusInMiles: Int = 10, limit: Int = 10) async throws -> [KrogerStore] {
        let token = try await getToken()
        var components = URLComponents(string: "\(baseURL)/v1/locations")!
        components.queryItems = [
            URLQueryItem(name: "filter.lat.near", value: "\(lat)"),
            URLQueryItem(name: "filter.lon.near", value: "\(lon)"),
            URLQueryItem(name: "filter.radiusInMiles", value: "\(radiusInMiles)"),
            URLQueryItem(name: "filter.limit", value: "\(limit)")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(KrogerLocationResponse.self, from: data)
        return response.data
    }

    // MARK: - Token Management

    private func getToken() async throws -> String {
        tokenLock.lock()
        if let token = token, Date() < tokenExpiry {
            tokenLock.unlock()
            return token
        }
        tokenLock.unlock()

        // Request new token
        let credentials = "\(clientId):\(clientSecret)"
        let credentialsData = credentials.data(using: .utf8)!
        let base64Credentials = credentialsData.base64EncodedString()

        var request = URLRequest(url: URL(string: "\(baseURL)/v1/connect/oauth2/token")!)
        request.httpMethod = "POST"
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "grant_type=client_credentials&scope=product.compact".data(using: .utf8)

        let (data, _) = try await session.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let accessToken = json["access_token"] as! String
        let expiresIn = json["expires_in"] as! Int

        tokenLock.lock()
        self.token = accessToken
        self.tokenExpiry = Date().addingTimeInterval(TimeInterval(expiresIn - 60))
        tokenLock.unlock()

        return accessToken
    }
}

// Response wrappers
private struct KrogerProductResponse: Codable {
    let data: [KrogerProduct]
}

private struct KrogerLocationResponse: Codable {
    let data: [KrogerStore]
}
