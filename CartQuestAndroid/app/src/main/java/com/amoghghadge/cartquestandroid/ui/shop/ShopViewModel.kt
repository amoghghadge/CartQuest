package com.amoghghadge.cartquestandroid.ui.shop

import android.annotation.SuppressLint
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.amoghghadge.cartquestandroid.BuildConfig
import com.amoghghadge.cartquestandroid.data.model.Cart
import com.amoghghadge.cartquestandroid.data.model.CartItem
import com.amoghghadge.cartquestandroid.data.model.KrogerProduct
import com.amoghghadge.cartquestandroid.data.remote.KrogerApiService
import com.amoghghadge.cartquestandroid.data.remote.KrogerAuthManager
import com.amoghghadge.cartquestandroid.data.repository.CartRepository
import com.amoghghadge.cartquestandroid.service.LocationService
import kotlinx.coroutines.Job
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class ProductResult(
    val product: KrogerProduct,
    val isAvailable: Boolean
) {
    val price: Double? get() = product.items?.firstOrNull()?.price?.regular
    val imageUrl: String? get() = product.bestImageUrl
}

data class ShopUiState(
    val searchQuery: String = "",
    val searchResults: List<ProductResult> = emptyList(),
    val isSearching: Boolean = false,
    val hasSearched: Boolean = false,
    val cart: Cart = Cart(),
    val isSaving: Boolean = false,
    val nearbyLocationIds: List<String> = emptyList(),
    val locationError: String? = null
)

class ShopViewModel : ViewModel() {

    private val _uiState = MutableStateFlow(ShopUiState())
    val uiState: StateFlow<ShopUiState> = _uiState.asStateFlow()

    private val cartRepository = CartRepository()
    private val krogerApiService = KrogerApiService.create()
    private val krogerAuthManager = KrogerAuthManager(
        clientId = BuildConfig.KROGER_CLIENT_ID,
        clientSecret = BuildConfig.KROGER_CLIENT_SECRET
    )

    @SuppressLint("StaticFieldLeak")
    private var locationService: LocationService? = null

    private var searchJob: Job? = null
    private var saveJob: Job? = null

    init {
        viewModelScope.launch {
            try {
                val activeCart = cartRepository.getActiveCart()
                if (activeCart != null) {
                    _uiState.update { it.copy(cart = activeCart) }
                }
            } catch (_: Exception) {
                // No active cart found, keep default empty cart
            }
        }
    }

    fun initLocation(locationService: LocationService) {
        this.locationService = locationService
        viewModelScope.launch {
            try {
                val latLng = locationService.getCurrentLocation()
                val token = krogerAuthManager.getToken()
                val response = krogerApiService.searchLocations(
                    auth = "Bearer $token",
                    lat = latLng.latitude,
                    lon = latLng.longitude
                )
                val locationIds = response.data.map { it.locationId }
                _uiState.update { it.copy(nearbyLocationIds = locationIds) }
            } catch (e: Exception) {
                _uiState.update { it.copy(locationError = e.message) }
            }
        }
    }

    fun updateSearchQuery(query: String) {
        _uiState.update { it.copy(searchQuery = query) }
        if (query.isBlank()) {
            searchJob?.cancel()
            _uiState.update { it.copy(searchResults = emptyList(), isSearching = false) }
        }
    }

    fun search() {
        val query = _uiState.value.searchQuery.trim()
        if (query.isBlank()) return
        searchJob?.cancel()
        searchJob = viewModelScope.launch {
            _uiState.update { it.copy(isSearching = true) }
            try {
                val token = krogerAuthManager.getToken()
                val locationIds = _uiState.value.nearbyLocationIds

                val allProducts = if (locationIds.isEmpty()) {
                    // Fallback: search without location filter
                    val response = krogerApiService.searchProducts(
                        auth = "Bearer $token",
                        term = query
                    )
                    response.data
                } else {
                    // Search all nearby stores in parallel
                    locationIds.map { locationId ->
                        async {
                            try {
                                krogerApiService.searchProducts(
                                    auth = "Bearer $token",
                                    term = query,
                                    locationId = locationId
                                ).data
                            } catch (_: Exception) {
                                emptyList()
                            }
                        }
                    }.awaitAll().flatten()
                }

                // Deduplicate by product ID, keep first occurrence
                val seen = mutableSetOf<String>()
                val results = allProducts.mapNotNull { product ->
                    val inStore = product.items?.firstOrNull()?.fulfillment?.inStore == true
                    if (inStore && seen.add(product.productId)) {
                        ProductResult(product = product, isAvailable = true)
                    } else null
                }
                _uiState.update { it.copy(searchResults = results, isSearching = false, hasSearched = true) }
            } catch (_: Exception) {
                _uiState.update { it.copy(isSearching = false, hasSearched = true) }
            }
        }
    }

