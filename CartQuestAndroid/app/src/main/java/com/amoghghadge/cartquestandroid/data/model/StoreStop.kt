package com.amoghghadge.cartquestandroid.data.model

data class StoreStop(
    val storeId: String,
    val storeName: String,
    val address: String,
    val lat: Double,
    val lng: Double,
    val items: List<AssignedItem>
)

data class AssignedItem(
    val productId: String,
    val name: String,
    val brand: String,
    val price: Double
)
