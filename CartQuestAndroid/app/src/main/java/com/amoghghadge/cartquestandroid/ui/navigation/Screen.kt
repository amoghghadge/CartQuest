package com.amoghghadge.cartquestandroid.ui.navigation

sealed class Screen(val route: String) {
    object ShopHome : Screen("shop_home")
    object ProductList : Screen("product_list")
    object CartDetail : Screen("cart_detail")
    object RouteMap : Screen("route_map/{cartId}") {
        fun createRoute(cartId: String) = "route_map/$cartId"
    }
    object SubstituteSearch : Screen("substitute_search/{cartItemIndex}") {
        fun createRoute(cartItemIndex: Int) = "substitute_search/$cartItemIndex"
    }
    object CommunityFeed : Screen("community_feed")
    object RunDetail : Screen("run_detail/{runId}") {
        fun createRoute(runId: String) = "run_detail/$runId"
    }
    object Profile : Screen("profile")
}
