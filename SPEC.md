# SmartCard — 智慧會員卡錢包 規格書

## 目標
一個純本地、完全離線的 Android App，整合所有會員卡條碼，
透過 GPS + WiFi SSID 自動偵測當前店家，桌面小工具自動顯示對應條碼。

## 核心設計原則
- 完全離線（不需要網路）
- 資料全部存本地（Hive 加密）
- 不需帳號、不需伺服器
- 簡約、便利、省事

## 開發分階段
### Phase 1（本次）：架構 + 核心邏輯
- Flutter 專案建立
- 資料模型定義
- 本地資料庫（Hive）
- 條碼輸入（相機掃描 + 截圖辨識 + 手動輸入）
- 條碼顯示（含全螢幕常亮模式）
- WiFi SSID 偵測邏輯
- GPS Geofencing 邏輯
- Android Widget 基礎架構

### Phase 2（下次）：UI 設計
### Phase 3（最後）：結合 + Opus Review + Debug

## 技術棧
- 框架：Flutter 3.x
- 本地DB：Hive（加密）
- 桌面小工具：home_widget
- 條碼顯示：barcode_widget
- 條碼掃描：google_mlkit_barcode_scanning
- GPS：geolocator
- WiFi：network_info_plus
- Geofencing：geofencing_api

## 資料模型

### MemberCard
```dart
class MemberCard {
  String id;              // UUID
  String storeName;       // 店家名稱（例：全聯）
  String barcodeValue;    // 條碼號碼
  BarcodeFormat barcodeFormat; // EAN13 / QR / Code128...
  String? cardColor;      // 自訂顏色 hex
  String? iconPath;       // 自訂圖示路徑
  int sortOrder;          // 排序
  List<String> ssidKeywords;   // WiFi SSID 關鍵字
  List<GpsZone> gpsZones;      // GPS 範圍設定
  DateTime createdAt;
  DateTime updatedAt;
}
```

### GpsZone
```dart
class GpsZone {
  double latitude;
  double longitude;
  double radiusMeters;  // 預設 100 公尺
  String? label;        // 例：全聯 中港店
}
```

### AppSettings
```dart
class AppSettings {
  bool enableWifi;          // WiFi 偵測開關
  bool enableGps;           // GPS 偵測開關
  int updateIntervalMinutes; // Widget 更新間隔
  int screenBrightnessMode; // 顯示條碼時亮度
}
```

## 定位引擎邏輯
```
觸發：解鎖手機 / 每 5 分鐘背景
    ↓
Step 1：掃描附近 WiFi SSID
    ↓
    比對所有卡片的 ssidKeywords
    ↓ 有符合
    回傳符合的卡片清單

    ↓ 無符合，進行 GPS
Step 2：取得當前 GPS 座標
    ↓
    比對所有卡片的 GpsZone
    ↓ 有符合（在範圍內）
    回傳符合的卡片清單

    ↓ 無符合
Step 3：回傳空清單（Widget 顯示最近門市）
```

## Widget 行為
- 0 家符合 → 顯示最近門市的卡片
- 1 家符合 → 直接顯示條碼
- 2~5 家符合 → 顯示店家按鈕，點擊後顯示條碼
- 點擊條碼 → 開啟 App 全螢幕顯示 + 螢幕常亮

## 條碼輸入方式
1. 相機掃描實體卡（ML Kit）
2. 截圖/圖片辨識（ML Kit）
3. 手動輸入號碼 + 選擇格式
