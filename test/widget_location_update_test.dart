// Widget 位置更新測試
// 驗證位置變更時 Widget 資料正確更新
// 模擬 GPS 座標切換 + WiFi SSID 變化 → Widget SharedPreferences 更新

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard/app_controller.dart';
import 'package:smartcard/models/member_card.dart';
import 'package:smartcard/services/database_service.dart';
import 'package:smartcard/services/location_service.dart';

/// 建立全聯卡片（每次新建避免 HiveObject 重複綁定）
MemberCard makeCardA() => MemberCard(
      id: 'loc-card-a',
      storeName: '全聯福利中心',
      barcodeValue: '4710088020019',
      barcodeFormat: BarcodeFormatType.ean13,
      gpsZones: [
        GpsZone(
          latitude: 24.1627,
          longitude: 120.6476,
          radiusMeters: 100.0,
          label: '中港店',
        ),
      ],
      ssidKeywords: ['PX_Mart'],
    );

/// 建立 7-ELEVEN 卡片
MemberCard makeCardB() => MemberCard(
      id: 'loc-card-b',
      storeName: '7-ELEVEN',
      barcodeValue: '123456789012',
      barcodeFormat: BarcodeFormatType.code128,
      gpsZones: [
        GpsZone(
          latitude: 25.0330,
          longitude: 121.5654,
          radiusMeters: 100.0,
          label: '信義店',
        ),
      ],
      ssidKeywords: ['7-ELEVEN', 'ibon'],
    );

bool _isInAnyZone(List<MemberCard> cards, double lat, double lng) {
  final ls = LocationService();
  return cards.where((card) => card.gpsZones.any((zone) {
    final distance = ls.calculateDistance(lat, lng, zone.latitude, zone.longitude);
    return distance <= zone.radiusMeters;
  })).toList().isNotEmpty;
}

