package com.ddouwill.smartcard

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Color
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import com.google.zxing.BarcodeFormat
import com.google.zxing.EncodeHintType
import com.google.zxing.MultiFormatWriter
import es.antonborri.home_widget.HomeWidgetPlugin

class SmartCardWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {

    private var cardCount = 0
    private var actualCardCount = 0

    override fun onCreate() {}

    override fun onDataSetChanged() {
        val prefs = HomeWidgetPlugin.getData(context)
        val mode = prefs.getString("widget_mode", null)
        actualCardCount = if (mode == "multipleCards") {
            prefs.getInt("card_count", 0)
        } else {
            if (prefs.getString("primary_barcode_value", null) != null) 1 else 0
        }
        // < 4 張時填充到 4 張，讓 StackView 堆疊效果飽滿
        cardCount = if (actualCardCount in 1..3) {
            4
        } else {
            actualCardCount
        }
    }

    override fun onDestroy() {}

    override fun getCount(): Int = cardCount

    override fun getViewAt(position: Int): RemoteViews {
        val prefs = HomeWidgetPlugin.getData(context)
        val mode = prefs.getString("widget_mode", null)


        val storeName: String
        val barcodeValue: String
        val barcodeFormat: String

        val cardId: String

        if (mode == "multipleCards") {
            val idx = if (actualCardCount > 0) position % actualCardCount else 0
            storeName = prefs.getString("card_${idx}_store_name", "") ?: ""
            barcodeValue = prefs.getString("card_${idx}_barcode_value", "") ?: ""
            barcodeFormat = prefs.getString("card_${idx}_barcode_format", "CODE_128") ?: "CODE_128"
            cardId = prefs.getString("card_${idx}_card_id", "") ?: ""
        } else {
            storeName = prefs.getString("primary_store_name", "") ?: ""
            barcodeValue = prefs.getString("primary_barcode_value", "") ?: ""
            barcodeFormat = prefs.getString("primary_barcode_format", "CODE_128") ?: "CODE_128"
            cardId = prefs.getString("primary_card_id", "") ?: ""
        }

        val rv = RemoteViews(context.packageName, R.layout.widget_stack_item)

        // App icon
        rv.setImageViewResource(R.id.widget_item_icon, R.mipmap.ic_launcher)

        // Barcode
        val bitmap = generateBarcodeBitmap(barcodeValue, barcodeFormat)
        if (bitmap != null) {
            rv.setImageViewBitmap(R.id.widget_item_barcode, bitmap)
        }

        // Store name
        rv.setTextViewText(R.id.widget_item_store_name, storeName)

        // Fill-in intent for card click（與 Provider 的 setPendingIntentTemplate 組合）
        val fillInIntent = Intent().apply {
            putExtra(SmartCardWidgetProvider.EXTRA_CARD_ID, cardId)
        }
        rv.setOnClickFillInIntent(R.id.widget_item_barcode, fillInIntent)
        rv.setOnClickFillInIntent(R.id.widget_item_store_name, fillInIntent)

        return rv
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = true

    private fun generateBarcodeBitmap(
        value: String,
        formatStr: String,
        width: Int = 600,
        height: Int = 200
    ): Bitmap? {
        return try {
            val format = parseBarcodeFormat(formatStr)

            val w: Int
            val h: Int
            if (format == BarcodeFormat.QR_CODE || format == BarcodeFormat.DATA_MATRIX || format == BarcodeFormat.AZTEC) {
                val size = minOf(width, height)
                w = size
                h = size
            } else {
                w = width
                h = height
            }

            val hints = mapOf(EncodeHintType.MARGIN to 0)
            val bitMatrix = MultiFormatWriter().encode(value, format, w, h, hints)
            val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
            for (x in 0 until w) {
                for (y in 0 until h) {
                    bitmap.setPixel(x, y, if (bitMatrix[x, y]) Color.BLACK else Color.WHITE)
                }
            }
            bitmap
        } catch (e: Exception) {
            null
        }
    }
}
