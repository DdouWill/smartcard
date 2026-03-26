# Test Plan — SmartCard v1.1.0

> PR #13 `develop/v1.1.0`
> 測試範圍：Geofence 智慧篩選、位置快取粗篩、版本判斷 + Widget UI 改善
> 日期：2026-03-26

---

## 測試項目總覽

| Test ID | 類別 | 測試項目 | 預期結果 | 優先級 |
|---------|------|---------|---------|--------|
| P0-01 | P0 | 品牌過濾正確性 — 使用者有卡品牌門市應被保留 | `loadNearbyStores` 回傳的門市清單僅包含 `userBrands` 中品牌的門市（`contains(brand, ignoreCase = true)` 比對） | P0 |
| P0-02 | P0 | 品牌過濾 — 大小寫不敏感 | storeName="全聯" 與 brand="全聯" 匹配；英文品牌 "Starbucks" 與 "starbucks" 匹配 | P0 |
| P0-03 | P0 | 空卡片 fallback — `userBrands` 為空時全品牌搜索 | 當 `native_card_list` 為空陣列或 key 不存在時，`userBrands` 為 `emptySet()`，不做品牌過濾，回傳所有 3km 內門市 | P0 |
| P0-04 | P0 | 搜索半徑 3km 限制 | 距離 > `GEOFENCE_SEARCH_RADIUS`（3000m）的門市不被加入候選清單 | P0 |
| P0-05 | P0 | 搜索半徑 — 邊界值 3000m | 距離恰好 = 3000m 的門市不被加入（`> GEOFENCE_SEARCH_RADIUS`）；2999m 的應被加入 | P0 |
| P0-06 | P0 | Firebase Analytics — `geofence_registered` 事件參數 | 事件包含 `filtered_brands`（逗號分隔品牌）、`total_candidates`、`filtered_candidates` 三個新參數 | P0 |
| P0-07 | P0 | `FilterResult` 統計正確性 | `totalCandidates` = bounding box + 距離上限過濾後數量；`filteredCandidates` = 再經品牌過濾後數量；`stores` = 取最近 80 間 | P0 |
| P0-08 | P0 | `loadUserBrands` 解析 `native_card_list` | 正確從 HomeWidget SharedPreferences 讀取 JSON 陣列，提取每筆的 `storeName` 欄位為 Set | P0 |
| P0-09 | P0 | `loadUserBrands` — storeName 為空字串時過濾 | `storeName` 為 `""` 的項目不被加入 `userBrands` | P0 |
| P0-10 | P0 | `loadUserBrands` 異常處理 | JSON 格式異常時回傳 `emptySet()` 並記錄 Log.e | P0 |
| P1-01 | P1 | 快取 HIT — 位置變化 < 1km | 第二次呼叫 `getFilteredStores` 時位置移動 < 1km，應回傳快取資料，不重新讀取 JSON | P1 |
| P1-02 | P1 | 快取 MISS — 位置變化 ≥ 1km | 位置移動 ≥ `CACHE_INVALIDATION_DISTANCE`（1000m）時重新粗篩 | P1 |
| P1-03 | P1 | 快取 MISS — 首次呼叫（快取為 null） | 第一次呼叫時 `cachedNearbyStores` 為 null，應從完整 JSON 粗篩 | P1 |
| P1-04 | P1 | bounding box 範圍正確性 | 粗篩邊界為 ±0.045° 緯度、±0.055° 經度（約 ±5km），僅保留此範圍內的門市 | P1 |
| P1-05 | P1 | bounding box — 邊界值 | 恰好在 `minLat`/`maxLat`/`minLng`/`maxLng` 上的門市應被包含（`in` range 包含端點） | P1 |
| P1-06 | P1 | 粗篩後子集結構正確性 | 回傳的 `JSONObject` 僅包含有門市落在 bounding box 內的品牌；每個品牌的 `locations` 陣列僅包含 box 內門市 | P1 |
| P1-07 | P1 | 粗篩 log 輸出 | HIT 時 log 包含距離與快取品牌數；MISS 時 log 包含全量門市數、粗篩後門市數、品牌數 | P1 |
| P1-08 | P1 | GeofenceManager bounding box 一致性 | `GeofenceManager.loadNearbyStores` 使用相同 `BOUNDING_BOX_LAT_DELTA`/`LNG_DELTA` 值（0.045/0.055） | P1 |
| P1-09 | P1 | 快取與 GeofenceManager 粗篩結果對齊 | `WidgetMatchHelper` 快取粗篩的門市集合應為 `GeofenceManager` 粗篩結果的超集（bounding box 相同） | P1 |
| P2-01 | P2 | Android 版本判斷 log | `registerGeofences` 開頭輸出 `SDK version`、`ACCESS_FINE_LOCATION`、`ACCESS_BACKGROUND_LOCATION` 三項資訊 | P2 |
| P2-02 | P2 | Android 12+ 背景定位權限警告 | `Build.VERSION.SDK_INT >= S` 且缺少 `ACCESS_BACKGROUND_LOCATION` 時，輸出 Log.w 警告 | P2 |
| P2-03 | P2 | Android 11 以下不觸發背景權限警告 | `Build.VERSION.SDK_INT < S` 時不輸出背景權限警告 | P2 |
| P2-04 | P2 | noMatch 狀態 — 有卡但無匹配門市 | `card_count > 0` 且無匹配時：顯示「附近無符合店家」，文字色 `#616161` | P2 |
| P2-05 | P2 | noMatch 狀態 — 有卡無匹配時顯示最近門市提示 | `nearest_store_text` 非空時顯示「📍 最近：{text}」；為空時隱藏 `widget_nearest_text` | P2 |
| P2-06 | P2 | noMatch 狀態 — 無卡片 | `card_count == 0` 時：顯示「點擊新增會員卡」，文字色 `#90A4AE`，隱藏 `widget_nearest_text` | P2 |
| P2-07 | P2 | 頁碼文字更新 | 多卡模式下 `widget_stack_page` 顯示「{n} 張匹配」而非舊版「{n} 張卡片」 | P2 |
| E-01 | Edge | 無卡片 + 無門市 | `native_card_list` 為空，附近無門市 → Widget 顯示「點擊新增會員卡」，geofence 不註冊 | P0 |
| E-02 | Edge | 單卡使用者 | 僅一張卡 → 品牌過濾後只保留該品牌門市，Widget 正確顯示該卡，無頁碼 | P1 |
| E-03 | Edge | 多卡使用者（≥ 3 張不同品牌） | 多品牌過濾正確，Widget 多卡堆疊模式顯示正確，頁碼顯示「{n} 張匹配」 | P1 |
| E-04 | Edge | 位置權限缺失 — 僅有粗略定位 | 缺少 `ACCESS_FINE_LOCATION` 時，`registerGeofences` 檢查 `checkLocationPermission` 應中止並 return | P0 |
| E-05 | Edge | 位置權限缺失 — 無任何定位權限 | 同 E-04，確保不 crash，log 輸出「缺少位置權限」 | P0 |
| E-06 | Edge | app 進程被 kill 後重啟 | `WidgetMatchHelper` 的 static 快取（`cachedNearbyStores`）被清空；重啟後首次匹配為 MISS，正常重新粗篩 | P1 |
| E-07 | Edge | app 進程被 kill 後 geofence 重新註冊 | `savedLastLocation` 在 SharedPreferences 中持久化，重啟後可從 prefs 讀取上次位置重新註冊 | P1 |
| E-08 | Edge | store_locations.json 格式異常 | JSON 解析失敗時回傳 `FilterResult(emptyList(), 0, 0)`，不 crash | P1 |
| E-09 | Edge | native_card_list JSON 格式異常 | `loadUserBrands` 回傳 `emptySet()`，fallback 到全品牌搜索 | P1 |
| E-10 | Edge | 門市座標為 NaN | `lat` 或 `lng` 為 `NaN` 時跳過該門市，不影響其餘結果 | P2 |
| E-11 | Edge | MAX_GEOFENCES 上限（> 80 間門市在範圍內） | 品牌過濾 + 距離排序後取最近 80 間，超出部分被截斷 | P1 |
| E-12 | Edge | 快取 lat/lng 為 NaN（初始狀態） | `cacheLat`/`cacheLng` 初始為 `Double.NaN`，`isNaN()` 判斷應走 MISS 路徑 | P1 |

---

## 測試環境需求

- Android 11 (API 30) 及 Android 12+ (API 31+) 實機或模擬器
- 已安裝 SmartCard Widget
- 可模擬 GPS 定位的工具（Mock Location / ADB）
- Firebase Analytics DebugView 開啟

## 備註

- P0 測試項目為上線前必須通過
- P1 測試項目為上線前建議通過
- P2 測試項目可於上線後回歸
