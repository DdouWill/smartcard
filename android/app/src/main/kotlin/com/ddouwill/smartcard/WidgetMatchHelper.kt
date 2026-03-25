package com.ddouwill.smartcard

import android.content.Context
import android.location.Location
import android.util.Log
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject

/**
 * Widget 門市匹配輔助器
 *
 * 在 Kotlin 端獨立完成：GPS → 最近門市品牌 → 匹配使用者卡片 → 寫入 widget SharedPreferences
 * 解決 Flutter 未啟動時 widget 無法更新的問題。
 */
object WidgetMatchHelper {

    private const val TAG = "WidgetMatchHelper"

    // 門市匹配半徑（公尺）
    private const val MATCH_RADIUS = 500f

    // native_card_list key（Flutter 端寫入）
    private const val KEY_CARD_LIST = "native_card_list"

    /**
     * 根據目前位置匹配使用者卡片並更新 widget
     *
     * 1. 讀取 store_locations.json → 找半徑 500m 內的門市品牌
     * 2. 讀取 native_card_list → 解析使用者卡片
     * 3. 比對卡片的 storeName 是否包含附近門市品牌關鍵字
     * 4. 匹配結果寫入 widget SharedPreferences（與 Flutter WidgetService 格式一致）
     * 5. 呼叫 SmartCardWidgetProvider.updateAllWidgets()
     */
    fun matchAndUpdateWidget(context: Context, latitude: Double, longitude: Double) {
        Log.d(TAG, "開始匹配 (lat=$latitude, lng=$longitude)")

        // 1. 找附近 500m 內的門市品牌
        val nearbyBrands = findNearbyBrands(context, latitude, longitude)
        Log.d(TAG, "附近品牌: $nearbyBrands")

        // 2. 讀取使用者卡片清單
        val cards = loadCardList(context)
        Log.d(TAG, "使用者卡片數: ${cards.size}")

        // 3. 比對匹配
        val matchedCards = cards.filter { card ->
            val storeName = card.optString("storeName", "")
            nearbyBrands.any { brand ->
                storeName.contains(brand, ignoreCase = true)
            }
        }
        Log.d(TAG, "匹配卡片數: ${matchedCards.size}")

        // 找最近品牌（用於 analytics 和 nearest_store_text）
        val cardBrands = cards.map { it.optString("storeName", "") }.filter { it.isNotEmpty() }.toSet()
        val nearestBrand = findNearestBrand(context, latitude, longitude, cardBrands)

        // 4. 寫入 widget SharedPreferences
        val widgetData = HomeWidgetPlugin.getData(context)
        val editor = widgetData.edit()

        // 重設導航索引
        editor.putInt("widget_current_index", 0)

        when {
            matchedCards.isEmpty() -> {
                editor.putString("widget_mode", "noMatch")

                if (cards.isNotEmpty()) {
                    // 顯示最近使用的卡片（第一張）
                    val recentCard = cards.first()
                    saveCardToPrefs(editor, "primary", recentCard)
                    editor.putString("widget_title", "最近使用")
                } else {
                    editor.putString("widget_title", "點擊新增會員卡")
                    editor.putString("primary_store_name", "")
                    editor.putString("primary_barcode_value", "")
                    editor.putString("primary_card_id", "")
                }

                // 最近門市提示
                if (nearestBrand != null) {
                    editor.putString("nearest_store_text", nearestBrand.displayText)
                } else {
                    editor.putString("nearest_store_text", "")
                }
            }

            matchedCards.size == 1 -> {
                editor.putString("widget_mode", "singleCard")
                val card = matchedCards.first()
                editor.putString("widget_title", card.optString("storeName", ""))
                saveCardToPrefs(editor, "primary", card)
                editor.putString("nearest_store_text", "")
            }

            else -> {
                editor.putString("widget_mode", "multipleCards")
                editor.putString("widget_title", "附近 ${matchedCards.size} 家店")

                val displayCards = matchedCards.take(10)
                editor.putInt("card_count", displayCards.size)

                for (i in 0 until 10) {
                    if (i < displayCards.size) {
                        saveCardToPrefs(editor, "card_$i", displayCards[i])
                    } else {
                        clearCardPrefs(editor, "card_$i")
                    }
                }
                editor.putString("nearest_store_text", "")
            }
        }

        editor.apply()

        // 5. 通知 widget 更新
        SmartCardWidgetProvider.updateAllWidgets(context)

        // Firebase Analytics
        logMatchResult(context, matchedCards, nearestBrand)
    }

    // ──────────────────────────────────────────
    // 品牌匹配
    // ──────────────────────────────────────────

