package com.amoghghadge.cartquestandroid.data.model

data class KrogerProduct(
    val productId: String,
    val description: String,
    val brand: String,
    val images: List<KrogerImage>,
    val items: List<KrogerItemPrice>
)

data class KrogerImage(
    val perspective: String,
    val sizes: List<KrogerImageSize>
)

data class KrogerImageSize(
    val size: String,
    val url: String
)

data class KrogerItemPrice(
    val price: KrogerPrice?,
    val fulfillment: KrogerFulfillment?
)

data class KrogerPrice(
    val regular: Double,
    val promo: Double
)

data class KrogerFulfillment(
    val inStore: Boolean
)
