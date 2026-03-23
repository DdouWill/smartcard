# SmartCard 測試擴充規劃

## 現有覆蓋率摘要

| 層級 | 現有測試數 | 覆蓋功能 | 主要缺口 |
|------|-----------|----------|----------|
| E2E | 7 | 基本 CRUD、導航、設定頁 | 備份、顏色/關鍵字/GPS 編輯、排序、亮度 |
| Unit | 43 | 距離計算、SSID 匹配、GPS 邊界、資料格式 | DatabaseService、BackupService、BarcodeService 驗證 |
| Widget | 0 | — | 所有 Widget 皆無獨立測試 |

---

## 一、E2E 測試擴充方案

| # | 測試名稱 | 測試內容描述 | 優先級 | 複雜度 | 前置條件 |
|---|---------|-------------|--------|--------|---------|
| E1 | 卡片顏色選擇 | 新增卡片時選擇不同顏色 → 儲存 → Home 列表顯示對應顏色條 | P0 | S | 無卡片 |
| E2 | SSID 關鍵字編輯 | 新增卡片 → 輸入多個 SSID 關鍵字 → Chip 顯示正確 → 刪除其中一個 → 儲存後再編輯確認保留 | P0 | M | 無卡片 |
| E3 | GPS Zone 手動新增 | 新增卡片 → 開啟 GPS Zone 編輯器 → 手動輸入經緯度/半徑/標籤 → 儲存 → 編輯頁確認 zone 存在 | P0 | M | 無卡片 |
| E4 | 條碼格式切換與預覽 | 手動輸入 Tab → 切換不同條碼格式（EAN13, QR, Code128）→ 預覽 Widget 即時更新 | P0 | M | 無卡片 |
| E5 | 條碼驗證錯誤提示 | 輸入不合法 EAN13（長度錯/checksum 錯）→ 顯示錯誤訊息 → 無法儲存 | P0 | S | 無卡片 |
| E6 | 卡片拖拽排序 | 新增 3 張卡片 → 拖拽重新排序 → 返回確認順序保持 | P1 | L | 需先建立 3 張卡片 |
| E7 | 設定：螢幕亮度模式切換 | 進入設定 → 切換亮度模式（系統/最大/常亮）→ 返回後再進入確認保持 | P1 | S | 無 |
| E8 | 設定：WiFi/GPS 開關 | 切換 WiFi 偵測開關、GPS 開關 → 返回後再進入確認狀態保持 | P1 | S | 無 |
| E9 | 設定：Widget 更新間隔 | 切換更新間隔（1/5/10/30 分鐘）→ 返回後再進入確認保持 | P1 | S | 無 |
| E10 | 設定：顯示最近卡片開關 | 切換「無匹配時顯示最近卡片」開關 → 確認保持 | P1 | S | 無 |
| E11 | 備份匯出流程 | 設定 → 匯出 → 輸入密碼 → 確認密碼 → 產生檔案（驗證不報錯） | P1 | M | 至少 1 張卡片 |
| E12 | 清除所有卡片（設定頁） | 設定 → 清除全部 → 確認對話框 → 確認 → 回 Home 無卡片 | P1 | S | 至少 1 張卡片 |
| E13 | 卡片詳情頁縮放 | 進入詳情頁 → 雙指縮放（模擬 scale gesture）→ 條碼放大 | P2 | M | 至少 1 張卡片 |
| E14 | 卡片長按快捷選單 | 長按卡片 → 顯示選單（開啟/編輯/刪除）→ 點擊編輯 → 進入編輯頁 | P1 | M | 至少 1 張卡片 |
| E15 | 滑動刪除單張卡片 | 向左滑動卡片 → 確認對話框 → 確認刪除 → 列表更新 | P0 | S | 至少 2 張卡片 |
| E16 | 空狀態顯示 | App 啟動無卡片 → 顯示空狀態提示文字 | P2 | S | 無卡片 |
| E17 | 店名自動完成 | 手動輸入 Tab → 輸入「全」→ 出現自動完成建議（全聯等）→ 選擇建議 | P1 | M | 無卡片 |
| E18 | 編輯時保留所有欄位 | 新增含顏色+SSID+GPS 的卡片 → 編輯 → 確認所有欄位已填入 → 只改店名 → 儲存 → 其他欄位不變 | P0 | M | 無卡片 |

---

## 二、Widget 測試方案

