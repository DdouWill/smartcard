import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smartcard/main.dart' as app;
import 'package:smartcard/services/store_location_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('GPS Match via store_locations.json', () {
    testWidgets('建卡 7-ELEVEN + 全家 → GPS 匹配驗證', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // ── 建第一張卡：7-ELEVEN ──
      await _createCard(tester, '7-ELEVEN', '1234567890123');
      expect(find.text('7-ELEVEN'), findsWidgets);
      debugPrint('✅ 7-ELEVEN 卡片建立成功');

      // ── 建第二張卡：全家 FamilyMart ──
      await _createCard(tester, '全家 FamilyMart', '9876543210987');
      expect(find.text('全家 FamilyMart'), findsWidgets);
      debugPrint('✅ 全家 FamilyMart 卡片建立成功');

      // ── 驗證 GPS 匹配邏輯 ──
      final service = StoreLocationService();
      const userLat = 24.1492072;
      const userLng = 120.6451422;

      // 查 7-ELEVEN 附近門市
      final sevenZones = await service.getNearbyStoreLocations(
        '7-ELEVEN',
        userLat: userLat,
        userLng: userLng,
        radiusKm: 0.5,
      );
      debugPrint('📍 7-ELEVEN zones in 500m: ${sevenZones.length}');
      expect(sevenZones.isNotEmpty, true, reason: '7-ELEVEN 應有門市在 500m 內');

      // 檢查最近的是否在 100m 內
      bool sevenInRange = false;
      for (final zone in sevenZones) {
        final dist = _haversine(userLat, userLng, zone.latitude, zone.longitude);
        debugPrint('  → (${zone.latitude}, ${zone.longitude}) = ${dist.toStringAsFixed(0)}m (r=${zone.radiusMeters}m)');
        if (dist <= zone.radiusMeters) {
          sevenInRange = true;
        }
      }
      expect(sevenInRange, true, reason: '至少一間 7-ELEVEN 應在 100m 匹配半徑內');
      debugPrint('✅ 7-ELEVEN GPS 匹配: 有門市在 100m 內');

      // 查全家附近門市
      final familyZones = await service.getNearbyStoreLocations(
        '全家 FamilyMart',
        userLat: userLat,
        userLng: userLng,
        radiusKm: 0.5,
      );
      debugPrint('📍 全家 zones in 500m: ${familyZones.length}');
      // 全家不一定在 100m 內
      bool familyInRange = false;
      for (final zone in familyZones) {
        final dist = _haversine(userLat, userLng, zone.latitude, zone.longitude);
        if (dist <= zone.radiusMeters) familyInRange = true;
      }
      debugPrint('📍 全家 100m 內: $familyInRange');

      // 測最近門市
      final nearest = await service.findNearestStore(
        userLat: userLat,
        userLng: userLng,
      );
      debugPrint('📍 最近門市: ${nearest?.brandName} (${nearest?.distanceText})');
      expect(nearest, isNotNull);

      // 點定位按鈕觸發偵測
      final locationButton = find.byIcon(Icons.my_location);
      if (locationButton.evaluate().isNotEmpty) {
        await tester.tap(locationButton);
        await tester.pumpAndSettle(const Duration(seconds: 10));
        debugPrint('📍 已觸發定位偵測');
        
        // 截圖看結果
        await tester.pumpAndSettle(const Duration(seconds: 3));
      }

      debugPrint('');
      debugPrint('═══ GPS 匹配測試全部通過 ═══');
    });
  });
}

Future<void> _createCard(WidgetTester tester, String storeName, String barcode) async {
  await tester.tap(find.text('新增卡片'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('手動輸入'));
  await tester.pumpAndSettle();

  // 填店名
  final storeField = find.widgetWithText(TextFormField, '店家名稱 *');
  await tester.enterText(storeField, storeName);
  await tester.pumpAndSettle(const Duration(seconds: 1));

  // 關 autocomplete — 點頁面標題
  await tester.tap(find.text('新增會員卡'));
  await tester.pumpAndSettle();

  // 選 CODE128
  await tester.tap(find.text('CODE128'));
  await tester.pumpAndSettle();

  // 填條碼
  await tester.enterText(
    find.widgetWithText(TextFormField, '條碼號碼 *'),
    barcode,
  );
  await tester.pumpAndSettle();

  // 捲到底部，儲存
  await tester.ensureVisible(find.text('儲存卡片'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('儲存卡片'));
  await tester.pumpAndSettle(const Duration(seconds: 3));

  // 確認對話框
  final confirm = find.text('確認儲存');
  if (confirm.evaluate().isNotEmpty) {
    await tester.tap(confirm);
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }
}

double _haversine(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371000.0;
  final p = pi / 180;
  final a = sin((lat2 - lat1) * p / 2) * sin((lat2 - lat1) * p / 2) +
      cos(lat1 * p) * cos(lat2 * p) *
      sin((lon2 - lon1) * p / 2) * sin((lon2 - lon1) * p / 2);
  return R * 2 * asin(sqrt(a));
}
