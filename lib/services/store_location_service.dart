// 門市座標服務
// 從 store_locations.json 載入品牌門市座標，提供 GPS 圍欄自動填入
// 支援 bounding box 5km 粗篩，只載入使用者附近的門市

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';

import '../models/member_card.dart';

/// 門市座標服務（Singleton）
/// 讀取 store_locations.json，依品牌名稱回傳門市 GPS 圍欄
class StoreLocationService {
  static final StoreLocationService _instance =
      StoreLocationService._internal();
  factory StoreLocationService() => _instance;
  StoreLocationService._internal();

  /// 快取已載入的 JSON 資料
  Map<String, dynamic>? _storesData;

  /// 每緯度約 111 km
  static const double _kmPerDegreeLat = 111.0;

  /// 載入 store_locations.json（lazy，只讀一次）
  Future<Map<String, dynamic>> _loadData() async {
    if (_storesData != null) return _storesData!;

    final jsonString =
        await rootBundle.loadString('lib/data/store_locations.json');
    final decoded = json.decode(jsonString) as Map<String, dynamic>;
    _storesData = decoded['stores'] as Map<String, dynamic>;
    return _storesData!;
  }

  /// 取得指定品牌的所有門市座標，轉為 GpsZone
  ///
  /// [brandName] 品牌名稱，需與 store_locations.json 的 key 完全一致
  /// 回傳空 List 代表該品牌無門市資料
  Future<List<GpsZone>> getStoreLocations(String brandName) async {
    final stores = await _loadData();
    final brandData = stores[brandName] as Map<String, dynamic>?;
    if (brandData == null) return [];

    final locations = brandData['locations'] as List<dynamic>;
    return locations.map((loc) {
      final m = loc as Map<String, dynamic>;
      return GpsZone(
        latitude: (m['lat'] as num).toDouble(),
        longitude: (m['lng'] as num).toDouble(),
        radiusMeters: (m['radius'] as num?)?.toDouble() ?? 100.0,
        label: m['name'] as String?,
      );
    }).toList();
  }

  /// 取得指定品牌門市中，位於使用者位置 5km 內的門市座標
  ///
  /// 使用 bounding box 粗篩（非精確距離），效能優先
  /// [userLat] / [userLng] 使用者當前位置
  /// [radiusKm] 篩選半徑，預設 5km
  Future<List<GpsZone>> getNearbyStoreLocations(
    String brandName, {
    required double userLat,
    required double userLng,
    double radiusKm = 5.0,
  }) async {
    final allZones = await getStoreLocations(brandName);
    if (allZones.isEmpty) return [];

    // Bounding box 粗篩
    final latDelta = radiusKm / _kmPerDegreeLat;
    final lngDelta =
        radiusKm / (_kmPerDegreeLat * _cosApprox(userLat));

    final minLat = userLat - latDelta;
    final maxLat = userLat + latDelta;
    final minLng = userLng - lngDelta;
    final maxLng = userLng + lngDelta;

    return allZones.where((zone) {
      return zone.latitude >= minLat &&
          zone.latitude <= maxLat &&
          zone.longitude >= minLng &&
          zone.longitude <= maxLng;
    }).toList();
  }

  /// 檢查指定品牌是否有門市座標資料
  Future<bool> hasLocations(String brandName) async {
    final stores = await _loadData();
    final brandData = stores[brandName] as Map<String, dynamic>?;
    if (brandData == null) return false;
    final locations = brandData['locations'] as List<dynamic>?;
    return locations != null && locations.isNotEmpty;
  }

  /// 取得所有有門市資料的品牌名稱
  Future<List<String>> getAvailableBrands() async {
    final stores = await _loadData();
    return stores.keys.toList();
  }

  /// cos 近似值（度數輸入），避免引入 dart:math 只為一個 cos
  static double _cosApprox(double degrees) {
    // cos(x) ≈ 1 - x²/2 + x⁴/24（Taylor 展開，台灣緯度 22-26° 精度足夠）
    final rad = degrees * 3.141592653589793 / 180.0;
    final r2 = rad * rad;
    return 1.0 - r2 / 2.0 + r2 * r2 / 24.0;
  }

  /// 最近門市搜尋結果
  /// [brandName] 品牌名稱, [distance] 距離（公尺）, [zone] 門市座標
  static const double _defaultSearchRadiusKm = 1.0;

  /// 在所有品牌中找出離使用者最近的門市
  ///
  /// [userLat] / [userLng] 使用者當前位置
  /// [maxDistanceKm] 搜尋半徑上限，預設 1km
  /// 回傳 null 表示範圍內無門市
  Future<NearestStoreInfo?> findNearestStore({
    required double userLat,
    required double userLng,
    double maxDistanceKm = _defaultSearchRadiusKm,
  }) async {
    final stores = await _loadData();

    double? minDist;
    String? minBrand;
    GpsZone? minZone;

    for (final entry in stores.entries) {
      final brandName = entry.key;
      final brandData = entry.value as Map<String, dynamic>;
      final locations = brandData['locations'] as List<dynamic>?;
      if (locations == null) continue;

      // Bounding box 粗篩
      final latDelta = maxDistanceKm / _kmPerDegreeLat;
      final lngDelta =
          maxDistanceKm / (_kmPerDegreeLat * _cosApprox(userLat));
      final minLat = userLat - latDelta;
      final maxLat = userLat + latDelta;
      final minLng = userLng - lngDelta;
      final maxLng = userLng + lngDelta;

      for (final loc in locations) {
        final m = loc as Map<String, dynamic>;
        final lat = (m['lat'] as num).toDouble();
        final lng = (m['lng'] as num).toDouble();

        // 粗篩
        if (lat < minLat || lat > maxLat || lng < minLng || lng > maxLng) {
          continue;
        }

        // Haversine 精確距離
        final dist = _haversineMeters(userLat, userLng, lat, lng);
        if (dist <= maxDistanceKm * 1000 && (minDist == null || dist < minDist)) {
          minDist = dist;
          minBrand = brandName;
          minZone = GpsZone(
            latitude: lat,
            longitude: lng,
            radiusMeters: (m['radius'] as num?)?.toDouble() ?? 100.0,
            label: m['name'] as String?,
          );
        }
      }
    }

    if (minDist == null || minBrand == null || minZone == null) return null;

    return NearestStoreInfo(
      brandName: minBrand,
      distanceMeters: minDist,
      zone: minZone,
    );
  }

  /// Haversine 公式計算兩點球面距離（公尺）
  static double _haversineMeters(
      double lat1, double lng1, double lat2, double lng2) {
    const R = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLng = (lng2 - lng1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return R * 2 * math.asin(math.sqrt(a));
  }

    /// 清除快取（用於測試或熱重載）
  void clearCache() {
    _storesData = null;
  }
}


/// 最近門市資訊
class NearestStoreInfo {
  final String brandName;
  final double distanceMeters;
  final GpsZone zone;

  const NearestStoreInfo({
    required this.brandName,
    required this.distanceMeters,
    required this.zone,
  });

  /// 格式化距離文字
  String get distanceText {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()}m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)}km';
  }
}
