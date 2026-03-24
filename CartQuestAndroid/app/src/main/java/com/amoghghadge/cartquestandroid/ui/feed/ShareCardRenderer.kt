package com.amoghghadge.cartquestandroid.ui.feed

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import com.amoghghadge.cartquestandroid.BuildConfig
import com.amoghghadge.cartquestandroid.R
import com.amoghghadge.cartquestandroid.data.model.CompletedRun
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class ShareCardRenderer {
    companion object {
        private const val WIDTH = 1080
        private const val PADDING = 64f
        private const val CONTENT_WIDTH = WIDTH - 2 * PADDING

        private val brandColor = Color.parseColor("#4285F4")
        private val textPrimary = Color.parseColor("#1A1A1A")
        private val textSecondary = Color.parseColor("#888888")
        private val dividerColor = Color.parseColor("#EEEEEE")

        fun render(run: CompletedRun, context: Context, mapBitmap: Bitmap? = null): Bitmap {
            val height = calculateHeight(run, mapBitmap != null)
            val bitmap = Bitmap.createBitmap(WIDTH, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)

            canvas.drawColor(Color.WHITE)

            var y = PADDING

            // -- App icon + title --
            val appIcon = BitmapFactory.decodeResource(context.resources, R.drawable.app_icon)
            if (appIcon != null) {
                val iconSize = 120f
                val scaledIcon = Bitmap.createScaledBitmap(appIcon, iconSize.toInt(), iconSize.toInt(), true)
                val iconRect = RectF(PADDING, y, PADDING + iconSize, y + iconSize)
                val iconPaint = Paint(Paint.ANTI_ALIAS_FLAG)
                canvas.drawBitmap(scaledIcon, null, iconRect, iconPaint)

                val titlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = brandColor
                    textSize = 56f
                    typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                }
                canvas.drawText("CartQuest", PADDING + iconSize + 32f, y + iconSize / 2f + 18f, titlePaint)
            }
            y += 120f + 48f

            // -- Date --
            val datePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = textSecondary
                textSize = 36f
            }
            val dateFormat = SimpleDateFormat("EEEE, MMM d, yyyy", Locale.getDefault())
            canvas.drawText(dateFormat.format(Date(run.completedAt)), PADDING, y, datePaint)
            y += 56f

            // -- Map image --
            if (mapBitmap != null) {
                val mapHeight = (CONTENT_WIDTH / mapBitmap.width.toFloat() * mapBitmap.height).toInt()
                val scaledMap = Bitmap.createScaledBitmap(mapBitmap, CONTENT_WIDTH.toInt(), mapHeight, true)
                val mapRect = RectF(PADDING, y, PADDING + CONTENT_WIDTH, y + mapHeight)
                canvas.drawBitmap(scaledMap, null, mapRect, Paint(Paint.ANTI_ALIAS_FLAG))
                y += mapHeight + 40f
            }

            // -- Stores visited --
            val sectionLabelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = textSecondary
                textSize = 28f
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                letterSpacing = 0.1f
            }
            canvas.drawText("STORES VISITED", PADDING, y, sectionLabelPaint)
            y += 44f

            val storeNamePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = textPrimary
                textSize = 38f
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.NORMAL)
            }

            val circlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = brandColor }
            val circleTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.WHITE
                textSize = 24f
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                textAlign = Paint.Align.CENTER
            }

            val itemCountPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.parseColor("#AAAAAA")
                textSize = 32f
                textAlign = Paint.Align.RIGHT
            }

            for ((index, store) in run.stores.withIndex()) {
                val circleRadius = 28f
                val circleCenterX = PADDING + circleRadius
                val circleCenterY = y + circleRadius - 6f
                canvas.drawCircle(circleCenterX, circleCenterY, circleRadius, circlePaint)
                canvas.drawText(
                    "${index + 1}",
                    circleCenterX,
                    circleCenterY + 9f,
                    circleTextPaint
                )
                canvas.drawText(
                    store.storeName,
                    PADDING + circleRadius * 2 + 24f,
                    y + circleRadius + 4f,
                    storeNamePaint
                )
                val count = store.items.size
                canvas.drawText(
                    "$count item${if (count == 1) "" else "s"}",
                    WIDTH - PADDING,
                    y + circleRadius + 4f,
                    itemCountPaint
                )
                y += 64f
            }
            y += 16f

            // -- Divider --
            val dividerPaint = Paint().apply { color = dividerColor; strokeWidth = 2f }
            canvas.drawLine(PADDING, y, WIDTH - PADDING, y, dividerPaint)
            y += 40f

            // -- Stats row: Total cost + Drive time --
            val statsLabelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = textSecondary
                textSize = 28f
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                letterSpacing = 0.05f
            }
            val costValuePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = brandColor
                textSize = 48f
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            }
            val driveValuePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = textPrimary
                textSize = 48f
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                textAlign = Paint.Align.RIGHT
            }
            val driveLabelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = textSecondary
                textSize = 28f
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                letterSpacing = 0.05f
                textAlign = Paint.Align.RIGHT
            }

            val totalItems = run.stores.sumOf { it.items.size }

            val rightColX = WIDTH - PADDING - 250f

            canvas.drawText("TOTAL COST", PADDING, y, statsLabelPaint)
            canvas.drawText("ITEMS", rightColX, y, driveLabelPaint)
            canvas.drawText("DRIVE TIME", WIDTH - PADDING, y, driveLabelPaint)
            y += 56f
            canvas.drawText("$${String.format("%.2f", run.totalCost)}", PADDING, y, costValuePaint)
            canvas.drawText("$totalItems", rightColX, y, driveValuePaint)
            canvas.drawText("${run.totalDriveTimeMinutes} min", WIDTH - PADDING, y, driveValuePaint)

            return bitmap
        }

        fun loadStaticMapBitmap(stores: List<com.amoghghadge.cartquestandroid.data.model.StoreStop>): Bitmap? {
            if (stores.isEmpty()) return null
            val apiKey = BuildConfig.GOOGLE_MAPS_API_KEY
            if (apiKey.isBlank()) return null

            val sb = StringBuilder("https://maps.googleapis.com/maps/api/staticmap?size=800x400&maptype=roadmap&scale=2")

            for ((index, store) in stores.withIndex()) {
                sb.append("&markers=color:0x4285F4|label:${index + 1}|${store.lat},${store.lng}")
            }

            if (stores.size > 1) {
                val pathCoords = stores.joinToString("|") { "${it.lat},${it.lng}" }
                sb.append("&path=color:0x4285F4ff|weight:3|$pathCoords")
            }

            sb.append("&key=$apiKey")

            return try {
                val stream = URL(sb.toString()).openStream()
                BitmapFactory.decodeStream(stream)
            } catch (_: Exception) {
                null
            }
        }

        private fun calculateHeight(run: CompletedRun, hasMap: Boolean): Int {
            var h = PADDING.toInt()       // top padding
            h += 120 + 48                 // icon + title + gap
            h += 56                       // date
            if (hasMap) h += 500 + 40     // map image estimate + gap
            h += 44                       // section label
            h += run.stores.size * 64     // store rows
            h += 16                       // gap
            h += 2 + 40                   // divider + gap
            h += 28 + 56                  // stats labels + values
            h += PADDING.toInt()          // bottom padding
            return h
        }
    }
}
