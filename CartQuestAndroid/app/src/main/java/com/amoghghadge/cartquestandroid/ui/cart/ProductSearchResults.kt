package com.amoghghadge.cartquestandroid.ui.cart

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.amoghghadge.cartquestandroid.data.model.KrogerProduct

@Composable
fun ProductSearchResults(
    products: List<KrogerProduct>,
    onProductClick: (KrogerProduct) -> Unit,
    modifier: Modifier = Modifier
) {
    LazyColumn(modifier = modifier) {
        items(products, key = { it.productId }) { product ->
            ProductSearchRow(
                product = product,
                onClick = { onProductClick(product) }
            )
            HorizontalDivider()
        }
    }
}

@Composable
private fun ProductSearchRow(
    product: KrogerProduct,
    onClick: () -> Unit
) {
    val imageUrl = product.images.firstOrNull()?.sizes?.firstOrNull()?.url
    val price = product.items.firstOrNull()?.price?.regular

    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 12.dp)
    ) {
        AsyncImage(
            model = imageUrl,
            contentDescription = product.description,
            contentScale = ContentScale.Crop,
            modifier = Modifier
                .size(48.dp)
                .clip(RoundedCornerShape(8.dp))
        )
        Spacer(modifier = Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = product.description,
                style = MaterialTheme.typography.bodyMedium
            )
            Text(
                text = product.brand,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        if (price != null) {
            Text(
                text = "$${String.format("%.2f", price)}",
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold
            )
        }
    }
}
