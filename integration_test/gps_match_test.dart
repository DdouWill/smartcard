import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smartcard/main.dart' as app;
import 'package:smartcard/services/store_location_service.dart';
import 'package:smartcard/models/member_card.dart';
import 'package:smartcard/services/location_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('GPS Match via store_locations.json', () {

    testWidgets('StoreLocationService: 座標 (24.1492, 120.6451) 附近門市查詢', (tester) async {
      // 需要啟動 app 才能載入 assets
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final service = StoreLocationService();
      const userLat = 24.1492072;
      const userLng = 120.6451422;

      // ── Test 1: 7-ELEVEN 500m 內有門市 ──
      final sevenZones = await service.getNearbyStoreLocations(
        '7-ELEVEN',
        userLat: userLat,
        userLng: userLng,
        radiusKm: 0.5,
      );
      debugPrint('📍 7-ELEVEN zones in 500m: ${sevenZones.length}');
      expect(sevenZones.isNotEmpty, true, reason: '7-ELEVEN 應有門市在 500m 內');

      // ── Test 2: 至少一間 7-ELEVEN 在 100m radius 內 ──
      bool sevenInRange = false;
      for (final zone in sevenZones) {
        final dist = _haversine(userLat, userLng, zone.latitude, zone.longitude);
        debugPrint('  7-ELEVEN: (${zone.latitude}, ${zone.longitude}) = ${dist.toStringAsFixed(0)}m (r=${zone.radiusMeters}m) ${dist <= zone.radiusMeters ? "✅" : ""}');
        if (dist <= zone.radiusMeters) sevenInRange = true;
      }
      expect(sevenInRange, true, reason: '至少一間 7-ELEVEN 應在匹配半徑內');
      debugPrint('✅ Test 2 PASS: 7-ELEVEN 在 100m 匹配半徑內');

      // ── Test 3: 全家 500m 內查詢 ──
      final familyZones = await service.getNearbyStoreLocations(
        '全家 FamilyMart',
        userLat: userLat,
        userLng: userLng,
        radiusKm: 0.5,
      );
      debugPrint('📍 全家 zones in 500m: ${familyZones.length}');
      bool familyInRange = false;
      for (final zone in familyZones) {
        final dist = _haversine(userLat, userLng, zone.latitude, zone.longitude);
        debugPrint('  全家: (${zone.latitude}, ${zone.longitude}) = ${dist.toStringAsFixed(0)}m (r=${zone.radiusMeters}m) ${dist <= zone.radiusMeters ? "✅" : ""}');
        if (dist <= zone.radiusMeters) familyInRange = true;
      }
      debugPrint('📍 全家 100m 內匹配: $familyInRange');

      // ── Test 4: findNearestStore ──
      final nearest = await service.findNearestStore(
        userLat: userLat,
        userLng: userLng,
      );
      debugPrint('📍 最近門市: ${nearest?.brandName} (${nearest?.distanceText})');
      expect(nearest, isNotNull, reason: '應找到最近門市');

      // ── Test 5: 模擬 _matchByGps 邏輯 ──
      // 建立無 gpsZones 的模擬卡片
      final testCards = [
        MemberCard(
          id: 'test-seven',
          storeName: '7-ELEVEN',
          barcodeValue: '1234567890123',
          barcodeFormat: BarcodeFormatType.code128,
        ),
        MemberCard(
          id: 'test-family',
          storeName: '全家 FamilyMart',
          barcodeValue: '9876543210987',
          barcodeFormat: BarcodeFormatType.code128,
        ),
      ];

      // 模擬 _matchByGps: gpsZones 為空 → 查 store_locations.json
      final matched = <MemberCard>[];
      for (final card in testCards) {
        if (card.gpsZones.isEmpty) {
          final nearbyZones = await service.getNearbyStoreLocations(
            card.storeName,
            userLat: userLat,
            userLng: userLng,
            radiusKm: 0.5,
          );
          final inZone = nearbyZones.any((zone) {
            final dist = _haversine(userLat, userLng, zone.latitude, zone.longitude);
            return dist <= zone.radiusMeters;
          });
          if (inZone) matched.add(card);
          debugPrint('  ${card.storeName}: gpsZones=空, store_locations查詢=${nearbyZones.length}筆, 匹配=$inZone');
        }
      }

      debugPrint('📍 匹配結果: ${matched.map((c) => c.storeName).toList()}');
      expect(matched.any((c) => c.storeName == '7-ELEVEN'), true,
          reason: '7-ELEVEN 應該匹配（26m < 100m）');
      debugPrint('✅ Test 5 PASS: GPS 匹配邏輯驗證成功');

      debugPrint('');
      debugPrint('═══ 全部測試通過 ═══');
    });
  });
}

double _haversine(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371000.0;
  final p = pi / 180;
  final a = sin((lat2 - lat1) * p / 2) * sin((lat2 - lat1) * p / 2) +
      cos(lat1 * p) * cos(lat2 * p) *
      sin((lon2 - lon1) * p / 2) * sin((lon2 - lon1) * p / 2);
  return R * 2 * asin(sqrt(a));
}
