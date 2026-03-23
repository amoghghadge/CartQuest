package com.amoghghadge.cartquestandroid.ui.route

import android.app.Application
import android.content.Intent
import android.net.Uri
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.viewModelScope
import com.amoghghadge.cartquestandroid.BuildConfig
import com.amoghghadge.cartquestandroid.data.model.CompletedRun
import com.amoghghadge.cartquestandroid.data.remote.DirectionsApiService
import com.amoghghadge.cartquestandroid.data.remote.KrogerApiService
import com.amoghghadge.cartquestandroid.data.remote.KrogerAuthManager
import com.amoghghadge.cartquestandroid.data.repository.CartRepository
import com.amoghghadge.cartquestandroid.data.repository.RunsRepository
import com.amoghghadge.cartquestandroid.service.LocationService
import com.amoghghadge.cartquestandroid.service.RouteOptimizer
import com.google.android.gms.maps.model.LatLng
import com.google.firebase.auth.ktx.auth
import com.google.firebase.ktx.Firebase
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

sealed class RouteState {
    object Loading : RouteState()
    data class Computed(val route: RouteOptimizer.OptimizedRoute, val userLocation: LatLng) : RouteState()
    data class Error(val message: String) : RouteState()
}

class RouteMapViewModel(
    application: Application,
    savedStateHandle: SavedStateHandle
) : AndroidViewModel(application) {

    private val cartId: String = savedStateHandle["cartId"] ?: ""
    private val cartRepository = CartRepository()
    private val runsRepository = RunsRepository()
    private val locationService = LocationService(application)
    private val krogerApi = KrogerApiService.create()
    private val krogerAuth = KrogerAuthManager(
        clientId = BuildConfig.KROGER_CLIENT_ID,
        clientSecret = BuildConfig.KROGER_CLIENT_SECRET
    )
    private val directionsApi = DirectionsApiService(BuildConfig.GOOGLE_MAPS_API_KEY)
    private val optimizer = RouteOptimizer()

    private val _routeState = MutableStateFlow<RouteState>(RouteState.Loading)
    val routeState: StateFlow<RouteState> = _routeState

    private val _tripCompleted = MutableStateFlow(false)
    val tripCompleted: StateFlow<Boolean> = _tripCompleted

    init {
        computeRoute()
    }

    fun computeRoute() {
        viewModelScope.launch {
            _routeState.value = RouteState.Loading
            try {
                // 1. Load cart
                val cart = cartRepository.getActiveCart()
                    ?: throw IllegalStateException("No active cart found")
                val cartItems = cart.items
                if (cartItems.isEmpty()) throw IllegalStateException("Cart is empty")

                // 2. Get user location
                val userLocation = locationService.getCurrentLocation()

                // 3. Query nearby stores
                val token = krogerAuth.getToken()
                val storesResponse = krogerApi.searchLocations(
                    auth = "Bearer $token",
                    lat = userLocation.latitude,
                    lon = userLocation.longitude
                )
                val stores = storesResponse.data
                if (stores.isEmpty()) throw IllegalStateException("No nearby stores found")

                // 4. For each store, query product availability
                val storeAvailabilities = stores.mapNotNull { store ->
                    try {
                        val availableProducts = mutableMapOf<String, com.amoghghadge.cartquestandroid.data.model.KrogerProduct>()
                        for (item in cartItems) {
                            val allProductIds = listOf(item.productId) + item.substitutes.map { it.productId }
                            for (pid in allProductIds) {
                                if (availableProducts.containsKey(pid)) continue
                                try {
                                    val response = krogerApi.searchProducts(
                                        auth = "Bearer $token",
                                        term = pid,
                                        locationId = store.locationId,
                                        limit = 1
                                    )
                                    val product = response.data.firstOrNull { it.productId == pid }
                                    if (product != null) {
                                        availableProducts[pid] = product
                                    }
                                } catch (_: Exception) {
                                    // skip product if query fails
                                }
                            }
                        }
                        if (availableProducts.isNotEmpty()) {
                            RouteOptimizer.StoreAvailability(store, availableProducts)
                        } else null
                    } catch (_: Exception) {
                        null
                    }
                }

                if (storeAvailabilities.isEmpty()) {
                    throw IllegalStateException("No stores have the requested products")
                }

                // 5. Run optimizer
                val optimizedRoute = optimizer.optimize(
                    cartItems = cartItems,
                    storeAvailabilities = storeAvailabilities,
                    userLocation = userLocation,
                    getDriveTime = { origin, storeList ->
                        val waypoints = storeList.map {
                            LatLng(it.geolocation.latitude, it.geolocation.longitude)
                        }
                        val destination = waypoints.last()
                        val intermediateWaypoints = if (waypoints.size > 1) waypoints.dropLast(1) else emptyList()
                        val result = directionsApi.getDirections(
                            origin = origin,
                            destination = destination,
                            waypoints = intermediateWaypoints
                        )
                        Pair(result.totalDurationSeconds, result.encodedPolyline)
                    }
                )

                _routeState.value = RouteState.Computed(optimizedRoute, userLocation)
            } catch (e: Exception) {
                _routeState.value = RouteState.Error(e.message ?: "Unknown error")
            }
        }
    }

    fun startNavigation(context: android.content.Context) {
        val state = _routeState.value
        if (state !is RouteState.Computed) return

        val stops = state.route.stops
        if (stops.isEmpty()) return

        val destination = stops.last()
        val waypoints = if (stops.size > 1) {
            stops.dropLast(1).joinToString("|") { "${it.lat},${it.lng}" }
        } else null

        val uri = if (waypoints != null) {
            Uri.parse("https://www.google.com/maps/dir/?api=1&destination=${destination.lat},${destination.lng}&waypoints=$waypoints")
        } else {
            Uri.parse("google.navigation:q=${destination.lat},${destination.lng}")
        }

        val intent = Intent(Intent.ACTION_VIEW, uri).apply {
            setPackage("com.google.android.apps.maps")
        }
        if (intent.resolveActivity(context.packageManager) != null) {
            context.startActivity(intent)
        } else {
            // Fall back to browser if Google Maps not installed
            val browserIntent = Intent(Intent.ACTION_VIEW, uri)
            context.startActivity(browserIntent)
        }
    }

    fun completeTrip() {
        viewModelScope.launch {
            try {
                val state = _routeState.value
                if (state !is RouteState.Computed) return@launch

                val user = Firebase.auth.currentUser
                val run = CompletedRun(
                    userId = user?.uid ?: "",
                    displayName = user?.displayName ?: "",
                    photoUrl = user?.photoUrl?.toString() ?: "",
                    completedAt = System.currentTimeMillis(),
                    stores = state.route.stops,
                    totalDriveTimeMinutes = state.route.totalDriveTimeSeconds / 60,
                    totalCost = state.route.stops.sumOf { stop ->
                        stop.items.sumOf { it.price }
                    }
                )
                runsRepository.saveCompletedRun(run)
                cartRepository.completeCart(cartId)
                _tripCompleted.value = true
            } catch (_: Exception) {
                // handle silently for now
            }
        }
    }
}
