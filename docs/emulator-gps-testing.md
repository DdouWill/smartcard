# 模擬器 GPS 測試指南

## 問題

Android 模擬器上 `adb emu geo fix` 設定的座標不會自動更新到 FusedLocationProviderClient 的 `lastLocation`。App 使用 Flutter geolocator（底層走 fused location）在模擬器上可能拿不到座標。

## 原因

Google Play Services 的 FusedLocationProviderClient 有「冷啟動」行為：
- `geo fix` 更新的是模擬器 GPS 硬體層的座標
- 如果沒有 client 正在請求位置，fused provider 不會主動去讀 GPS 硬體
- `lastLocation` 保持 null，直到有人觸發一次定位請求

## 正確的測試流程

### 1. 設定座標
```bash
adb -s emulator-5554 emu geo fix <longitude> <latitude>
```
注意：geo fix 的參數順序是**經度在前、緯度在後**。

範例（台北 101 附近）：
```bash
adb -s emulator-5554 emu geo fix 121.5654 25.033
```

### 2. 用 Google Maps 觸發定位
在模擬器上打開 **Google Maps**，等它定位完成（藍點出現在正確位置）。
這一步讓 fused provider 建立 `lastLocation` 快取。

### 3. 開啟 Smartcard App
回到桌面，打開 Smartcard。此時 Flutter geolocator 就能從 fused provider 取得座標。

### 4. 驗證
```bash
# 查看 fused location 是否正確
adb -s emulator-5554 shell dumpsys location | findstr "last location"

# 查看 Flutter log
adb -s emulator-5554 logcat -d -s flutter:D | findstr "Location"

# 查看 Kotlin WidgetMatchHelper log
adb -s emulator-5554 logcat -d -s WidgetMatchHelper:D
```

## 其他注意事項

- `adb shell cmd location providers set-test-provider-location fused` 可以設定 mock location，但需要先 `add-test-provider fused` + `set-test-provider-enabled fused true`，且不一定被 geolocator plugin 接收
- Extended Controls → Location → Set Location 效果等同 `geo fix`，同樣需要先觸發一次定位
- 模擬器權限：確認 app 有 `ACCESS_FINE_LOCATION` granted（`adb shell dumpsys package com.ddouwill.smartcard | findstr location`）

## 測試用座標

| 位置 | 緯度 | 經度 | 200m 內門市 |
|------|------|------|------------|
| 台北 101 附近 | 25.033 | 121.5654 | 7-ELEVEN、全家、星巴克 |
| 大雅（金雅店） | 24.227194 | 120.649944 | 200m 內無（最近 302m） |
