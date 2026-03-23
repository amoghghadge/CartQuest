package com.amoghghadge.cartquestandroid.data.model

data class Substitute(
    val productId: String = "",
    val name: String = "",
    val brand: String = ""
)

data class CartItem(
    val productId: String = "",
    val name: String = "",
    val brand: String = "",
    val imageUrl: String = "",
    val quantity: Int = 1,
    val substitutes: List<Substitute> = emptyList()
)
