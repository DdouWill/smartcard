import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard/models/member_card.dart';
import 'package:smartcard/services/store_location_service.dart';
import 'package:smartcard/services/widget_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final savedData = <String, dynamic>{};
  final widgetService = WidgetService();

  setUp(() {
    savedData.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('home_widget'),
      (call) async {
        if (call.method == 'saveWidgetData') {
          final args = call.arguments as Map<dynamic, dynamic>;
          savedData[args['id'] as String] = args['data'];
          return true;
        }
        if (call.method == 'updateWidget') {
          return true;
        }
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'), null);
  });

  MemberCard createCard({
    required String id,
    required String storeName,
    String barcodeValue = 'CODE123',
    BarcodeFormatType format = BarcodeFormatType.qr,
    String cardColor = '#2196F3',
  }) {
    return MemberCard(
      id: id,
      storeName: storeName,
      barcodeValue: barcodeValue,
      barcodeFormat: format,
      cardColor: cardColor,
    );
  }

  // ──────────────────────────────────────────
  // U14: WidgetService noMatch mode
  // ──────────────────────────────────────────
  group('U14: noMatch mode', () {
    test('0 匹配 + 有最近卡片 → 寫入 noMatch + primary_* keys', () async {
      final recentCard = createCard(
        id: 'recent-1',
        storeName: '最近店家',
        barcodeValue: 'RECENT-CODE',
        cardColor: '#FF0000',
      );

      await widgetService.updateWidget(
        matchedCards: [],
        recentCard: recentCard,
      );

      expect(savedData['widget_mode'], 'noMatch');
      expect(savedData['widget_title'], '最近使用');
      expect(savedData['primary_store_name'], '最近店家');
      expect(savedData['primary_barcode_value'], 'RECENT-CODE');
      expect(savedData['primary_card_id'], 'recent-1');
    });

    test('0 匹配 + 無最近卡片 → 顯示引導文字', () async {
      await widgetService.updateWidget(
        matchedCards: [],
        recentCard: null,
      );

      expect(savedData['widget_mode'], 'noMatch');
      expect(savedData['widget_title'], '點擊新增會員卡');
      expect(savedData['primary_store_name'], '');
      expect(savedData['primary_barcode_value'], '');
    });

    test('0 匹配 + nearestStore 非 null → 寫入 nearest_store_text', () async {
      final recentCard = createCard(id: 'r1', storeName: '測試', barcodeValue: 'X');
      await widgetService.updateWidget(
        matchedCards: [],
        recentCard: recentCard,
        nearestStore: NearestStoreInfo(
          brandName: '7-ELEVEN',
          distanceMeters: 200,
          zone: GpsZone(latitude: 25.0, longitude: 121.0),
        ),
      );
      expect(savedData['nearest_store_text'], '7-ELEVEN（200m）');
    });

    test('nearestStore 為 null → nearest_store_text 為空字串', () async {
      await widgetService.updateWidget(matchedCards: [], recentCard: null, nearestStore: null);
      expect(savedData['nearest_store_text'], '');
    });
  });

  // ──────────────────────────────────────────
  // U15: WidgetService singleCard mode
  // ──────────────────────────────────────────
  group('U15: singleCard mode', () {
    test('1 匹配 → 寫入 singleCard + 正確 key/value', () async {
      final card = createCard(
        id: 'single-1',
        storeName: '全聯福利中心',
        barcodeValue: 'SINGLE-CODE',
        format: BarcodeFormatType.ean13,
        cardColor: '#4CAF50',
      );

      await widgetService.updateWidget(matchedCards: [card]);

      expect(savedData['widget_mode'], 'singleCard');
      expect(savedData['widget_title'], '全聯福利中心');
      expect(savedData['primary_store_name'], '全聯福利中心');
      expect(savedData['primary_barcode_value'], 'SINGLE-CODE');
      expect(savedData['primary_barcode_format'], 'ean13');
      expect(savedData['primary_card_color'], '#4CAF50');
      expect(savedData['primary_card_id'], 'single-1');
    });
  });

  // ──────────────────────────────────────────
  // U16: WidgetService multipleCards mode
  // ──────────────────────────────────────────
  group('U16: multipleCards mode', () {
    test('5 匹配 → 寫入 card_0 ~ card_4', () async {
      final cards = List.generate(
        5,
        (i) => createCard(
          id: 'card-$i',
          storeName: '店家$i',
          barcodeValue: 'CODE-$i',
        ),
      );

      await widgetService.updateWidget(matchedCards: cards);

      expect(savedData['widget_mode'], 'multipleCards');
      expect(savedData['widget_title'], '附近 5 家店');
      expect(savedData['card_count'], 5);

      for (int i = 0; i < 5; i++) {
        expect(savedData['card_${i}_store_name'], '店家$i');
        expect(savedData['card_${i}_barcode_value'], 'CODE-$i');
        expect(savedData['card_${i}_card_id'], 'card-$i');
      }
    });

    test('超過 10 張卡片 → 截斷為 10', () async {
      final cards = List.generate(
        12,
        (i) => createCard(
          id: 'many-$i',
          storeName: '店$i',
          barcodeValue: 'M-$i',
        ),
      );

      await widgetService.updateWidget(matchedCards: cards);

      expect(savedData['widget_mode'], 'multipleCards');
      expect(savedData['widget_title'], '附近 12 家店');
      expect(savedData['card_count'], 10); // _maxCards = 10

      // 前 10 張有資料
      for (int i = 0; i < 10; i++) {
        expect(savedData['card_${i}_store_name'], '店$i');
      }
    });

    test('2 張卡片 → multipleCards mode', () async {
      final cards = [
        createCard(id: 'two-0', storeName: '店A'),
        createCard(id: 'two-1', storeName: '店B'),
      ];

      await widgetService.updateWidget(matchedCards: cards);

      expect(savedData['widget_mode'], 'multipleCards');
      expect(savedData['widget_title'], '附近 2 家店');
      expect(savedData['card_count'], 2);
      expect(savedData['card_0_store_name'], '店A');
      expect(savedData['card_1_store_name'], '店B');
    });
  });

  // ──────────────────────────────────────────
  // U17: WidgetService 空值防護
  // ──────────────────────────────────────────
  group('U17: WidgetService 空值防護', () {
    test('空店名卡片 → 仍寫入空字串不 crash', () async {
      final card = createCard(id: 'empty-name', storeName: '', barcodeValue: 'CODE');

      await widgetService.updateWidget(matchedCards: [card]);

      expect(savedData['widget_mode'], 'singleCard');
      expect(savedData['primary_store_name'], '');
      expect(savedData['primary_barcode_value'], 'CODE');
    });

    test('空條碼卡片 → 仍寫入空字串不 crash', () async {
      final card = createCard(id: 'empty-barcode', storeName: '店家', barcodeValue: '');

      await widgetService.updateWidget(matchedCards: [card]);

      expect(savedData['widget_mode'], 'singleCard');
      expect(savedData['primary_store_name'], '店家');
      expect(savedData['primary_barcode_value'], '');
    });

    test('null recentCard + 空匹配 → noMatch 引導文字不 crash', () async {
      await widgetService.updateWidget(matchedCards: [], recentCard: null);

      expect(savedData['widget_mode'], 'noMatch');
      expect(savedData['widget_title'], '點擊新增會員卡');
      expect(savedData['primary_store_name'], '');
      expect(savedData['primary_barcode_value'], '');
    });

    test('卡片有特殊字元店名 → 正常寫入', () async {
      final card = createCard(
        id: 'special-char',
        storeName: '7-ELEVEN (台北店)',
        barcodeValue: 'ABC-123',
      );

      await widgetService.updateWidget(matchedCards: [card]);

      expect(savedData['primary_store_name'], '7-ELEVEN (台北店)');
    });
  });
}
