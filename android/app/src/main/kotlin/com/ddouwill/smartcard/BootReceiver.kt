package com.ddouwill.smartcard

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * 開機啟動 Receiver
 *
 * 裝置重新開機或 App 更新後，由系統廣播觸發此 Receiver。
 * 確保背景服務與 Widget 排程更新在重開機後能自動啟動。
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED -> {
                Log.d(TAG, "裝置開機或 App 更新完成，準備啟動背景定位服務")
                startService(context)
            }
        }
    }

    private fun startService(context: Context) {
        val serviceIntent = Intent(context, LocationForegroundService::class.java)
        
        // Android 8.0+ 使用 startForegroundService
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
        
        Log.d(TAG, "LocationForegroundService 啟動指令已發送")

        // 開機後啟動 AlarmManager geofence 維護 & widget 保底更新排程
        WidgetUpdateAlarmReceiver.scheduleNextAlarm(context, 15)
        Log.d(TAG, "AlarmManager geofence 維護排程已啟動（15 分鐘）")

        // 開機後重新註冊 geofence
        GeofenceManager.reRegisterFromLastLocation(context)
        Log.d(TAG, "Geofence 重新註冊已觸發")
    }
}
