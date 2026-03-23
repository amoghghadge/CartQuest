package com.amoghghadge.cartquestandroid.ui.navigation

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.People
import androidx.compose.material.icons.filled.ShoppingCart
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController

@Composable
fun AppNavigation() {
    var selectedTab by remember { mutableIntStateOf(0) }

    val shopNavController = rememberNavController()
    val communityNavController = rememberNavController()

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
            }
        }
    ) { innerPadding ->
        when (selectedTab) {
            0 -> NavHost(
                navController = shopNavController,
                startDestination = Screen.CartBuilder.route,
                modifier = Modifier.padding(innerPadding)
            ) {
                composable(Screen.CartBuilder.route) {
                    Text(text = "CartBuilder")
                }
                composable(Screen.RouteMap.route) {
                    Text(text = "RouteMap")
                }
            }
            1 -> NavHost(
                navController = communityNavController,
                startDestination = Screen.CommunityFeed.route,
                modifier = Modifier.padding(innerPadding)
            ) {
                composable(Screen.CommunityFeed.route) {
                    Text(text = "CommunityFeed")
                }
                composable(Screen.RunDetail.route) {
                    Text(text = "RunDetail")
                }
            }
        }
    }
}
