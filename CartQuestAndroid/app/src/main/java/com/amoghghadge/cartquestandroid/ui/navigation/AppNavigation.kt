package com.amoghghadge.cartquestandroid.ui.navigation

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.People
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.ShoppingCart
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.amoghghadge.cartquestandroid.service.LocationService
import com.amoghghadge.cartquestandroid.ui.feed.CommunityFeedScreen
import com.amoghghadge.cartquestandroid.ui.feed.RunDetailScreen
import com.amoghghadge.cartquestandroid.ui.profile.ProfileScreen
import com.amoghghadge.cartquestandroid.ui.route.RouteMapScreen
import com.amoghghadge.cartquestandroid.ui.shop.CartScreen
import com.amoghghadge.cartquestandroid.ui.shop.ProductListScreen
import com.amoghghadge.cartquestandroid.ui.shop.ShopHomeScreen
import com.amoghghadge.cartquestandroid.ui.shop.ShopViewModel

@Composable
fun AppNavigation(onLoggedOut: () -> Unit) {
    var selectedTab by remember { mutableIntStateOf(0) }

    val shopNavController = rememberNavController()
    val communityNavController = rememberNavController()
    val shopViewModel: ShopViewModel = viewModel()
    val context = LocalContext.current

    LaunchedEffect(Unit) {
        shopViewModel.initLocation(LocationService(context))
    }

    Scaffold(
        bottomBar = {
            NavigationBar {
                NavigationBarItem(
                    selected = selectedTab == 0,
                    onClick = { selectedTab = 0 },
                    icon = {
                        Icon(
                            imageVector = Icons.Default.ShoppingCart,
                            contentDescription = "Shop"
                        )
                    },
                    label = { Text("Shop") }
                )
                NavigationBarItem(
                    selected = selectedTab == 1,
                    onClick = { selectedTab = 1 },
                    icon = {
                        Icon(
                            imageVector = Icons.Default.People,
                            contentDescription = "Community"
                        )
                    },
                    label = { Text("Community") }
                )
                NavigationBarItem(
                    selected = selectedTab == 2,
                    onClick = { selectedTab = 2 },
                    icon = {
                        Icon(
                            imageVector = Icons.Default.Person,
                            contentDescription = "Profile"
                        )
                    },
                    label = { Text("Profile") }
                )
            }
        }
    ) { innerPadding ->
        when (selectedTab) {
            0 -> NavHost(
                navController = shopNavController,
                startDestination = Screen.ShopHome.route,
                modifier = Modifier.padding(innerPadding)
            ) {
                composable(Screen.ShopHome.route) {
                    ShopHomeScreen(
                        viewModel = shopViewModel,
                        onNavigateToResults = {
                            shopNavController.navigate(Screen.ProductList.route)
                        },
                        onNavigateToCart = {
                            shopNavController.navigate(Screen.CartDetail.route)
                        }
                    )
                }
                composable(Screen.ProductList.route) {
                    ProductListScreen(
                        viewModel = shopViewModel,
                        onNavigateToCart = {
                            shopNavController.navigate(Screen.CartDetail.route)
                        },
                        onNavigateBack = { shopNavController.popBackStack() }
                    )
                }
                composable(Screen.CartDetail.route) {
                    CartScreen(
                        viewModel = shopViewModel,
                        onNavigateToRoute = { cartId ->
                            shopNavController.navigate(Screen.RouteMap.createRoute(cartId))
                        },
                        onNavigateBack = { shopNavController.popBackStack() }
                    )
                }
                composable(
                    route = Screen.RouteMap.route,
                    arguments = listOf(navArgument("cartId") { type = NavType.StringType })
                ) {
                    RouteMapScreen(
                        onNavigateBack = { shopNavController.popBackStack() }
                    )
                }
            }
            1 -> NavHost(
                navController = communityNavController,
                startDestination = Screen.CommunityFeed.route,
                modifier = Modifier.padding(innerPadding)
            ) {
                composable(Screen.CommunityFeed.route) {
                    CommunityFeedScreen(
                        onNavigateToRunDetail = { runId ->
                            communityNavController.navigate(Screen.RunDetail.createRoute(runId))
                        }
                    )
                }
                composable(
                    route = Screen.RunDetail.route,
                    arguments = listOf(navArgument("runId") { type = NavType.StringType })
                ) {
                    RunDetailScreen(
                        onNavigateBack = { communityNavController.popBackStack() }
                    )
                }
            }
            2 -> ProfileScreen(onLoggedOut = onLoggedOut)
        }
    }
}
