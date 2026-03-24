package com.amoghghadge.cartquestandroid.service

import com.amoghghadge.cartquestandroid.data.model.*
import com.google.android.gms.maps.model.LatLng
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope

class RouteOptimizer {

    data class StoreAvailability(
        val store: KrogerStore,
        val availableProducts: Map<String, KrogerProduct> // productId -> product with price
    )

    data class OptimizedRoute(
        val stops: List<StoreStop>,  // ordered by visit sequence
        val totalDriveTimeSeconds: Int,
        val encodedPolyline: String
    )

    /**
     * Find the route that covers all cart items with minimum total drive time.
     *
     * Algorithm:
     * 1. For each cart item, resolve which product to buy at each store
     *    (prefer primary, fall back through substitutes in order)
     * 2. Build coverage matrix: which stores can fulfill which cart items
     * 3. Find all minimal store subsets that cover all items
     *    - Start from subset size 1, increase up to store count
     *    - For each size, generate combinations and check coverage
     *    - Stop once we find feasible subsets at current size
     * 4. For each feasible subset, call getDriveTime to get actual driving time
     * 5. Return the subset + route with lowest total drive time
     * 6. Assign items to stores: for each cart item, assign to the first store
     *    in visit order that has it (prefer primary, then substitutes in priority order)
     */
    suspend fun optimize(
        cartItems: List<CartItem>,
        storeAvailabilities: List<StoreAvailability>,
        userLocation: LatLng,
        getDriveTime: suspend (origin: LatLng, stores: List<KrogerStore>) -> Pair<Int, String>
        // returns (totalDriveTimeSeconds, encodedPolyline)
    ): OptimizedRoute {
        if (cartItems.isEmpty()) throw IllegalArgumentException("Cart is empty")
        if (storeAvailabilities.isEmpty()) throw IllegalArgumentException("No stores available")

        // Step 1 & 2: Build coverage matrix
        // For each cart item index, which store indices can fulfill it
        val coverage = buildCoverageMatrix(cartItems, storeAvailabilities)

        // Check if all items can be covered
        if (coverage.any { it.value.isEmpty() }) {
            val uncoveredItems = coverage.filter { it.value.isEmpty() }.keys
            throw IllegalStateException("Items at indices $uncoveredItems cannot be found at any store")
        }

        // Step 3: Find minimal store subsets that cover all items
        val storeIndices = storeAvailabilities.indices.toList()
        var feasibleSubsets = listOf<Set<Int>>()

        for (subsetSize in 1..storeIndices.size) {
            feasibleSubsets = combinations(storeIndices, subsetSize)
                .filter { subset -> coversAllItems(subset, coverage) }
            if (feasibleSubsets.isNotEmpty()) break
        }

        if (feasibleSubsets.isEmpty()) {
            throw IllegalStateException("Cannot cover all items with available stores")
        }

        // Step 4: For each feasible subset, get drive time (parallelized)
        val routeCandidates = coroutineScope {
            feasibleSubsets.map { subset ->
                async {
                    val stores = subset.map { storeAvailabilities[it].store }
                    try {
                        val (driveTime, polyline) = getDriveTime(userLocation, stores)
                        val stops = assignItemsToStores(cartItems, subset.toList(), storeAvailabilities)
                        OptimizedRoute(stops, driveTime, polyline)
                    } catch (_: Exception) {
                        null
                    }
                }
            }.awaitAll().filterNotNull()
        }

        return routeCandidates.minByOrNull { it.totalDriveTimeSeconds }
            ?: throw IllegalStateException("Could not compute route for any store combination")
    }

    private fun buildCoverageMatrix(
        cartItems: List<CartItem>,
        storeAvailabilities: List<StoreAvailability>
    ): Map<Int, Set<Int>> {
        // cartItemIndex -> set of storeIndices that can fulfill it
        return cartItems.indices.associateWith { itemIdx ->
            val item = cartItems[itemIdx]
            val productIds = listOf(item.productId) + item.substitutes.map { it.productId }
            storeAvailabilities.indices.filter { storeIdx ->
                val available = storeAvailabilities[storeIdx].availableProducts
                productIds.any { pid -> available.containsKey(pid) }
            }.toSet()
        }
    }

    private fun coversAllItems(storeSubset: Set<Int>, coverage: Map<Int, Set<Int>>): Boolean {
        return coverage.all { (_, stores) -> stores.any { it in storeSubset } }
    }

    private fun <T> combinations(list: List<T>, size: Int): List<Set<Int>> {
        // Generate all combinations of indices of given size
        if (size == 0) return listOf(emptySet())
        if (list.isEmpty()) return emptyList()
        val result = mutableListOf<Set<Int>>()
        fun backtrack(start: Int, current: MutableSet<Int>) {
            if (current.size == size) {
                result.add(current.toSet())
                return
            }
            for (i in start until list.size) {
                current.add(i)
                backtrack(i + 1, current)
                current.remove(i)
            }
        }
        backtrack(0, mutableSetOf())
        return result
    }

    private fun assignItemsToStores(
        cartItems: List<CartItem>,
        storeIndices: List<Int>,
        storeAvailabilities: List<StoreAvailability>
    ): List<StoreStop> {
        // For each store, track which items to buy there
        val storeItems = storeIndices.associateWith { mutableListOf<AssignedItem>() }

        for (item in cartItems) {
            val productIds = listOf(item.productId) + item.substitutes.map { it.productId }

            // Find first store (in order) that has any of the products
            for (storeIdx in storeIndices) {
                val available = storeAvailabilities[storeIdx].availableProducts
                val matchedPid = productIds.firstOrNull { available.containsKey(it) }
                if (matchedPid != null) {
                    val product = available[matchedPid]!!
                    val price = product.items?.firstOrNull()?.price?.regular ?: 0.0
                    storeItems[storeIdx]!!.add(
                        AssignedItem(
                            productId = matchedPid,
                            name = product.description,
                            brand = product.brand.orEmpty(),
                            price = price
                        )
                    )
                    break
                }
            }
        }

        // Build StoreStop objects
        return storeIndices.map { idx ->
            val store = storeAvailabilities[idx].store
            StoreStop(
                storeId = store.locationId,
                storeName = store.name,
                address = "${store.address.addressLine1}, ${store.address.city}, ${store.address.state}",
                lat = store.geolocation.latitude,
                lng = store.geolocation.longitude,
                items = storeItems[idx] ?: emptyList()
            )
        }.filter { it.items.isNotEmpty() } // only include stores that have items assigned
    }
}
