import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard/models/member_card.dart';
import 'package:smartcard/services/store_location_service.dart';
import 'package:smartcard/services/widget_service.dart';

const homeWidgetChannel = MethodChannel('home_widget');

MemberCard testCard({
  required String id,
  required String storeName,
  required String barcodeValue,
}) {
  return MemberCard(
    id: id,
    storeName: storeName,
    barcodeValue: barcodeValue,
    barcodeFormat: BarcodeFormatType.ean13,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final savedData = <String, dynamic>{};
  final widgetService = WidgetService();

  setUp(() {
    savedData.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(homeWidgetChannel, (call) async {
      switch (call.method) {
        case 'saveWidgetData':
          savedData[call.arguments['id'] as String] = call.arguments['data'];
          return true;
        case 'updateWidget':
          savedData['_updateWidgetCalled'] = true;
          savedData['_updateWidgetArgs'] = call.arguments;
          return true;
        case 'getWidgetData':
          return savedData[call.arguments['id'] as String];
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(homeWidgetChannel, null);
  });

  group('WidgetService', () {
    test('單一命中卡片時，widget 顯示對應店家與條碼', () async {
      final muji = testCard(
        id: 'muji-1',
        storeName: 'MUJI',
        barcodeValue: '4710088020017',
      );

      await widgetService.updateWidget(matchedCards: [muji], allCards: [muji]);

      expect(savedData['widget_mode'], WidgetDisplayMode.singleCard.name);
      expect(savedData['widget_title'], 'MUJI');
      expect(savedData['primary_store_name'], 'MUJI');
      expect(savedData['primary_barcode_value'], '4710088020017');
      expect(savedData['_updateWidgetCalled'], true);
    });

    test('無命中但最近門市在 1000m 內時，widget 會退回顯示最近品牌卡片', () async {
      final muji = testCard(
        id: 'muji-1',
        storeName: 'MUJI',
        barcodeValue: '4710088020017',
      );

      await widgetService.updateWidget(
        matchedCards: const [],
        allCards: [muji],
        nearestStore: NearestStoreInfo(
          brandName: 'MUJI',
          distanceMeters: 180,
          zone: GpsZone(
              latitude: 22.7793352, longitude: 120.2995445, label: '岡山門市'),
        ),
      );

      expect(savedData['widget_mode'], WidgetDisplayMode.noMatch.name);
      expect(savedData['widget_title'], '最近門市・180m');
      expect(savedData['primary_store_name'], 'MUJI');
      expect(savedData['primary_barcode_value'], '4710088020017');
      expect(savedData['nearest_store_text'], 'MUJI（180m）');
    });

    test('無命中且最近門市太遠時，widget 顯示附近無符合店家', () async {
      final muji = testCard(
        id: 'muji-1',
        storeName: 'MUJI',
        barcodeValue: '4710088020017',
      );

      await widgetService.updateWidget(
        matchedCards: const [],
        allCards: [muji],
        nearestStore: NearestStoreInfo(
          brandName: 'MUJI',
          distanceMeters: 1400,
          zone: GpsZone(
              latitude: 22.7793352, longitude: 120.2995445, label: '岡山門市'),
        ),
      );

      expect(savedData['widget_mode'], WidgetDisplayMode.noMatch.name);
      expect(savedData['widget_title'], '附近無符合店家');
      expect(savedData['primary_store_name'], '');
      expect(savedData['primary_barcode_value'], '');
      expect(savedData['nearest_store_text'], 'MUJI（1.4km）');
    });
  });
}
