import Foundation
import Observation

@Observable
class CartBuilderViewModel {
    var searchQuery: String = "" {
        didSet { debouncedSearch() }
    }
    var searchResults: [KrogerProduct] = []
    var isSearching: Bool = false
    var cart: Cart = Cart()
    var isSaving: Bool = false
    var addingSubstituteForIndex: Int?

    private let krogerService: KrogerService
    private let cartRepository: CartRepository
    private var searchTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?

    init(
        krogerService: KrogerService = KrogerService(
            clientId: "KROGER_CLIENT_ID_PLACEHOLDER",
            clientSecret: "KROGER_CLIENT_SECRET_PLACEHOLDER"
        ),
        cartRepository: CartRepository = CartRepository()
    ) {
        self.krogerService = krogerService
        self.cartRepository = cartRepository
        Task { await loadActiveCart() }
    }

    // MARK: - Load

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

    private func debouncedSearch() {
        searchTask?.cancel()
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await search(query: query)
        }
    }

    func search() {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        searchTask?.cancel()
        searchTask = Task { await search(query: query) }
    }

    private func search(query: String) async {
        isSearching = true
        defer { isSearching = false }
        do {
            let results = try await krogerService.searchProducts(term: query)
            guard !Task.isCancelled else { return }
            searchResults = results
        } catch {
            guard !Task.isCancelled else { return }
            print("Search failed: \(error)")
            searchResults = []
        }
    }

    // MARK: - Cart mutations

    func addToCart(product: KrogerProduct) {
        if let subIndex = addingSubstituteForIndex {
            addSubstitute(cartItemIndex: subIndex, product: product)
            addingSubstituteForIndex = nil
        } else {
            let imageUrl = product.images.first?.sizes.first?.url ?? ""
            let item = CartItem(
                productId: product.productId,
                name: product.description,
                brand: product.brand,
                imageUrl: imageUrl,
                quantity: 1,
                substitutes: []
            )
            cart.items.append(item)
        }
        searchQuery = ""
        searchResults = []
        debounceSave()
    }

    func removeFromCart(at index: Int) {
        guard cart.items.indices.contains(index) else { return }
        cart.items.remove(at: index)
        debounceSave()
    }

    func addSubstitute(cartItemIndex: Int, product: KrogerProduct) {
        guard cart.items.indices.contains(cartItemIndex) else { return }
        let sub = Substitute(
            productId: product.productId,
            name: product.description,
            brand: product.brand
        )
        cart.items[cartItemIndex].substitutes.append(sub)
        debounceSave()
    }

    func removeSubstitute(cartItemIndex: Int, subIndex: Int) {
        guard cart.items.indices.contains(cartItemIndex),
              cart.items[cartItemIndex].substitutes.indices.contains(subIndex) else { return }
        cart.items[cartItemIndex].substitutes.remove(at: subIndex)
        debounceSave()
    }

    func updateQuantity(at index: Int, quantity: Int) {
        guard cart.items.indices.contains(index) else { return }
        cart.items[index].quantity = max(1, quantity)
        debounceSave()
    }

    // MARK: - Persistence

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
