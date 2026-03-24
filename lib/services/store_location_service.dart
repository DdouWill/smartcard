// 門市座標服務
// 從 store_locations.json 載入品牌門市座標，提供 GPS 圍欄自動填入
// 支援 bounding box 5km 粗篩，只載入使用者附近的門市

import 'dart:convert';
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

  /// 清除快取（用於測試或熱重載）
  void clearCache() {
    _storesData = null;
  }
}
