package com.amoghghadge.cartquestandroid.data.model

data class KrogerStore(
    val locationId: String,
    val chain: String,
    val name: String,
    val address: KrogerAddress,
    val geolocation: KrogerGeolocation
)

data class KrogerAddress(
    val addressLine1: String,
    val city: String,
    val state: String,
    val zipCode: String
)

data class KrogerGeolocation(
    val latitude: Double,
    val longitude: Double
)
