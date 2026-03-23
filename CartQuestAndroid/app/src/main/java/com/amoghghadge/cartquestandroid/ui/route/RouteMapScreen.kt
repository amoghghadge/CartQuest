package com.amoghghadge.cartquestandroid.ui.route

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.google.android.gms.maps.CameraUpdateFactory
import com.google.android.gms.maps.model.BitmapDescriptorFactory
import com.google.android.gms.maps.model.LatLng
import com.google.android.gms.maps.model.LatLngBounds
import com.google.maps.android.compose.GoogleMap
import com.google.maps.android.compose.Marker
import com.google.maps.android.compose.MarkerState
import com.google.maps.android.compose.Polyline
import com.google.maps.android.compose.rememberCameraPositionState

@Composable
fun RouteMapScreen(
    onNavigateBack: () -> Unit,
    viewModel: RouteMapViewModel = viewModel()
) {
    val routeState by viewModel.routeState.collectAsState()
    val tripCompleted by viewModel.tripCompleted.collectAsState()
    val context = LocalContext.current

    LaunchedEffect(tripCompleted) {
        if (tripCompleted) {
            onNavigateBack()
        }
    }

    when (val state = routeState) {
        is RouteState.Loading -> {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    CircularProgressIndicator()
                    Spacer(modifier = Modifier.height(16.dp))
                    Text(
                        text = "Computing optimal route...",
                        style = MaterialTheme.typography.bodyLarge
                    )
                }
            }
        }

        is RouteState.Error -> {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier.padding(32.dp)
                ) {
                    Text(
                        text = "Error",
                        style = MaterialTheme.typography.headlineSmall,
                        fontWeight = FontWeight.Bold
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = state.message,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.error
                    )
                    Spacer(modifier = Modifier.height(16.dp))
                    Row {
                        OutlinedButton(onClick = onNavigateBack) {
                            Text("Back to Cart")
                        }
                        Spacer(modifier = Modifier.width(8.dp))
                        Button(onClick = { viewModel.computeRoute() }) {
                            Text("Retry")
                        }
                    }
                }
            }
        }

        is RouteState.Computed -> {
            RouteMapContent(
                route = state.route,
                userLocation = state.userLocation,
                onNavigateBack = onNavigateBack,
                onStartNavigation = { viewModel.startNavigation(context) },
                onCompleteTrip = { viewModel.completeTrip() }
            )
        }
    }
}

@Composable
private fun RouteMapContent(
    route: com.amoghghadge.cartquestandroid.service.RouteOptimizer.OptimizedRoute,
    userLocation: LatLng,
    onNavigateBack: () -> Unit,
    onStartNavigation: () -> Unit,
    onCompleteTrip: () -> Unit
) {
    val cameraPositionState = rememberCameraPositionState()

    // Fit camera to show all points
    LaunchedEffect(route) {
        val boundsBuilder = LatLngBounds.Builder()
        boundsBuilder.include(userLocation)
        route.stops.forEach { stop ->
            boundsBuilder.include(LatLng(stop.lat, stop.lng))
        }
        val bounds = boundsBuilder.build()
        cameraPositionState.move(CameraUpdateFactory.newLatLngBounds(bounds, 80))
    }

    Column(modifier = Modifier.fillMaxSize()) {
        // Map section
        GoogleMap(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f),
            cameraPositionState = cameraPositionState
        ) {
            // User location marker
            Marker(
                state = MarkerState(position = userLocation),
                title = "Your Location",
                icon = BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_AZURE)
            )

            // Store stop markers
            route.stops.forEachIndexed { index, stop ->
                Marker(
                    state = MarkerState(position = LatLng(stop.lat, stop.lng)),
                    title = "${index + 1}. ${stop.storeName}",
                    snippet = stop.address,
                    icon = BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_RED)
                )
            }

            // Polyline connecting route
            if (route.encodedPolyline.isNotEmpty()) {
                val decodedPath = decodePolyline(route.encodedPolyline)
                Polyline(
                    points = decodedPath,
                    color = Color(0xFF4285F4),
                    width = 8f
                )
            }
        }

        // Route summary
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text(
                text = "${route.stops.size} stop(s)",
                style = MaterialTheme.typography.titleSmall
            )
            Text(
                text = "Drive: ${route.totalDriveTimeSeconds / 60} min",
                style = MaterialTheme.typography.titleSmall
            )
            val totalCost = route.stops.sumOf { stop -> stop.items.sumOf { it.price } }
            Text(
                text = "Total: $${String.format("%.2f", totalCost)}",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Bold
            )
        }

        // Store stop list
        LazyColumn(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f)
        ) {
            itemsIndexed(route.stops) { index, stop ->
                StoreStopCard(stopIndex = index, stop = stop)
            }
        }

        // Bottom bar
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            OutlinedButton(
                onClick = onNavigateBack,
                modifier = Modifier.weight(1f)
            ) {
                Text("Back to Cart")
            }
            Button(
                onClick = onStartNavigation,
                modifier = Modifier.weight(1f)
            ) {
                Text("Navigate")
            }
            Button(
                onClick = onCompleteTrip,
                modifier = Modifier.weight(1f),
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.tertiary
                )
            ) {
                Text("Complete Trip")
            }
        }
    }
}

/**
 * Decodes an encoded polyline string into a list of LatLng points.
 * Uses the Google Encoded Polyline Algorithm.
 */
fun decodePolyline(encoded: String): List<LatLng> {
    val poly = mutableListOf<LatLng>()
    var index = 0
    val len = encoded.length
    var lat = 0
    var lng = 0

    while (index < len) {
        var b: Int
        var shift = 0
        var result = 0
        do {
            b = encoded[index++].code - 63
            result = result or ((b and 0x1f) shl shift)
            shift += 5
        } while (b >= 0x20)
        val dlat = if (result and 1 != 0) (result shr 1).inv() else result shr 1
        lat += dlat

        shift = 0
        result = 0
        do {
            b = encoded[index++].code - 63
            result = result or ((b and 0x1f) shl shift)
            shift += 5
        } while (b >= 0x20)
        val dlng = if (result and 1 != 0) (result shr 1).inv() else result shr 1
        lng += dlng

        poly.add(LatLng(lat / 1E5, lng / 1E5))
    }
    return poly
}
