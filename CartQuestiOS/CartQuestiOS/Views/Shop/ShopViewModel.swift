import CoreLocation
import Foundation
import Observation

@Observable
class ShopViewModel {

    // MARK: - Nested Types

    struct ProductResult: Identifiable {
        let product: KrogerProduct
        let isAvailable: Bool

        var id: String { product.productId }

        var price: Double? {
            product.items?.first?.price?.regular
        }

        var imageUrl: String? {
            product.bestImageUrl
        }
    }

    // MARK: - State

    var searchQuery: String = ""
    var searchResults: [ProductResult] = []
    var isSearching: Bool = false
    var hasSearched: Bool = false

    var cart: Cart = Cart()
    var isSaving: Bool = false

    var nearbyLocationIds: [String] = []
    var locationError: String? = nil

    // MARK: - Private

    private let krogerService: KrogerService
    private let cartRepository: CartRepository
    private let locationService: LocationService

    private var searchTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?

    // MARK: - Init

    init(
        krogerService: KrogerService = KrogerService(
            clientId: Bundle.main.infoDictionary?["KROGER_CLIENT_ID"] as? String ?? "",
            clientSecret: Bundle.main.infoDictionary?["KROGER_CLIENT_SECRET"] as? String ?? ""
        ),
        cartRepository: CartRepository = CartRepository(),
        locationService: LocationService = LocationService()
    ) {
        self.krogerService = krogerService
        self.cartRepository = cartRepository
        self.locationService = locationService
        Task { await loadActiveCart() }
        Task { await fetchNearbyLocation() }
    }

    private init(skipInit: Bool) {
        self.krogerService = KrogerService(clientId: "", clientSecret: "")
        self.cartRepository = CartRepository()
        self.locationService = LocationService()
    }

    // MARK: - Location

    private func fetchNearbyLocation() async {
        do {
            let coordinate = try await locationService.getCurrentLocation()
            let stores = try await krogerService.searchLocations(
                lat: coordinate.latitude,
                lon: coordinate.longitude,
                radiusInMiles: 10,
                limit: 50
            )
            nearbyLocationIds = stores.map { $0.locationId }
        } catch {
            locationError = error.localizedDescription
        }
    }

    // MARK: - Cart Loading

    private func loadActiveCart() async {
        do {
            if let activeCart = try await cartRepository.getActiveCart() {
                cart = activeCart
            }
        } catch {
            print("Failed to load active cart: \(error)")
        }
    }

    // MARK: - Search

    func search() {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        searchTask?.cancel()
        searchTask = Task { await performSearch(query: query) }
    }

    private func performSearch(query: String) async {
        isSearching = true
        defer {
            isSearching = false
            hasSearched = true
        }

        let locationIds = nearbyLocationIds
        guard !locationIds.isEmpty else {
            // No stores found — search without location filter as fallback
            do {
                let products = try await krogerService.searchProducts(term: query, limit: 50)
                guard !Task.isCancelled else { return }
                searchResults = products.compactMap { product in
                    let inStore = product.items?.first?.fulfillment?.inStore ?? false
                    guard inStore else { return nil }
                    return ProductResult(product: product, isAvailable: true)
                }
            } catch {
                guard !Task.isCancelled else { return }
                print("Search failed: \(error)")
                searchResults = []
            }
            return
        }

        // Search all nearby stores in parallel
        let results = await withTaskGroup(of: [KrogerProduct].self) { group in
            for locationId in locationIds {
                group.addTask { [krogerService] in
                    (try? await krogerService.searchProducts(
                        term: query,
                        locationId: locationId,
                        limit: 50
                    )) ?? []
                }
            }
            var all: [KrogerProduct] = []
            for await batch in group {
                all.append(contentsOf: batch)
            }
            return all
        }

        guard !Task.isCancelled else { return }

        // Deduplicate by product ID, keeping the first occurrence
        var seen = Set<String>()
        searchResults = results.compactMap { product in
            let inStore = product.items?.first?.fulfillment?.inStore ?? false
            guard inStore, seen.insert(product.productId).inserted else { return nil }
            return ProductResult(product: product, isAvailable: true)
        }
    }

    func searchProducts(query: String) async -> [ProductResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let locationIds = nearbyLocationIds
        if locationIds.isEmpty {
            do {
                let products = try await krogerService.searchProducts(term: trimmed, limit: 50)
                return products.compactMap { product in
                    let inStore = product.items?.first?.fulfillment?.inStore ?? false
                    guard inStore else { return nil }
                    return ProductResult(product: product, isAvailable: true)
                }
            } catch {
                return []
            }
        }

        let results = await withTaskGroup(of: [KrogerProduct].self) { group in
            for locationId in locationIds {
                group.addTask { [krogerService] in
                    (try? await krogerService.searchProducts(term: trimmed, locationId: locationId, limit: 50)) ?? []
                }
            }
            var all: [KrogerProduct] = []
            for await batch in group { all.append(contentsOf: batch) }
            return all
        }

        var seen = Set<String>()
        return results.compactMap { product in
            let inStore = product.items?.first?.fulfillment?.inStore ?? false
            guard inStore, seen.insert(product.productId).inserted else { return nil }
            return ProductResult(product: product, isAvailable: true)
        }
    }

