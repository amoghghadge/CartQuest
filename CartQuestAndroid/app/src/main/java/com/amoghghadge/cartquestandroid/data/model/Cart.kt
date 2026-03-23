package com.amoghghadge.cartquestandroid.data.model

data class Cart(
    val id: String = "",
    val status: String = "active",
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
    val items: List<CartItem> = emptyList()
)
