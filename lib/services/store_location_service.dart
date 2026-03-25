// 門市座標服務
// 從 store_locations.json 載入品牌門市座標，提供 GPS 圍欄自動填入
// 支援 bounding box 5km 粗篩，只載入使用者附近的門市

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../models/member_card.dart';

/// 門市座標服務（Singleton）
/// 讀取 store_locations.json，依品牌名稱回傳門市 GPS 圍欄

/// 店名別名映射：手動輸入的常見名稱 → store_locations.json 的正式 key
const _storeNameAliases = <String, String>{
  // 7-ELEVEN
  '7-11': '7-ELEVEN',
  '711': '7-ELEVEN',
  '小七': '7-ELEVEN',
  '7eleven': '7-ELEVEN',
  '7-eleven': '7-ELEVEN',
  'seven': '7-ELEVEN',
  'seven eleven': '7-ELEVEN',
  // 全家
  '全家': '全家 FamilyMart',
  'familymart': '全家 FamilyMart',
  'family mart': '全家 FamilyMart',
  // 萊爾富
  '萊爾富': '萊爾富 Hi-Life',
  'hilife': '萊爾富 Hi-Life',
  'hi-life': '萊爾富 Hi-Life',
  // OK
  'ok': 'OK 超商',
  'ok超商': 'OK 超商',
  // 全聯
  '全聯': '全聯福利中心',
  // 家樂福
  '家樂福': '家樂福 Carrefour',
  'carrefour': '家樂福 Carrefour',
  // 好市多
  '好市多': '好市多 Costco',
  'costco': '好市多 Costco',
  // 屈臣氏
  '屈臣氏': '屈臣氏 Watsons',
  'watsons': '屈臣氏 Watsons',
  // 康是美
  '康是美': '康是美 COSMED',
  'cosmed': '康是美 COSMED',
  // 寶雅
  '寶雅': '寶雅 POYA',
  'poya': '寶雅 POYA',
  // 路易莎
  '路易莎': '路易莎 Louisa',
  'louisa': '路易莎 Louisa',
  // 星巴克
  '星巴克': '星巴克 Starbucks',
  'starbucks': '星巴克 Starbucks',
  // cama
  'cama': 'cama café',
  // 摩斯
  '摩斯': '摩斯漢堡',
  '摩斯漢堡 MOS': '摩斯漢堡',
  'mos': '摩斯漢堡',
  // 麥當勞
  '麥當勞 McDonald': '麥當勞',
  'mcdonalds': '麥當勞',
  "mcdonald's": '麥當勞',
  // 肯德基
  '肯德基': '肯德基 KFC',
  'kfc': '肯德基 KFC',
  // 八方雲集
  '八方': '八方雲集',
  // 全國電子
  '全國電子 elife': '全國電子',
  // 燦坤
  '燦坤': '燦坤 3C',
  // 大潤發
  '大潤發 RT-Mart': '大潤發',
  // 美廉社
  '美廉社 Simple Mart': '美廉社',
  // 大創
  '大創': '大創 DAISO',
  'daiso': '大創 DAISO',
  // 誠品
  '誠品書店': '誠品',
  '誠品生活': '誠品',
  // 中油
  '中油': '中油 CPC',
  'cpc': '中油 CPC',
  // 台塑
  '台塑': '台塑 FPCC',
  // 新光三越
  '新光': '新光三越',
  // 遠百
  '遠百': '遠東百貨',
};

class StoreLocationService {
  static final StoreLocationService _instance =
      StoreLocationService._internal();
  factory StoreLocationService() => _instance;
  StoreLocationService._internal();

  /// 快取已載入的 JSON 資料
  Map<String, dynamic>? _storesData;

  /// 每緯度約 111 km
  static const double _kmPerDegreeLat = 111.0;

  /// 本地更新檔案名稱
  static const _localFileName = 'store_locations.json';

  /// GitHub raw content URL
  static const _remoteUrl =
      'https://raw.githubusercontent.com/DdouWill/smartcard/main/lib/data/store_locations.json';

  /// 載入門市資料（比較 bundled / local 版本，取較新者）
  Future<Map<String, dynamic>> _loadData() async {
    if (_storesData != null) return _storesData!;

    // 1. 讀 bundled asset
    final bundledString =
        await rootBundle.loadString('lib/data/store_locations.json');
    final bundledDecoded = json.decode(bundledString) as Map<String, dynamic>;
    final bundledVersion = (bundledDecoded['version'] as int?) ?? 0;

    // 2. 讀 local file（如果存在）
    Map<String, dynamic>? localDecoded;
    int localVersion = 0;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final localFile = File('${dir.path}/$_localFileName');
      if (await localFile.exists()) {
        final localString = await localFile.readAsString();
        localDecoded = json.decode(localString) as Map<String, dynamic>;
        localVersion = (localDecoded['version'] as int?) ?? 0;
      }
    } catch (_) {
      // local 讀取失敗，使用 bundled
    }

    // 3. 比較版本：local >= bundled 用 local，否則用 bundled
    final chosen = (localDecoded != null && localVersion >= bundledVersion)
        ? localDecoded
        : bundledDecoded;

