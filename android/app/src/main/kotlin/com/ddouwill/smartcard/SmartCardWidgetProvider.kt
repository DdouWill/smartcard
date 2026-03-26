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
 * 將 Dart barcodeFormat.name 字串轉換為 ZXing BarcodeFormat
 *
 * Dart 端送出 lowercase（qr, ean13, code128…），
 * 存入 SharedPrefs 後可能為任意大小寫，故統一 uppercase 比對。
 */
fun parseBarcodeFormat(formatStr: String): BarcodeFormat {
    return when (formatStr.uppercase()) {
        "QR", "QRCODE", "QR_CODE" -> BarcodeFormat.QR_CODE
        "EAN13", "EAN_13" -> BarcodeFormat.EAN_13
        "EAN8", "EAN_8" -> BarcodeFormat.EAN_8
        "CODE128", "CODE_128" -> BarcodeFormat.CODE_128
        "CODE39", "CODE_39" -> BarcodeFormat.CODE_39
        "PDF417", "PDF_417" -> BarcodeFormat.PDF_417
        "DATAMATRIX", "DATA_MATRIX" -> BarcodeFormat.DATA_MATRIX
        "AZTEC" -> BarcodeFormat.AZTEC
        "ITF", "ITF14", "ITF_14" -> BarcodeFormat.ITF
        "UPCA", "UPC_A" -> BarcodeFormat.UPC_A
        "UPCE", "UPC_E" -> BarcodeFormat.UPC_E
        "CODABAR" -> BarcodeFormat.CODABAR
        else -> BarcodeFormat.CODE_128
    }
}

/**
 * SmartCard 桌面小工具 Provider
 *
 * 負責讀取 Flutter 透過 home_widget 儲存的卡片資料，
 * 並根據顯示模式更新 Widget 的 RemoteViews。
 *
 * 多卡模式：
 * - 使用 StackView 上下滑動切換卡片
 * - 每張卡片由 SmartCardWidgetFactory 提供 RemoteViews
 */
class SmartCardWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_WIDGET_CLICK = "com.ddouwill.smartcard.WIDGET_CLICK"
        const val ACTION_LOCATION_UPDATE = "com.ddouwill.smartcard.LOCATION_UPDATE"
        const val ACTION_NEXT_CARD = "com.ddouwill.smartcard.NEXT_CARD"
        const val ACTION_PREV_CARD = "com.ddouwill.smartcard.PREV_CARD"
        const val EXTRA_CARD_ID = "card_id"

        const val MODE_NO_MATCH = "noMatch"
        const val MODE_SINGLE_CARD = "singleCard"
        const val MODE_MULTIPLE_CARDS = "multipleCards"

        private const val PREFS_WIDGET_UPDATE = "widget_update_prefs"
        private const val KEY_LAST_UPDATE_TIME = "last_widget_update_time"
        private const val DEBOUNCE_MILLIS = 30_000L // 30 秒 debounce

        /**
         * 更新所有已註冊的 SmartCard Widget（含 30 秒 debounce）
         *
         * Geofence ENTER 和 AlarmManager 可能同時觸發更新，
         * 透過 debounce 避免短時間內重複刷新。
         *
         * @param force 若為 true 則跳過 debounce（用於使用者主動操作）
         */
        fun updateAllWidgets(context: Context, force: Boolean = false) {
            if (!force) {
                val prefs = context.getSharedPreferences(PREFS_WIDGET_UPDATE, Context.MODE_PRIVATE)
                val lastUpdate = prefs.getLong(KEY_LAST_UPDATE_TIME, 0L)
                val now = System.currentTimeMillis()
                if (now - lastUpdate < DEBOUNCE_MILLIS) {
                    android.util.Log.d("SmartCardWidget", "距離上次更新 ${now - lastUpdate}ms < ${DEBOUNCE_MILLIS}ms，跳過")
                    return
                }
                prefs.edit().putLong(KEY_LAST_UPDATE_TIME, now).apply()
            }

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

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        // Widget 第一次被加到桌面時，啟動 alarm 排程（15 分鐘維護間隔）
        WidgetUpdateAlarmReceiver.scheduleNextAlarm(context, 15)
        // 啟動 geofence 初始註冊
        GeofenceManager.reRegisterFromLastLocation(context)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        // 所有 Widget 都被移除時，取消 alarm 排程與 geofence
        WidgetUpdateAlarmReceiver.cancelAlarm(context)
        GeofenceManager.removeAllGeofences(context)
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
                updateAllWidgets(context)
            }
            ACTION_NEXT_CARD, ACTION_PREV_CARD -> {
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val componentName = android.content.ComponentName(context, SmartCardWidgetProvider::class.java)
                val widgetIds = appWidgetManager.getAppWidgetIds(componentName)
                for (id in widgetIds) {
                    val views = RemoteViews(context.packageName, R.layout.smart_card_widget)
                    if (intent.action == ACTION_NEXT_CARD) {
                        views.showNext(R.id.widget_stack_view)
                    } else {
                        views.showPrevious(R.id.widget_stack_view)
                    }
                    appWidgetManager.partiallyUpdateAppWidget(id, views)
                }
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
            MODE_MULTIPLE_CARDS -> updateMultipleCardsMode(context, views, widgetData, appWidgetId)
            else -> updateNoMatchMode(context, views, widgetData)
        }

        appWidgetManager.updateAppWidget(appWidgetId, views)

        // 多卡模式時通知 StackView 資料已更新
        if (displayMode == MODE_MULTIPLE_CARDS) {
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_stack_view)
        }
    }

    // ──────────────────────────────────────────
    // 顯示模式
    // ──────────────────────────────────────────

    /** 無匹配：顯示最近門市或空狀態 */
    private fun updateNoMatchMode(
        context: Context,
        views: RemoteViews,
        widgetData: android.content.SharedPreferences
    ) {
        // 隱藏 StackView + 箭頭
        views.setViewVisibility(R.id.widget_stack_view, View.GONE)
        views.setViewVisibility(R.id.widget_arrow_up, View.GONE)
        views.setViewVisibility(R.id.widget_arrow_down, View.GONE)
        views.setViewVisibility(R.id.widget_stack_page, View.GONE)

        val storeName = widgetData.getString("primary_store_name", "") ?: ""
        val cardId = widgetData.getString("primary_card_id", "") ?: ""

        if (storeName.isNotEmpty() && cardId.isNotEmpty()) {
            showCardViews(views, storeName)

            val barcodeValue = widgetData.getString("primary_barcode_value", "") ?: ""
            val barcodeFormat = widgetData.getString("primary_barcode_format", "CODE_128") ?: "CODE_128"
            setBarcodeDisplay(views, barcodeValue, barcodeFormat)

            val clickIntent = createOpenAppIntent(context, cardId)
            views.setOnClickPendingIntent(R.id.widget_barcode_image, clickIntent)
        } else {
            // 空狀態
            views.setViewVisibility(R.id.widget_top_bar, View.GONE)
            views.setViewVisibility(R.id.widget_barcode_image, View.GONE)
            views.setViewVisibility(R.id.widget_empty_text, View.VISIBLE)

            // 最近門市提示
            val nearestText = widgetData.getString("nearest_store_text", "") ?: ""
            if (nearestText.isNotEmpty()) {
                views.setViewVisibility(R.id.widget_nearest_text, View.VISIBLE)
                views.setTextViewText(R.id.widget_nearest_text, "📍 最近：$nearestText")
            } else {
                views.setViewVisibility(R.id.widget_nearest_text, View.GONE)
            }

            val clickIntent = createOpenAppIntent(context, null)
            views.setOnClickPendingIntent(R.id.widget_empty_text, clickIntent)
        }
    }

    /** 單卡：直接顯示條碼，無 StackView */
    private fun updateSingleCardMode(
        context: Context,
        views: RemoteViews,
        widgetData: android.content.SharedPreferences
    ) {
        // 隱藏 StackView + 箭頭
        views.setViewVisibility(R.id.widget_stack_view, View.GONE)
        views.setViewVisibility(R.id.widget_arrow_up, View.GONE)
        views.setViewVisibility(R.id.widget_arrow_down, View.GONE)
        views.setViewVisibility(R.id.widget_stack_page, View.GONE)

        val storeName = widgetData.getString("primary_store_name", "") ?: ""
        val cardId = widgetData.getString("primary_card_id", "") ?: ""
        val barcodeValue = widgetData.getString("primary_barcode_value", "") ?: ""
        val barcodeFormat = widgetData.getString("primary_barcode_format", "CODE_128") ?: "CODE_128"

        showCardViews(views, storeName)
        views.setViewVisibility(R.id.widget_page_indicator, View.GONE)
        setBarcodeDisplay(views, barcodeValue, barcodeFormat)

        val clickIntent = createOpenAppIntent(context, cardId)
        views.setOnClickPendingIntent(R.id.widget_barcode_image, clickIntent)
    }

    /**
     * 多卡模式：使用 StackView 上下滑動切換卡片
     *
     * 佈局：
     *   StackView 佔滿整個 Widget，每一頁由 Factory 提供
     *   每頁包含 icon + 條碼 + 店名 + 頁碼指示
     */
    private fun updateMultipleCardsMode(
        context: Context,
        views: RemoteViews,
        widgetData: android.content.SharedPreferences,
        appWidgetId: Int
    ) {
        val cardCount = widgetData.getInt("card_count", 0)
        if (cardCount == 0) {
            updateNoMatchMode(context, views, widgetData)
            return
        }

        // 隱藏 singleCard 相關元素
        views.setViewVisibility(R.id.widget_top_bar, View.GONE)
        views.setViewVisibility(R.id.widget_barcode_image, View.GONE)
        views.setViewVisibility(R.id.widget_empty_text, View.GONE)
        views.setViewVisibility(R.id.widget_nearest_text, View.GONE)

        // 顯示 StackView + 箭頭 + 頁碼
        views.setViewVisibility(R.id.widget_stack_view, View.VISIBLE)
        views.setViewVisibility(R.id.widget_arrow_up, View.VISIBLE)
        views.setViewVisibility(R.id.widget_arrow_down, View.VISIBLE)
        views.setViewVisibility(R.id.widget_stack_page, View.VISIBLE)
        views.setTextViewText(R.id.widget_stack_page, "${cardCount} 張卡片")

        // 箭頭顏色（初始：第一張，▲ 亮可往上滑看下一張，▼ 暗）
        val enabledColor = android.graphics.Color.parseColor("#1565C0")
        val disabledColor = android.graphics.Color.parseColor("#CCCCCC")
        views.setTextColor(R.id.widget_arrow_up, enabledColor)
        views.setTextColor(R.id.widget_arrow_down, enabledColor)

        // 綁定 StackView 到 SmartCardWidgetService
        val serviceIntent = Intent(context, SmartCardWidgetService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            // 讓每個 widget instance 有獨立的 Intent（避免 Intent 共用）
            data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
        }
        views.setRemoteAdapter(R.id.widget_stack_view, serviceIntent)

        // 設定 PendingIntentTemplate 處理卡片點擊
        val clickIntent = Intent(context, SmartCardWidgetProvider::class.java).apply {
            action = ACTION_WIDGET_CLICK
        }
        val clickPending = PendingIntent.getBroadcast(
            context,
            0,
            clickIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )
        views.setPendingIntentTemplate(R.id.widget_stack_view, clickPending)

        // 設定空 View（StackView 沒資料時顯示）
        views.setEmptyView(R.id.widget_stack_view, R.id.widget_empty_text)
    }

    // ──────────────────────────────────────────
    // UI 輔助方法
    // ──────────────────────────────────────────

    /** 顯示卡片相關的 UI 元件，隱藏空狀態 */
    private fun showCardViews(views: RemoteViews, storeName: String) {
        views.setViewVisibility(R.id.widget_top_bar, View.VISIBLE)
        views.setViewVisibility(R.id.widget_barcode_image, View.VISIBLE)
        views.setViewVisibility(R.id.widget_empty_text, View.GONE)
        views.setViewVisibility(R.id.widget_nearest_text, View.GONE)
        views.setTextViewText(R.id.widget_store_name, storeName)
    }

    /** 設定條碼圖片 */
    private fun setBarcodeDisplay(views: RemoteViews, barcodeValue: String, barcodeFormat: String) {
        if (barcodeValue.isNotEmpty()) {
            val bitmap = generateBarcodeBitmap(barcodeValue, barcodeFormat)
            if (bitmap != null) {
                views.setImageViewBitmap(R.id.widget_barcode_image, bitmap)
            }
        }
    }

    // ──────────────────────────────────────────
    // Intent 建立
    // ──────────────────────────────────────────

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
            val format = parseBarcodeFormat(formatStr)

            val isSquare = format in listOf(
                BarcodeFormat.QR_CODE, BarcodeFormat.DATA_MATRIX, BarcodeFormat.AZTEC
            )
            val w = if (isSquare) minOf(width, height) else width
            val h = if (isSquare) minOf(width, height) else height

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
            android.util.Log.e("SmartCardWidget", "條碼生成失敗: $e")
            null
        }
    }
}
