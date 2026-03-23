package com.amoghghadge.cartquestandroid.ui.cart

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel

@Composable
fun CartBuilderScreen(
    onNavigateToRoute: (String) -> Unit,
    viewModel: CartBuilderViewModel = viewModel()
) {
    val state by viewModel.uiState.collectAsState()

    Column(modifier = Modifier.fillMaxSize()) {
        // Search bar
        OutlinedTextField(
            value = state.searchQuery,
            onValueChange = { viewModel.search(it) },
            placeholder = { Text("Search products...") },
            leadingIcon = {
                Icon(
                    imageVector = Icons.Default.Search,
                    contentDescription = "Search"
                )
            },
            singleLine = true,
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
        )

        if (state.addingSubstituteForIndex != null) {
            Text(
                text = "Search for a substitute for item ${state.addingSubstituteForIndex!! + 1}",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier.padding(horizontal = 16.dp)
            )
        }

        // Search results
        if (state.isSearching) {
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(100.dp)
            ) {
                CircularProgressIndicator()
            }
        } else if (state.searchResults.isNotEmpty()) {
            ProductSearchResults(
                products = state.searchResults,
                onProductClick = { viewModel.addToCart(it) },
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f)
            )
        } else {
            // Cart section
            Text(
                text = "Your Cart",
                style = MaterialTheme.typography.titleLarge,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
            )

            if (state.isSaving) {
                Text(
                    text = "Saving...",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(horizontal = 16.dp)
                )
            }

            if (state.cart.items.isEmpty()) {
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f)
                ) {
                    Text(
                        text = "Your cart is empty. Search for products to add.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            } else {
                LazyColumn(
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f)
                ) {
                    itemsIndexed(state.cart.items) { index, item ->
                        CartItemRow(
                            item = item,
                            index = index,
                            onQuantityChange = { qty -> viewModel.updateQuantity(index, qty) },
                            onRemove = { viewModel.removeFromCart(index) },
                            onAddSubstitute = { viewModel.startAddingSubstitute(index) },
                            onRemoveSubstitute = { subIndex ->
                                viewModel.removeSubstitute(index, subIndex)
                            }
                        )
                    }
                }
            }

            // Find Route button
            Spacer(modifier = Modifier.height(8.dp))
            Button(
                onClick = { onNavigateToRoute(state.cart.id) },
                enabled = state.cart.items.isNotEmpty(),
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp)
            ) {
                Text(text = "Find Route")
            }
        }
    }
}