    _storesData = chosen['stores'] as Map<String, dynamic>;
    return _storesData!;
  }

  /// 從遠端下載最新門市資料並儲存到本地
  ///
  /// 回傳更新結果：品牌數 / 門市總數
  /// 失敗時拋出 Exception
  Future<StoreUpdateResult> updateStoreData() async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(_remoteUrl));
      request.headers.set('User-Agent', 'SmartCard-App');
      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception('下載失敗 (HTTP \${response.statusCode})');
      }

      final jsonString = await response.transform(utf8.decoder).join();

      // 驗證 JSON 格式（遠端 JSON 需包含 version）
      final decoded = json.decode(jsonString) as Map<String, dynamic>;
      final stores = decoded['stores'] as Map<String, dynamic>?;
      if (stores == null || stores.isEmpty) {
        throw Exception('資料格式錯誤');
      }
      // 確保 version 欄位存在
      decoded['version'] ??= 0;

      // 計算統計
      int totalLocations = 0;
      for (final brand in stores.values) {
        final locs =
            (brand as Map<String, dynamic>)['locations'] as List<dynamic>?;
        totalLocations += locs?.length ?? 0;
      }

      // 儲存到本地
      final dir = await getApplicationDocumentsDirectory();
      final localFile = File('${dir.path}/$_localFileName');
      await localFile.writeAsString(jsonString);

      // 清除快取，下次讀取使用新資料
      _storesData = null;

      return StoreUpdateResult(
        brandCount: stores.length,
        locationCount: totalLocations,
      );
    } finally {
      client.close();
    }
  }

  /// 檢查遠端是否有新版門市資料
  /// 回傳 true 表示有新版可更新
  Future<bool> checkForStoreUpdate() async {
    try {
      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse(_remoteUrl));
        request.headers.set('User-Agent', 'SmartCard-App');
        final response = await request.close();

        if (response.statusCode != 200) return false;

        final jsonString = await response.transform(utf8.decoder).join();
        final decoded = json.decode(jsonString) as Map<String, dynamic>;
        final remoteVersion = decoded['version'] as int? ?? 0;

        // 取得本地版本（bundled 或 local 的較大者）
        final localData = await _loadData();
        // _loadData 回傳的是 stores map，要從原始 JSON 讀 version
        // 這裡直接重新讀一次 bundled
        final bundledStr = await rootBundle.loadString('lib/data/store_locations.json');
        final bundledDecoded = json.decode(bundledStr) as Map<String, dynamic>;
        int localVersion = bundledDecoded['version'] as int? ?? 0;

        // 檢查 local file 版本
        try {
          final dir = await getApplicationDocumentsDirectory();
                    final localFile = File('${dir.path}/$_localFileName');
          if (await localFile.exists()) {
            final localStr = await localFile.readAsString();
            final localDecoded = json.decode(localStr) as Map<String, dynamic>;
            final fileVersion = localDecoded['version'] as int? ?? 0;
            if (fileVersion > localVersion) localVersion = fileVersion;
          }
        } catch (_) {}

        return remoteVersion > localVersion;
      } finally {
        client.close();
      }
    } catch (_) {
      return false;
    }
  }

    /// 取得本地更新檔的修改時間（null 表示尚未更新過）
  Future<DateTime?> getLastUpdateTime() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final localFile = File('${dir.path}/$_localFileName');
      if (await localFile.exists()) {
        return await localFile.lastModified();
      }
    } catch (_) {}
    return null;
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
        radiusMeters: (m['radius'] as num?)?.toDouble() ?? 200.0,
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
    // 嘗試別名解析（支援手動輸入的非標準店名）
    final resolvedName = resolveStoreName(brandName);
    final allZones = await getStoreLocations(resolvedName);
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

  /// 解析店名：精確匹配 → 別名匹配 → 模糊匹配（不分大小寫）
  String resolveStoreName(String input) {
    // 1. 精確匹配
    final stores = _storesData;
    if (stores != null && stores.containsKey(input)) return input;

    // 2. 別名匹配（不分大小寫）
    final lower = input.toLowerCase().trim();
    if (_storeNameAliases.containsKey(lower)) {
      return _storeNameAliases[lower]!;
    }

    // 3. 模糊匹配：輸入包含品牌 key 或品牌 key 包含輸入
    if (stores != null) {
      for (final key in stores.keys) {
        final keyLower = key.toLowerCase();
        if (keyLower.contains(lower) || lower.contains(keyLower)) {
          return key;
        }
      }
    }

    return input; // 無匹配，原樣回傳
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
    Set<String>? brandFilter,
  }) async {
    final stores = await _loadData();

    double? minDist;
    String? minBrand;
    GpsZone? minZone;

    for (final entry in stores.entries) {
      final brandName = entry.key;
      // 只搜尋使用者有卡片的品牌
      if (brandFilter != null && !brandFilter.contains(brandName)) {
        continue;
      }
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
            radiusMeters: (m['radius'] as num?)?.toDouble() ?? 200.0,
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


/// 門市資料更新結果
class StoreUpdateResult {
  final int brandCount;
  final int locationCount;

  const StoreUpdateResult({
    required this.brandCount,
    required this.locationCount,
  });
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
