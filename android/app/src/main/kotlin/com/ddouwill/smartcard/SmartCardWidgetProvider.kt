package com.ddouwill.smartcard

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.app.PendingIntent
import android.graphics.Bitmap
import android.graphics.Color
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import com.google.zxing.BarcodeFormat
import com.google.zxing.EncodeHintType
import com.google.zxing.MultiFormatWriter
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * SmartCard 桌面小工具 Provider
 *
 * 負責讀取 Flutter 透過 home_widget 儲存的卡片資料，
 * 並根據顯示模式更新 Widget 的 RemoteViews。
 * 
 * 加強穩定性：
 * 1. 增加 null 檢查，避免 String.hashCode() 等崩潰。
 * 2. 處理資料不一致或空缺情況。
 */
class SmartCardWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_WIDGET_CLICK = "com.ddouwill.smartcard.WIDGET_CLICK"
        const val EXTRA_CARD_ID = "card_id"

        const val MODE_NO_MATCH = "noMatch"
        const val MODE_SINGLE_CARD = "singleCard"
        const val MODE_MULTIPLE_CARDS = "multipleCards"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        if (intent.action == ACTION_WIDGET_CLICK) {
            val cardId = intent.getStringExtra(EXTRA_CARD_ID)
            val deepLinkUri = if (cardId != null && cardId.isNotEmpty()) {
                Uri.parse("smartcard://card/$cardId")
            } else {
                Uri.parse("smartcard://home")
            }

            val launchIntent = Intent(context, MainActivity::class.java).apply {
                data = deepLinkUri
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            context.startActivity(launchIntent)
        }
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val widgetData = HomeWidgetPlugin.getData(context)

        val displayMode = widgetData.getString("widget_mode", MODE_NO_MATCH) ?: MODE_NO_MATCH
        val widgetTitle = widgetData.getString("widget_title", "SmartCard") ?: "SmartCard"

        val views = RemoteViews(context.packageName, R.layout.smart_card_widget)

        views.setTextViewText(R.id.widget_title, widgetTitle)

        val openAppIntent = createOpenAppIntent(context, null)
        views.setOnClickPendingIntent(R.id.widget_app_icon, openAppIntent)
        views.setOnClickPendingIntent(R.id.widget_title, openAppIntent)

        when (displayMode) {
            MODE_SINGLE_CARD -> updateSingleCardMode(context, views, widgetData)
            MODE_MULTIPLE_CARDS -> updateMultipleCardsMode(context, views, widgetData)
            else -> updateNoMatchMode(context, views, widgetData)
        }

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun updateNoMatchMode(
        context: Context,
        views: RemoteViews,
        widgetData: android.content.SharedPreferences
    ) {
        val storeName = widgetData.getString("primary_store_name", "") ?: ""
        val cardId = widgetData.getString("primary_card_id", "") ?: ""

        if (storeName.isNotEmpty() && cardId.isNotEmpty()) {
            views.setViewVisibility(R.id.widget_barcode_image, View.VISIBLE)
            views.setViewVisibility(R.id.widget_multi_card_container, View.GONE)
            views.setViewVisibility(R.id.widget_empty_text, View.GONE)

            val barcodeValue = widgetData.getString("primary_barcode_value", "") ?: ""
            val barcodeFormat = widgetData.getString("primary_barcode_format", "CODE_128") ?: "CODE_128"
            if (barcodeValue.isNotEmpty()) {
                val bitmap = generateBarcodeBitmap(barcodeValue, barcodeFormat)
                if (bitmap != null) {
                    views.setImageViewBitmap(R.id.widget_barcode_image, bitmap)
                }
            }

            val clickIntent = createOpenAppIntent(context, cardId)
            views.setOnClickPendingIntent(R.id.widget_barcode_image, clickIntent)
        } else {
            views.setViewVisibility(R.id.widget_barcode_image, View.GONE)
            views.setViewVisibility(R.id.widget_multi_card_container, View.GONE)
            views.setViewVisibility(R.id.widget_empty_text, View.VISIBLE)

            val clickIntent = createOpenAppIntent(context, null)
            views.setOnClickPendingIntent(R.id.widget_empty_text, clickIntent)
        }
    }

    private fun updateSingleCardMode(
        context: Context,
        views: RemoteViews,
        widgetData: android.content.SharedPreferences
    ) {
        views.setViewVisibility(R.id.widget_barcode_image, View.VISIBLE)
        views.setViewVisibility(R.id.widget_multi_card_container, View.GONE)
        views.setViewVisibility(R.id.widget_empty_text, View.GONE)

        val cardId = widgetData.getString("primary_card_id", "") ?: ""
        val barcodeValue = widgetData.getString("primary_barcode_value", "") ?: ""
        val barcodeFormat = widgetData.getString("primary_barcode_format", "CODE_128") ?: "CODE_128"
        
        if (barcodeValue.isNotEmpty()) {
            val bitmap = generateBarcodeBitmap(barcodeValue, barcodeFormat)
            if (bitmap != null) {
                views.setImageViewBitmap(R.id.widget_barcode_image, bitmap)
            }
        }

        val clickIntent = createOpenAppIntent(context, cardId)
        views.setOnClickPendingIntent(R.id.widget_barcode_image, clickIntent)
    }

    private fun updateMultipleCardsMode(
        context: Context,
        views: RemoteViews,
        widgetData: android.content.SharedPreferences
    ) {
        views.setViewVisibility(R.id.widget_barcode_image, View.GONE)
        views.setViewVisibility(R.id.widget_multi_card_container, View.VISIBLE)
        views.setViewVisibility(R.id.widget_empty_text, View.GONE)

        val cardCount = widgetData.getInt("card_count", 0)

        val buttonIds = intArrayOf(
            R.id.widget_card_btn_0,
            R.id.widget_card_btn_1,
            R.id.widget_card_btn_2,
            R.id.widget_card_btn_3,
            R.id.widget_card_btn_4
        )

        for (i in buttonIds.indices) {
            val storeName = widgetData.getString("card_${i}_store_name", "") ?: ""
            val cardId = widgetData.getString("card_${i}_card_id", "") ?: ""

            if (i < cardCount && storeName.isNotEmpty() && cardId.isNotEmpty()) {
                views.setViewVisibility(buttonIds[i], View.VISIBLE)
                views.setTextViewText(buttonIds[i], storeName)

                val clickIntent = createOpenAppIntent(context, cardId)
                views.setOnClickPendingIntent(buttonIds[i], clickIntent)
            } else {
                views.setViewVisibility(buttonIds[i], View.GONE)
            }
        }
    }


    /**
     * 生成條碼 Bitmap
     */
    private fun generateBarcodeBitmap(
        value: String,
        formatStr: String,
        width: Int = 600,
        height: Int = 200
    ): Bitmap? {
        return try {
            val format = when (formatStr.uppercase()) {
                "QR", "QRCODE", "QR_CODE" -> BarcodeFormat.QR_CODE
                "EAN13", "EAN_13" -> BarcodeFormat.EAN_13
                "EAN8", "EAN_8" -> BarcodeFormat.EAN_8
                "CODE128", "CODE_128" -> BarcodeFormat.CODE_128
                "CODE39", "CODE_39" -> BarcodeFormat.CODE_39
                "PDF417" -> BarcodeFormat.PDF_417
                "DATAMATRIX", "DATA_MATRIX" -> BarcodeFormat.DATA_MATRIX
                "AZTEC" -> BarcodeFormat.AZTEC
                "ITF", "ITF14", "ITF_14" -> BarcodeFormat.ITF
                "UPCA", "UPC_A" -> BarcodeFormat.UPC_A
                "UPCE", "UPC_E" -> BarcodeFormat.UPC_E
                "CODABAR" -> BarcodeFormat.CODABAR
                else -> BarcodeFormat.CODE_128
            }
            
            val isSquare = format in listOf(
                BarcodeFormat.QR_CODE, BarcodeFormat.DATA_MATRIX, BarcodeFormat.AZTEC
            )
            val w = if (isSquare) minOf(width, height) else width
            val h = if (isSquare) minOf(width, height) else height
            
            val hints = mapOf(EncodeHintType.MARGIN to 1)
            val bitMatrix = MultiFormatWriter().encode(value, format, w, h, hints)
            
            val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
            for (x in 0 until w) {
                for (y in 0 until h) {
                    bitmap.setPixel(x, y, if (bitMatrix[x, y]) Color.BLACK else Color.WHITE)
                }
            }
            bitmap
        } catch (e: Exception) {
            android.util.Log.e("SmartCardWidget", "條碼生成失敗: $e")
            null
        }
    }

    private fun createOpenAppIntent(context: Context, cardId: String?): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            if (cardId != null && cardId.isNotEmpty()) {
                data = Uri.parse("smartcard://card/$cardId")
            }
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        // 使用安全的 requestCode 避免 PendingIntent 衝突
        val requestCode = if (cardId != null && cardId.isNotEmpty()) cardId.hashCode() else 0

        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}
