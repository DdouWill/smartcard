import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard/models/member_card.dart';
import 'package:smartcard/services/location_service.dart';
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
  final locationService = LocationService();
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
          return true;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(homeWidgetChannel, null);
  });

  test('既有卡片在 GPS 位置切換後，widget 會改顯示對應店家條碼', () async {
    final muji = testCard(
      id: 'muji-1',
      storeName: 'MUJI',
      barcodeValue: '4710088020017',
    );
    final uniqlo = testCard(
      id: 'uniqlo-1',
      storeName: 'UNIQLO',
      barcodeValue: '4900000000001',
    );
    final cards = [muji, uniqlo];

    final mujiResult = await locationService.matchCardsByGpsPositionForTest(
      allCards: cards,
      latitude: 22.7793352,
      longitude: 120.2995445,
    );
    await widgetService.updateWidget(
      matchedCards: mujiResult.matchedCards,
      allCards: cards,
      nearestStore: mujiResult.nearestStore,
    );

    expect(mujiResult.matchedCards.map((c) => c.storeName), contains('MUJI'));
    expect(savedData['widget_title'], 'MUJI');
    expect(savedData['primary_store_name'], 'MUJI');
    expect(savedData['primary_barcode_value'], '4710088020017');

    savedData.clear();

    final uniqloResult = await locationService.matchCardsByGpsPositionForTest(
      allCards: cards,
      latitude: 22.7819079,
      longitude: 120.2972144,
    );
    await widgetService.updateWidget(
      matchedCards: uniqloResult.matchedCards,
      allCards: cards,
      nearestStore: uniqloResult.nearestStore,
    );

    expect(
        uniqloResult.matchedCards.map((c) => c.storeName), contains('UNIQLO'));
    expect(savedData['widget_title'], 'UNIQLO');
    expect(savedData['primary_store_name'], 'UNIQLO');
    expect(savedData['primary_barcode_value'], '4900000000001');
  });
}
