package com.amoghghadge.cartquestandroid.data.model

data class KrogerProduct(
    val productId: String,
    val description: String,
    val brand: String? = null,
    val images: List<KrogerImage>? = null,
    val items: List<KrogerItemPrice>? = null
) {
    val bestImageUrl: String?
        get() {
            val featured = images?.firstOrNull { it.featured == true }
            return (featured ?: images?.firstOrNull())?.bestUrl
        }
}

data class KrogerImage(
    val perspective: String? = null,
    val sizes: List<KrogerImageSize>? = null,
    val featured: Boolean? = null
) {
    val bestUrl: String?
        get() {
            val prefs = listOf("xlarge", "large", "medium", "small", "thumbnail")
            for (preferred in prefs) {
                val match = sizes?.firstOrNull { it.size == preferred }
                if (match != null) return match.url
            }
            return sizes?.lastOrNull()?.url
        }
}

data class KrogerImageSize(
    val size: String,
    val url: String
)

data class KrogerItemPrice(
    val price: KrogerPrice?,
    val fulfillment: KrogerFulfillment?
)

data class KrogerPrice(
    val regular: Double? = null,
    val promo: Double? = null
)

data class KrogerFulfillment(
    val inStore: Boolean
)
