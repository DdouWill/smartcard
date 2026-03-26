# SmartCard — Phase 2 UI 設計規格書

## 設計原則
- **簡約、便利、省事**（用戶核心需求）
- Material Design 3（Flutter 預設）
- 深色/淺色模式自動跟隨系統
- 主色調：#2196F3（藍）

## 畫面清單

### 1. HomeScreen（主畫面）重設計
**現況：** 簡單 ListView placeholder
**目標：**
- 頂部「智慧偵測狀態卡片」（顯示當前 WiFi/GPS 偵測結果）
  - 偵測中：動態波紋動畫
  - 偵測到店家：店名 + 大型條碼縮圖
  - 無符合：顯示最近門市
- 卡片列表（GridView 2欄 或 ListView）
  - 每張卡片顯示：店家名稱、條碼格式標籤、自訂顏色背景
  - 長按進入編輯模式（Swipe-to-delete）
- 底部 FAB：「+ 新增卡片」
- AppBar 右側：重新整理按鈕、設定按鈕

### 2. CardDetailScreen（條碼顯示頁）新增
**觸發：** 點擊卡片列表項目 / Widget 點擊
**設計：**
- 全螢幕黑底白字
- 超大條碼顯示（佔螢幕 60% 高度）
- 自動調高螢幕亮度（WakeLock）
- 頂部：店家名稱 + 關閉按鈕
- 底部：條碼數值文字 + 格式標籤
- 支援雙擊縮放條碼

### 3. AddCardScreen（新增卡片）重設計
**現況：** 三個 Tab placeholder
**目標：**
- Tab 1 相機掃描：真實相機預覽框（用 image_picker 模擬，Phase 3 升級為 mobile_scanner）
- Tab 2 圖片辨識：圖片選取後預覽 + 識別結果高亮
- Tab 3 手動輸入：
  - 店家名稱欄位（帶自動補全常見店家）
  - 條碼輸入 + 即時預覽條碼圖形
  - 格式選擇（ChoiceChip，常用格式排前）
  - 顏色選擇器（預設 8 種顏色）
  - SSID 關鍵字設定（可選，進階）
  - GPS 圍欄設定（可選，進階，Phase 3 實作）
- 存檔前顯示條碼預覽確認對話框

### 4. SettingsScreen（設定頁）新增
**設計：**
- WiFi 偵測開關
- GPS 偵測開關
- Widget 更新間隔選擇
- 亮度模式選擇（系統/最亮/常亮）
- 資料管理（清除所有卡片、匯出加密備份）
- 關於 App

## 共用元件（lib/widgets/）
- `CardWidget`：卡片列表項目（可複用於主畫面和詳情）
- `BarcodeDisplayWidget`：條碼顯示（供詳情頁和 AddCard 預覽用）
- `LocationStatusCard`：定位狀態卡（主畫面頂部）
- `StoreColorPicker`：顏色選擇器（新增卡片用）
- `SsidKeywordEditor`：SSID 關鍵字編輯器

## 新增套件需求
- `wakelock_plus`：螢幕常亮（CardDetail 時）
- `flutter_colorpicker` 或自訂 8 色選擇器
- `shimmer`：載入動畫

## 路由設計（GoRouter 或 Navigator）
```
/ → HomeScreen
/card/:id → CardDetailScreen
/add-card → AddCardScreen
/settings → SettingsScreen
```

## 動畫規格
- 卡片列表 → 詳情頁：Hero 動畫（條碼圖片）
- 偵測狀態：波紋/脈衝動畫
- FAB：展開動畫
