package com.amoghghadge.cartquestandroid.data.model

data class CompletedRun(
    val id: String = "",
    val userId: String = "",
    val displayName: String = "",
    val photoUrl: String = "",
    val completedAt: Long = System.currentTimeMillis(),
    val stores: List<StoreStop> = emptyList(),
    val totalDriveTimeMinutes: Int = 0,
    val totalCost: Double = 0.0
)
