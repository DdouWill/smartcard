import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard/data/known_stores.dart';

void main() {
  group('known store logo metadata', () {
    test('每個 known store 都有 widget logo label 與品牌色', () {
      for (final store in knownStores) {
        expect(getStoreLogoLabel(store.name), isNotEmpty, reason: store.name);
        expect(getStoreBrandColor(store.name), isNotNull, reason: store.name);
      }
    });

    test('store_locations 內每個品牌都能取得 widget logo label', () {
      final file = File('lib/data/store_locations.json');
      final decoded =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final stores = decoded['stores'] as Map<String, dynamic>;

      for (final brandName in stores.keys) {
        expect(getStoreLogoLabel(brandName), isNotEmpty, reason: brandName);
      }
    });

    test('未知店家會產生可辨識 fallback label', () {
      expect(getStoreLogoLabel('測試商店'), '測試');
      expect(getStoreLogoLabel('Example Market'), 'EM');
      expect(getStoreLogoLabel(''), '卡');
    });
  });
}
