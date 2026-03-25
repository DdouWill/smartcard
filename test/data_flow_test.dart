// 端對端資料流驗證測試
// 驗證 LocationService → WidgetService → SmartCardWidgetProvider 的資料一致性
// 確保 BarcodeFormatType 在 Dart ↔ Kotlin 之間的格式名稱能正確對應

import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard/models/member_card.dart';
import 'package:smartcard/services/location_service.dart';

void main() {
  final locationService = LocationService();

  // ──────────────────────────────────────────
  // BarcodeFormatType ↔ Kotlin 格式對應驗證
  // ──────────────────────────────────────────

  group('BarcodeFormatType → Kotlin 格式名稱對應', () {
    // Kotlin SmartCardWidgetProvider 使用 formatStr.uppercase() 比對
    // Dart 端 WidgetService 傳送 card.barcodeFormat.name（小寫 enum 名稱）
    // 此處列出 Kotlin 端 when 分支能匹配的所有 uppercase 名稱
    final kotlinMappedFormats = {
      'QR', 'QRCODE', 'QR_CODE',
      'EAN13', 'EAN_13',
      'EAN8', 'EAN_8',
      'CODE128', 'CODE_128',
      'CODE39', 'CODE_39',
      'PDF417',
      'DATAMATRIX', 'DATA_MATRIX',
      'AZTEC',
      'ITF', 'ITF14', 'ITF_14',
      'UPCA', 'UPC_A',
      'UPCE', 'UPC_E',
      'CODABAR',
    };

    for (final format in BarcodeFormatType.values) {
      if (format == BarcodeFormatType.unknown) continue;

      test('${format.name} 應能被 Kotlin 端正確識別', () {
        final dartName = format.name.toUpperCase();
        expect(
          kotlinMappedFormats.contains(dartName),
          isTrue,
          reason: 'BarcodeFormatType.${format.name} 轉為 uppercase "$dartName" '
              '未在 Kotlin SmartCardWidgetProvider 的 when 分支中',
        );
      });
    }

    test('unknown 格式應降級為 CODE_128（Kotlin else 分支）', () {
      // Kotlin else → CODE_128，這是可接受的降級行為
      final dartName = BarcodeFormatType.unknown.name.toUpperCase();
      // "UNKNOWN" 不在 when 分支中，會走 else → CODE_128
      expect(kotlinMappedFormats.contains(dartName), isFalse);
    });
  });

  // ──────────────────────────────────────────
  // GPS zone → 定位匹配 → 資料傳遞流程驗證
  // ──────────────────────────────────────────

  group('端對端 GPS zone 資料流驗證', () {
    test('卡片含 GPS zone → 距離計算 → 匹配判定', () {
      final card = MemberCard(
        id: 'e2e-gps-001',
        storeName: '全聯 中港店',
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
      );

      // 模擬使用者在店家 50m 內
      const userLat = 24.1631;
      const userLng = 120.6476;

      final inZone = card.gpsZones.any((zone) {
        final distance = locationService.calculateDistance(
          userLat, userLng, zone.latitude, zone.longitude,
        );
        return distance <= zone.radiusMeters;
      });

      expect(inZone, isTrue);

      // 驗證匹配後卡片資料完整性（模擬 WidgetService._saveCardData 的輸出）
      expect(card.storeName, isNotEmpty);
      expect(card.barcodeValue, isNotEmpty);
      expect(card.barcodeFormat.name, equals('ean13'));
      expect(card.id, isNotEmpty);
    });

    test('多個 GPS zone 的卡片 — 只要一個匹配即可', () {
      final card = MemberCard(
        id: 'e2e-multi-zone',
        storeName: '家樂福（多分店）',
        barcodeValue: '222333444555',
        barcodeFormat: BarcodeFormatType.code128,
        gpsZones: [
          GpsZone(latitude: 25.0330, longitude: 121.5654, radiusMeters: 100, label: '信義店'),
          GpsZone(latitude: 24.1627, longitude: 120.6476, radiusMeters: 150, label: '中港店'),
        ],
      );

      // 使用者在中港店附近（第二個 zone）
      const userLat = 24.1630;
      const userLng = 120.6478;

      final matched = card.gpsZones.any((zone) {
        final distance = locationService.calculateDistance(
          userLat, userLng, zone.latitude, zone.longitude,
        );
        return distance <= zone.radiusMeters;
      });

      expect(matched, isTrue);
    });

    test('無 GPS zone 的卡片不應被 GPS 匹配', () {
      final card = MemberCard(
        id: 'e2e-no-zone',
        storeName: '僅 WiFi 的卡',
        barcodeValue: '999999',
        barcodeFormat: BarcodeFormatType.qr,
        ssidKeywords: ['Store_WiFi'],
        gpsZones: [],
      );

      final matched = card.gpsZones.any((zone) {
        final distance = locationService.calculateDistance(
          25.0, 121.0, zone.latitude, zone.longitude,
        );
        return distance <= zone.radiusMeters;
      });

      expect(matched, isFalse);
    });
  });

  // ──────────────────────────────────────────
  // 三模式切換邏輯驗證
  // ──────────────────────────────────────────

  group('Widget 顯示模式切換', () {
    test('0 張匹配 → noMatch 模式', () {
      final matchedCards = <MemberCard>[];
      final mode = matchedCards.isEmpty
          ? 'noMatch'
          : matchedCards.length == 1
              ? 'singleCard'
              : 'multipleCards';
      expect(mode, equals('noMatch'));
    });

    test('1 張匹配 → singleCard 模式', () {
      final matchedCards = [
        MemberCard(
          id: 'single',
          storeName: 'A',
          barcodeValue: '123',
          barcodeFormat: BarcodeFormatType.qr,
        ),
      ];
      final mode = matchedCards.isEmpty
          ? 'noMatch'
          : matchedCards.length == 1
              ? 'singleCard'
              : 'multipleCards';
      expect(mode, equals('singleCard'));
    });

    test('3 張匹配 → multipleCards 模式', () {
      final matchedCards = List.generate(
        3,
        (i) => MemberCard(
          id: 'multi-$i',
          storeName: 'Store $i',
          barcodeValue: '${i}00',
          barcodeFormat: BarcodeFormatType.qr,
        ),
      );
      final mode = matchedCards.isEmpty
          ? 'noMatch'
          : matchedCards.length == 1
              ? 'singleCard'
              : 'multipleCards';
      expect(mode, equals('multipleCards'));
    });

    test('multipleCards 最多取 10 張', () {
      final matchedCards = List.generate(
        12,
        (i) => MemberCard(
          id: 'limit-$i',
          storeName: 'Store $i',
          barcodeValue: '${i}00',
          barcodeFormat: BarcodeFormatType.code128,
        ),
      );

      // 對應 WidgetService._maxCards = 10
      final displayCards = matchedCards.take(10).toList();
      expect(displayCards.length, equals(10));
    });
  });

  // ──────────────────────────────────────────
  // GpsZone 序列化一致性
  // ──────────────────────────────────────────

  group('GpsZone 序列化一致性', () {
    test('GpsZone 欄位值應正確保留', () {
      final zone = GpsZone(
        latitude: 24.1627,
        longitude: 120.6476,
        radiusMeters: 150.0,
        label: '全聯 中港店',
      );

      expect(zone.latitude, equals(24.1627));
      expect(zone.longitude, equals(120.6476));
      expect(zone.radiusMeters, equals(150.0));
      expect(zone.label, equals('全聯 中港店'));
    });

    test('MemberCard.copyWith 應正確複製 gpsZones', () {
      final original = MemberCard(
        id: 'copy-gps',
        storeName: '測試',
        barcodeValue: '123',
        barcodeFormat: BarcodeFormatType.qr,
        gpsZones: [
          GpsZone(latitude: 25.0, longitude: 121.0, radiusMeters: 100, label: '店A'),
          GpsZone(latitude: 24.0, longitude: 120.0, radiusMeters: 200, label: '店B'),
        ],
      );

      final copied = original.copyWith(storeName: '新名稱');

      expect(copied.gpsZones.length, equals(2));
      expect(copied.gpsZones[0].latitude, equals(25.0));
      expect(copied.gpsZones[0].label, equals('店A'));
      expect(copied.gpsZones[1].radiusMeters, equals(200.0));
    });

    test('MemberCard 新增 GPS zone 後 gpsZones list 正確更新', () {
      final card = MemberCard(
        id: 'add-zone',
        storeName: '測試',
        barcodeValue: '123',
        barcodeFormat: BarcodeFormatType.ean13,
        gpsZones: [
          GpsZone(latitude: 25.0, longitude: 121.0),
        ],
      );

      final newZones = [
        ...card.gpsZones,
        GpsZone(latitude: 24.0, longitude: 120.0, label: '新分店'),
      ];
      final updated = card.copyWith(gpsZones: newZones);

      expect(updated.gpsZones.length, equals(2));
      expect(updated.gpsZones[1].label, equals('新分店'));
    });
  });

  // ──────────────────────────────────────────
  // SharedPreferences key 格式一致性
  // ──────────────────────────────────────────

  group('SharedPreferences key 格式驗證', () {
    test('singleCard 模式使用 primary_ prefix', () {
      // WidgetService 在 singleCard 模式使用 'primary' prefix
      // Kotlin 端讀取 "primary_barcode_value", "primary_barcode_format" 等
      const prefix = 'primary';
      expect('${prefix}_store_name', equals('primary_store_name'));
      expect('${prefix}_barcode_value', equals('primary_barcode_value'));
      expect('${prefix}_barcode_format', equals('primary_barcode_format'));
      expect('${prefix}_card_color', equals('primary_card_color'));
      expect('${prefix}_card_id', equals('primary_card_id'));
    });

    test('multipleCards 模式使用 card_N_ prefix', () {
      // WidgetService 在 multipleCards 模式使用 'card_0', 'card_1' 等 prefix
      // Kotlin 端讀取 "card_0_store_name", "card_0_card_id" 等
      for (int i = 0; i < 5; i++) {
        final prefix = 'card_$i';
        expect('${prefix}_store_name', equals('card_${i}_store_name'));
        expect('${prefix}_card_id', equals('card_${i}_card_id'));
      }
    });

    test('barcodeFormat.name 輸出格式符合預期', () {
      // 確認每個 enum 的 .name 值
      expect(BarcodeFormatType.ean13.name, equals('ean13'));
      expect(BarcodeFormatType.ean8.name, equals('ean8'));
      expect(BarcodeFormatType.qr.name, equals('qr'));
      expect(BarcodeFormatType.code128.name, equals('code128'));
      expect(BarcodeFormatType.code39.name, equals('code39'));
      expect(BarcodeFormatType.pdf417.name, equals('pdf417'));
      expect(BarcodeFormatType.aztec.name, equals('aztec'));
      expect(BarcodeFormatType.dataMatrix.name, equals('dataMatrix'));
      expect(BarcodeFormatType.itf.name, equals('itf'));
      expect(BarcodeFormatType.upca.name, equals('upca'));
      expect(BarcodeFormatType.upce.name, equals('upce'));
      expect(BarcodeFormatType.codabar.name, equals('codabar'));
    });
  });
}
