package com.amoghghadge.cartquestandroid.service

import android.annotation.SuppressLint
import android.content.Context
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.maps.model.LatLng
import kotlinx.coroutines.tasks.await

class LocationService(private val context: Context) {
    private val fusedClient = LocationServices.getFusedLocationProviderClient(context)

    @SuppressLint("MissingPermission")
    suspend fun getCurrentLocation(): LatLng {
        val location = fusedClient.getCurrentLocation(
            Priority.PRIORITY_HIGH_ACCURACY, null
        ).await()
        return LatLng(location.latitude, location.longitude)
    }
}
