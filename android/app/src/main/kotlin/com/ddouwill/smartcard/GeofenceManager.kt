package com.ddouwill.smartcard

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.core.content.ContextCompat
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import com.google.firebase.analytics.FirebaseAnalytics
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject

/**
 * Geofence 管理器
 *
 * 負責門市 geofence 的註冊、移除、重新註冊。
 * 當使用者進入門市附近 200m 範圍時，自動觸發 widget 更新。
 */
class GeofenceManager {

    companion object {
        private const val TAG = "GeofenceManager"
        private const val PREFS_NAME = "geofence_prefs"
        private const val KEY_LAST_LAT = "geofence_last_lat"
        private const val KEY_LAST_LNG = "geofence_last_lng"
        private const val GEOFENCE_RADIUS = 200f // 公尺（觸發半徑）
        private const val GEOFENCE_SEARCH_RADIUS = 3000f // 公尺（搜索半徑 3km）
        private const val MAX_GEOFENCES = 80
        private const val GEOFENCE_EXPIRATION = Geofence.NEVER_EXPIRE
        private const val REQUEST_CODE_GEOFENCE = 8002
        private const val KEY_CARD_LIST = WidgetConstants.KEY_CARD_LIST
        private const val BOUNDING_BOX_LAT_DELTA = WidgetConstants.BOUNDING_BOX_LAT_DELTA
        private const val BOUNDING_BOX_LNG_DELTA = WidgetConstants.BOUNDING_BOX_LNG_DELTA

        /**
         * 註冊最近 80 間門市的 geofence
         * @param context Context
         * @param latitude 目前緯度
         * @param longitude 目前經度
         */
        fun registerNearbyStores(context: Context, latitude: Double, longitude: Double) {
            Log.d(TAG, "開始註冊附近門市 geofence (lat=$latitude, lng=$longitude)")

            // 權限檢查
            if (!hasLocationPermission(context)) {
                Log.w(TAG, "缺少定位權限，無法註冊 geofence")
                return
            }

            // Android 版本判斷 + 背景定位權限檢查
            Log.d(TAG, "SDK version: ${Build.VERSION.SDK_INT}, " +
                "ACCESS_FINE_LOCATION: ${hasPermission(context, android.Manifest.permission.ACCESS_FINE_LOCATION)}, " +
                "ACCESS_BACKGROUND_LOCATION: ${hasPermission(context, android.Manifest.permission.ACCESS_BACKGROUND_LOCATION)}")

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                if (!hasPermission(context, android.Manifest.permission.ACCESS_BACKGROUND_LOCATION)) {
                    Log.w(TAG, "Android 10+ 需要 ACCESS_BACKGROUND_LOCATION 權限才能正常觸發 geofence，" +
                        "目前缺少此權限，geofence 可能無法在背景觸發")
                }
            }

            // 儲存目前位置供重新註冊使用
            saveLastLocation(context, latitude, longitude)

            // 讀取使用者有卡品牌
            val userBrands = loadUserBrands(context)
            Log.d(TAG, "使用者有卡品牌: $userBrands")

            val filterResult = loadNearbyStores(context, latitude, longitude, userBrands)
            val stores = filterResult.stores
            if (stores.isEmpty()) {
                Log.d(TAG, "附近無門市，跳過 geofence 註冊")
                return
            }

            Log.d(TAG, "過濾前候選門市: ${filterResult.totalCandidates}, " +
                "過濾後候選門市: ${filterResult.filteredCandidates}, " +
                "最終註冊數: ${stores.size}")

            val geofenceList = stores.map { store ->
                Geofence.Builder()
                    .setRequestId(store.requestId)
                    .setCircularRegion(store.lat, store.lng, GEOFENCE_RADIUS)
                    .setExpirationDuration(GEOFENCE_EXPIRATION)
                    .setTransitionTypes(
                        Geofence.GEOFENCE_TRANSITION_ENTER or Geofence.GEOFENCE_TRANSITION_EXIT
                    )
                    .build()
            }

            val geofencingRequest = GeofencingRequest.Builder()
                .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
                .addGeofences(geofenceList)
                .build()

            val geofencingClient = LocationServices.getGeofencingClient(context)
            val pendingIntent = getGeofencePendingIntent(context)

            try {
                // 先移除舊的再註冊新的
                geofencingClient.removeGeofences(pendingIntent).addOnCompleteListener {
                    geofencingClient.addGeofences(geofencingRequest, pendingIntent)
                        .addOnSuccessListener {
                            Log.d(TAG, "成功註冊 ${geofenceList.size} 個 geofence")
                            // Firebase Analytics: geofence_registered
                            try {
                                FirebaseAnalytics.getInstance(context).logEvent(
                                    "geofence_registered",
                                    Bundle().apply {
                                        putInt("count", geofenceList.size)
                                        putString("filtered_brands", userBrands.joinToString(","))
                                        putInt("total_candidates", filterResult.totalCandidates)
                                        putInt("filtered_candidates", filterResult.filteredCandidates)
                                    }
                                )
                            } catch (_: Exception) {}
                        }
                        .addOnFailureListener { e ->
                            Log.e(TAG, "Geofence 註冊失敗: $e")
                        }
                }
            } catch (e: SecurityException) {
                Log.e(TAG, "缺少定位權限，無法註冊 geofence: $e")
            }
        }

