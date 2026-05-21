import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard/models/member_card.dart';
import 'package:smartcard/services/location_service.dart';
import 'package:smartcard/services/store_location_service.dart';

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

  final storeService = StoreLocationService();
  final locationService = LocationService();

  setUp(() {
    storeService.clearCache();
  });

  group('GPS matching for existing cards', () {
    test('MUJI 岡山座標會匹配 MUJI 卡片', () async {
      final cards = [
        testCard(
            id: 'muji-1', storeName: 'MUJI', barcodeValue: '4710088020017'),
        testCard(
            id: 'uniqlo-1', storeName: 'UNIQLO', barcodeValue: '4900000000001'),
      ];

      final result = await locationService.matchCardsByGpsPositionForTest(
        allCards: cards,
        latitude: 22.7793352,
        longitude: 120.2995445,
      );

      expect(result.matchedCards.map((c) => c.storeName), contains('MUJI'));
      expect(result.matchedCards.map((c) => c.storeName),
          isNot(contains('UNIQLO')));
    });

    test('UNIQLO 高雄岡山店座標會匹配 UNIQLO 卡片', () async {
      final cards = [
        testCard(
            id: 'muji-1', storeName: 'MUJI', barcodeValue: '4710088020017'),
        testCard(
            id: 'uniqlo-1', storeName: 'UNIQLO', barcodeValue: '4900000000001'),
      ];

      final result = await locationService.matchCardsByGpsPositionForTest(
        allCards: cards,
        latitude: 22.7819079,
        longitude: 120.2972144,
      );

      expect(result.matchedCards.map((c) => c.storeName), contains('UNIQLO'));
      expect(
          result.matchedCards.map((c) => c.storeName), isNot(contains('MUJI')));
    });

    test('附近無命中時，仍可找出最近門市品牌', () async {
      final nearest = await storeService.findNearestStore(
        userLat: 22.7810,
        userLng: 120.2980,
        brandFilter: {'MUJI', 'UNIQLO'},
      );

      expect(nearest, isNotNull);
      expect({'MUJI', 'UNIQLO'}, contains(nearest!.brandName));
      expect(nearest.distanceMeters, lessThanOrEqualTo(1000));
    });
  });
}
