package com.amoghghadge.cartquestandroid.ui.navigation

sealed class Screen(val route: String) {
    object CartBuilder : Screen("cart_builder")
    object RouteMap : Screen("route_map/{cartId}") {
        fun createRoute(cartId: String) = "route_map/$cartId"
    }
    object CommunityFeed : Screen("community_feed")
    object RunDetail : Screen("run_detail/{runId}") {
        fun createRoute(runId: String) = "run_detail/$runId"
    }
}
