# SmartCard 智慧會員卡錢包

一款自動偵測附近門市、在桌面 Widget 即時顯示會員卡條碼的 Android App。

## 功能

### 核心
- 會員卡管理（新增、編輯、刪除）
- 支援多種條碼格式（CODE128、EAN13、QR Code 等）
- 條碼掃描快速新增

### 智慧定位
- GPS 自動偵測附近門市
- Geofence 智慧篩選（只監聽有卡品牌，3km 搜索範圍）
- 位置快取粗篩（bounding box 5km，降低運算）
- App 與 Widget 統一匹配邏輯

### 桌面 Widget
- StackView 多卡上下滑動切換
- 自動依門市距離排序
- 背景自動更新（Geofence + AlarmManager 15 分鐘）
- noMatch 智慧提示（區分無卡片 / 有卡無匹配）

### 門市資料
- 22,000+ 門市座標（38 品牌）
- 7-ELEVEN、全家：官方 API
- 其他品牌：OpenStreetMap

### 監控
- Firebase Analytics
- Firebase Crashlytics（debug build 自動停用）

## 技術

- **框架**：Flutter
- **語言**：Dart + Kotlin（Widget / Geofence）
- **最低版本**：Android 8.0 (API 26)
- **Build**：compileSdk 36, AGP 8.7.3, Gradle 8.9

## 授權

AGPL-3.0
