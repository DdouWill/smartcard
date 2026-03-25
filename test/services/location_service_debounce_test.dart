import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard/services/location_service.dart';
import 'package:smartcard/models/member_card.dart';

void main() {
  // ──────────────────────────────────────────
  // U22: LocationService 30 秒 debounce
  // ──────────────────────────────────────────

  group('U22: LocationService debounce 邏輯', () {
    test('singleton 且首次無快取（首次呼叫走真實邏輯）', () async {
      final a = LocationService();
      final b = LocationService();
      expect(identical(a, b), isTrue);

      // 首次呼叫（兩源關閉）應走真實邏輯回傳空結果，而非快取
      final result = await a.matchCardsByLocation(
        allCards: [
          MemberCard(
            id: 'debounce-1',
            storeName: '測試',
            barcodeValue: '123',
            barcodeFormat: BarcodeFormatType.qr,
          ),
        ],
        enableWifi: false,
        enableGps: false,
      );

      expect(result.matchedCards, isEmpty);
      expect(result.trigger, LocationTrigger.none);
    });

    test('debounce window 內不同 allCards → 仍回傳第一次快取結果', () async {
      final service = LocationService();

      final cardsA = [
        MemberCard(
          id: 'debounce-a',
          storeName: '卡片A',
          barcodeValue: '111',
          barcodeFormat: BarcodeFormatType.qr,
        ),
      ];

      final result1 = await service.matchCardsByLocation(
        allCards: cardsA,
        enableWifi: false,
        enableGps: false,
      );

      // 在 debounce window 內用不同 cards 呼叫
      final cardsB = [
        MemberCard(
          id: 'debounce-b',
          storeName: '卡片B',
          barcodeValue: '222',
          barcodeFormat: BarcodeFormatType.ean13,
        ),
        MemberCard(
          id: 'debounce-c',
          storeName: '卡片C',
          barcodeValue: '333',
          barcodeFormat: BarcodeFormatType.code128,
        ),
      ];

      final result2 = await service.matchCardsByLocation(
        allCards: cardsB,
        enableWifi: false,
        enableGps: false,
      );

      // 第二次應回傳快取（與第一次 identical）
      expect(identical(result1, result2), isTrue);
    });

    test('matchCardsByLocation 兩源皆關閉 → 回傳空結果', () async {
      final service = LocationService();
      final result = await service.matchCardsByLocation(
        allCards: [
          MemberCard(
            id: 'debounce-1',
            storeName: '測試',
            barcodeValue: '123',
            barcodeFormat: BarcodeFormatType.qr,
          ),
        ],
        enableWifi: false,
        enableGps: false,
      );

      expect(result.matchedCards, isEmpty);
      expect(result.trigger, LocationTrigger.none);
    });

    test('連續兩次呼叫（兩源皆關閉）→ 第二次回傳快取結果', () async {
      final service = LocationService();
      final cards = [
        MemberCard(
          id: 'debounce-2',
          storeName: '測試',
          barcodeValue: '456',
          barcodeFormat: BarcodeFormatType.qr,
        ),
      ];

      final result1 = await service.matchCardsByLocation(
        allCards: cards,
        enableWifi: false,
        enableGps: false,
      );

      // Second call within 30s should return cached result
      final result2 = await service.matchCardsByLocation(
        allCards: cards,
        enableWifi: false,
        enableGps: false,
      );

      // Both should be empty (no WiFi/GPS) and identical due to debounce
      expect(result1.trigger, LocationTrigger.none);
      expect(result2.trigger, LocationTrigger.none);
      expect(result2.matchedCards, isEmpty);
      // The second call returns the cached object
      expect(identical(result1, result2), isTrue);
    });
  });
}
