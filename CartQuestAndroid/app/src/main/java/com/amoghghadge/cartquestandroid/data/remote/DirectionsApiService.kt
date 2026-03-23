package com.amoghghadge.cartquestandroid.data.remote

import com.google.android.gms.maps.model.LatLng
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject

data class DirectionsResult(
    val totalDurationSeconds: Int,
    val encodedPolyline: String,
    val waypointOrder: List<Int> // optimized order if optimize:true was used
)

class DirectionsApiService(private val apiKey: String) {
    private val client = OkHttpClient()

    suspend fun getDirections(
        origin: LatLng,
        destination: LatLng,
        waypoints: List<LatLng> = emptyList()
    ): DirectionsResult {
        val waypointsParam = if (waypoints.isNotEmpty()) {
            "&waypoints=optimize:true|" + waypoints.joinToString("|") { "${it.latitude},${it.longitude}" }
        } else ""

        val url = "https://maps.googleapis.com/maps/api/directions/json?" +
            "origin=${origin.latitude},${origin.longitude}" +
            "&destination=${destination.latitude},${destination.longitude}" +
            waypointsParam +
            "&key=$apiKey"

        val response = withContext(Dispatchers.IO) {
            client.newCall(Request.Builder().url(url).build()).execute()
        }
        val json = JSONObject(response.body!!.string())
        val route = json.getJSONArray("routes").getJSONObject(0)

        val legs = route.getJSONArray("legs")
        var totalSeconds = 0
        for (i in 0 until legs.length()) {
            totalSeconds += legs.getJSONObject(i).getJSONObject("duration").getInt("value")
        }

        val polyline = route.getJSONObject("overview_polyline").getString("points")

        val waypointOrder = mutableListOf<Int>()
        if (route.has("waypoint_order")) {
            val orderArray = route.getJSONArray("waypoint_order")
            for (i in 0 until orderArray.length()) {
                waypointOrder.add(orderArray.getInt(i))
            }
        }

        return DirectionsResult(totalSeconds, polyline, waypointOrder)
    }
}