    /**
     * 從 store_locations.json 找出半徑 500m 內的所有品牌
     */
    private fun findNearbyBrands(
        context: Context,
        latitude: Double,
        longitude: Double
    ): Set<String> {
        val brands = mutableSetOf<String>()

        try {
            val jsonStr = context.assets
                .open("flutter_assets/lib/data/store_locations.json")
                .bufferedReader()
                .use { it.readText() }

            val root = JSONObject(jsonStr)
            val storesObj = root.getJSONObject("stores")
            val brandKeys = storesObj.keys()

            while (brandKeys.hasNext()) {
                val brand = brandKeys.next()
                val brandObj = storesObj.getJSONObject(brand)
                val locations = brandObj.getJSONArray("locations")

                for (i in 0 until locations.length()) {
                    val loc = locations.getJSONObject(i)
                    val lat = loc.optDouble("lat", Double.NaN)
                    val lng = loc.optDouble("lng", Double.NaN)
                    if (lat.isNaN() || lng.isNaN()) continue

                    val distance = calculateDistance(latitude, longitude, lat, lng)
                    if (distance <= MATCH_RADIUS) {
                        brands.add(brand)
                        break // 此品牌已有門市在範圍內，不需繼續檢查
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "讀取 store_locations.json 失敗: $e")
        }

        return brands
    }

    /**
     * 找出最近的品牌門市（用於空狀態提示）
     */
    private fun findNearestBrand(
        context: Context,
        latitude: Double,
        longitude: Double,
        cardBrands: Set<String>? = null
    ): NearestBrandInfo? {
        var nearestBrand: String? = null
        var nearestDistance = Float.MAX_VALUE

        try {
            val jsonStr = context.assets
                .open("flutter_assets/lib/data/store_locations.json")
                .bufferedReader()
                .use { it.readText() }

            val root = JSONObject(jsonStr)
            val storesObj = root.getJSONObject("stores")
            val brandKeys = storesObj.keys()

            while (brandKeys.hasNext()) {
                val brand = brandKeys.next()
                // 只搜尋使用者有卡片的品牌
                if (cardBrands != null && !cardBrands.any { cb ->
                    brand.contains(cb, ignoreCase = true) || cb.contains(brand, ignoreCase = true)
                }) continue
                val brandObj = storesObj.getJSONObject(brand)
                val locations = brandObj.getJSONArray("locations")

                for (i in 0 until locations.length()) {
                    val loc = locations.getJSONObject(i)
                    val lat = loc.optDouble("lat", Double.NaN)
                    val lng = loc.optDouble("lng", Double.NaN)
                    if (lat.isNaN() || lng.isNaN()) continue

                    val distance = calculateDistance(latitude, longitude, lat, lng)
                    if (distance < nearestDistance) {
                        nearestDistance = distance
                        nearestBrand = brand
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "尋找最近品牌失敗: $e")
        }

        return if (nearestBrand != null) {
            NearestBrandInfo(nearestBrand, nearestDistance)
        } else null
    }

    // ──────────────────────────────────────────
    // 卡片清單讀取
    // ──────────────────────────────────────────

    /**
     * 從 HomeWidget SharedPreferences 讀取 native_card_list
     */
    private fun loadCardList(context: Context): List<JSONObject> {
        val widgetData = HomeWidgetPlugin.getData(context)
        val jsonStr = widgetData.getString(KEY_CARD_LIST, null) ?: return emptyList()

        return try {
            val array = JSONArray(jsonStr)
            (0 until array.length()).map { array.getJSONObject(it) }
        } catch (e: Exception) {
            Log.e(TAG, "解析 native_card_list 失敗: $e")
            emptyList()
        }
    }

    // ──────────────────────────────────────────
    // SharedPreferences 寫入（與 Flutter WidgetService 格式一致）
    // ──────────────────────────────────────────

    private fun saveCardToPrefs(
        editor: android.content.SharedPreferences.Editor,
        prefix: String,
        card: JSONObject
    ) {
        editor.putString("${prefix}_store_name", card.optString("storeName", ""))
        editor.putString("${prefix}_barcode_value", card.optString("barcodeValue", ""))
        editor.putString("${prefix}_barcode_format", card.optString("barcodeFormat", "code128"))
        editor.putString("${prefix}_card_color", card.optString("cardColor", "#2196F3"))
        editor.putString("${prefix}_card_id", card.optString("id", ""))
    }

    private fun clearCardPrefs(
        editor: android.content.SharedPreferences.Editor,
        prefix: String
    ) {
        editor.putString("${prefix}_store_name", "")
        editor.putString("${prefix}_barcode_value", "")
        editor.putString("${prefix}_barcode_format", "")
        editor.putString("${prefix}_card_color", "")
        editor.putString("${prefix}_card_id", "")
    }

    // ──────────────────────────────────────────
    // 工具方法
    // ──────────────────────────────────────────

    private fun calculateDistance(
        lat1: Double, lng1: Double,
        lat2: Double, lng2: Double
    ): Float {
        val results = FloatArray(1)
        Location.distanceBetween(lat1, lng1, lat2, lng2, results)
        return results[0]
    }

    private fun logMatchResult(
        context: Context,
        matchedCards: List<JSONObject>,
        nearestBrand: NearestBrandInfo?
    ) {
        try {
            val analytics = com.google.firebase.analytics.FirebaseAnalytics.getInstance(context)
            val mode = when {
                matchedCards.isEmpty() -> "noMatch"
                matchedCards.size == 1 -> "singleCard"
                else -> "multipleCards"
            }
            val params = android.os.Bundle().apply {
                putString("mode", mode)
                putInt("matched_count", matchedCards.size)
                putString("nearest_brand", nearestBrand?.brand ?: "")
            }
            analytics.logEvent("widget_match_result", params)
        } catch (e: Exception) {
            Log.e(TAG, "Firebase Analytics 記錄失敗: $e")
        }
    }

    data class NearestBrandInfo(val brand: String, val distance: Float) {
        val displayText: String
            get() {
                val distStr = if (distance < 1000) {
                    "${distance.toInt()}m"
                } else {
                    String.format("%.1fkm", distance / 1000)
                }
                return "$brand（$distStr）"
            }
    }
}
