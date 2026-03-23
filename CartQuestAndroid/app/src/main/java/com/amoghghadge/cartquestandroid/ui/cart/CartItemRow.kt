package com.amoghghadge.cartquestandroid.ui.cart

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material3.Card
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.amoghghadge.cartquestandroid.data.model.CartItem

@Composable
fun CartItemRow(
    item: CartItem,
    index: Int,
    onQuantityChange: (Int) -> Unit,
    onRemove: () -> Unit,
    onAddSubstitute: () -> Unit,
    onRemoveSubstitute: (Int) -> Unit,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 4.dp)
    ) {
        Column(modifier = Modifier.padding(12.dp)) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth()
            ) {
                AsyncImage(
                    model = item.imageUrl,
                    contentDescription = item.name,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier
                        .size(56.dp)
                        .clip(RoundedCornerShape(8.dp))
                )
                Spacer(modifier = Modifier.width(12.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = item.name,
                        style = MaterialTheme.typography.bodyLarge
                    )
                    Text(
                        text = item.brand,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                IconButton(onClick = onRemove) {
                    Icon(
                        imageVector = Icons.Default.Delete,
                        contentDescription = "Remove item"
                    )
                }
            }

            // Quantity stepper
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.padding(top = 8.dp)
            ) {
                Text(text = "Qty:", style = MaterialTheme.typography.bodyMedium)
                Spacer(modifier = Modifier.width(8.dp))
                IconButton(
                    onClick = { onQuantityChange(item.quantity - 1) },
                    enabled = item.quantity > 1
                ) {
                    Icon(
                        imageVector = Icons.Default.Remove,
                        contentDescription = "Decrease quantity"
                    )
                }
                Text(
                    text = "${item.quantity}",
                    style = MaterialTheme.typography.bodyLarge
                )
                IconButton(onClick = { onQuantityChange(item.quantity + 1) }) {
                    Icon(
                        imageVector = Icons.Default.Add,
                        contentDescription = "Increase quantity"
                    )
                }
            }

            // Substitutes
            if (item.substitutes.isNotEmpty()) {
                Text(
                    text = "Substitutes",
                    style = MaterialTheme.typography.labelMedium,
                    modifier = Modifier.padding(top = 8.dp)
                )
                item.substitutes.forEachIndexed { subIndex, substitute ->
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(start = 8.dp, top = 4.dp)
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = "${subIndex + 1}. ${substitute.name}",
                                style = MaterialTheme.typography.bodySmall
                            )
                            Text(
                                text = substitute.brand,
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        IconButton(onClick = { onRemoveSubstitute(subIndex) }) {
                            Icon(
                                imageVector = Icons.Default.Close,
                                contentDescription = "Remove substitute",
                                modifier = Modifier.size(18.dp)
                            )
                        }
                    }
                }
            }

            TextButton(onClick = onAddSubstitute) {
                Icon(
                    imageVector = Icons.Default.Add,
                    contentDescription = null,
                    modifier = Modifier.size(16.dp)
                )
                Spacer(modifier = Modifier.width(4.dp))
                Text(text = "Add Substitute")
            }
        }
    }
}
