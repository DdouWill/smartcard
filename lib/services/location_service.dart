// 定位服務
// 實作 WiFi SSID 偵測 + GPS 地理圍欄邏輯
// 依照 SPEC.md 的三步驟定位引擎：WiFi → GPS → 空清單

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'; // 導入 MethodChannel
import 'package:geolocator/geolocator.dart';
import 'package:home_widget/home_widget.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../debug_config.dart';
import '../models/member_card.dart';
import 'store_location_service.dart';

/// 定位結果，包含觸發來源與匹配卡片清單
class LocationResult {
  final List<MemberCard> matchedCards; // 符合的卡片清單
  final LocationTrigger trigger; // 觸發來源
  final String? currentSsid; // 目前連線的 WiFi SSID（可能為 null）
  final Position? currentPosition; // 目前 GPS 位置（可能為 null）
  final NearestStoreInfo? nearestStore; // 最近門市資訊（無符合時提示用）

  const LocationResult({
    required this.matchedCards,
    required this.trigger,
    this.currentSsid,
    this.currentPosition,
    this.nearestStore,
  });

  /// 是否有符合的卡片
  bool get hasMatches => matchedCards.isNotEmpty;
}

/// 定位觸發來源類型
enum LocationTrigger {
  wifi, // 由 WiFi SSID 匹配觸發
  gps, // 由 GPS 地理圍欄匹配觸發
  none, // 無符合（顯示最近門市或空狀態）
}

