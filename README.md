# SmartCard 智慧會員卡錢包

[![License: AGPL-3.0](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/DdouWill/smartcard)](https://github.com/DdouWill/smartcard/releases)

純本地、完全離線的 Android App。整合所有會員卡條碼，透過 GPS + WiFi SSID 自動偵測店家，桌面小工具自動顯示對應條碼。

## 特色

- **完全離線** — 不需網路、不需帳號、不需伺服器
- **自動偵測** — WiFi SSID + GPS 自動辨識當前店家
- **桌面小工具** — StackView 上下滑動切換多卡，卡片圓角陰影邊框，循環滑動
- **最近門市提示** — 無符合時顯示 1km 內最近門市與距離
- **Geofence 背景更新** — AlarmManager + Geofence 自動刷新 Widget
- **加密儲存** — Hive 加密資料庫 + Android KeyStore
- **多種輸入** — 相機掃描 / 截圖辨識 / 手動輸入
- **38 品牌資料庫** — 內建台灣常見品牌 + 23,000+ 門市 GPS 座標
- **Firebase Analytics** — 匿名使用分析
- **更新檢查** — 自動偵測 GitHub Release 新版本
- **Debug Log** — `--dart-define=ENABLE_DEBUG_LOG=true` 輸出定位匹配細節

## 截圖

| 主畫面 | 儲存確認 |
|--------|----------|
| ![主畫面](docs/screenshots/home_with_card.png) | ![確認對話框](docs/screenshots/confirm_dialog.png) |

## 下載

前往 [Releases](https://github.com/DdouWill/smartcard/releases) 下載最新 APK。

## 桌面小工具

| 功能 | 說明 |
|------|------|
| 自動偵測 | GPS 比對門市座標，自動顯示對應條碼 |
| 多卡切換 | StackView 上下滑動循環切換，▲▼ 箭頭提示 |
| 卡片樣式 | 圓角 8dp + 淺灰描邊 + 微陰影 |
| 背景更新 | Geofence ENTER + AlarmManager 15 分鐘維護 |
| 無符合提示 | 顯示最近門市名稱與距離 |
| 點擊開啟 | 點擊條碼跳轉 App 對應卡片 |

## 技術棧

| 項目 | 技術 |
|------|------|
| 框架 | Flutter 3.x |
| 本地 DB | Hive（加密） |
| 桌面小工具 | home_widget + Kotlin RemoteViews（StackView） |
| 條碼生成 | barcode_widget（Flutter）/ ZXing（Widget） |
| 條碼掃描 | google_mlkit_barcode_scanning |
| GPS | geolocator |
| WiFi 偵測 | network_info_plus |
| 地圖 | flutter_map + OpenStreetMap |
| 背景排程 | AlarmManager + GeofencingClient |
| 分析 | Firebase Analytics |
| 權限管理 | permission_handler |

## 專案結構

```
lib/
├── main.dart                 # App 入口
├── app_controller.dart       # 全域狀態管理（Singleton + ChangeNotifier）
├── app_router.dart           # 路由定義
├── data/
│   └── store_locations.json  # 門市 GPS 座標資料庫（23,000+ 筆）
├── models/
│   ├── member_card.dart      # 會員卡資料模型 + GpsZone
│   └── app_settings.dart     # App 設定模型
├── services/
│   ├── database_service.dart       # Hive 加密資料庫
│   ├── barcode_service.dart        # 條碼掃描 / 辨識
│   ├── location_service.dart       # WiFi + GPS 偵測引擎
│   ├── store_location_service.dart # 門市座標查詢 + 最近門市搜尋
│   ├── widget_service.dart         # Android Widget 通訊
│   └── backup_service.dart         # 加密備份匯出/匯入
├── screens/
│   ├── home_screen.dart      # 主畫面（卡片列表 + 偵測狀態）
│   ├── add_card_screen.dart  # 新增卡片（含品牌 dropdown + 地圖選擇器）
│   ├── card_detail_screen.dart # 條碼全螢幕顯示
│   └── settings_screen.dart  # 設定頁面
└── widgets/
    ├── card_widget.dart           # 卡片列表項目
    ├── barcode_display_widget.dart # 條碼顯示元件
    ├── location_status_card.dart  # 偵測狀態卡片（含最近門市提示）
    ├── store_color_picker.dart    # 自訂顏色選擇器
    ├── ssid_keyword_editor.dart   # WiFi 關鍵字編輯器
    └── gps_zone_editor.dart       # GPS 圍欄區域編輯器

android/app/src/main/kotlin/com/ddouwill/smartcard/
├── SmartCardWidgetProvider.kt   # Widget Provider（模式切換、條碼生成）
├── SmartCardWidgetFactory.kt    # StackView RemoteViewsFactory
├── SmartCardWidgetService.kt    # RemoteViewsService
├── GeofenceManager.kt           # Geofence 註冊 / 管理
├── GeofenceBroadcastReceiver.kt # Geofence ENTER 事件處理
├── WidgetUpdateAlarmReceiver.kt # AlarmManager 定時維護
├── WidgetMatchHelper.kt         # 門市匹配邏輯（Kotlin 端）
└── MainActivity.kt              # Flutter Activity
```

## 開發

### 環境需求

- Flutter 3.4+
- Dart 3.4+
- Android SDK（compileSdk 36）
- google-services.json（Firebase，不含在 repo）

### 建置

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build apk --release
```

### Debug 建置（含定位 log）

```bash
flutter build apk --debug --dart-define=ENABLE_DEBUG_LOG=true
```

### 測試

```bash
flutter test
```

## 權限說明

| 權限 | 用途 |
|------|------|
| `CAMERA` | 相機掃描條碼 |
| `ACCESS_FINE_LOCATION` | GPS 偵測店家位置 |
| `ACCESS_BACKGROUND_LOCATION` | Geofence 背景偵測 |
| `ACCESS_WIFI_STATE` | WiFi SSID 偵測店家 |
| `RECEIVE_BOOT_COMPLETED` | 開機自動更新 Widget |
| `SCHEDULE_EXACT_ALARM` | AlarmManager Widget 維護排程 |
| `FOREGROUND_SERVICE_LOCATION` | 背景位置偵測 |
| `POST_NOTIFICATIONS` | 偵測到店家時通知 |

## License

This project is licensed under the [AGPL-3.0](LICENSE).
