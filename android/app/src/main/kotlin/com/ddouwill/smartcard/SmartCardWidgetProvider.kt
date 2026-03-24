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
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * SmartCard 桌面小工具 Provider
 *
 * 負責讀取 Flutter 透過 home_widget 儲存的卡片資料，
 * 並根據顯示模式更新 Widget 的 RemoteViews。
 *
 * 多卡模式：
 * - 當定位匹配多張卡片時，顯示 ◀ ▶ 箭頭按鈕左右切換
 * - 頂部顯示店名（左）+ 頁碼（右），例如 "1/3"
 * - 底部顯示 ◀ | 條碼號碼 | ▶
 * - 邊界處理：第一張隱藏 ◀，最後一張隱藏 ▶
 * - 位置變更或資料更新時重設 index 為 0
 */
class SmartCardWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_WIDGET_CLICK = "com.ddouwill.smartcard.WIDGET_CLICK"
        const val ACTION_LOCATION_UPDATE = "com.ddouwill.smartcard.LOCATION_UPDATE"
        const val ACTION_NAV_PREV = "com.ddouwill.smartcard.NAV_PREV"
        const val ACTION_NAV_NEXT = "com.ddouwill.smartcard.NAV_NEXT"
        const val EXTRA_CARD_ID = "card_id"

        const val MODE_NO_MATCH = "noMatch"
        const val MODE_SINGLE_CARD = "singleCard"
        const val MODE_MULTIPLE_CARDS = "multipleCards"

        // 導航用 PendingIntent 的固定 requestCode，避免與卡片 click 衝突
        private const val RC_NAV_PREV = 9001
        private const val RC_NAV_NEXT = 9002

        // 多卡切換的當前索引（儲存在 home_widget SharedPreferences）
        private const val KEY_CURRENT_INDEX = "widget_current_index"

        /**
         * 強制更新所有已註冊的 SmartCard Widget
         * 由 LocationForegroundService 在位置變更時呼叫
         */
        fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = android.content.ComponentName(context, SmartCardWidgetProvider::class.java)
            val widgetIds = appWidgetManager.getAppWidgetIds(componentName)
            if (widgetIds.isNotEmpty()) {
                val intent = Intent(context, SmartCardWidgetProvider::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, widgetIds)
                }
                context.sendBroadcast(intent)
            }
        }
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

        when (intent.action) {
            ACTION_LOCATION_UPDATE -> {
                // 位置變更 → 重設卡片索引並更新 Widget
                resetCardIndex(context)
                updateAllWidgets(context)
            }
            ACTION_NAV_PREV -> {
                navigateCard(context, -1)
            }
            ACTION_NAV_NEXT -> {
                navigateCard(context, +1)
            }
            ACTION_WIDGET_CLICK -> {
                val cardId = intent.getStringExtra(EXTRA_CARD_ID)
                val deepLinkUri = if (!cardId.isNullOrEmpty()) {
                    Uri.parse("smartcard://card/$cardId")
                } else {
                    Uri.parse("smartcard://home")
                }
                // 使用 HomeWidget 標準啟動方式，讓 Flutter 端能收到 URI callback
                val launchPending = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    deepLinkUri
                )
                launchPending.send()
            }
        }
    }

    // ──────────────────────────────────────────
    // 多卡導航
    // ──────────────────────────────────────────

    /**
     * 切換到上一張/下一張卡片
     * @param direction -1 = 上一張, +1 = 下一張
     */
    private fun navigateCard(context: Context, direction: Int) {
        val widgetData = HomeWidgetPlugin.getData(context)
        val cardCount = widgetData.getInt("card_count", 0)
        if (cardCount <= 1) return

        val currentIndex = widgetData.getInt(KEY_CURRENT_INDEX, 0)
        val newIndex = (currentIndex + direction).coerceIn(0, cardCount - 1)

        // 邊界檢查：已在首張按 ◀ 或末張按 ▶ 時不動作
        if (newIndex != currentIndex) {
            widgetData.edit().putInt(KEY_CURRENT_INDEX, newIndex).apply()
            updateAllWidgets(context)
        }
    }

    /** 重設卡片導航索引為 0（位置變更或資料更新時呼叫） */
    private fun resetCardIndex(context: Context) {
        HomeWidgetPlugin.getData(context)
            .edit()
            .putInt(KEY_CURRENT_INDEX, 0)
            .apply()
    }

    // ──────────────────────────────────────────
    // Widget 更新
    // ──────────────────────────────────────────

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

        // App icon 點擊 → 開啟 App
        val openAppIntent = createOpenAppIntent(context, null)
        views.setOnClickPendingIntent(R.id.widget_app_icon, openAppIntent)

        when (displayMode) {
            MODE_SINGLE_CARD -> updateSingleCardMode(context, views, widgetData)
            MODE_MULTIPLE_CARDS -> updateMultipleCardsMode(context, views, widgetData)
            else -> updateNoMatchMode(context, views, widgetData)
        }

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    // ──────────────────────────────────────────
    // 顯示模式
    // ──────────────────────────────────────────

    /** 無匹配：顯示最近使用的卡片或空狀態 */
    private fun updateNoMatchMode(
        context: Context,
        views: RemoteViews,
        widgetData: android.content.SharedPreferences
    ) {
        val storeName = widgetData.getString("primary_store_name", "") ?: ""
        val cardId = widgetData.getString("primary_card_id", "") ?: ""

        if (storeName.isNotEmpty() && cardId.isNotEmpty()) {
            showCardViews(views, storeName)
            hideNavigation(views)

            val barcodeValue = widgetData.getString("primary_barcode_value", "") ?: ""
            val barcodeFormat = widgetData.getString("primary_barcode_format", "CODE_128") ?: "CODE_128"
            setBarcodeDisplay(views, barcodeValue, barcodeFormat, storeName)

            val clickIntent = createOpenAppIntent(context, cardId)
            views.setOnClickPendingIntent(R.id.widget_barcode_image, clickIntent)
        } else {
            // 空狀態
            views.setViewVisibility(R.id.widget_top_bar, View.GONE)
            views.setViewVisibility(R.id.widget_barcode_image, View.GONE)
            views.setViewVisibility(R.id.widget_bottom_bar, View.GONE)
            views.setViewVisibility(R.id.widget_empty_text, View.VISIBLE)

            val clickIntent = createOpenAppIntent(context, null)
            views.setOnClickPendingIntent(R.id.widget_empty_text, clickIntent)
        }
    }

    /** 單卡：直接顯示條碼，無導航箭頭 */
    private fun updateSingleCardMode(
        context: Context,
        views: RemoteViews,
        widgetData: android.content.SharedPreferences
    ) {
        val storeName = widgetData.getString("primary_store_name", "") ?: ""
        val cardId = widgetData.getString("primary_card_id", "") ?: ""
        val barcodeValue = widgetData.getString("primary_barcode_value", "") ?: ""
        val barcodeFormat = widgetData.getString("primary_barcode_format", "CODE_128") ?: "CODE_128"

        showCardViews(views, storeName)
        hideNavigation(views)
        setBarcodeDisplay(views, barcodeValue, barcodeFormat, storeName)

        val clickIntent = createOpenAppIntent(context, cardId)
        views.setOnClickPendingIntent(R.id.widget_barcode_image, clickIntent)
    }

    /**
     * 多卡模式：顯示當前索引的卡片條碼，附帶 ◀ ▶ 切換
     *
     * 佈局：
     *   頂部：[icon] 店名                1/N
     *   中間：     ████ 條碼 ████
     *   底部：  ◀  │  條碼號碼  │  ▶
     */
    private fun updateMultipleCardsMode(
        context: Context,
        views: RemoteViews,
        widgetData: android.content.SharedPreferences
    ) {
        val cardCount = widgetData.getInt("card_count", 0)
        if (cardCount == 0) {
            updateNoMatchMode(context, views, widgetData)
            return
        }

        // 取得當前索引，確保在有效範圍內
        val currentIndex = widgetData.getInt(KEY_CURRENT_INDEX, 0)
            .coerceIn(0, cardCount - 1)

        // 讀取當前卡片資料
        val storeName = widgetData.getString("card_${currentIndex}_store_name", "") ?: ""
        val cardId = widgetData.getString("card_${currentIndex}_card_id", "") ?: ""
        val barcodeValue = widgetData.getString("card_${currentIndex}_barcode_value", "") ?: ""
        val barcodeFormat = widgetData.getString("card_${currentIndex}_barcode_format", "CODE_128") ?: "CODE_128"

        showCardViews(views, storeName)

        // 頁碼指示器
        views.setViewVisibility(R.id.widget_page_indicator, View.VISIBLE)
        views.setTextViewText(R.id.widget_page_indicator, "${currentIndex + 1}/$cardCount")

        // 條碼顯示
        setBarcodeDisplay(views, barcodeValue, barcodeFormat, storeName)

        // ◀ 上一張：第一張時隱藏
        if (currentIndex > 0) {
            views.setViewVisibility(R.id.widget_prev_btn, View.VISIBLE)
            views.setOnClickPendingIntent(
                R.id.widget_prev_btn,
                createNavPendingIntent(context, ACTION_NAV_PREV, RC_NAV_PREV)
            )
        } else {
            views.setViewVisibility(R.id.widget_prev_btn, View.INVISIBLE)
        }

        // ▶ 下一張：最後一張時隱藏
        if (currentIndex < cardCount - 1) {
            views.setViewVisibility(R.id.widget_next_btn, View.VISIBLE)
            views.setOnClickPendingIntent(
                R.id.widget_next_btn,
                createNavPendingIntent(context, ACTION_NAV_NEXT, RC_NAV_NEXT)
            )
        } else {
            views.setViewVisibility(R.id.widget_next_btn, View.INVISIBLE)
        }

        // 條碼點擊 → 開啟 App 顯示該卡片
        val clickIntent = createOpenAppIntent(context, cardId)
        views.setOnClickPendingIntent(R.id.widget_barcode_image, clickIntent)
    }

    // ──────────────────────────────────────────
    // UI 輔助方法
    // ──────────────────────────────────────────

    /** 顯示卡片相關的 UI 元件，隱藏空狀態 */
    private fun showCardViews(views: RemoteViews, storeName: String) {
        views.setViewVisibility(R.id.widget_top_bar, View.VISIBLE)
        views.setViewVisibility(R.id.widget_barcode_image, View.VISIBLE)
        views.setViewVisibility(R.id.widget_bottom_bar, View.VISIBLE)
        views.setViewVisibility(R.id.widget_empty_text, View.GONE)
        views.setTextViewText(R.id.widget_store_name, storeName)
    }

    /** 隱藏多卡導航元件（單卡/無匹配時使用） */
    private fun hideNavigation(views: RemoteViews) {
        views.setViewVisibility(R.id.widget_page_indicator, View.GONE)
        views.setViewVisibility(R.id.widget_prev_btn, View.GONE)
        views.setViewVisibility(R.id.widget_next_btn, View.GONE)
    }

    /** 設定條碼圖片和底部店名文字 */
    private fun setBarcodeDisplay(views: RemoteViews, barcodeValue: String, barcodeFormat: String, storeName: String = "") {
        if (barcodeValue.isNotEmpty()) {
            val bitmap = generateBarcodeBitmap(barcodeValue, barcodeFormat)
            if (bitmap != null) {
                views.setImageViewBitmap(R.id.widget_barcode_image, bitmap)
            }
            // 底部不顯示文字，只保留箭頭
            views.setViewVisibility(R.id.widget_barcode_number, View.GONE)
        } else {
            views.setViewVisibility(R.id.widget_barcode_number, View.GONE)
        }
    }

    // ──────────────────────────────────────────
    // Intent 建立
    // ──────────────────────────────────────────

    /** 建立導航按鈕的 PendingIntent（廣播給自己處理） */
    private fun createNavPendingIntent(context: Context, action: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, SmartCardWidgetProvider::class.java).apply {
            this.action = action
        }
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    /** 建立開啟 App 的 PendingIntent（使用 HomeWidget 讓 Flutter 收到 URI） */
    private fun createOpenAppIntent(context: Context, cardId: String?): PendingIntent {
        val uri = if (!cardId.isNullOrEmpty()) {
            Uri.parse("smartcard://card/$cardId")
        } else {
            Uri.parse("smartcard://home")
        }
        return HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            uri
        )
    }

    // ──────────────────────────────────────────
    // 條碼生成
    // ──────────────────────────────────────────

    /**
     * 使用 ZXing 生成條碼 Bitmap
     * 支援多種格式：QR_CODE, EAN_13, CODE_128 等
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
}
