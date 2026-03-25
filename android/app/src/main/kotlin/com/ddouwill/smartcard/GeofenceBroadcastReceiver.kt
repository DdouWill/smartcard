package com.ddouwill.smartcard

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.util.Log
import androidx.core.content.ContextCompat
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent
import com.google.android.gms.location.LocationServices
import com.google.firebase.analytics.FirebaseAnalytics

/**
 * Geofence 事件 Receiver
 *
 * 接收 GeofencingClient 的進入/離開事件：
 * - ENTER：更新 widget 條碼（顯示附近門市對應卡片）
 * - EXIT：若離開所有 geofence，重新計算附近門市並重新註冊
 */
class GeofenceBroadcastReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "GeofenceReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val geofencingEvent = GeofencingEvent.fromIntent(intent)
        if (geofencingEvent == null) {
            Log.e(TAG, "無法解析 GeofencingEvent")
            return
        }
        if (geofencingEvent.hasError()) {
            Log.e(TAG, "GeofencingEvent 錯誤碼: ${geofencingEvent.errorCode}")
            return
        }

        val transition = geofencingEvent.geofenceTransition

        when (transition) {
            Geofence.GEOFENCE_TRANSITION_ENTER -> {
                val ids = geofencingEvent.triggeringGeofences?.map { it.requestId } ?: emptyList()
                Log.d(TAG, "進入 geofence: $ids")

                // Firebase Analytics: geofence_enter
                try {
                    FirebaseAnalytics.getInstance(context).logEvent(
                        "geofence_enter",
                        Bundle().apply {
                            putString("store_ids", ids.joinToString(","))
                        }
                    )
                } catch (_: Exception) {}

                // 取得目前位置，由 WidgetMatchHelper 匹配並更新 widget
                if (ContextCompat.checkSelfPermission(context, android.Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
                    ContextCompat.checkSelfPermission(context, android.Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
                    try {
                        val fusedClient = LocationServices.getFusedLocationProviderClient(context)
                        fusedClient.lastLocation.addOnSuccessListener { location ->
                            if (location != null) {
                                WidgetMatchHelper.matchAndUpdateWidget(
                                    context, location.latitude, location.longitude
                                )
                            } else {
                                SmartCardWidgetProvider.updateAllWidgets(context)
                            }
                        }
                    } catch (e: SecurityException) {
                        Log.e(TAG, "缺少定位權限: $e")
                        SmartCardWidgetProvider.updateAllWidgets(context)
                    }
                } else {
                    SmartCardWidgetProvider.updateAllWidgets(context)
                }
            }

            Geofence.GEOFENCE_TRANSITION_EXIT -> {
                val ids = geofencingEvent.triggeringGeofences?.map { it.requestId } ?: emptyList()
                Log.d(TAG, "離開 geofence: $ids")

                // Firebase Analytics: geofence_exit
                try {
                    FirebaseAnalytics.getInstance(context).logEvent("geofence_exit", null)
                } catch (_: Exception) {}

                // 權限檢查
                if (ContextCompat.checkSelfPermission(context, android.Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED &&
                    ContextCompat.checkSelfPermission(context, android.Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
                    Log.w(TAG, "缺少定位權限，無法重新註冊 geofence")
                    return
                }

                // 取得目前位置，重新計算附近門市並重新註冊 geofence
                try {
                    val fusedClient = LocationServices.getFusedLocationProviderClient(context)
                    fusedClient.lastLocation.addOnSuccessListener { location ->
                        if (location != null) {
                            Log.d(TAG, "離開 geofence，重新註冊附近門市")
                            GeofenceManager.registerNearbyStores(
                                context,
                                location.latitude,
                                location.longitude
                            )
                            WidgetMatchHelper.matchAndUpdateWidget(
                                context, location.latitude, location.longitude
                            )
                        }
                    }
                } catch (e: SecurityException) {
                    Log.e(TAG, "缺少定位權限: $e")
                }
            }

            else -> {
                Log.w(TAG, "未處理的 geofence 轉換類型: $transition")
            }
        }
    }
}