| # | 測試名稱 | 測試內容描述 | 優先級 | 複雜度 | 前置條件 |
|---|---------|-------------|--------|--------|---------|
| W1 | CardWidget 基本渲染 | pumpWidget CardWidget → 顯示店名、條碼值、格式標籤、顏色條 | P0 | S | Mock MemberCard |
| W2 | CardWidget 長按選單 | 模擬長按 → 彈出 PopupMenu → 包含開啟/編輯/刪除選項 | P0 | S | Mock MemberCard + callbacks |
| W3 | CardWidget 滑動刪除 | 模擬 Dismissible swipe → 觸發 onDismissed callback | P1 | M | Mock MemberCard + callbacks |
| W4 | BarcodeDisplayWidget 各格式渲染 | 分別測試 EAN13, QR, Code128, EAN8, Code39 → 不報錯、正確渲染 | P0 | M | 各格式有效條碼值 |
| W5 | BarcodeDisplayWidget 無效條碼 | 傳入無效條碼 → 顯示 placeholder/錯誤狀態，不 crash | P0 | S | 無效條碼值 |
| W6 | LocationStatusCard 偵測中 | 傳入 isDetecting=true → 顯示 Shimmer 動畫 + 偵測文字 | P0 | S | 無 |
| W7 | LocationStatusCard 單一匹配 | 傳入 1 張匹配卡片 → 顯示漸層卡片 + 店名 + 條碼縮圖 | P0 | S | Mock MemberCard |
| W8 | LocationStatusCard 多重匹配 | 傳入 3 張匹配卡片 → 顯示「附近有 3 家店」+ 水平捲動列表 | P0 | M | 3 個 Mock MemberCard |
| W9 | LocationStatusCard 無匹配 | 傳入空列表 → 顯示「附近無符合店家」 | P1 | S | 無 |
| W10 | LocationStatusCard 最近卡片 | 無匹配 + showRecentOnEmpty=true → 顯示半透明最近卡片 | P1 | S | Mock MemberCard |
| W11 | SsidKeywordEditor 新增/刪除 | 輸入關鍵字 → 按新增 → Chip 出現 → 點 Chip X → 移除 | P0 | S | 無 |
| W12 | SsidKeywordEditor 重複偵測 | 輸入已存在的關鍵字 → 不新增/顯示提示 | P1 | S | 預設有一個關鍵字 |
| W13 | GpsZoneEditor 新增 Zone | 點新增 → 填入經緯度/半徑/標籤 → 確認 → 列表新增一筆 | P0 | M | 無 |
| W14 | GpsZoneEditor 驗證 | 輸入超出範圍的經緯度（lat > 90）→ 顯示驗證錯誤 | P1 | S | 無 |
| W15 | GpsZoneEditor 刪除 Zone | 列表中有 2 個 zone → 刪除其中一個 → 列表剩 1 個 | P1 | S | 預設 2 個 zone |
| W16 | StoreColorPicker 選擇 | 點擊不同顏色按鈕 → 選中標記移動 → onColorChanged callback 觸發正確色碼 | P0 | S | 無 |
| W17 | HomeScreen 空狀態 | pumpWidget HomeScreen（無卡片）→ 顯示空提示 + FAB | P1 | M | Mock 空 DB |
| W18 | HomeScreen 有卡片列表 | pumpWidget HomeScreen（3 張卡片）→ 列表顯示 3 項 | P1 | M | Mock DB 含 3 張卡 |
| W19 | SettingsScreen 所有開關 | pumpWidget SettingsScreen → 所有 Switch/Radio 可切換且觸發回調 | P1 | M | Mock AppSettings |
| W20 | AddCardScreen Tab 切換 | pumpWidget → 切換 3 個 Tab → 各 Tab 內容正確顯示 | P1 | M | 無 |
| W21 | CardDetailScreen 基本渲染 | pumpWidget → 黑色背景 + 大條碼 + 店名 + 編輯按鈕 | P1 | S | Mock MemberCard |

---

## 三、Unit 測試擴充方案

