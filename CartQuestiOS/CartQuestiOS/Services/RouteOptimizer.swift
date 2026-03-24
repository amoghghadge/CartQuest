import Foundation
import CoreLocation

class RouteOptimizer {

    struct StoreAvailability {
        let store: KrogerStore
        let availableProducts: [String: KrogerProduct] // productId -> product
    }

    struct OptimizedRoute {
        let stops: [StoreStop]
        let totalDriveTimeSeconds: Int
        let encodedPolyline: String
    }

    enum RouteError: LocalizedError {
        case emptyCart
        case noStoresAvailable
        case uncoveredItems(indices: [Int])
        case cannotCoverAll
        case noRouteFound

        var errorDescription: String? {
            switch self {
            case .emptyCart:
                return "Cart is empty"
            case .noStoresAvailable:
                return "No stores available"
            case .uncoveredItems(let indices):
                return "Items at indices \(indices) cannot be found at any store"
            case .cannotCoverAll:
                return "Cannot cover all items with available stores"
            case .noRouteFound:
                return "Could not compute route for any store combination"
            }
        }
    }

    /// Find the route that covers all cart items with minimum total drive time.
    ///
    /// Algorithm:
    /// 1. For each cart item, resolve which product to buy at each store
    ///    (prefer primary, fall back through substitutes in order)
    /// 2. Build coverage matrix: which stores can fulfill which cart items
    /// 3. Find all minimal store subsets that cover all items
    ///    - Start from subset size 1, increase up to store count
    ///    - For each size, generate combinations and check coverage
    ///    - Stop once we find feasible subsets at current size
    /// 4. For each feasible subset, call getDriveTime to get actual driving time
    /// 5. Return the subset + route with lowest total drive time
    /// 6. Assign items to stores: for each cart item, assign to the first store
    ///    in visit order that has it (prefer primary, then substitutes in priority order)
    func optimize(
        cartItems: [CartItem],
        storeAvailabilities: [StoreAvailability],
        userLocation: CLLocationCoordinate2D,
        getDriveTime: @Sendable @escaping (CLLocationCoordinate2D, [KrogerStore]) async throws -> (Int, String)
    ) async throws -> OptimizedRoute {
        guard !cartItems.isEmpty else { throw RouteError.emptyCart }
        guard !storeAvailabilities.isEmpty else { throw RouteError.noStoresAvailable }

        // Step 1 & 2: Build coverage matrix
        let coverage = buildCoverageMatrix(cartItems: cartItems, storeAvailabilities: storeAvailabilities)

        // Check if all items can be covered
        let uncoveredIndices = coverage.filter { $0.value.isEmpty }.map { $0.key }.sorted()
        if !uncoveredIndices.isEmpty {
            throw RouteError.uncoveredItems(indices: uncoveredIndices)
        }

        // Step 3: Find minimal store subsets that cover all items
        let storeIndices = Array(storeAvailabilities.indices)
        var feasibleSubsets: [Set<Int>] = []

        for subsetSize in 1...storeIndices.count {
            feasibleSubsets = combinations(count: storeIndices.count, size: subsetSize)
                .filter { subset in coversAllItems(storeSubset: subset, coverage: coverage) }
            if !feasibleSubsets.isEmpty { break }
        }

        guard !feasibleSubsets.isEmpty else { throw RouteError.cannotCoverAll }

        // Pre-compute item assignments for each feasible subset (sync, no concurrency issues)
        let subsetAssignments: [(subset: Set<Int>, stops: [StoreStop], stores: [KrogerStore])] = feasibleSubsets.map { subset in
            let sortedIndices = subset.sorted()
            let stops = assignItemsToStores(
                cartItems: cartItems,
                storeIndices: sortedIndices,
                storeAvailabilities: storeAvailabilities
            )
            let stores = sortedIndices.map { storeAvailabilities[$0].store }
            return (subset, stops, stores)
        }

        // Step 4: For each feasible subset, get drive time (parallelized)
        let routeCandidates: [OptimizedRoute] = await withTaskGroup(of: OptimizedRoute?.self) { group in
            for assignment in subsetAssignments {
                group.addTask {
                    do {
                        let (driveTime, polyline) = try await getDriveTime(userLocation, assignment.stores)
                        return OptimizedRoute(
                            stops: assignment.stops,
                            totalDriveTimeSeconds: driveTime,
                            encodedPolyline: polyline
                        )
                    } catch {
                        return nil
                    }
                }
            }
            var results: [OptimizedRoute] = []
            for await candidate in group {
                if let candidate { results.append(candidate) }
            }
            return results
        }

        guard let route = routeCandidates.min(by: { $0.totalDriveTimeSeconds < $1.totalDriveTimeSeconds }) else {
            throw RouteError.noRouteFound
        }
        return route
    }

