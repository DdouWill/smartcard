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
        
        // 此服務主要維持背景存活，具體邏輯由 Flutter 端或 WidgetService 處理
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
