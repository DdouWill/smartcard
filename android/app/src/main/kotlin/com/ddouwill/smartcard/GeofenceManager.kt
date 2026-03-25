package com.ddouwill.smartcard

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.os.Bundle
import android.util.Log
import androidx.core.content.ContextCompat
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import com.google.firebase.analytics.FirebaseAnalytics
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
        private const val GEOFENCE_RADIUS = 200f // 公尺
        private const val MAX_GEOFENCES = 80
        private const val GEOFENCE_EXPIRATION = Geofence.NEVER_EXPIRE
        private const val REQUEST_CODE_GEOFENCE = 8002

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

            // 儲存目前位置供重新註冊使用
            saveLastLocation(context, latitude, longitude)

            val stores = loadNearbyStores(context, latitude, longitude)
            if (stores.isEmpty()) {
                Log.d(TAG, "附近無門市，跳過 geofence 註冊")
                return
            }

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
            return ContextCompat.checkSelfPermission(
                context, android.Manifest.permission.ACCESS_FINE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(
                context, android.Manifest.permission.ACCESS_COARSE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED
        }

        private fun getGeofencePendingIntent(context: Context): PendingIntent {
            val intent = Intent(context, GeofenceBroadcastReceiver::class.java)
            return PendingIntent.getBroadcast(
                context,
                REQUEST_CODE_GEOFENCE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
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
         * 從 store_locations.json 讀取門市，計算距離並回傳最近的 80 間
         */
        private fun loadNearbyStores(
            context: Context,
            latitude: Double,
            longitude: Double
        ): List<StoreInfo> {
            val stores = mutableListOf<StoreInfo>()

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

                        val distance = calculateDistance(latitude, longitude, lat, lng)
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
                return emptyList()
            }

            // 按距離排序，取最近 80 間
            return stores.sortedBy { it.distance }.take(MAX_GEOFENCES)
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
}
