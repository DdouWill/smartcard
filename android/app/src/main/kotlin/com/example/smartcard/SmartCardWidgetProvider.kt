package com.example.smartcard

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.app.PendingIntent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
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
        const val ACTION_WIDGET_CLICK = "com.example.smartcard.WIDGET_CLICK"
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