    func clearSearch() {
        searchQuery = ""
        searchResults = []
        hasSearched = false
        searchTask?.cancel()
    }

    // MARK: - Cart Queries

    func cartQuantity(for productId: String) -> Int {
        cart.items.first(where: { $0.productId == productId })?.quantity ?? 0
    }

    // MARK: - Cart Mutations

    func addToCart(product: KrogerProduct) {
        let imageUrl = product.bestImageUrl ?? ""
        let item = CartItem(
            productId: product.productId,
            name: product.description,
            brand: product.brand ?? "",
            imageUrl: imageUrl,
            quantity: 1,
            substitutes: []
        )
        cart.items.append(item)
        debounceSave()
    }

    func incrementQuantity(productId: String) {
        guard let index = cart.items.firstIndex(where: { $0.productId == productId }) else { return }
        cart.items[index].quantity += 1
        debounceSave()
    }

    func decrementQuantity(productId: String) {
        guard let index = cart.items.firstIndex(where: { $0.productId == productId }) else { return }
        if cart.items[index].quantity <= 1 {
            cart.items.remove(at: index)
        } else {
            cart.items[index].quantity -= 1
        }
        debounceSave()
    }

    func removeFromCart(at index: Int) {
        guard cart.items.indices.contains(index) else { return }
        cart.items.remove(at: index)
        debounceSave()
    }

    // MARK: - Substitutes

    func addSubstitute(to cartItemIndex: Int, product: KrogerProduct) {
        guard cart.items.indices.contains(cartItemIndex) else { return }
        let sub = Substitute(
            productId: product.productId,
            name: product.description,
            brand: product.brand ?? ""
        )
        // Don't add duplicate substitutes
        guard !cart.items[cartItemIndex].substitutes.contains(where: { $0.productId == sub.productId }) else { return }
        cart.items[cartItemIndex].substitutes.append(sub)
        debounceSave()
    }

    func removeSubstitute(from cartItemIndex: Int, substituteIndex: Int) {
        guard cart.items.indices.contains(cartItemIndex),
              cart.items[cartItemIndex].substitutes.indices.contains(substituteIndex) else { return }
        cart.items[cartItemIndex].substitutes.remove(at: substituteIndex)
        debounceSave()
    }

    var tripJustCompleted: Bool = false

    func clearCart() {
        saveTask?.cancel()
        cart = Cart()
        searchQuery = ""
        searchResults = []
        hasSearched = false
    }

    func updateQuantity(at index: Int, quantity: Int) {
        guard cart.items.indices.contains(index) else { return }
        if quantity < 1 {
            cart.items.remove(at: index)
        } else {
            cart.items[index].quantity = quantity
        }
        debounceSave()
    }

    // MARK: - Persistence

    func saveCartNow() async {
        saveTask?.cancel()
        saveTask = nil
        await saveCart()
    }

    private func debounceSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            await saveCart()
        }
    }

    private func saveCart() async {
        isSaving = true
        defer { isSaving = false }
        do {
            cart = try await cartRepository.saveCart(cart)
        } catch {
            print("Failed to save cart: \(error)")
        }
    }
}

// MARK: - Preview Helper

extension ShopViewModel {
    static var preview: ShopViewModel {
        let vm = ShopViewModel(skipInit: true)
        vm.searchResults = [
            ProductResult(
                product: KrogerProduct(productId: "001", description: "Organic Strawberries, 1 Lb", brand: "Simple Truth", images: [], items: [KrogerItemPrice(price: KrogerPrice(regular: 3.99, promo: 3.99), fulfillment: KrogerFulfillment(inStore: true))]),
                isAvailable: true
            ),
            ProductResult(
                product: KrogerProduct(productId: "002", description: "Whole Milk, 1 Gallon", brand: "Kroger", images: [], items: [KrogerItemPrice(price: KrogerPrice(regular: 4.29, promo: 4.29), fulfillment: KrogerFulfillment(inStore: true))]),
                isAvailable: true
            )
        ]
        vm.cart = Cart(items: [CartItem(productId: "001", name: "Organic Strawberries, 1 Lb", brand: "Simple Truth", imageUrl: "", quantity: 2, substitutes: [])])
        return vm
    }
}
