// 定位服務
// 實作 WiFi SSID 偵測 + GPS 地理圍欄邏輯
// 依照 SPEC.md 的三步驟定位引擎：WiFi → GPS → 空清單

import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'; // 導入 MethodChannel
import 'package:geolocator/geolocator.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/member_card.dart';

/// 定位結果，包含觸發來源與匹配卡片清單
class LocationResult {
  final List<MemberCard> matchedCards; // 符合的卡片清單
  final LocationTrigger trigger; // 觸發來源
  final String? currentSsid; // 目前連線的 WiFi SSID（可能為 null）
  final Position? currentPosition; // 目前 GPS 位置（可能為 null）

  const LocationResult({
    required this.matchedCards,
    required this.trigger,
    this.currentSsid,
    this.currentPosition,
  });

  /// 是否有符合的卡片
  bool get hasMatches => matchedCards.isNotEmpty;
}

/// 定位觸發來源類型
enum LocationTrigger {
  wifi, // 由 WiFi SSID 匹配觸發
  gps, // 由 GPS 地理圍欄匹配觸發
  none, // 無符合（顯示最近使用）
}

/// 定位服務（Singleton）
/// 封裝 WiFi SSID 偵測與 GPS Geofencing 邏輯
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final NetworkInfo _networkInfo = NetworkInfo();
  static const _channel = MethodChannel('com.ddouwill.smartcard/location_service');

  // ──────────────────────────────────────────
  // 啟動 / 停止 背景服務
  // ──────────────────────────────────────────

  /// 啟動 Android 前台服務，維持背景定位
  Future<void> startBackgroundService() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        // 先請求通知權限（Android 13+）
        await requestNotificationPermission();
        await _channel.invokeMethod('startLocationService');
      }
    } catch (_) {
    }
  }

  /// 停止背景服務
  Future<void> stopBackgroundService() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _channel.invokeMethod('stopLocationService');
      }
    } catch (_) {
    }
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

    // ── Step 1：WiFi SSID 比對 ──
    if (enableWifi) {
      final wifiResult = await _matchByWifi(allCards);
      if (wifiResult.hasMatches) {
        result = wifiResult;
        return _updateLastResult(result);
      }
    }

    // ── Step 2：GPS 地理圍欄比對 ──
    if (enableGps) {
      final gpsResult = await _matchByGps(allCards);
      if (gpsResult.hasMatches) {
        result = gpsResult;
        return _updateLastResult(result);
      }
    }

    // ── Step 3：無符合 ──
    result = const LocationResult(
      matchedCards: [],
      trigger: LocationTrigger.none,
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
  Future<LocationResult> _matchByGps(List<MemberCard> allCards) async {
    final position = await getCurrentPosition();

    if (position == null) {
      return const LocationResult(
        matchedCards: [],
        trigger: LocationTrigger.gps,
      );
    }

    final matched = allCards.where((card) {
      return card.gpsZones.any((zone) =>
          _isInZone(position.latitude, position.longitude, zone));
    }).toList();

    return LocationResult(
      matchedCards: matched,
      trigger: LocationTrigger.gps,
      currentPosition: position,
    );
  }

  // ──────────────────────────────────────────
  // 地理計算
  // ──────────────────────────────────────────

  /// 判斷座標是否在地理圍欄內
  /// 使用 Haversine 公式計算球面距離
  bool _isInZone(double lat, double lng, GpsZone zone) {
    final distance = calculateDistance(lat, lng, zone.latitude, zone.longitude);
    return distance <= zone.radiusMeters;
  }

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
