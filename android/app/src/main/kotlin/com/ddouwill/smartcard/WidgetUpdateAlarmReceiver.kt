package com.ddouwill.smartcard

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.util.Log
import androidx.core.content.ContextCompat
import com.google.android.gms.location.LocationServices
import com.google.firebase.analytics.FirebaseAnalytics

/**
 * Geofence 維護 & Widget 保底更新 Receiver
 *
 * 透過 AlarmManager 每 15 分鐘喚醒一次，職責：
 * 1. 檢查 geofence 是否仍然存活（Google Play Services 可能清除）
 * 2. 若位置變化 > 200m，重新註冊附近門市 geofence
 * 3. 更新 widget 作為 fallback（主要更新由 Geofence ENTER 觸發）
 */
class WidgetUpdateAlarmReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "WidgetAlarmReceiver"
        const val ACTION = "com.ddouwill.smartcard.ALARM_WIDGET_UPDATE"

        private const val PREFS_NAME = "widget_alarm_prefs"
        private const val KEY_LAST_LAT = "last_lat"
        private const val KEY_LAST_LNG = "last_lng"

        // Geofence 重新註冊閾值（公尺）
        private const val GEOFENCE_RE_REGISTER_THRESHOLD = 200f

        // 統一間隔：15 分鐘（geofence 維護 + widget fallback 更新）
        private const val INTERVAL_GEOFENCE_MAINTENANCE = 15
        // 無法取得位置時的重試間隔
        private const val INTERVAL_FALLBACK = 5

        private const val REQUEST_CODE = 8001

        /**
         * 排程下一次 alarm
         * @param intervalMinutes 幾分鐘後觸發
         */
        fun scheduleNextAlarm(context: Context, intervalMinutes: Int) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, WidgetUpdateAlarmReceiver::class.java).apply {
                action = ACTION
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val triggerAtMillis = SystemClock.elapsedRealtime() + intervalMinutes * 60 * 1000L

            // Android 12+ 需要檢查 canScheduleExactAlarms()，否則降級為非精確 alarm
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (alarmManager.canScheduleExactAlarms()) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.ELAPSED_REALTIME_WAKEUP,
                        triggerAtMillis,
                        pendingIntent
                    )
                } else {
                    // 降級：使用非精確 alarm，避免 SecurityException
                    alarmManager.setAndAllowWhileIdle(
                        AlarmManager.ELAPSED_REALTIME_WAKEUP,
                        triggerAtMillis,
                        pendingIntent
                    )
                    Log.w(TAG, "無 SCHEDULE_EXACT_ALARM 權限，使用非精確 alarm")
                }
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    triggerAtMillis,
                    pendingIntent
                )
            } else {
                alarmManager.setExact(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    triggerAtMillis,
                    pendingIntent
                )
            }

            Log.d(TAG, "已排程下次 alarm: ${intervalMinutes} 分鐘後")
        }

        /**
         * 取消已排程的 alarm
         */
        fun cancelAlarm(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, WidgetUpdateAlarmReceiver::class.java).apply {
                action = ACTION
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pendingIntent)
            Log.d(TAG, "已取消 alarm 排程")
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION) return
        Log.d(TAG, "Alarm 觸發，開始 geofence 維護檢查")

        // 權限檢查
        if (!hasLocationPermission(context)) {
            Log.w(TAG, "缺少定位權限，跳過本次檢查")
            scheduleNextAlarm(context, INTERVAL_GEOFENCE_MAINTENANCE)
            return
        }

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val lastLat = prefs.getFloat(KEY_LAST_LAT, Float.MIN_VALUE)
        val lastLng = prefs.getFloat(KEY_LAST_LNG, Float.MIN_VALUE)

        try {
            val fusedClient = LocationServices.getFusedLocationProviderClient(context)
            fusedClient.lastLocation.addOnSuccessListener { location: Location? ->
                // Firebase Analytics: widget_alarm_triggered
                try {
                    FirebaseAnalytics.getInstance(context).logEvent(
                        "widget_alarm_triggered",
                        Bundle().apply {
                            putBoolean("has_location", location != null)
                            putInt("interval", INTERVAL_GEOFENCE_MAINTENANCE)
                        }
                    )
                } catch (_: Exception) {}

                if (location != null) {
                    handleLocationResult(context, prefs, location, lastLat, lastLng)
                } else {
                    Log.d(TAG, "無法取得位置，使用 fallback 間隔")
                    SmartCardWidgetProvider.updateAllWidgets(context)
                    scheduleNextAlarm(context, INTERVAL_FALLBACK)
                }
            }.addOnFailureListener { e ->
                Log.e(TAG, "取得位置失敗: $e")
                SmartCardWidgetProvider.updateAllWidgets(context)
                scheduleNextAlarm(context, INTERVAL_FALLBACK)
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "缺少定位權限: $e")
            scheduleNextAlarm(context, INTERVAL_GEOFENCE_MAINTENANCE)
        }
    }

    private fun handleLocationResult(
        context: Context,
        prefs: android.content.SharedPreferences,
        location: Location,
        lastLat: Float,
        lastLng: Float
    ) {
        val hasLastLocation = lastLat != Float.MIN_VALUE && lastLng != Float.MIN_VALUE

        if (hasLastLocation) {
            val lastLocation = Location("saved").apply {
                latitude = lastLat.toDouble()
                longitude = lastLng.toDouble()
            }
            val distance = location.distanceTo(lastLocation)
            Log.d(TAG, "與上次位置距離: ${distance}m")

            // 位置變化超過 200m：重新註冊 geofence
            if (distance > GEOFENCE_RE_REGISTER_THRESHOLD) {
                Log.d(TAG, "位置變化 ${distance}m > ${GEOFENCE_RE_REGISTER_THRESHOLD}m，重新註冊 geofence 並更新 widget")
                saveLocation(prefs, location)
                GeofenceManager.registerNearbyStores(
                    context,
                    location.latitude,
                    location.longitude
                )
            } else {
                // 位置未大幅變化：僅確保 geofence 存活（re-register 為冪等操作）
                Log.d(TAG, "位置穩定，維護性重新註冊 geofence")
                GeofenceManager.registerNearbyStores(
                    context,
                    location.latitude,
                    location.longitude
                )
            }
        } else {
            // 首次：儲存位置 + 註冊 geofence
            Log.d(TAG, "首次取得位置，初始化 geofence 與 widget")
            saveLocation(prefs, location)
            GeofenceManager.registerNearbyStores(context, location.latitude, location.longitude)
        }

        // 由 WidgetMatchHelper 執行匹配並更新 widget
        WidgetMatchHelper.matchAndUpdateWidget(context, location.latitude, location.longitude)

        // 統一排程下次：15 分鐘
        scheduleNextAlarm(context, INTERVAL_GEOFENCE_MAINTENANCE)
    }

    private fun saveLocation(prefs: android.content.SharedPreferences, location: Location) {
        prefs.edit()
            .putFloat(KEY_LAST_LAT, location.latitude.toFloat())
            .putFloat(KEY_LAST_LNG, location.longitude.toFloat())
            .apply()
    }

    private fun hasLocationPermission(context: Context): Boolean {
        return ContextCompat.checkSelfPermission(
            context, android.Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED ||
        ContextCompat.checkSelfPermission(
            context, android.Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
    }
}
