import Foundation
import UIKit
import CoreLocation
import FirebaseAuth
import Observation

enum RouteState: Equatable {
    case loading
    case computed(route: RouteOptimizer.OptimizedRoute, userLocation: CLLocationCoordinate2D)
    case error(String)

    static func == (lhs: RouteState, rhs: RouteState) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading):
            return true
        case (.error(let a), .error(let b)):
            return a == b
        case (.computed(let r1, let l1), .computed(let r2, let l2)):
            return r1.encodedPolyline == r2.encodedPolyline
                && l1.latitude == l2.latitude
                && l1.longitude == l2.longitude
        default:
            return false
        }
    }
}

@Observable
class RouteMapViewModel {
    var routeState: RouteState = .loading
    var tripCompleted: Bool = false

    private let cartId: String
    private let cartRepository: CartRepository
    private let runsRepository: RunsRepository
    private let krogerService: KrogerService
    private let locationService: LocationService
    private let directionsService: DirectionsService
    private let routeOptimizer: RouteOptimizer

    private var cart: Cart?

    init(
        cartId: String,
        cartRepository: CartRepository = CartRepository(),
        runsRepository: RunsRepository = RunsRepository(),
        krogerService: KrogerService = KrogerService(
            clientId: "KROGER_CLIENT_ID_PLACEHOLDER",
            clientSecret: "KROGER_CLIENT_SECRET_PLACEHOLDER"
        ),
        locationService: LocationService = LocationService(),
        directionsService: DirectionsService = DirectionsService(apiKey: "GOOGLE_MAPS_API_KEY_PLACEHOLDER"),
        routeOptimizer: RouteOptimizer = RouteOptimizer()
    ) {
        self.cartId = cartId
        self.cartRepository = cartRepository
        self.runsRepository = runsRepository
        self.krogerService = krogerService
        self.locationService = locationService
        self.directionsService = directionsService
        self.routeOptimizer = routeOptimizer

        Task { await computeRoute() }
    }

    // MARK: - Route Computation

    private func computeRoute() async {
        routeState = .loading
        do {
            // 1. Load cart
            guard let activeCart = try await cartRepository.getActiveCart(),
                  !activeCart.items.isEmpty else {
                routeState = .error("Cart is empty or not found.")
                return
            }
            self.cart = activeCart

            // 2. Get user location
            let userLocation = try await locationService.getCurrentLocation()

            // 3. Query nearby stores
            let stores = try await krogerService.searchLocations(
                lat: userLocation.latitude,
                lon: userLocation.longitude,
                radiusInMiles: 10,
                limit: 10
            )

            guard !stores.isEmpty else {
                routeState = .error("No stores found nearby.")
                return
            }

            // 4. For each store, query product availability
            var storeAvailabilities: [RouteOptimizer.StoreAvailability] = []
            let allProductIds = activeCart.items.flatMap { item in
                [item.productId] + item.substitutes.map { $0.productId }
            }
            let uniqueProductIds = Array(Set(allProductIds))

            for store in stores {
                var availableProducts: [String: KrogerProduct] = [:]
                // Search for each product at this store location
                for productId in uniqueProductIds {
                    do {
                        let results = try await krogerService.searchProducts(
                            term: productId,
                            locationId: store.locationId,
                            limit: 1
                        )
                        if let product = results.first(where: { $0.productId == productId }) {
                            availableProducts[productId] = product
                        }
                    } catch {
                        // Skip product if query fails for this store
                        continue
                    }
                }
                if !availableProducts.isEmpty {
                    storeAvailabilities.append(
                        RouteOptimizer.StoreAvailability(
                            store: store,
                            availableProducts: availableProducts
                        )
                    )
                }
            }

            // 5 & 6. Run optimizer
            let route = try await routeOptimizer.optimize(
                cartItems: activeCart.items,
                storeAvailabilities: storeAvailabilities,
                userLocation: userLocation,
                getDriveTime: { [weak self] origin, storeList in
                    guard let self else { throw URLError(.cancelled) }
                    let waypoints = storeList.dropLast().map {
                        CLLocationCoordinate2D(latitude: $0.geolocation.latitude, longitude: $0.geolocation.longitude)
                    }
                    let lastStore = storeList.last!
                    let destination = CLLocationCoordinate2D(
                        latitude: lastStore.geolocation.latitude,
                        longitude: lastStore.geolocation.longitude
                    )
                    let result = try await self.directionsService.getDirections(
                        origin: origin,
                        destination: destination,
                        waypoints: Array(waypoints)
                    )
                    return (result.totalDurationSeconds, result.encodedPolyline)
                }
            )

            routeState = .computed(route: route, userLocation: userLocation)
        } catch {
            routeState = .error(error.localizedDescription)
        }
    }

    // MARK: - Navigation

    func startNavigation() {
        guard case .computed(let route, let userLocation) = routeState else { return }

        let stops = route.stops
        guard !stops.isEmpty else { return }

        // Build Google Maps URL with waypoints
        let destination = stops.last!
        let destinationStr = "\(destination.lat),\(destination.lng)"

        var urlString = "comgooglemaps://?saddr=\(userLocation.latitude),\(userLocation.longitude)"
        urlString += "&daddr=\(destinationStr)"

        if stops.count > 1 {
            let waypointStops = stops.dropLast()
            let waypointsStr = waypointStops.map { "\($0.lat),\($0.lng)" }.joined(separator: "+to:")
            urlString += "+to:\(waypointsStr)"
        }

        urlString += "&directionsmode=driving"

        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        } else if let mapsUrl = URL(string: "https://www.google.com/maps/dir/?api=1&origin=\(userLocation.latitude),\(userLocation.longitude)&destination=\(destinationStr)&travelmode=driving") {
            UIApplication.shared.open(mapsUrl)
        }
    }

    // MARK: - Trip Completion

    func completeTrip() async {
        guard case .computed(let route, _) = routeState else { return }

        do {
            let user = Auth.auth().currentUser
            let totalCost = route.stops.flatMap { $0.items }.reduce(0.0) { $0 + $1.price }

            let run = CompletedRun(
                userId: user?.uid ?? "",
                displayName: user?.displayName ?? "Anonymous",
                photoUrl: user?.photoURL?.absoluteString ?? "",
                completedAt: Date(),
                stores: route.stops,
                totalDriveTimeMinutes: route.totalDriveTimeSeconds / 60,
                totalCost: totalCost
            )

            _ = try await runsRepository.saveCompletedRun(run)

            // Mark cart as completed
            if let cart = self.cart, !cart.id.isEmpty {
                try await cartRepository.completeCart(cartId: cart.id)
            }

            tripCompleted = true
        } catch {
            routeState = .error("Failed to save trip: \(error.localizedDescription)")
        }
    }
}