    // MARK: - Private helpers

    /// Build coverage matrix: cartItemIndex -> set of storeIndices that can fulfill it
    private func buildCoverageMatrix(
        cartItems: [CartItem],
        storeAvailabilities: [StoreAvailability]
    ) -> [Int: Set<Int>] {
        var coverage: [Int: Set<Int>] = [:]
        for itemIdx in cartItems.indices {
            let item = cartItems[itemIdx]
            let productIds = [item.productId] + item.substitutes.map { $0.productId }
            var storeSet = Set<Int>()
            for storeIdx in storeAvailabilities.indices {
                let available = storeAvailabilities[storeIdx].availableProducts
                if productIds.contains(where: { available.keys.contains($0) }) {
                    storeSet.insert(storeIdx)
                }
            }
            coverage[itemIdx] = storeSet
        }
        return coverage
    }

    /// Check if a store subset covers all cart items
    private func coversAllItems(storeSubset: Set<Int>, coverage: [Int: Set<Int>]) -> Bool {
        return coverage.allSatisfy { (_, stores) in
            !stores.isDisjoint(with: storeSubset)
        }
    }

    /// Generate all combinations of indices [0..<count] of given size
    private func combinations(count: Int, size: Int) -> [Set<Int>] {
        if size == 0 { return [Set<Int>()] }
        if count == 0 { return [] }
        var result: [Set<Int>] = []

        func backtrack(start: Int, current: inout Set<Int>) {
            if current.count == size {
                result.append(current)
                return
            }
            for i in start..<count {
                current.insert(i)
                backtrack(start: i + 1, current: &current)
                current.remove(i)
            }
        }

        var current = Set<Int>()
        backtrack(start: 0, current: &current)
        return result
    }

    /// Assign cart items to stores, building StoreStop objects
    private func assignItemsToStores(
        cartItems: [CartItem],
        storeIndices: [Int],
        storeAvailabilities: [StoreAvailability]
    ) -> [StoreStop] {
        var storeItems: [Int: [AssignedItem]] = [:]
        for idx in storeIndices {
            storeItems[idx] = []
        }

        for item in cartItems {
            let productIds = [item.productId] + item.substitutes.map { $0.productId }

            // Find first store (in order) that has any of the products
            for storeIdx in storeIndices {
                let available = storeAvailabilities[storeIdx].availableProducts
                if let matchedPid = productIds.first(where: { available.keys.contains($0) }) {
                    let product = available[matchedPid]!
                    let price = product.items?.first?.price?.regular ?? 0.0
                    storeItems[storeIdx]!.append(
                        AssignedItem(
                            productId: matchedPid,
                            name: product.description,
                            brand: product.brand ?? "",
                            price: price
                        )
                    )
                    break
                }
            }
        }

        // Build StoreStop objects, only include stores with assigned items
        return storeIndices.compactMap { idx in
            let items = storeItems[idx] ?? []
            guard !items.isEmpty else { return nil }
            let store = storeAvailabilities[idx].store
            return StoreStop(
                storeId: store.locationId,
                storeName: store.name,
                address: "\(store.address.addressLine1), \(store.address.city), \(store.address.state)",
                lat: store.geolocation.latitude,
                lng: store.geolocation.longitude,
                items: items
            )
        }
    }
}