/// 定位服務（Singleton）
/// 封裝 WiFi SSID 偵測與 GPS Geofencing 邏輯
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final NetworkInfo _networkInfo = NetworkInfo();
  static const _channel =
      MethodChannel('com.ddouwill.smartcard/location_service');
  static const _locationChannel =
      MethodChannel('com.ddouwill.smartcard/location');

  /// Kotlin 端匹配結果的有效時間（5 分鐘）
  static const _kotlinMatchMaxAge = Duration(minutes: 5);

  // ──────────────────────────────────────────
  // 啟動 / 停止 背景服務
  // ──────────────────────────────────────────

  /// 啟動 Android 前台服務，維持背景定位
  Future<void> startBackgroundService() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        // 檢查位置權限 — 未授權就跳過，避免閃退
        final locationStatus = await Permission.location.status;
        if (!locationStatus.isGranted) {
          return;
        }
        // 請求通知權限（Android 13+，非必要但影響前台服務通知）
        await requestNotificationPermission();
        await _channel.invokeMethod('startLocationService');
      }
    } catch (_) {
      // 權限被拒或平台不支援，靜默失敗
    }
  }

  /// 停止背景服務
  Future<void> stopBackgroundService() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _channel.invokeMethod('stopLocationService');
      }
    } catch (_) {}
  }

  // ──────────────────────────────────────────
  // 主要入口：依照 SPEC.md 三步驟定位引擎
  // ──────────────────────────────────────────

  // 用於去抖動（Debounce）的變數
  LocationResult? _lastResult;
  DateTime? _lastUpdateTime;
  static const _debounceDuration = Duration(seconds: 30); // 30 秒內不重複更新 Widget

  /// 依照所有卡片設定，匹配當前位置對應的卡片
  ///
  /// 執行順序：
  /// 1. 掃描 WiFi SSID → 比對 ssidKeywords
  /// 2. 無 WiFi 符合 → 取得 GPS → 比對 gpsZones
  /// 3. 均無符合 → 回傳空清單
  ///
  /// [allCards] 所有已儲存的會員卡
  /// [settings] 目前設定（控制是否啟用 WiFi/GPS）
  Future<LocationResult> matchCardsByLocation({
    required List<MemberCard> allCards,
    bool enableWifi = true,
    bool enableGps = true,
  }) async {
    // ── 去抖動 (Debounce) 邏輯 ──
    // 如果 30 秒內剛更新過，且沒有重要變化，則直接回傳快取結果
    final now = DateTime.now();
    if (_lastResult != null && _lastUpdateTime != null) {
      if (now.difference(_lastUpdateTime!) < _debounceDuration) {
        return _lastResult!;
      }
    }

    LocationResult result;

    if (kEnableDebugLog) {
      debugPrint(
          '[Location] matchCardsByLocation start, cards=${allCards.length}, wifi=$enableWifi, gps=$enableGps');
    }

    // ── Step 1：WiFi SSID 比對 ──
    if (enableWifi) {
      final wifiResult = await _matchByWifi(allCards);
      if (wifiResult.hasMatches) {
        result = wifiResult;
        return _updateLastResult(result);
      }
    }

    // ── Step 2：GPS 匹配 ──
    // 先檢查使用者自訂 gpsZones（優先級最高），再嘗試讀取 Kotlin 端統一匹配結果
    Position? pos;
    if (enableGps) {
      pos = await getCurrentPosition();
      if (kEnableDebugLog && pos != null) {
        debugPrint('[Location] GPS: ${pos.latitude}, ${pos.longitude}');
      }
      if (pos != null) {
        // Step 2a：自訂 gpsZones 匹配（優先）
        final customGpsResult = await _matchByCustomGpsZones(allCards, pos);
        if (customGpsResult.hasMatches) {
          // 同時觸發 Kotlin 端匹配（讓 Widget 保持同步）
          _triggerKotlinMatch(pos.latitude, pos.longitude);
          return _updateLastResult(customGpsResult);
        }

        // Step 2b：觸發 Kotlin 端匹配，再讀取結果
        await _triggerKotlinMatch(pos.latitude, pos.longitude);
        final kotlinResult = await _readKotlinMatchResult(allCards, pos);
        if (kotlinResult != null && kotlinResult.hasMatches) {
          if (kEnableDebugLog) {
            debugPrint(
                '[Location] 使用 Kotlin 端匹配結果: matched=${kotlinResult.matchedCards.length}');
          }
          return _updateLastResult(kotlinResult);
        }

        // Step 2c：Fallback — Kotlin 結果不可用時，用 Flutter 端匹配
        if (kEnableDebugLog) {
          debugPrint('[Location] Kotlin 結果不可用，fallback 到 Flutter 匹配');
        }
        final gpsResult = await _matchByGps(allCards, pos);
        if (gpsResult.hasMatches) {
          result = gpsResult;
          return _updateLastResult(result);
        }
      }
    }

    // ── Step 3：無符合 → 找最近門市作為提示 ──
    NearestStoreInfo? nearest;
    // 記錄 Step 2 是否已取得座標並跑過 GPS 匹配
    final bool gpsAttempted = pos != null && enableGps;
    // 若 Step 2 未取得座標（冷啟動），再嘗試一次
    pos ??= await getCurrentPosition();
    if (pos != null) {
      // 冷啟動情境：Step 2 拿不到座標但現在拿到了，補跑 GPS 匹配
      // 如果 Step 2 已經跑過就跳過，避免重複執行
      if (enableGps && !gpsAttempted) {
        // 先試自訂 zones
        final customRetry = await _matchByCustomGpsZones(allCards, pos);
        if (customRetry.hasMatches) {
          _triggerKotlinMatch(pos.latitude, pos.longitude);
          return _updateLastResult(customRetry);
        }

        // 觸發 Kotlin 端匹配
        await _triggerKotlinMatch(pos.latitude, pos.longitude);
        final kotlinRetry = await _readKotlinMatchResult(allCards, pos);
        if (kotlinRetry != null && kotlinRetry.hasMatches) {
          return _updateLastResult(kotlinRetry);
        }

        // Fallback
        final retryGpsResult = await _matchByGps(allCards, pos);
        if (retryGpsResult.hasMatches) {
          return _updateLastResult(retryGpsResult);
        }
      }

      // 讀取 Kotlin 端的 nearest brand 資訊
      nearest = await _readKotlinNearestStore(allCards);

      // Fallback：Kotlin 無結果時用 Flutter 端找最近門市
      if (nearest == null) {
        final storeService = StoreLocationService();
        final userBrands = allCards
            .map((c) => storeService.resolveStoreName(c.storeName))
            .toSet();
        nearest = await storeService.findNearestStore(
          userLat: pos.latitude,
          userLng: pos.longitude,
          brandFilter: userBrands,
        );
      }

      if (kEnableDebugLog) {
        if (nearest != null) {
          debugPrint(
              '[Location] Nearest: ${nearest.brandName} @ ${nearest.distanceMeters.toStringAsFixed(0)}m');
        } else {
          debugPrint('[Location] Nearest: none found');
        }
      }
    }
    result = LocationResult(
      matchedCards: [],
      trigger: LocationTrigger.none,
      currentPosition: pos,
      nearestStore: nearest,
    );
    return _updateLastResult(result);
  }

  /// 內部更新輔助
  LocationResult _updateLastResult(LocationResult result) {
    _lastResult = result;
    _lastUpdateTime = DateTime.now();
    return result;
  }

  // ──────────────────────────────────────────
  // Kotlin 端匹配結果讀取
  // ──────────────────────────────────────────

  /// 透過 MethodChannel 觸發 Kotlin 端執行匹配
  Future<void> _triggerKotlinMatch(double latitude, double longitude) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _locationChannel.invokeMethod('triggerMatch', {
          'latitude': latitude,
          'longitude': longitude,
        });
      }
    } catch (e) {
      if (kEnableDebugLog) {
        debugPrint('[Location] triggerKotlinMatch 失敗: $e');
      }
    }
  }

  /// 讀取 Kotlin 端寫入的匹配結果（SharedPreferences）
  ///
  /// 回傳 null 表示結果不可用（過期、不存在、或平台不支援）
  Future<LocationResult?> _readKotlinMatchResult(
    List<MemberCard> allCards,
    Position position,
  ) async {
    try {
      if (defaultTargetPlatform != TargetPlatform.android) return null;

      // 檢查 timestamp 是否在有效範圍內
      // Kotlin 端用 putString 存所有數值，避免 home_widget 的 getLong/getFloat 型別不匹配
      final timestampStr =
          await HomeWidget.getWidgetData<String>('match_timestamp');
      if (timestampStr == null) return null;
      final timestamp = int.tryParse(timestampStr);
      if (timestamp == null) return null;

      final matchTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      if (DateTime.now().difference(matchTime) > _kotlinMatchMaxAge) {
        if (kEnableDebugLog) {
          debugPrint(
              '[Location] Kotlin 匹配結果已過期 (${DateTime.now().difference(matchTime).inSeconds}s ago)');
        }
        return null;
      }

      // 讀取匹配到的品牌清單
      final matchedBrandsJson =
          await HomeWidget.getWidgetData<String>('matched_brands');
      if (matchedBrandsJson == null) return null;

      final List<dynamic> matchedBrandNames = json.decode(matchedBrandsJson);

      if (matchedBrandNames.isEmpty) {
        // Kotlin 端判定 noMatch — 讀取 nearest store 資訊
        final nearestStore = await _readKotlinNearestStore(allCards);
        return LocationResult(
          matchedCards: [],
          trigger: LocationTrigger.gps,
          currentPosition: position,
          nearestStore: nearestStore,
        );
      }

      // 將品牌名稱對應到使用者的 MemberCard
      final List<MemberCard> matchedCards = [];
      for (final brandName in matchedBrandNames) {
        final name = brandName as String;
        if (name.isEmpty) continue;
        for (final card in allCards) {
          if (card.storeName == name && !matchedCards.contains(card)) {
            matchedCards.add(card);
            break;
          }
        }
      }

      return LocationResult(
        matchedCards: matchedCards,
        trigger: LocationTrigger.gps,
        currentPosition: position,
      );
    } catch (e) {
      if (kEnableDebugLog) {
        debugPrint('[Location] 讀取 Kotlin 匹配結果失敗: $e');
      }
      return null;
    }
  }

  /// 從 Kotlin 端的 SharedPreferences 讀取最近門市資訊
  Future<NearestStoreInfo?> _readKotlinNearestStore(
      List<MemberCard> allCards) async {
    try {
      if (defaultTargetPlatform != TargetPlatform.android) return null;

      final nearestName =
          await HomeWidget.getWidgetData<String>('nearest_brand_name');
      final nearestDistStr =
          await HomeWidget.getWidgetData<String>('nearest_brand_distance');
      final nearestDistance =
          nearestDistStr != null ? double.tryParse(nearestDistStr) : null;

      if (nearestName == null ||
          nearestName.isEmpty ||
          nearestDistance == null ||
          nearestDistance < 0) {
        return null;
      }

      // 建構 NearestStoreInfo（zone 用 match_lat/lng 近似）
      final latStr = await HomeWidget.getWidgetData<String>('match_lat');
      final lngStr = await HomeWidget.getWidgetData<String>('match_lng');
      final lat = latStr != null ? double.tryParse(latStr) : null;
      final lng = lngStr != null ? double.tryParse(lngStr) : null;

      return NearestStoreInfo(
        brandName: nearestName,
        distanceMeters: nearestDistance,
        zone: GpsZone(
          latitude: lat ?? 0,
          longitude: lng ?? 0,
        ),
      );
    } catch (e) {
      if (kEnableDebugLog) {
        debugPrint('[Location] 讀取 Kotlin nearest store 失敗: $e');
      }
      return null;
    }
  }

  /// 只匹配使用者自訂的 gpsZones（不查 store_locations.json）
  Future<LocationResult> _matchByCustomGpsZones(
    List<MemberCard> allCards,
    Position position,
  ) async {
    final List<MemberCard> matched = [];

    for (final card in allCards) {
      if (card.gpsZones.isEmpty) continue;
      for (final zone in card.gpsZones) {
        final dist = calculateDistance(position.latitude, position.longitude,
            zone.latitude, zone.longitude);
        if (dist <= zone.radiusMeters) {
          matched.add(card);
          break;
        }
      }
    }

    return LocationResult(
      matchedCards: matched,
      trigger: LocationTrigger.gps,
      currentPosition: position,
    );
  }

  // ──────────────────────────────────────────
  // WiFi SSID 偵測
  // ──────────────────────────────────────────

  /// 取得當前連線的 WiFi SSID
  /// 回傳 null 表示未連線或無法取得
  Future<String?> getCurrentSsid() async {
    try {
      // 需要位置權限才能讀取 SSID（Android 限制）
      final locationPermission = await Permission.location.status;
      if (!locationPermission.isGranted) {
        return null;
      }

      final ssid = await _networkInfo.getWifiName();
      // Android 回傳的 SSID 可能帶有引號，需去除
      return ssid?.replaceAll('"', '');
    } catch (_) {
      return null;
    }
  }

  /// 依 WiFi SSID 關鍵字比對卡片
  Future<LocationResult> _matchByWifi(List<MemberCard> allCards) async {
    final currentSsid = await getCurrentSsid();

    if (currentSsid == null || currentSsid.isEmpty) {
      return LocationResult(
        matchedCards: [],
        trigger: LocationTrigger.wifi,
        currentSsid: currentSsid,
      );
    }

    final matched = allCards.where((card) {
      return card.ssidKeywords.any((keyword) =>
          currentSsid.toLowerCase().contains(keyword.toLowerCase()));
    }).toList();

    return LocationResult(
      matchedCards: matched,
      trigger: LocationTrigger.wifi,
      currentSsid: currentSsid,
    );
  }

  // ──────────────────────────────────────────
  // GPS 地理圍欄
  // ──────────────────────────────────────────

  /// 取得當前 GPS 位置
  /// 回傳 null 表示權限不足或定位失敗
  Future<Position?> getCurrentPosition() async {
    try {
      // 檢查位置服務是否啟用
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      // 檢查位置權限
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // 取得位置（使用中精度平衡精確度與耗電）
      // 注意：low (~500m) 對 100m 地理圍欄不夠精確，
      //       medium (~100m) 符合預設圍欄半徑需求
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium, // 約 100m 精度，匹配預設圍欄半徑
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// 依 GPS 地理圍欄比對卡片
  ///
  /// [position] 已取得的 GPS 座標（由 matchCardsByLocation 統一管理）
  ///
  /// 匹配邏輯：
  /// 1. 卡片有自訂 gpsZones → 用自訂座標比對
  /// 2. 卡片無 gpsZones 但店名匹配 known store → 從 store_locations.json 查詢附近門市
  /// 3. 兩者皆無 → 不匹配
  Future<LocationResult> _matchByGps(
    List<MemberCard> allCards,
    Position position,
  ) async {
    final storeService = StoreLocationService();
    final List<MemberCard> matched = [];

    for (final card in allCards) {
      if (card.gpsZones.isNotEmpty) {
        // 有自訂 GPS 圍欄 → 用卡片自帶座標比對
        for (final zone in card.gpsZones) {
          final dist = calculateDistance(position.latitude, position.longitude,
              zone.latitude, zone.longitude);
          final inZone = dist <= zone.radiusMeters;
          if (kEnableDebugLog) {
            debugPrint(
                '[Location] Match: ${card.storeName} @ ${dist.toStringAsFixed(0)}m (radius: ${zone.radiusMeters}m) → ${inZone ? "HIT" : "miss"}');
          }
          if (inZone) {
            matched.add(card);
            break;
          }
        }
      } else {
        // 無自訂圍欄 → 嘗試從 store_locations.json 查詢品牌門市
        final nearbyZones = await storeService.getNearbyStoreLocations(
          card.storeName,
          userLat: position.latitude,
          userLng: position.longitude,
          radiusKm: 0.5, // 500m 粗篩，實際用 zone.radiusMeters 精確判斷
        );
        bool isMatched = false;
        for (final zone in nearbyZones) {
          final dist = calculateDistance(position.latitude, position.longitude,
              zone.latitude, zone.longitude);
          final inZone = dist <= zone.radiusMeters;
          if (kEnableDebugLog) {
            debugPrint(
                '[Location] Match: ${card.storeName} @ ${dist.toStringAsFixed(0)}m (radius: ${zone.radiusMeters}m) → ${inZone ? "HIT" : "miss"}');
          }
          if (inZone) {
            isMatched = true;
            break;
          }
        }
        if (isMatched) matched.add(card);
      }
    }

    return LocationResult(
      matchedCards: matched,
      trigger: LocationTrigger.gps,
      currentPosition: position,
    );
  }

  @visibleForTesting
  Future<LocationResult> matchCardsByGpsPositionForTest({
    required List<MemberCard> allCards,
    required double latitude,
    required double longitude,
  }) async {
    final position = Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
    return _matchByGps(allCards, position);
  }

  // ──────────────────────────────────────────
  // 地理計算
  // ──────────────────────────────────────────

  /// 計算兩點間球面距離（公尺）
  /// 使用 Haversine 公式
  double calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadiusMeters = 6371000.0; // 地球半徑

    final double dLat = _toRadians(lat2 - lat1);
    final double dLng = _toRadians(lng2 - lng1);

    final double a = math.pow(math.sin(dLat / 2), 2).toDouble() +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.pow(math.sin(dLng / 2), 2).toDouble();

    final double c = 2 * math.asin(math.sqrt(a));
    return earthRadiusMeters * c;
  }

  /// 角度轉弧度
  double _toRadians(double degrees) => degrees * math.pi / 180.0;

  // ──────────────────────────────────────────
  // 權限請求輔助
  // ──────────────────────────────────────────

  /// 請求所有定位相關權限
  Future<bool> requestLocationPermissions() async {
    // 優先請求通知權限
    await requestNotificationPermission();

    final permissions = await [
      Permission.location,
      Permission.locationWhenInUse,
    ].request();

    final allGranted = permissions.values.every(
      (status) => status.isGranted || status.isLimited,
    );

    return allGranted;
  }

  /// 請求背景位置權限（Geofencing 需要）
  Future<bool> requestBackgroundLocationPermission() async {
    final status = await Permission.locationAlways.request();
    return status.isGranted;
  }

  /// 請求通知權限（Android 13+ 需要）
  Future<bool> requestNotificationPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }
    return true;
  }
}
