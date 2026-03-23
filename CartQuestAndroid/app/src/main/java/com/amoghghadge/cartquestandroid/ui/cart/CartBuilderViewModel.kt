package com.amoghghadge.cartquestandroid.ui.cart

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.amoghghadge.cartquestandroid.BuildConfig
import com.amoghghadge.cartquestandroid.data.model.Cart
import com.amoghghadge.cartquestandroid.data.model.CartItem
import com.amoghghadge.cartquestandroid.data.model.KrogerProduct
import com.amoghghadge.cartquestandroid.data.model.Substitute
import com.amoghghadge.cartquestandroid.data.remote.KrogerApiService
import com.amoghghadge.cartquestandroid.data.remote.KrogerAuthManager
import com.amoghghadge.cartquestandroid.data.repository.CartRepository
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class CartBuilderUiState(
    val searchQuery: String = "",
    val searchResults: List<KrogerProduct> = emptyList(),
    val isSearching: Boolean = false,
    val cart: Cart = Cart(),
    val isSaving: Boolean = false,
    val addingSubstituteForIndex: Int? = null
)

class CartBuilderViewModel : ViewModel() {

    private val _uiState = MutableStateFlow(CartBuilderUiState())
    val uiState: StateFlow<CartBuilderUiState> = _uiState.asStateFlow()

    private val cartRepository = CartRepository()
    private val krogerApiService = KrogerApiService.create()
    private val krogerAuthManager = KrogerAuthManager(
        clientId = BuildConfig.KROGER_CLIENT_ID,
        clientSecret = BuildConfig.KROGER_CLIENT_SECRET
    )

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

    fun search(query: String) {
        _uiState.update { it.copy(searchQuery = query) }
        searchJob?.cancel()
        if (query.isBlank()) {
            _uiState.update { it.copy(searchResults = emptyList(), isSearching = false) }
            return
        }
        searchJob = viewModelScope.launch {
            delay(500)
            _uiState.update { it.copy(isSearching = true) }
            try {
                val token = krogerAuthManager.getToken()
                val response = krogerApiService.searchProducts(
                    auth = "Bearer $token",
                    term = query
                )
                _uiState.update { it.copy(searchResults = response.data, isSearching = false) }
            } catch (_: Exception) {
                _uiState.update { it.copy(isSearching = false) }
            }
        }
    }

    fun addToCart(product: KrogerProduct) {
        val substituteIndex = _uiState.value.addingSubstituteForIndex
        if (substituteIndex != null) {
            addSubstitute(substituteIndex, product)
            cancelAddingSubstitute()
            return
        }
        val imageUrl = product.images.firstOrNull()?.sizes?.firstOrNull()?.url.orEmpty()
        val newItem = CartItem(
            productId = product.productId,
            name = product.description,
            brand = product.brand,
            imageUrl = imageUrl,
            quantity = 1
        )
        _uiState.update { state ->
            state.copy(
                cart = state.cart.copy(items = state.cart.items + newItem),
                searchQuery = "",
                searchResults = emptyList()
            )
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
            val item = items[cartItemIndex]
            val substitute = Substitute(
                productId = product.productId,
                name = product.description,
                brand = product.brand
            )
            items[cartItemIndex] = item.copy(substitutes = item.substitutes + substitute)
            state.copy(cart = state.cart.copy(items = items))
        }
        debounceSave()
    }

    fun removeSubstitute(cartItemIndex: Int, subIndex: Int) {
        _uiState.update { state ->
            val items = state.cart.items.toMutableList()
            val item = items[cartItemIndex]
            val subs = item.substitutes.toMutableList().apply { removeAt(subIndex) }
            items[cartItemIndex] = item.copy(substitutes = subs)
            state.copy(cart = state.cart.copy(items = items))
        }
        debounceSave()
    }

    fun updateQuantity(index: Int, quantity: Int) {
        if (quantity < 1) return
        _uiState.update { state ->
            val items = state.cart.items.toMutableList()
            items[index] = items[index].copy(quantity = quantity)
            state.copy(cart = state.cart.copy(items = items))
        }
        debounceSave()
    }

    fun startAddingSubstitute(index: Int) {
        _uiState.update { it.copy(addingSubstituteForIndex = index) }
    }

    fun cancelAddingSubstitute() {
        _uiState.update { it.copy(addingSubstituteForIndex = null) }
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