        /**
         * 移除所有已註冊的 geofence
         */
        fun removeAllGeofences(context: Context) {
            val geofencingClient = LocationServices.getGeofencingClient(context)
            val pendingIntent = getGeofencePendingIntent(context)
            geofencingClient.removeGeofences(pendingIntent)
                .addOnSuccessListener {
                    Log.d(TAG, "已移除所有 geofence")
                }
                .addOnFailureListener { e ->
                    Log.e(TAG, "移除 geofence 失敗: $e")
                }
        }

        /**
         * 從 SharedPreferences 讀取上次位置，重新註冊 geofence
         * 用於開機後恢復
         */
        fun reRegisterFromLastLocation(context: Context) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val lat = prefs.getFloat(KEY_LAST_LAT, Float.MIN_VALUE)
            val lng = prefs.getFloat(KEY_LAST_LNG, Float.MIN_VALUE)

            if (lat == Float.MIN_VALUE || lng == Float.MIN_VALUE) {
                Log.d(TAG, "無上次位置紀錄，跳過重新註冊")
                return
            }

            Log.d(TAG, "從上次位置重新註冊 geofence (lat=$lat, lng=$lng)")
            registerNearbyStores(context, lat.toDouble(), lng.toDouble())
        }

        // ──────────────────────────────────────────
        // 內部方法
        // ──────────────────────────────────────────

        private fun hasLocationPermission(context: Context): Boolean {
            return hasPermission(context, android.Manifest.permission.ACCESS_FINE_LOCATION) ||
                hasPermission(context, android.Manifest.permission.ACCESS_COARSE_LOCATION)
        }

        private fun hasPermission(context: Context, permission: String): Boolean {
            return ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED
        }

        private fun getGeofencePendingIntent(context: Context): PendingIntent {
            val intent = Intent(context, GeofenceBroadcastReceiver::class.java)
            return PendingIntent.getBroadcast(
                context,
                REQUEST_CODE_GEOFENCE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            )
        }

        private fun saveLastLocation(context: Context, latitude: Double, longitude: Double) {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putFloat(KEY_LAST_LAT, latitude.toFloat())
                .putFloat(KEY_LAST_LNG, longitude.toFloat())
                .apply()
        }

        /**
         * 從 HomeWidget SharedPreferences 讀取 native_card_list，
         * 解析使用者有卡的品牌名稱（storeName 欄位）
         */
        private fun loadUserBrands(context: Context): Set<String> {
            return try {
                val widgetData = HomeWidgetPlugin.getData(context)
                val jsonStr = widgetData.getString(KEY_CARD_LIST, null)
                    ?: return emptySet()
                val array = JSONArray(jsonStr)
                (0 until array.length()).mapNotNull { i ->
                    val storeName = array.getJSONObject(i).optString("storeName", "")
                    storeName.ifEmpty { null }
                }.toSet()
            } catch (e: Exception) {
                Log.e(TAG, "讀取 native_card_list 失敗: $e")
                emptySet()
            }
        }

        /**
         * 從 store_locations.json 讀取門市，依品牌過濾 + 距離上限過濾，
         * 回傳最近的 80 間及過濾統計資訊。
         *
         * @param userBrands 使用者有卡的品牌名稱；為空時 fallback 到全品牌搜索
         */
        private fun loadNearbyStores(
            context: Context,
            latitude: Double,
            longitude: Double,
            userBrands: Set<String>
        ): FilterResult {
            val stores = mutableListOf<StoreInfo>()
            var totalCandidates = 0
            var totalLocations = 0

            // bounding box 粗篩邊界
            val minLat = latitude - BOUNDING_BOX_LAT_DELTA
            val maxLat = latitude + BOUNDING_BOX_LAT_DELTA
            val minLng = longitude - BOUNDING_BOX_LNG_DELTA
            val maxLng = longitude + BOUNDING_BOX_LNG_DELTA

            try {
                val jsonStr = context.assets
                    .open("flutter_assets/lib/data/store_locations.json")
                    .bufferedReader()
                    .use { it.readText() }

                val root = JSONObject(jsonStr)
                val storesObj = root.getJSONObject("stores")
                val brands = storesObj.keys()

                while (brands.hasNext()) {
                    val brand = brands.next()
                    val brandObj = storesObj.getJSONObject(brand)
                    val locations = brandObj.getJSONArray("locations")

                    for (i in 0 until locations.length()) {
                        val loc = locations.getJSONObject(i)
                        val lat = loc.optDouble("lat", Double.NaN)
                        val lng = loc.optDouble("lng", Double.NaN)
                        if (lat.isNaN() || lng.isNaN()) continue

                        totalLocations++

                        // bounding box 粗篩：跳過明顯超出範圍的門市
                        if (lat !in minLat..maxLat || lng !in minLng..maxLng) continue

                        val distance = calculateDistance(latitude, longitude, lat, lng)

                        // 距離上限過濾：超過搜索半徑的不加入候選
                        if (distance > GEOFENCE_SEARCH_RADIUS) continue

                        totalCandidates++

                        // 品牌過濾：只加入使用者有卡的品牌門市
                        // userBrands 為空時 fallback 到全品牌搜索
                        if (userBrands.isNotEmpty()) {
                            val matchesBrand = userBrands.any { storeName ->
                                storeName.contains(brand, ignoreCase = true)
                            }
                            if (!matchesBrand) continue
                        }

                        stores.add(
                            StoreInfo(
                                requestId = "${brand}_$i",
                                lat = lat,
                                lng = lng,
                                distance = distance
                            )
                        )
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "讀取 store_locations.json 失敗: $e")
                return FilterResult(emptyList(), 0, 0)
            }

            val filteredCandidates = stores.size

            Log.d(TAG, "粗篩: 全量門市=$totalLocations, 距離篩後=$totalCandidates, 品牌過濾後=$filteredCandidates")

            // 按距離排序，取最近 80 間
            return FilterResult(
                stores = stores.sortedBy { it.distance }.take(MAX_GEOFENCES),
                totalCandidates = totalCandidates,
                filteredCandidates = filteredCandidates
            )
        }

        /**
         * 使用 Location.distanceBetween 計算兩點距離（公尺）
         */
        private fun calculateDistance(
            lat1: Double, lng1: Double,
            lat2: Double, lng2: Double
        ): Float {
            val results = FloatArray(1)
            Location.distanceBetween(lat1, lng1, lat2, lng2, results)
            return results[0]
        }
    }

    private data class StoreInfo(
        val requestId: String,
        val lat: Double,
        val lng: Double,
        val distance: Float
    )

    private data class FilterResult(
        val stores: List<StoreInfo>,
        val totalCandidates: Int,
        val filteredCandidates: Int
    )
}
