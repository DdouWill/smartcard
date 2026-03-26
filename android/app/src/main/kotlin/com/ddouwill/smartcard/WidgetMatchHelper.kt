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

    // 門市匹配半徑（公尺）── 需與 Flutter 端 (store_location_service.dart)
    // 及 GeofenceManager.kt (GEOFENCE_RADIUS) 保持同步
    private const val MATCH_RADIUS = 200f

    // noMatch 時顯示最近門市卡片的最大距離（公尺）
    private const val NEAREST_STORE_MAX_DISTANCE = 1000f

    // native_card_list key（Flutter 端寫入）
    private const val KEY_CARD_LIST = "native_card_list"

    /**
     * 根據目前位置匹配使用者卡片並更新 widget
     *
     * 1. 讀取 store_locations.json → 找半徑 200m 內的門市品牌
     * 2. 讀取 native_card_list → 解析使用者卡片
     * 3. 比對卡片的 storeName 是否包含附近門市品牌關鍵字
     * 4. 匹配結果寫入 widget SharedPreferences（與 Flutter WidgetService 格式一致）
     * 5. 呼叫 SmartCardWidgetProvider.updateAllWidgets()
     */
    fun matchAndUpdateWidget(context: Context, latitude: Double, longitude: Double) {
        Log.d(TAG, "開始匹配 (lat=$latitude, lng=$longitude)")

        // 讀取 store_locations.json（只讀一次，傳入各 helper）
        val storesObj = loadStoreLocations(context) ?: return

        // 1. 找附近 200m 內的門市品牌
        val nearbyBrands = findNearbyBrands(storesObj, latitude, longitude)
        Log.d(TAG, "附近品牌: $nearbyBrands")

        // 2. 讀取使用者卡片清單
        val cards = loadCardList(context)
        Log.d(TAG, "使用者卡片數: ${cards.size}")

        // 3. 比對匹配，依品牌最近門市距離排序（近→遠）
        val sortedMatchedCards = cards.filter { card ->
            val storeName = card.optString("storeName", "")
            nearbyBrands.any { brand ->
                storeName.contains(brand, ignoreCase = true)
            }
        }.let { matched ->
            Log.d(TAG, "匹配卡片數: ${matched.size}")
            if (matched.size > 1) {
                matched.sortedBy { card ->
                    val storeName = card.optString("storeName", "")
                    findMinDistanceForBrand(storesObj, latitude, longitude, storeName)
                }
            } else {
                matched
            }
        }

        // 找最近品牌（用於 analytics 和 nearest_store_text）
        val cardBrands = cards.map { it.optString("storeName", "") }.filter { it.isNotEmpty() }.toSet()
        val nearestBrand = findNearestBrand(storesObj, latitude, longitude, cardBrands)

        // 4. 寫入 widget SharedPreferences
        val widgetData = HomeWidgetPlugin.getData(context)
        val editor = widgetData.edit()

        // 重設導航索引
        editor.putInt("widget_current_index", 0)

        when {
            sortedMatchedCards.isEmpty() -> {
                editor.putString("widget_mode", "noMatch")

                // 找最近門市品牌對應的卡片（距離 <= 1000m）
                var nearestCard: JSONObject? = null
                if (nearestBrand != null && nearestBrand.distance <= NEAREST_STORE_MAX_DISTANCE) {
                    nearestCard = cards.firstOrNull { card ->
                        val storeName = card.optString("storeName", "")
                        storeName.contains(nearestBrand.brand, ignoreCase = true) ||
                            nearestBrand.brand.contains(storeName, ignoreCase = true)
                    }
                }

                if (nearestCard != null && nearestBrand != null) {
                    saveCardToPrefs(editor, "primary", nearestCard)
                    editor.putString("widget_title", "最近門市・${nearestBrand.distanceText}")
                } else if (cards.isEmpty()) {
                    editor.putString("widget_title", "點擊新增會員卡")
                    editor.putString("primary_store_name", "")
                    editor.putString("primary_barcode_value", "")
                    editor.putString("primary_card_id", "")
                } else {
                    editor.putString("widget_title", "附近無符合店家")
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

            sortedMatchedCards.size == 1 -> {
                editor.putString("widget_mode", "singleCard")
                val card = sortedMatchedCards.first()
                editor.putString("widget_title", card.optString("storeName", ""))
                saveCardToPrefs(editor, "primary", card)
                editor.putString("nearest_store_text", "")
            }

            else -> {
                editor.putString("widget_mode", "multipleCards")
                editor.putString("widget_title", "附近 ${sortedMatchedCards.size} 家店")

                val displayCards = sortedMatchedCards.take(10)
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
        logMatchResult(context, sortedMatchedCards, nearestBrand)
    }

    // ──────────────────────────────────────────
    // store_locations.json 讀取
    // ──────────────────────────────────────────

    private fun loadStoreLocations(context: Context): JSONObject? {
        return try {
            val jsonStr = context.assets
                .open("flutter_assets/lib/data/store_locations.json")
                .bufferedReader()
                .use { it.readText() }
            JSONObject(jsonStr).getJSONObject("stores")
        } catch (e: Exception) {
            Log.e(TAG, "讀取 store_locations.json 失敗: $e")
            null
        }
    }

    // ──────────────────────────────────────────
    // 品牌匹配
    // ──────────────────────────────────────────

    /**
     * 從已解析的 stores JSONObject 找出半徑 200m 內的所有品牌
     */
    private fun findNearbyBrands(
        storesObj: JSONObject,
        latitude: Double,
        longitude: Double
    ): Set<String> {
        val brands = mutableSetOf<String>()
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

        return brands
    }

    /**
     * 找出最近的品牌門市（用於空狀態提示）
     */
    private fun findNearestBrand(
        storesObj: JSONObject,
        latitude: Double,
        longitude: Double,
        cardBrands: Set<String>? = null
    ): NearestBrandInfo? {
        var nearestBrand: String? = null
        var nearestDistance = Float.MAX_VALUE
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

    /**
     * 取得某品牌（storeName）在 store_locations.json 中距離最近的門市距離（公尺）。
     * 若找不到對應品牌則回傳 Float.MAX_VALUE。
     */
    private fun findMinDistanceForBrand(
        storesObj: JSONObject,
        latitude: Double,
        longitude: Double,
        storeName: String
    ): Float {
        var minDistance = Float.MAX_VALUE
        val brandKeys = storesObj.keys()

        while (brandKeys.hasNext()) {
            val brand = brandKeys.next()
            if (!storeName.contains(brand, ignoreCase = true)) continue

            val brandObj = storesObj.getJSONObject(brand)
            val locations = brandObj.getJSONArray("locations")

            for (i in 0 until locations.length()) {
                val loc = locations.getJSONObject(i)
                val lat = loc.optDouble("lat", Double.NaN)
                val lng = loc.optDouble("lng", Double.NaN)
                if (lat.isNaN() || lng.isNaN()) continue

                val distance = calculateDistance(latitude, longitude, lat, lng)
                if (distance < minDistance) {
                    minDistance = distance
                }
            }
        }

        return minDistance
    }

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
        val distanceText: String
            get() = if (distance < 1000) {
                "${distance.toInt()}m"
            } else {
                String.format("%.1fkm", distance / 1000)
            }

        val displayText: String
            get() = "$brand（$distanceText）"
    }
}