| # | 測試名稱 | 測試內容描述 | 優先級 | 複雜度 | 前置條件 |
|---|---------|-------------|--------|--------|---------|
| U1 | BarcodeService EAN13 驗證 | 合法/不合法 EAN13 → validateBarcode 返回 null/錯誤訊息 | P0 | S | 無 |
| U2 | BarcodeService EAN8 驗證 | 合法/不合法 EAN8（長度 8 vs 其他）| P0 | S | 無 |
| U3 | BarcodeService UPC-A 驗證 | 合法/不合法 UPC-A（長度 12 vs 其他）| P0 | S | 無 |
| U4 | BarcodeService 格式轉換 | 所有 12 種 BarcodeFormatType ↔ barcode_widget 字串互轉 | P0 | S | 無 |
| U5 | BarcodeService scanFromImage | Mock 圖片 → 辨識成功/失敗/多條碼優先選擇 | P1 | M | Mock image bytes |
| U6 | BackupService 加密→解密往返 | 建立卡片 JSON → encrypt → decrypt → 資料一致 | P0 | M | 測試用卡片 JSON |
| U7 | BackupService 錯誤密碼 | 用密碼 A 加密 → 用密碼 B 解密 → 拋出 BackupException | P0 | S | 加密後的資料 |
| U8 | BackupService 合併匯入 | 已有 2 張卡 → 匯入含 1 重複 + 1 新 → imported=1, skipped=1 | P0 | M | Mock DB |
| U9 | BackupService 替換匯入 | 已有 2 張卡 → 替換匯入 3 張 → 總共 3 張 | P1 | M | Mock DB |
| U10 | BackupService 格式損壞 | 傳入損壞的 bytes → 拋出 BackupException | P1 | S | 隨機 bytes |
| U11 | DatabaseService CRUD | addCard → getCardById → updateCard → deleteCard → getAllCards | P0 | M | Mock Hive box |
| U12 | DatabaseService reorderCards | 3 張卡 → reorder → sortOrder 正確更新 | P1 | S | Mock Hive box |
| U13 | DatabaseService Settings | saveSettings → getSettings → 值一致 | P1 | S | Mock Hive box |
| U14 | WidgetService noMatch mode | 0 匹配 + 有最近卡片 → SharedPreferences 寫入 primary_* keys | P0 | M | Mock SharedPreferences |
| U15 | WidgetService singleCard mode | 1 匹配 → 寫入正確 key/value | P0 | S | Mock SharedPreferences |
| U16 | WidgetService multipleCards mode | 5 匹配 → 寫入 card_0 ~ card_4，超過 5 張截斷 | P0 | M | Mock SharedPreferences |
| U17 | WidgetService 空值防護 | 卡片有空店名/空條碼 → 不寫入 widget | P1 | S | Mock SharedPreferences |
| U18 | AppSettings 預設值 | 新建 AppSettings → 所有欄位有合理預設值 | P1 | S | 無 |
| U19 | MemberCard copyWith | 修改單一欄位 → 其他欄位不變、updatedAt 更新 | P1 | S | 無 |
| U20 | GpsZone 序列化往返 | toJson → fromJson → 欄位完全一致 | P1 | S | 無 |
| U21 | LocationService 多來源匹配合併 | WiFi 匹配卡 A、GPS 匹配卡 B → 返回 [A, B] 去重 | P1 | M | Mock WiFi + GPS |
| U22 | LocationService 30 秒 debounce | 連續呼叫 2 次 → 第二次返回快取結果 | P2 | M | Mock timer |
| U23 | AppController 初始化流程 | initialize() → cards/settings 從 DB 載入 → 背景計時啟動 | P1 | L | Mock 全部 Service |
| U24 | AppController 卡片增刪 | addCard/deleteCard → notifyListeners → widget 更新 | P1 | M | Mock 全部 Service |
| U25 | AppRouter 路由解析 | 所有 named route → 返回正確 Widget type | P2 | S | 無 |

---

## 四、優先級總覽

### P0（必做）— 18 項
- E2E: 5 項（E1, E2, E3, E4, E5, E15, E18）
- Widget: 8 項（W1, W2, W4, W5, W6, W7, W8, W11, W13, W16）
- Unit: 8 項（U1, U2, U3, U4, U6, U7, U8, U11, U14, U15, U16）

### P1（建議）— 28 項
### P2（Nice-to-have）— 5 項

---

## 五、模擬器環境限制對策

| 限制 | E2E 對策 | Widget/Unit 對策 |
|------|---------|-----------------|
| 無真實 GPS | 不測 GPS 偵測流程，只測 GPS Zone 手動輸入 UI | Mock Geolocator 回傳假座標 |
| 無真實相機 | 跳過相機掃描 Tab，只測手動輸入 | Mock MobileScanner |
| 無真實 WiFi | 不測 WiFi 偵測，只測 SSID 關鍵字編輯 UI | Mock NetworkInfo 回傳假 SSID |
| 無 Home Widget | 不測 Widget 顯示，只測資料寫入邏輯 | Mock HomeWidget plugin |
| 無檔案分享 | 備份測到密碼對話框為止，不測分享 | Mock Share plugin |

## 六、建議執行順序

1. **先做 Widget 測試 P0**（8 項，獨立性高，不需模擬器）
2. **再做 Unit 測試 P0**（8 項，需要 mock 設置但可平行開發）
3. **最後做 E2E 測試 P0**（5 項，依賴模擬器，執行較慢）
4. P1 依各類型交叉進行
