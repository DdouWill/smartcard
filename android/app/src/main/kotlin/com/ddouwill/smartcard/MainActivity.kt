package com.ddouwill.smartcard

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * SmartCard 主 Activity
 *
 * 繼承 FlutterActivity，Flutter 框架處理所有 UI 渲染。
 * 實作 MethodChannel 以控制背景定位服務。
 */
class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.ddouwill.smartcard/location_service"
    private val LOCATION_CHANNEL = "com.ddouwill.smartcard/location"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startLocationService" -> {
                    startLocationService()
                    result.success(null)
                }
                "stopLocationService" -> {
                    stopLocationService()
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LOCATION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "triggerMatch" -> {
                    val lat = call.argument<Double>("latitude")
                    val lng = call.argument<Double>("longitude")
                    if (lat != null && lng != null) {
                        WidgetMatchHelper.matchAndUpdateWidget(this, lat, lng, "app")
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "latitude and longitude are required", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun startLocationService() {
        try {
            // 先檢查位置權限
            if (androidx.core.content.ContextCompat.checkSelfPermission(this,
                    android.Manifest.permission.ACCESS_FINE_LOCATION) != android.content.pm.PackageManager.PERMISSION_GRANTED &&
                androidx.core.content.ContextCompat.checkSelfPermission(this,
                    android.Manifest.permission.ACCESS_COARSE_LOCATION) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                android.util.Log.w("MainActivity", "位置權限未授權，跳過啟動背景服務")
                return
            }
            val intent = Intent(this, LocationForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "啟動背景定位服務失敗: $e")
        }
    }

    private fun stopLocationService() {
        val intent = Intent(this, LocationForegroundService::class.java)
        stopService(intent)
    }
}
