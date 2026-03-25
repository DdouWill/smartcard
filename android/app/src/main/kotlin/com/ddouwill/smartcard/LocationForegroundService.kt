package com.ddouwill.smartcard

import android.app.*
import android.content.Context
import android.content.Intent
import android.location.Location
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.*

/**
 * 背景定位前台服務
 *
 * 實作持續定位偵測，確保裝置在背景時仍能根據位置更新 Widget。
 * 遵循 Android 12+ 規範：正確處理 Foreground Service Type 與持續通知。
 *
 * 與 Geofence 整合：
 * - 每次位置更新時檢查移動距離
 * - 移動 > 200m 時重新註冊附近門市 geofence
 * - 重設 AlarmManager 為 15 分鐘維護間隔
 */
class LocationForegroundService : Service() {

    companion object {
        private const val TAG = "LocationFgService"
        private const val NOTIFICATION_ID = 101
        private const val CHANNEL_ID = "location_service_channel"

        // 定位間隔（毫秒）
        // 為了平衡電池與即時性，使用 5 分鐘間隔，最快 1 分鐘
        private const val UPDATE_INTERVAL = 300000L // 5 分鐘
        private const val FASTEST_INTERVAL = 60000L // 1 分鐘

        // Geofence 重新註冊閾值（公尺）
        private const val GEOFENCE_RE_REGISTER_THRESHOLD = 200f

        private const val PREFS_NAME = "location_service_prefs"
        private const val KEY_LAST_LAT = "service_last_lat"
        private const val KEY_LAST_LNG = "service_last_lng"
    }

    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var locationCallback: LocationCallback

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "背景定位服務已建立")

        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)

        locationCallback = object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                locationResult.lastLocation?.let { location ->
                    onLocationChanged(location)
                }
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "背景定位服務啟動")

        // 先檢查位置權限，未授權則不啟動 foreground service
        if (androidx.core.content.ContextCompat.checkSelfPermission(this,
                android.Manifest.permission.ACCESS_FINE_LOCATION) != android.content.pm.PackageManager.PERMISSION_GRANTED &&
            androidx.core.content.ContextCompat.checkSelfPermission(this,
                android.Manifest.permission.ACCESS_COARSE_LOCATION) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
            Log.w(TAG, "位置權限未授權，停止服務")
            stopSelf()
            return START_NOT_STICKY
        }

        createNotificationChannel()
        val notification = createNotification()

        // Android 10+ 必須指定 foregroundServiceType
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(NOTIFICATION_ID, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "無法啟動前台服務: $e")
            stopSelf()
            return START_NOT_STICKY
        }

        startLocationUpdates()

        return START_STICKY
    }

    private fun startLocationUpdates() {
        // 使用新版 LocationRequest.Builder (Android 12+ 推薦)
        val locationRequest = LocationRequest.Builder(Priority.PRIORITY_BALANCED_POWER_ACCURACY, UPDATE_INTERVAL)
            .setMinUpdateIntervalMillis(FASTEST_INTERVAL)
            .build()

        try {
            fusedLocationClient.requestLocationUpdates(
                locationRequest,
                locationCallback,
                null
            )
        } catch (unlikely: SecurityException) {
            Log.e(TAG, "缺少定位權限，無法啟動更新：$unlikely")
        }
    }

    private fun onLocationChanged(location: Location) {
        Log.d(TAG, "位置已更新: ${location.latitude}, ${location.longitude}")

        // 發送廣播給 Flutter (如果 App 在前台或 Engine 存活)
        val intent = Intent("com.ddouwill.smartcard.LOCATION_UPDATE")
        intent.putExtra("latitude", location.latitude)
        intent.putExtra("longitude", location.longitude)
        sendBroadcast(intent)

        // 檢查是否需要重新註冊 geofence
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val lastLat = prefs.getFloat(KEY_LAST_LAT, Float.MIN_VALUE)
        val lastLng = prefs.getFloat(KEY_LAST_LNG, Float.MIN_VALUE)
        val hasLastLocation = lastLat != Float.MIN_VALUE && lastLng != Float.MIN_VALUE

        if (hasLastLocation) {
            val lastLocation = Location("saved").apply {
                latitude = lastLat.toDouble()
                longitude = lastLng.toDouble()
            }
            val distance = location.distanceTo(lastLocation)

            if (distance > GEOFENCE_RE_REGISTER_THRESHOLD) {
                Log.d(TAG, "移動 ${distance}m > ${GEOFENCE_RE_REGISTER_THRESHOLD}m，重新註冊 geofence")
                saveLocation(prefs, location)
                GeofenceManager.registerNearbyStores(this, location.latitude, location.longitude)
            }
        } else {
            // 首次位置：儲存並註冊 geofence
            Log.d(TAG, "首次位置，初始化 geofence")
            saveLocation(prefs, location)
            GeofenceManager.registerNearbyStores(this, location.latitude, location.longitude)
        }

        // 直接觸發 Widget 重繪，讓桌面小工具讀取最新 SharedPreferences 資料
        SmartCardWidgetProvider.updateAllWidgets(this)

        // 重設 AlarmManager 為 15 分鐘維護間隔
        WidgetUpdateAlarmReceiver.scheduleNextAlarm(this, 15)
    }

    private fun saveLocation(prefs: android.content.SharedPreferences, location: Location) {
        prefs.edit()
            .putFloat(KEY_LAST_LAT, location.latitude.toFloat())
            .putFloat(KEY_LAST_LNG, location.longitude.toFloat())
            .apply()
    }

    private fun createNotification(): Notification {
        val pendingIntent: PendingIntent = Intent(this, MainActivity::class.java).let { notificationIntent ->
            PendingIntent.getActivity(
                this, 0, notificationIntent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("SmartCard 正在守護您的會員卡")
            .setContentText("自動根據目前位置切換最適合的條碼")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentIntent(pendingIntent)
            .setOngoing(true) // 設為持續通知
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "背景定位服務通知",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "用於在背景偵測附近店家以更新會員卡小工具"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        fusedLocationClient.removeLocationUpdates(locationCallback)
        Log.d(TAG, "背景定位服務已停止")
    }
}
