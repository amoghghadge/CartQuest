package com.amoghghadge.cartquestandroid.service

import com.amoghghadge.cartquestandroid.data.model.*
import com.amoghghadge.cartquestandroid.service.RouteOptimizer.StoreAvailability
import com.google.android.gms.maps.model.LatLng
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Test

class RouteOptimizerTest {

    private val optimizer = RouteOptimizer()
    private val userLocation = LatLng(37.7749, -122.4194)

    // Helper to create a fake KrogerStore
    private fun fakeStore(id: String, name: String = "Store $id"): KrogerStore = KrogerStore(
        locationId = id,
        chain = "Kroger",
        name = name,
        address = KrogerAddress("123 Main St", "City", "CA", "90000"),
        geolocation = KrogerGeolocation(37.78, -122.42)
    )

    // Helper to create a fake KrogerProduct
    private fun fakeProduct(id: String, description: String = "Product $id", price: Double = 2.99): KrogerProduct =
        KrogerProduct(
            productId = id,
            description = description,
            brand = "Brand",
            images = emptyList(),
            items = listOf(
                KrogerItemPrice(
                    price = KrogerPrice(regular = price, promo = price),
                    fulfillment = KrogerFulfillment(inStore = true)
                )
            )
        )

    // Helper to create a CartItem
    private fun fakeCartItem(
        productId: String,
        substitutes: List<Substitute> = emptyList()
    ): CartItem = CartItem(
        productId = productId,
        name = "Item $productId",
        brand = "Brand",
        imageUrl = "",
        quantity = 1,
        substitutes = substitutes
    )

    // Mock getDriveTime: returns fixed seconds based on number of stores (100 per store)
    private val mockGetDriveTime: suspend (LatLng, List<KrogerStore>) -> Pair<Int, String> =
        { _, stores -> Pair(stores.size * 100, "encodedPolyline") }

    @Test
    fun `single store has all items returns 1 stop`() = runTest {
        val items = listOf(fakeCartItem("p1"), fakeCartItem("p2"), fakeCartItem("p3"))
        val store = fakeStore("s1")
        val availability = StoreAvailability(
            store = store,
            availableProducts = mapOf(
                "p1" to fakeProduct("p1"),
                "p2" to fakeProduct("p2"),
                "p3" to fakeProduct("p3")
            )
        )

        val result = optimizer.optimize(items, listOf(availability), userLocation, mockGetDriveTime)

        assertEquals(1, result.stops.size)
        assertEquals("s1", result.stops[0].storeId)
        assertEquals(3, result.stops[0].items.size)
        assertEquals(100, result.totalDriveTimeSeconds) // 1 store * 100
    }

    @Test
    fun `two stores each have half the items returns both stores`() = runTest {
        val items = listOf(fakeCartItem("p1"), fakeCartItem("p2"))
        val store1 = fakeStore("s1")
        val store2 = fakeStore("s2")

        val avail1 = StoreAvailability(
            store = store1,
            availableProducts = mapOf("p1" to fakeProduct("p1"))
        )
        val avail2 = StoreAvailability(
            store = store2,
            availableProducts = mapOf("p2" to fakeProduct("p2"))
        )

        val result = optimizer.optimize(items, listOf(avail1, avail2), userLocation, mockGetDriveTime)

        assertEquals(2, result.stops.size)
        assertEquals(200, result.totalDriveTimeSeconds) // 2 stores * 100
        // Each store should have 1 item
        assertTrue(result.stops.all { it.items.size == 1 })
    }

    @Test
    fun `three stores where 2 can cover everything picks combo with lower drive time`() = runTest {
        val items = listOf(fakeCartItem("p1"), fakeCartItem("p2"))

        val store1 = fakeStore("s1")
        val store2 = fakeStore("s2")
        val store3 = fakeStore("s3")

        // Store 1 has p1, Store 2 has p2, Store 3 has both
        val avail1 = StoreAvailability(store1, mapOf("p1" to fakeProduct("p1")))
        val avail2 = StoreAvailability(store2, mapOf("p2" to fakeProduct("p2")))
        val avail3 = StoreAvailability(store3, mapOf("p1" to fakeProduct("p1"), "p2" to fakeProduct("p2")))

        // Mock: 1 store = 100s (cheapest), so store3 alone should win
        val result = optimizer.optimize(
            items,
            listOf(avail1, avail2, avail3),
            userLocation,
            mockGetDriveTime
        )

        // Store3 alone covers everything with drive time 100 (1 store)
        assertEquals(1, result.stops.size)
        assertEquals("s3", result.stops[0].storeId)
        assertEquals(100, result.totalDriveTimeSeconds)
    }

    @Test
    fun `substitute fallback when primary unavailable`() = runTest {
        val items = listOf(
            fakeCartItem(
                productId = "p1",
                substitutes = listOf(Substitute("p1-sub", "Sub Product", "SubBrand"))
            )
        )

        val store = fakeStore("s1")
        // Store only has the substitute, not the primary
        val avail = StoreAvailability(
            store = store,
            availableProducts = mapOf("p1-sub" to fakeProduct("p1-sub", "Substitute Product"))
        )

        val result = optimizer.optimize(items, listOf(avail), userLocation, mockGetDriveTime)

        assertEquals(1, result.stops.size)
        assertEquals(1, result.stops[0].items.size)
        assertEquals("p1-sub", result.stops[0].items[0].productId)
    }

    @Test
    fun `no store has an item throws error`() = runTest {
        val items = listOf(fakeCartItem("p1"), fakeCartItem("p2"))
        val store = fakeStore("s1")
        // Store only has p1, not p2
        val avail = StoreAvailability(
            store = store,
            availableProducts = mapOf("p1" to fakeProduct("p1"))
        )

        try {
            optimizer.optimize(items, listOf(avail), userLocation, mockGetDriveTime)
            fail("Expected IllegalStateException")
        } catch (e: IllegalStateException) {
            assertTrue(e.message!!.contains("cannot be found at any store"))
        }
    }

    @Test
    fun `empty cart throws IllegalArgumentException`() = runTest {
        try {
            optimizer.optimize(emptyList(), emptyList(), userLocation, mockGetDriveTime)
            fail("Expected IllegalArgumentException")
        } catch (e: IllegalArgumentException) {
            assertEquals("Cart is empty", e.message)
        }
    }

    @Test
    fun `no stores available throws IllegalArgumentException`() = runTest {
        val items = listOf(fakeCartItem("p1"))
        try {
            optimizer.optimize(items, emptyList(), userLocation, mockGetDriveTime)
            fail("Expected IllegalArgumentException")
        } catch (e: IllegalArgumentException) {
            assertEquals("No stores available", e.message)
        }
    }
}
