import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard/services/store_location_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('findNearestStore', () {
    test('should find nearest store within 1km', () async {
      final service = StoreLocationService();
      
      // 大雅 (24.23, 120.65) — 離最近 7-ELEVEN 約 212m
      final result = await service.findNearestStore(
        userLat: 24.23,
        userLng: 120.65,
      );

      expect(result, isNotNull);
      expect(result!.distanceMeters, lessThan(1000));
      expect(result.distanceMeters, greaterThan(0));
      expect(result.brandName, isNotEmpty);
      print('Nearest: ${result.brandName} at ${result.distanceText}');
    });

    test('should return null when no store within 1km', () async {
      final service = StoreLocationService();
      
      // 台灣海峽中間 — 1km 內不可能有門市
      final result = await service.findNearestStore(
        userLat: 23.5,
        userLng: 119.5,
      );

      expect(result, isNull);
    });

    test('distanceText should format correctly', () {
      final info = NearestStoreInfo(
        brandName: '7-ELEVEN',
        distanceMeters: 212.0,
        zone: GpsZone(latitude: 0, longitude: 0),
      );
      expect(info.distanceText, '212m');

      final farInfo = NearestStoreInfo(
        brandName: 'FamilyMart',
        distanceMeters: 1500.0,
        zone: GpsZone(latitude: 0, longitude: 0),
      );
      // 超過 1km 不會出現（上限就是 1km），但 format 應該能處理
      expect(farInfo.distanceText, '1.5km');
    });
  });
}
