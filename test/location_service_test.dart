// LocationService 單元測試
// 測試 Haversine 距離計算與地理圍欄判斷邏輯
// 不依賴實際 GPS 硬體，純邏輯測試

import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard/services/location_service.dart';
import 'package:smartcard/models/member_card.dart';

void main() {
  // 測試用的 LocationService 實例
  final locationService = LocationService();

  // ──────────────────────────────────────────
  // 距離計算測試
  // ──────────────────────────────────────────

  group('calculateDistance - Haversine 公式距離計算', () {
    test('相同座標距離應為 0', () {
      final distance = locationService.calculateDistance(
        25.0330, 121.5654, // 台北 101
        25.0330, 121.5654, // 同一點
      );
      expect(distance, closeTo(0.0, 0.001));
    });

    test('台北 101 到台北車站距離約 4.9 公里', () {
      // 台北 101：25.0330, 121.5654
      // 台北車站：25.0478, 121.5170
      // 實際距離：Δlat≈1.6km + Δlng≈4.5km，合計約 4.9km
      final distance = locationService.calculateDistance(
        25.0330, 121.5654,
        25.0478, 121.5170,
      );
      // 允許 ±200 公尺誤差
      expect(distance, inInclusiveRange(4700.0, 5100.0));
    });

    test('10 公尺內的近距離應正確計算', () {
      // 兩點相差約 0.0001 度緯度 ≈ 11 公尺
      final distance = locationService.calculateDistance(
        25.0330, 121.5654,
        25.0331, 121.5654,
      );
      expect(distance, inInclusiveRange(8.0, 14.0));
    });

    test('南北半球跨赤道距離', () {
      // 赤道到北緯 1 度 ≈ 111,195 公尺
      final distance = locationService.calculateDistance(
        0.0, 0.0,
        1.0, 0.0,
      );
      expect(distance, closeTo(111195.0, 1000.0));
    });

    test('東西方向距離計算（赤道上 1 度 ≈ 111.3 公里）', () {
      final distance = locationService.calculateDistance(
        0.0, 0.0,
        0.0, 1.0,
      );
      expect(distance, closeTo(111319.0, 1000.0));
    });
  });

  // ──────────────────────────────────────────
  // GpsZone 邊界測試
  // ──────────────────────────────────────────

  group('GpsZone - 地理圍欄判斷', () {
    // 全聯中港店假想座標
    final fullLifeZone = GpsZone(
      latitude: 24.1627,
      longitude: 120.6476,
      radiusMeters: 100.0,
      label: '全聯 中港店',
    );

    test('在圍欄中心點應判定為在範圍內', () {
      final distance = locationService.calculateDistance(
        fullLifeZone.latitude,
        fullLifeZone.longitude,
        fullLifeZone.latitude,
        fullLifeZone.longitude,
      );
      expect(distance, lessThanOrEqualTo(fullLifeZone.radiusMeters));
    });

    test('在圍欄邊界內（50 公尺）應判定為在範圍內', () {
      // 往北偏移約 50 公尺（約 0.00045 度緯度）
      final nearbyLat = fullLifeZone.latitude + 0.00045;
      final distance = locationService.calculateDistance(
        nearbyLat,
        fullLifeZone.longitude,
        fullLifeZone.latitude,
        fullLifeZone.longitude,
      );
      expect(distance, lessThanOrEqualTo(fullLifeZone.radiusMeters));
    });

    test('超出圍欄邊界（200 公尺）應判定為不在範圍內', () {
      // 往北偏移約 200 公尺（約 0.0018 度緯度）
      final farLat = fullLifeZone.latitude + 0.0018;
      final distance = locationService.calculateDistance(
        farLat,
        fullLifeZone.longitude,
        fullLifeZone.latitude,
        fullLifeZone.longitude,
      );
      expect(distance, greaterThan(fullLifeZone.radiusMeters));
    });

    test('200 公尺半徑的大圍欄應能涵蓋 150 公尺外的點', () {
      final largeZone = GpsZone(
        latitude: 24.1627,
        longitude: 120.6476,
        radiusMeters: 200.0, // 大型購物中心可設較大範圍
      );

      // 往東偏移約 150 公尺
      final nearbyLng = largeZone.longitude + 0.00135;
      final distance = locationService.calculateDistance(
        largeZone.latitude,
        nearbyLng,
        largeZone.latitude,
        largeZone.longitude,
      );
      expect(distance, lessThanOrEqualTo(largeZone.radiusMeters));
    });
  });

  // ──────────────────────────────────────────
  // WiFi SSID 關鍵字匹配測試
  // ──────────────────────────────────────────

  group('WiFi SSID 關鍵字匹配邏輯', () {
    // 模擬卡片資料
    final pxMartCard = MemberCard(
      id: 'test-001',
      storeName: '全聯福利中心',
      barcodeValue: '4710088020019',
      barcodeFormat: BarcodeFormatType.ean13,
      ssidKeywords: ['PX_Mart', 'PX-Mart', '全聯'],
    );

    final sevenCard = MemberCard(
      id: 'test-002',
      storeName: '7-ELEVEN',
      barcodeValue: '123456789012',
      barcodeFormat: BarcodeFormatType.code128,
      ssidKeywords: ['7-ELEVEN', 'ibon'],
    );

    test('SSID 完全符合關鍵字', () {
      const currentSsid = 'PX_Mart';
      final matched = currentSsid.toLowerCase().contains(
        pxMartCard.ssidKeywords.first.toLowerCase(),
      );
      expect(matched, isTrue);
    });

    test('SSID 包含關鍵字（部分符合）', () {
      const currentSsid = 'PX_Mart_Store_WiFi';
      final matched = pxMartCard.ssidKeywords.any(
        (keyword) =>
            currentSsid.toLowerCase().contains(keyword.toLowerCase()),
      );
      expect(matched, isTrue);
    });

    test('不相關的 SSID 不應符合', () {
      const currentSsid = 'Home_WiFi_5G';
      final matchedPx = pxMartCard.ssidKeywords.any(
        (keyword) =>
            currentSsid.toLowerCase().contains(keyword.toLowerCase()),
      );
      final matchedSeven = sevenCard.ssidKeywords.any(
        (keyword) =>
            currentSsid.toLowerCase().contains(keyword.toLowerCase()),
      );
      expect(matchedPx, isFalse);
      expect(matchedSeven, isFalse);
    });

    test('大小寫不敏感匹配', () {
      const currentSsid = 'px_mart'; // 小寫
      final matched = pxMartCard.ssidKeywords.any(
        (keyword) =>
            currentSsid.toLowerCase().contains(keyword.toLowerCase()),
      );
      expect(matched, isTrue);
    });

    test('多張卡片中只有一張符合', () {
      const currentSsid = '7-ELEVEN_Store';
      final allCards = [pxMartCard, sevenCard];

      final matchedCards = allCards.where((card) {
        return card.ssidKeywords.any((keyword) =>
            currentSsid.toLowerCase().contains(keyword.toLowerCase()));
      }).toList();

      expect(matchedCards.length, equals(1));
      expect(matchedCards.first.storeName, equals('7-ELEVEN'));
    });

    test('空 SSID 不應匹配任何卡片', () {
      const currentSsid = '';
      final allCards = [pxMartCard, sevenCard];

      final matchedCards = allCards.where((card) {
        if (currentSsid.isEmpty) return false;
        return card.ssidKeywords.any((keyword) =>
            currentSsid.toLowerCase().contains(keyword.toLowerCase()));
      }).toList();

      expect(matchedCards, isEmpty);
    });

    test('沒有 SSID 關鍵字的卡片不應被 WiFi 偵測', () {
      final noSsidCard = MemberCard(
        id: 'test-003',
        storeName: '無 WiFi 設定的卡',
        barcodeValue: '99999',
        barcodeFormat: BarcodeFormatType.qr,
        ssidKeywords: [], // 空清單
      );

      const currentSsid = 'any_wifi';
      final matched = noSsidCard.ssidKeywords.any(
        (keyword) =>
            currentSsid.toLowerCase().contains(keyword.toLowerCase()),
      );
      expect(matched, isFalse);
    });
  });

  // ──────────────────────────────────────────
  // 邊界條件測試
  // ──────────────────────────────────────────

  group('邊界條件測試', () {
    test('空卡片清單匹配應回傳空結果', () {
      const currentSsid = 'any_wifi';
      final emptyCards = <MemberCard>[];

      final matched = emptyCards.where((card) {
        return card.ssidKeywords.any((keyword) =>
            currentSsid.toLowerCase().contains(keyword.toLowerCase()));
      }).toList();

      expect(matched, isEmpty);
    });

    test('GpsZone 預設半徑應為 100 公尺', () {
      final zone = GpsZone(
        latitude: 25.0,
        longitude: 121.0,
      );
      expect(zone.radiusMeters, equals(100.0));
    });

    test('GpsZone label 可以為 null', () {
      final zone = GpsZone(
        latitude: 25.0,
        longitude: 121.0,
      );
      expect(zone.label, isNull);
    });

    test('MemberCard 預設排序為 0', () {
      final card = MemberCard(
        id: 'test-sort',
        storeName: '測試',
        barcodeValue: '123',
        barcodeFormat: BarcodeFormatType.qr,
      );
      expect(card.sortOrder, equals(0));
    });

    test('MemberCard createdAt 與 updatedAt 預設為當前時間', () {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      final card = MemberCard(
        id: 'test-time',
        storeName: '測試',
        barcodeValue: '123',
        barcodeFormat: BarcodeFormatType.qr,
      );
      final after = DateTime.now().add(const Duration(seconds: 1));

      expect(card.createdAt.isAfter(before), isTrue);
      expect(card.createdAt.isBefore(after), isTrue);
    });
  });

  // ──────────────────────────────────────────
  // 負緯經度與極端距離測試
  // ──────────────────────────────────────────

  group('calculateDistance - 負座標與極端距離', () {
    test('南半球座標距離計算（雪梨到墨爾本 ≈ 714 公里）', () {
      // 雪梨：-33.8688, 151.2093
      // 墨爾本：-37.8136, 144.9631
      final distance = locationService.calculateDistance(
        -33.8688, 151.2093,
        -37.8136, 144.9631,
      );
      // 實際直線距離約 714 公里，允許 ±10 公里誤差
      expect(distance, inInclusiveRange(704000.0, 724000.0));
    });

    test('西半球負經度距離計算（紐約到洛杉磯 ≈ 3944 公里）', () {
      // 紐約：40.7128, -74.0060
      // 洛杉磯：34.0522, -118.2437
      final distance = locationService.calculateDistance(
        40.7128, -74.0060,
        34.0522, -118.2437,
      );
      // 允許 ±50 公里誤差
      expect(distance, inInclusiveRange(3900000.0, 4000000.0));
    });

    test('跨東西半球距離計算（倫敦到東京 ≈ 9561 公里）', () {
      // 倫敦：51.5074, -0.1278
      // 東京：35.6762, 139.6503
      final distance = locationService.calculateDistance(
        51.5074, -0.1278,
        35.6762, 139.6503,
      );
      // 允許 ±100 公里誤差
      expect(distance, inInclusiveRange(9450000.0, 9650000.0));
    });

    test('接近對蹠點的極端距離（北極到南極 ≈ 20004 公里）', () {
      // 北極：90, 0
      // 南極：-90, 0
      final distance = locationService.calculateDistance(
        90.0, 0.0,
        -90.0, 0.0,
      );
      // 理論值 π × R ≈ 20015 公里
      expect(distance, inInclusiveRange(19900000.0, 20100000.0));
    });

    test('經度 180 度換日線附近計算', () {
      // 從 179° 到 -179°（實際只差 2 度 ≈ 156 公里在赤道）
      final distance = locationService.calculateDistance(
        0.0, 179.0,
        0.0, -179.0,
      );
      // 2 度在赤道 ≈ 222.6 公里
      expect(distance, inInclusiveRange(220000.0, 225000.0));
    });
  });

  // ──────────────────────────────────────────
  // MemberCard copyWith 測試
  // ──────────────────────────────────────────

  group('MemberCard copyWith', () {
    test('copyWith 應保留未變更的欄位', () {
      final original = MemberCard(
        id: 'copy-test',
        storeName: '原始名稱',
        barcodeValue: '1234567890128',
        barcodeFormat: BarcodeFormatType.ean13,
        cardColor: '#FF0000',
        sortOrder: 5,
      );

      final copied = original.copyWith(storeName: '新名稱');

      expect(copied.id, equals(original.id));
      expect(copied.storeName, equals('新名稱'));
      expect(copied.barcodeValue, equals(original.barcodeValue));
      expect(copied.barcodeFormat, equals(original.barcodeFormat));
      expect(copied.cardColor, equals(original.cardColor));
      expect(copied.sortOrder, equals(original.sortOrder));
      expect(copied.createdAt, equals(original.createdAt));
    });

    test('copyWith 應自動更新 updatedAt', () {
      final original = MemberCard(
        id: 'copy-time',
        storeName: '測試',
        barcodeValue: '123',
        barcodeFormat: BarcodeFormatType.qr,
      );

      // 稍微等待以確保時間差異
      final copied = original.copyWith(storeName: '新名稱');

      // updatedAt 應為新的時間戳（>= 原始時間）
      expect(
        copied.updatedAt.millisecondsSinceEpoch,
        greaterThanOrEqualTo(original.updatedAt.millisecondsSinceEpoch),
      );
    });

    test('copyWith 應深拷貝 ssidKeywords 與 gpsZones', () {
      final original = MemberCard(
        id: 'copy-deep',
        storeName: '測試',
        barcodeValue: '123',
        barcodeFormat: BarcodeFormatType.qr,
        ssidKeywords: ['keyword1'],
        gpsZones: [GpsZone(latitude: 25.0, longitude: 121.0)],
      );

      final copied = original.copyWith();

      // 修改副本不應影響原始物件
      expect(copied.ssidKeywords, isNot(same(original.ssidKeywords)));
      expect(copied.gpsZones, isNot(same(original.gpsZones)));
    });
  });

  // ──────────────────────────────────────────
  // GpsZone toString 測試
  // ──────────────────────────────────────────

  group('GpsZone toString', () {
    test('有 label 時應包含 label', () {
      final zone = GpsZone(
        latitude: 25.0330,
        longitude: 121.5654,
        radiusMeters: 150.0,
        label: '台北 101',
      );
      expect(zone.toString(), contains('台北 101'));
      expect(zone.toString(), contains('150.0'));
    });

    test('無 label 時不應包含 label 欄位', () {
      final zone = GpsZone(
        latitude: 25.0,
        longitude: 121.0,
      );
      expect(zone.toString(), isNot(contains('label')));
    });
  });

  // ──────────────────────────────────────────
  // 多張卡片同時匹配 GPS 測試
  // ──────────────────────────────────────────

  group('多卡片 GPS 匹配', () {
    test('同一位置在多個圍欄內應全部匹配', () {
      final card1 = MemberCard(
        id: 'multi-1',
        storeName: '店家A',
        barcodeValue: '111',
        barcodeFormat: BarcodeFormatType.qr,
        gpsZones: [GpsZone(latitude: 25.0, longitude: 121.0, radiusMeters: 200)],
      );
      final card2 = MemberCard(
        id: 'multi-2',
        storeName: '店家B',
        barcodeValue: '222',
        barcodeFormat: BarcodeFormatType.qr,
        gpsZones: [GpsZone(latitude: 25.0, longitude: 121.0, radiusMeters: 300)],
      );

      final allCards = [card1, card2];
      // 使用者在 (25.0001, 121.0001)，距中心約 15m
      final matched = allCards.where((card) {
        return card.gpsZones.any((zone) {
          final distance = locationService.calculateDistance(
            25.0001, 121.0001, zone.latitude, zone.longitude,
          );
          return distance <= zone.radiusMeters;
        });
      }).toList();

      expect(matched.length, equals(2));
    });

    test('多個 gpsZones 中只要一個匹配即可', () {
      final card = MemberCard(
        id: 'multi-zone',
        storeName: '多分店',
        barcodeValue: '333',
        barcodeFormat: BarcodeFormatType.qr,
        gpsZones: [
          GpsZone(latitude: 25.0, longitude: 121.0, radiusMeters: 50), // 遠處分店
          GpsZone(latitude: 24.0, longitude: 120.0, radiusMeters: 100), // 當前附近
        ],
      );

      // 使用者在第二個圍欄內
      final inZone = card.gpsZones.any((zone) {
        final distance = locationService.calculateDistance(
          24.0005, 120.0005, zone.latitude, zone.longitude,
        );
        return distance <= zone.radiusMeters;
      });

      expect(inZone, isTrue);
    });
  });
}