    suspend fun searchProducts(query: String): List<ProductResult> {
        val trimmed = query.trim()
        if (trimmed.isBlank()) return emptyList()
        return try {
            val token = krogerAuthManager.getToken()
            val locationIds = _uiState.value.nearbyLocationIds
            val allProducts = if (locationIds.isEmpty()) {
                krogerApiService.searchProducts(auth = "Bearer $token", term = trimmed).data
            } else {
                locationIds.map { locationId ->
                    viewModelScope.async {
                        try {
                            krogerApiService.searchProducts(auth = "Bearer $token", term = trimmed, locationId = locationId).data
                        } catch (_: Exception) { emptyList() }
                    }
                }.awaitAll().flatten()
            }
            val seen = mutableSetOf<String>()
            allProducts.mapNotNull { product ->
                val inStore = product.items?.firstOrNull()?.fulfillment?.inStore == true
                if (inStore && seen.add(product.productId)) ProductResult(product, true) else null
            }
        } catch (_: Exception) { emptyList() }
    }

    fun clearSearch() {
        searchJob?.cancel()
        _uiState.update { it.copy(searchQuery = "", searchResults = emptyList(), hasSearched = false) }
    }

    fun cartQuantity(productId: String): Int {
        return _uiState.value.cart.items
            .firstOrNull { it.productId == productId }
            ?.quantity ?: 0
    }

    fun addToCart(product: KrogerProduct) {
        val imageUrl = product.bestImageUrl.orEmpty()
        val newItem = CartItem(
            productId = product.productId,
            name = product.description,
            brand = product.brand.orEmpty(),
            imageUrl = imageUrl,
            quantity = 1
        )
        _uiState.update { state ->
            state.copy(cart = state.cart.copy(items = state.cart.items + newItem))
        }
        debounceSave()
    }

    fun incrementQuantity(productId: String) {
        _uiState.update { state ->
            val items = state.cart.items.map { item ->
                if (item.productId == productId) item.copy(quantity = item.quantity + 1) else item
            }
            state.copy(cart = state.cart.copy(items = items))
        }
        debounceSave()
    }

    fun decrementQuantity(productId: String) {
        _uiState.update { state ->
            val items = state.cart.items.mapNotNull { item ->
                when {
                    item.productId != productId -> item
                    item.quantity <= 1 -> null
                    else -> item.copy(quantity = item.quantity - 1)
                }
            }
            state.copy(cart = state.cart.copy(items = items))
        }
        debounceSave()
    }

    fun removeFromCart(index: Int) {
        _uiState.update { state ->
            val items = state.cart.items.toMutableList().apply { removeAt(index) }
            state.copy(cart = state.cart.copy(items = items))
        }
        debounceSave()
    }

    fun addSubstitute(cartItemIndex: Int, product: KrogerProduct) {
        _uiState.update { state ->
            val items = state.cart.items.toMutableList()
            if (cartItemIndex in items.indices) {
                val item = items[cartItemIndex]
                val sub = com.amoghghadge.cartquestandroid.data.model.Substitute(
                    productId = product.productId,
                    name = product.description,
                    brand = product.brand.orEmpty()
                )
                if (item.substitutes.none { it.productId == sub.productId }) {
                    items[cartItemIndex] = item.copy(substitutes = item.substitutes + sub)
                }
            }
            state.copy(cart = state.cart.copy(items = items))
        }
        debounceSave()
    }

    fun removeSubstitute(cartItemIndex: Int, substituteIndex: Int) {
        _uiState.update { state ->
            val items = state.cart.items.toMutableList()
            if (cartItemIndex in items.indices) {
                val item = items[cartItemIndex]
                val subs = item.substitutes.toMutableList()
                if (substituteIndex in subs.indices) {
                    subs.removeAt(substituteIndex)
                    items[cartItemIndex] = item.copy(substitutes = subs)
                }
            }
            state.copy(cart = state.cart.copy(items = items))
        }
        debounceSave()
    }

    fun clearCart() {
        saveJob?.cancel()
        _uiState.update { it.copy(cart = Cart(), searchQuery = "", searchResults = emptyList(), hasSearched = false) }
    }

    fun updateQuantity(index: Int, quantity: Int) {
        if (quantity < 1) {
            removeFromCart(index)
            return
        }
        _uiState.update { state ->
            val items = state.cart.items.toMutableList()
            items[index] = items[index].copy(quantity = quantity)
            state.copy(cart = state.cart.copy(items = items))
        }
        debounceSave()
    }

    suspend fun saveCartNow() {
        saveJob?.cancel()
        _uiState.update { it.copy(isSaving = true) }
        try {
            val savedCart = cartRepository.saveCart(_uiState.value.cart)
            _uiState.update { it.copy(cart = savedCart, isSaving = false) }
        } catch (_: Exception) {
            _uiState.update { it.copy(isSaving = false) }
        }
    }

    private fun debounceSave() {
        saveJob?.cancel()
        saveJob = viewModelScope.launch {
            delay(1000)
            _uiState.update { it.copy(isSaving = true) }
            try {
                val savedCart = cartRepository.saveCart(_uiState.value.cart)
                _uiState.update { it.copy(cart = savedCart, isSaving = false) }
            } catch (_: Exception) {
                _uiState.update { it.copy(isSaving = false) }
            }
        }
    }
}