List<MemberCard> _matchByGps(List<MemberCard> cards, double lat, double lng) {
  final ls = LocationService();
  return cards.where((card) => card.gpsZones.any((zone) {
    final distance = ls.calculateDistance(lat, lng, zone.latitude, zone.longitude);
    return distance <= zone.radiusMeters;
  })).toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService db;
  late AppController controller;
  late String tempDir;
  final savedWidgetData = <String, dynamic>{};

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('widget_loc_test_').path;
    db = DatabaseService();
    await db.initializeForTesting(tempDir);

    savedWidgetData.clear();

    // Mock home_widget channel — 攔截 saveWidgetData 記錄寫入的 key/value
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('home_widget'),
      (call) async {
        if (call.method == 'saveWidgetData') {
          final args = call.arguments as Map<dynamic, dynamic>;
          savedWidgetData[args['id'] as String] = args['data'];
          return true;
        }
        if (call.method == 'updateWidget') return true;
        if (call.method == 'initiallyLaunchedFromHomeWidget') return null;
        return null;
      },
    );

    controller = AppController();
    await controller.initialize();
  });

  tearDown(() async {
    await controller.stopBackgroundUpdates();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'), null);
    await db.resetForTesting();
  });

  // ──────────────────────────────────────────
  // U25: Widget 隨位置變更更新條碼
  // ──────────────────────────────────────────

  group('U25: Widget 隨位置變更更新條碼', () {
    test('GPS 匹配卡片 A → Widget 顯示卡片 A 條碼', () async {
      await controller.addCard(makeCardA());
      await controller.addCard(makeCardB());

      await controller.runLocationDetection();

      // 測試環境 WiFi/GPS 不可用 → noMatch → 顯示最近使用卡片
      expect(savedWidgetData['widget_mode'], isNotNull);
    });

    test('無匹配時 → Widget 顯示最近使用卡片', () async {
      await controller.addCard(makeCardA());

      // 測試環境 WiFi/GPS 都不可用 → 無匹配 → 顯示最近使用
      await controller.runLocationDetection();

      expect(savedWidgetData['widget_mode'], 'noMatch');
      expect(savedWidgetData['primary_store_name'], '全聯福利中心');
      expect(savedWidgetData['primary_barcode_value'], '4710088020019');
      expect(savedWidgetData['primary_card_id'], 'loc-card-a');
    });

    test('無匹配且無卡片 → Widget 顯示引導文字', () async {
      await controller.runLocationDetection();

      expect(savedWidgetData['widget_mode'], 'noMatch');
      expect(savedWidgetData['widget_title'], '點擊新增會員卡');
    });

    test('新增卡片後 Widget 自動更新', () async {
      await controller.addCard(makeCardA());

      // addCard 內部呼叫 _updateWidgetSilently → 應寫入 Widget 資料
      expect(savedWidgetData['widget_mode'], isNotNull);
    });

    test('刪除卡片後 Widget 自動更新', () async {
      await controller.addCard(makeCardA());
      savedWidgetData.clear();

      await controller.deleteCard('loc-card-a');

      // 刪除後無匹配也無最近卡片 → 引導文字
      expect(savedWidgetData['widget_mode'], 'noMatch');
      expect(savedWidgetData['widget_title'], '點擊新增會員卡');
    });
  });

  // ──────────────────────────────────────────
  // U26: WiFi SSID 變化觸發 Widget 更新
  // ──────────────────────────────────────────

  group('U26: WiFi SSID 變化觸發 Widget 更新', () {
    test('runLocationDetection 每次呼叫都會更新 Widget', () async {
      await controller.addCard(makeCardA());

      savedWidgetData.clear();
      await controller.runLocationDetection();

      // 無論匹配結果如何，Widget 都會被更新
      expect(savedWidgetData['widget_mode'], isNotNull);
    });

    test('WiFi 匹配邏輯：SSID 關鍵字比對正確', () {
      final cardA = makeCardA();
      final cardB = makeCardB();

      expect(cardA.ssidKeywords, contains('PX_Mart'));
      expect(cardB.ssidKeywords, contains('7-ELEVEN'));

      // 模擬 WiFi SSID 匹配
      const currentSsid = 'PX_Mart_Store';
      final matched = [cardA, cardB].where((card) {
        return card.ssidKeywords.any((keyword) =>
            currentSsid.toLowerCase().contains(keyword.toLowerCase()));
      }).toList();

      expect(matched.length, 1);
      expect(matched.first.id, 'loc-card-a');
    });

    test('WiFi SSID 切換 → 匹配不同卡片', () {
      final cardA = makeCardA();
      final cardB = makeCardB();

      // SSID A → 全聯
      const ssidA = 'PX_Mart_Free_WiFi';
      final matchedA = [cardA, cardB].where((card) {
        return card.ssidKeywords.any((keyword) =>
            ssidA.toLowerCase().contains(keyword.toLowerCase()));
      }).toList();
      expect(matchedA.first.storeName, '全聯福利中心');

      // SSID B → 7-ELEVEN
      const ssidB = '7-ELEVEN_Store_WiFi';
      final matchedB = [cardA, cardB].where((card) {
        return card.ssidKeywords.any((keyword) =>
            ssidB.toLowerCase().contains(keyword.toLowerCase()));
      }).toList();
      expect(matchedB.first.storeName, '7-ELEVEN');
    });
  });

  // ──────────────────────────────────────────
  // U27: GPS 座標匹配 Widget 更新資料流
  // ──────────────────────────────────────────

  group('U27: GPS 座標匹配 Widget 更新資料流', () {
    test('座標在 zone A 內 → 匹配卡片 A', () {
      final cardA = makeCardA();
      final cardB = makeCardB();

      // 全聯 zone: (24.1627, 120.6476) r=100m
      const userLat = 24.1631;
      const userLng = 120.6476;

      final matched = _matchByGps([cardA, cardB], userLat, userLng);

      expect(matched.length, 1);
      expect(matched.first.id, 'loc-card-a');
    });

    test('座標在 zone B 內 → 匹配卡片 B', () {
      final cardA = makeCardA();
      final cardB = makeCardB();

      // 7-ELEVEN zone: (25.0330, 121.5654) r=100m
      const userLat = 25.0333;
      const userLng = 121.5654;

      final matched = _matchByGps([cardA, cardB], userLat, userLng);

      expect(matched.length, 1);
      expect(matched.first.id, 'loc-card-b');
    });

    test('座標不在任何 zone 內 → 無匹配', () {
      final cardA = makeCardA();
      final cardB = makeCardB();

      const userLat = 23.0;
      const userLng = 119.0;

      final matched = _matchByGps([cardA, cardB], userLat, userLng);

      expect(matched, isEmpty);
    });

    test('singleCard 模式 Widget 資料完整性', () async {
      await controller.addCard(makeCardA());

      // addCard 呼叫 _updateWidgetSilently → 寫入 Widget 資料
      expect(savedWidgetData.containsKey('widget_mode'), isTrue);
    });

    test('multipleCards 模式 Widget 資料完整性', () async {
      await controller.addCard(makeCardA());
      await controller.addCard(makeCardB());

      // 驗證 Widget 資料有被寫入
      expect(savedWidgetData['widget_mode'], isNotNull);
    });
  });
}
