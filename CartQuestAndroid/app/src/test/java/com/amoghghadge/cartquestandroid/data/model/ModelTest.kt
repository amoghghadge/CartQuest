package com.amoghghadge.cartquestandroid.data.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ModelTest {

    @Test
    fun `User can be instantiated with default values`() {
        val user = User()
        assertEquals("", user.uid)
        assertEquals("", user.email)
        assertEquals("", user.displayName)
        assertEquals("", user.photoUrl)
    }

    @Test
    fun `User can be instantiated with explicit values`() {
        val user = User(uid = "u1", email = "test@example.com", displayName = "Test User", photoUrl = "http://photo.url")
        assertEquals("u1", user.uid)
        assertEquals("test@example.com", user.email)
        assertEquals("Test User", user.displayName)
        assertEquals("http://photo.url", user.photoUrl)
    }

    @Test
    fun `CartItem can be instantiated with default values`() {
        val item = CartItem()
        assertEquals("", item.productId)
        assertEquals(1, item.quantity)
        assertTrue(item.substitutes.isEmpty())
    }

    @Test
    fun `CartItem substitutes list preserves insertion order`() {
        val sub1 = Substitute(productId = "s1", name = "Sub One", brand = "Brand A")
        val sub2 = Substitute(productId = "s2", name = "Sub Two", brand = "Brand B")
        val sub3 = Substitute(productId = "s3", name = "Sub Three", brand = "Brand C")
        val item = CartItem(productId = "p1", substitutes = listOf(sub1, sub2, sub3))
        assertEquals(3, item.substitutes.size)
        assertEquals("s1", item.substitutes[0].productId)
        assertEquals("s2", item.substitutes[1].productId)
        assertEquals("s3", item.substitutes[2].productId)
    }

    @Test
    fun `Cart can be instantiated with default values`() {
        val cart = Cart()
        assertEquals("", cart.id)
        assertEquals("active", cart.status)
        assertTrue(cart.items.isEmpty())
    }

    @Test
    fun `Cart holds CartItems`() {
        val item = CartItem(productId = "p1", name = "Milk", quantity = 2)
        val cart = Cart(id = "cart1", items = listOf(item))
        assertEquals(1, cart.items.size)
        assertEquals("p1", cart.items[0].productId)
    }

    @Test
    fun `KrogerProduct can be instantiated`() {
        val product = KrogerProduct(
            productId = "kp1",
            description = "Whole Milk",
            brand = "Kroger",
            images = emptyList(),
            items = emptyList()
        )
        assertEquals("kp1", product.productId)
        assertEquals("Whole Milk", product.description)
        assertEquals("Kroger", product.brand)
    }

    @Test
    fun `KrogerStore can be instantiated`() {
        val store = KrogerStore(
            locationId = "loc1",
            chain = "Kroger",
            name = "Kroger #123",
            address = KrogerAddress("123 Main St", "Atlanta", "GA", "30301"),
            geolocation = KrogerGeolocation(33.749, -84.388)
        )
        assertEquals("loc1", store.locationId)
        assertEquals("Atlanta", store.address.city)
        assertEquals(33.749, store.geolocation.latitude, 0.001)
    }

    @Test
    fun `StoreStop can be instantiated`() {
        val assignedItem = AssignedItem(productId = "p1", name = "Eggs", brand = "Generic", price = 2.99)
        val stop = StoreStop(
            storeId = "s1",
            storeName = "Kroger #123",
            address = "123 Main St, Atlanta, GA 30301",
            lat = 33.749,
            lng = -84.388,
            items = listOf(assignedItem)
        )
        assertEquals("s1", stop.storeId)
        assertEquals(1, stop.items.size)
        assertEquals(2.99, stop.items[0].price, 0.001)
    }

    @Test
    fun `CompletedRun can be instantiated with default values`() {
        val run = CompletedRun()
        assertEquals("", run.id)
        assertEquals("", run.userId)
        assertTrue(run.stores.isEmpty())
        assertEquals(0, run.totalDriveTimeMinutes)
        assertEquals(0.0, run.totalCost, 0.001)
    }

    @Test
    fun `CompletedRun stores preserves insertion order`() {
        val stop1 = StoreStop("s1", "Store One", "1 Addr", 33.0, -84.0, emptyList())
        val stop2 = StoreStop("s2", "Store Two", "2 Addr", 34.0, -85.0, emptyList())
        val stop3 = StoreStop("s3", "Store Three", "3 Addr", 35.0, -86.0, emptyList())
        val run = CompletedRun(id = "run1", stores = listOf(stop1, stop2, stop3))
        assertEquals(3, run.stores.size)
        assertEquals("s1", run.stores[0].storeId)
        assertEquals("s2", run.stores[1].storeId)
        assertEquals("s3", run.stores[2].storeId)
    }
}
