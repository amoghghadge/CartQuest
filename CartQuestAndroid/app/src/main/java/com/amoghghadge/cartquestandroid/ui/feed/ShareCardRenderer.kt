package com.amoghghadge.cartquestandroid.ui.feed

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import com.amoghghadge.cartquestandroid.data.model.CompletedRun
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class ShareCardRenderer {
    companion object {
        private const val WIDTH = 1080
        private const val HORIZONTAL_PADDING = 64f
        private const val MAX_ITEMS_SHOWN = 6

        private val brandColor = Color.parseColor("#4285F4")

        fun render(run: CompletedRun, context: Context): Bitmap {
            val height = calculateHeight(run)
            val bitmap = Bitmap.createBitmap(WIDTH, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)

            // White background
            canvas.drawColor(Color.WHITE)

            var y = 0f

            // -- Header accent bar --
            val accentPaint = Paint().apply { color = brandColor }
            canvas.drawRect(0f, 0f, WIDTH.toFloat(), 8f, accentPaint)
            y += 8f

            // -- App title --
            val titlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = brandColor
                textSize = 56f
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            }
            y += 80f
            canvas.drawText("CartQuest", HORIZONTAL_PADDING, y, titlePaint)

            // -- Date --
            val datePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.parseColor("#666666")
                textSize = 36f
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.NORMAL)
            }
            val dateFormat = SimpleDateFormat("EEEE, MMM d, yyyy", Locale.getDefault())
            y += 52f
            canvas.drawText(dateFormat.format(Date(run.completedAt)), HORIZONTAL_PADDING, y, datePaint)

            // -- Divider --
            y += 32f
            val dividerPaint = Paint().apply { color = Color.parseColor("#E0E0E0"); strokeWidth = 2f }
            canvas.drawLine(HORIZONTAL_PADDING, y, WIDTH - HORIZONTAL_PADDING, y, dividerPaint)

            // -- Route summary --
            val sectionLabelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.parseColor("#999999")
                textSize = 30f
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                letterSpacing = 0.08f
            }
            y += 52f
            canvas.drawText("ROUTE", HORIZONTAL_PADDING, y, sectionLabelPaint)

            val routePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.parseColor("#333333")
                textSize = 38f
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.NORMAL)
            }
            val routeText = run.stores.joinToString("  →  ") { it.storeName }
            y += 50f
            // Truncate route text if too long
            val maxRouteWidth = WIDTH - 2 * HORIZONTAL_PADDING
            val truncatedRoute = truncateText(routeText, routePaint, maxRouteWidth)
            canvas.drawText(truncatedRoute, HORIZONTAL_PADDING, y, routePaint)

            // -- Divider --
            y += 32f
            canvas.drawLine(HORIZONTAL_PADDING, y, WIDTH - HORIZONTAL_PADDING, y, dividerPaint)

            // -- Item highlights --
            y += 52f
            canvas.drawText("ITEMS", HORIZONTAL_PADDING, y, sectionLabelPaint)

            val itemNamePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.parseColor("#333333")
                textSize = 36f
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.NORMAL)
            }
            val itemPricePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.parseColor("#333333")
                textSize = 36f
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                textAlign = Paint.Align.RIGHT
            }

            val allItems = run.stores.flatMap { store ->
                store.items.map { item -> item to store.storeName }
            }
            val displayItems = allItems.take(MAX_ITEMS_SHOWN)

            for ((item, _) in displayItems) {
                y += 50f
                val nameMaxWidth = WIDTH - 2 * HORIZONTAL_PADDING - 180f
                val truncatedName = truncateText(item.name, itemNamePaint, nameMaxWidth)
                canvas.drawText(truncatedName, HORIZONTAL_PADDING, y, itemNamePaint)
                canvas.drawText(
                    "$${String.format("%.2f", item.price)}",
                    WIDTH - HORIZONTAL_PADDING,
                    y,
                    itemPricePaint
                )
            }

            if (allItems.size > MAX_ITEMS_SHOWN) {
                y += 50f
                val morePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = Color.parseColor("#999999")
                    textSize = 32f
                    typeface = Typeface.create(Typeface.DEFAULT, Typeface.ITALIC)
                }
                canvas.drawText(
                    "+${allItems.size - MAX_ITEMS_SHOWN} more item${if (allItems.size - MAX_ITEMS_SHOWN != 1) "s" else ""}",
                    HORIZONTAL_PADDING,
                    y,
                    morePaint
                )
            }

            // -- Divider --
            y += 40f
            canvas.drawLine(HORIZONTAL_PADDING, y, WIDTH - HORIZONTAL_PADDING, y, dividerPaint)

            // -- Total cost and drive time --
            val summaryLabelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.parseColor("#333333")
                textSize = 40f
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            }
            val summaryValuePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = brandColor
                textSize = 44f
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                textAlign = Paint.Align.RIGHT
            }

            y += 56f
            canvas.drawText("Total Cost", HORIZONTAL_PADDING, y, summaryLabelPaint)
            canvas.drawText(
                "$${String.format("%.2f", run.totalCost)}",
                WIDTH - HORIZONTAL_PADDING,
                y,
                summaryValuePaint
            )

            val driveTimeLabelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.parseColor("#333333")
                textSize = 36f
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            }
            val driveValuePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.parseColor("#333333")
                textSize = 40f
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                textAlign = Paint.Align.RIGHT
            }
            y += 52f
            canvas.drawText("Drive Time", HORIZONTAL_PADDING, y, driveTimeLabelPaint)
            canvas.drawText(
                "${run.totalDriveTimeMinutes} min",
                WIDTH - HORIZONTAL_PADDING,
                y,
                driveValuePaint
            )

            // -- Footer branding --
            y += 56f
            canvas.drawLine(HORIZONTAL_PADDING, y, WIDTH - HORIZONTAL_PADDING, y, dividerPaint)

            val footerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.parseColor("#AAAAAA")
                textSize = 28f
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.NORMAL)
                textAlign = Paint.Align.CENTER
            }
            y += 48f
            canvas.drawText(
                "Shared from CartQuest — Smart Grocery Shopping",
                WIDTH / 2f,
                y,
                footerPaint
            )

            return bitmap
        }

        private fun calculateHeight(run: CompletedRun): Int {
            var height = 0
            height += 8    // accent bar
            height += 80   // app title
            height += 52   // date
            height += 32   // divider gap
            height += 52   // route label
            height += 50   // route text
            height += 32   // divider gap
            height += 52   // items label

            val allItems = run.stores.flatMap { it.items }
            val displayCount = minOf(allItems.size, MAX_ITEMS_SHOWN)
            height += displayCount * 50

            if (allItems.size > MAX_ITEMS_SHOWN) {
                height += 50 // "+N more items"
            }

            height += 40   // divider gap
            height += 56   // total cost
            height += 52   // drive time
            height += 56   // divider gap
            height += 48   // footer text
            height += 48   // bottom padding

            return height
        }

        private fun truncateText(text: String, paint: Paint, maxWidth: Float): String {
            if (paint.measureText(text) <= maxWidth) return text
            var truncated = text
            while (truncated.isNotEmpty() && paint.measureText("$truncated...") > maxWidth) {
                truncated = truncated.dropLast(1)
            }
            return "$truncated..."
        }
    }
}
