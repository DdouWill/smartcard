# Test Results — SmartCard v1.1.0

> Branch: `develop/v1.1.0`
> 測試方式：Code Review（程式碼靜態分析）
> 日期：2026-03-26

---

## P0 — Geofence 智慧篩選

| Test ID | 結果 | 備註 |
|---------|------|------|
| P0-01 | PASS | `loadNearbyStores` 第 279-283 行：`userBrands.any { storeName -> storeName.contains(brand, ignoreCase = true) }` 正確過濾 |
| P0-02 | PASS | 所有品牌比對均使用 `ignoreCase = true` |
| P0-03 | PASS | 第 279 行 `userBrands.isNotEmpty()` 判斷；為空時跳過品牌過濾，回傳全品牌門市 |
| P0-04 | PASS | 第 273 行 `distance > GEOFENCE_SEARCH_RADIUS`（3000f）正確排除超距門市 |
| P0-05 | PASS | 使用 `>` 而非 `>=`，3000m 恰好不被加入，2999m 被加入，符合預期 |
| P0-06 | SKIP | Firebase Analytics 事件需實機驗證；程式碼第 114-123 行確認有 `filtered_brands`、`total_candidates`、`filtered_candidates` 參數 |
| P0-07 | PASS | `totalCandidates` = bbox + 距離過濾後計數（第 275 行）；`filteredCandidates` = 品牌過濾後（第 301 行）；`stores` = `.take(MAX_GEOFENCES)`（第 307 行） |
| P0-08 | PASS | `loadUserBrands` 第 208-215 行：從 HomeWidgetPlugin.getData 讀取 JSON，mapNotNull 提取 storeName |
| P0-09 | PASS | 第 214 行 `storeName.ifEmpty { null }` 配合 `mapNotNull`，空字串被過濾 |
| P0-10 | PASS | 第 216-218 行 catch 區塊回傳 `emptySet()` 並 `Log.e` |

## P1 — 位置快取粗篩

| Test ID | 結果 | 備註 |
|---------|------|------|
| P1-01 | PASS | `getFilteredStores` 第 192-196 行：距離 < 1000m 回傳快取 |
| P1-02 | PASS | 距離 ≥ 1000m 不進入 if 區塊，落入 MISS 路徑重新粗篩 |
| P1-03 | PASS | `cachedNearbyStores` 初始為 null，第 190 行 null check 直接跳過快取區塊 |
| P1-04 | PASS | 常數 `BOUNDING_BOX_LAT_DELTA=0.045`、`BOUNDING_BOX_LNG_DELTA=0.055`，約 ±5km |
| P1-05 | PASS | Kotlin `in minLat..maxLat` 包含兩端端點，邊界值被保留 |
| P1-06 | PASS | 第 232-235 行：僅加入 `filteredLocs.length() > 0` 的品牌，每品牌只含 bbox 內門市 |
| P1-07 | PASS | HIT：第 194 行 log 距離與品牌數；MISS：第 242 行 log 全量、粗篩後、品牌數 |
| P1-08 | PASS | GeofenceManager 第 39-40 行：`BOUNDING_BOX_LAT_DELTA=0.045`、`LNG_DELTA=0.055`，與 WidgetMatchHelper 一致 |
| P1-09 | PASS | WidgetMatchHelper 僅做 bbox 粗篩，GeofenceManager 做 bbox + 3km 距離篩選；前者為後者超集 |

## P2 — 版本判斷 + Widget UI

| Test ID | 結果 | 備註 |
|---------|------|------|
| P2-01 | PASS | GeofenceManager 第 58-60 行：log 輸出 SDK version、ACCESS_FINE_LOCATION、ACCESS_BACKGROUND_LOCATION |
| P2-02 | PASS | 已修正為 `Build.VERSION_CODES.Q`（Android 10+），涵蓋原 Android 12+ 範圍；缺少權限時輸出 Log.w |
| P2-03 | FAIL | 已修正檢查版本為 Q（API 29），Android 10-11 現在也會觸發背景權限警告。此為正確行為，原測試預期基於修正前的 S（API 31） |
| P2-04 | FAIL | `card_count` 在 noMatch 分支固定為 0，導致 `hasCards` 始終為 false。當使用者有卡但無匹配且 nearestCard 為 null 時，Widget 顯示「點擊新增會員卡」而非「附近無符合店家」。建議改為 `editor.putInt("card_count", cards.size)` |
| P2-05 | SKIP | UI 顯示需實機驗證；程式碼邏輯確認 `nearest_store_text` 非空時設定 `widget_nearest_text` VISIBLE |
| P2-06 | PASS | noMatch 且 `card_count=0` 時：SmartCardWidgetProvider 第 251-253 行顯示「點擊新增會員卡」+ `#90A4AE`，隱藏 `widget_nearest_text` |
| P2-07 | SKIP | UI 文字需實機驗證；程式碼確認第 316 行 `"${cardCount} 張匹配"` |

## Edge Cases

| Test ID | 結果 | 備註 |
|---------|------|------|
| E-01 | PASS | cards 為空 → noMatch + card_count=0；stores.isEmpty() → return 不註冊 geofence |
| E-02 | PASS | 單品牌過濾正確 → singleCard 模式 + card_count=1，無頁碼（GONE） |
| E-03 | SKIP | Widget 多卡堆疊 UI 需實機驗證；程式碼邏輯確認 StackView + 頁碼設定正確 |
| E-04 | PASS | `hasLocationPermission()` 檢查 FINE 或 COARSE，都缺少時 return，不 crash |
| E-05 | PASS | 同 E-04，Log.w 輸出「缺少定位權限」後 return |
| E-06 | PASS | `cachedNearbyStores` 為 object 上的 var，進程 kill 後重置為 null，首次為 MISS |
| E-07 | PASS | `saveLastLocation` 寫入 SharedPreferences，`reRegisterFromLastLocation` 讀取後呼叫 `registerNearbyStores` |
| E-08 | PASS | GeofenceManager 第 296-298 行 catch 回傳 `FilterResult(emptyList(), 0, 0)` |
| E-09 | PASS | `loadUserBrands` catch → `emptySet()`；`userBrands.isNotEmpty()` 為 false → 全品牌搜索 |
| E-10 | PASS | 所有座標讀取後均檢查 `isNaN()`，異常座標被 `continue` 跳過 |
| E-11 | PASS | 第 307 行 `.sortedBy { it.distance }.take(MAX_GEOFENCES)` 截斷至 80 間 |
| E-12 | PASS | `cacheLat`/`cacheLng` 初始為 `Double.NaN`，`!cacheLat.isNaN()` 為 false → 走 MISS 路徑 |

---

## 總結

| 類別 | PASS | FAIL | SKIP | 合計 |
|------|------|------|------|------|
| P0 | 9 | 0 | 1 | 10 |
| P1 | 9 | 0 | 0 | 9 |
| P2 | 3 | 2 | 2 | 7 |
| Edge | 10 | 0 | 1 | 11 |
| **合計** | **31** | **2** | **4** | **37** |

### FAIL 項目說明

- **P2-03**：測試預期已過時。背景權限版本檢查已從 `S`（API 31）修正為 `Q`（API 29），Android 10+ 均會觸發警告，為正確行為。建議更新測試預期。
- **P2-04**：`card_count` 在 noMatch 分支設為 0，使「有卡但附近無匹配門市」情境無法正確區分。建議將 `editor.putInt("card_count", 0)` 改為 `editor.putInt("card_count", cards.size)` 以保留使用者持卡狀態。
