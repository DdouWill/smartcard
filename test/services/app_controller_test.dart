import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard/app_controller.dart';
import 'package:smartcard/models/app_settings.dart';
import 'package:smartcard/models/member_card.dart';
import 'package:smartcard/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService db;
  late AppController controller;
  late String tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('ctrl_test_').path;
    db = DatabaseService();
    await db.initializeForTesting(tempDir);

    // Mock home_widget channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('home_widget'),
      (call) async {
        if (call.method == 'saveWidgetData') return true;
        if (call.method == 'updateWidget') return true;
        if (call.method == 'initiallyLaunchedFromHomeWidget') return null;
        return null;
      },
    );

    controller = AppController();
    await controller.initialize();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'), null);
    await db.resetForTesting();
  });

  // ──────────────────────────────────────────
  // U23: AppController 初始化流程
  // ──────────────────────────────────────────
  group('U23: AppController 初始化流程', () {
    test('initialize 後 cards 從 DB 載入（空）', () {
      expect(controller.cards, isEmpty);
      expect(controller.hasCards, isFalse);
    });

    test('initialize 後 settings 為預設值', () {
      final settings = controller.settings;
      expect(settings.enableWifi, isTrue);
      expect(settings.enableGps, isTrue);
      expect(settings.updateIntervalMinutes, 5);
    });

    test('initialize 後 initError 為 null', () {
      expect(controller.initError, isNull);
    });

    test('有卡片時 initialize 後 cards 載入正確', () async {
      await db.addCard(MemberCard(
        id: 'init-1', storeName: '初始卡', barcodeValue: 'V1',
        barcodeFormat: BarcodeFormatType.qr,
      ));

      await controller.initialize();

      expect(controller.cards.length, 1);
      expect(controller.cards.first.storeName, '初始卡');
      expect(controller.hasCards, isTrue);
    });
  });

  // ──────────────────────────────────────────
  // U24: AppController 卡片增刪
  // ──────────────────────────────────────────
  group('U24: AppController 卡片增刪', () {
    test('addCard → cards 列表更新', () async {
      expect(controller.cards, isEmpty);

      final card = MemberCard(
        id: 'add-1', storeName: '新增店', barcodeValue: 'ADD',
        barcodeFormat: BarcodeFormatType.qr,
      );
      await controller.addCard(card);

      expect(controller.cards.length, 1);
      expect(controller.cards.first.storeName, '新增店');
    });

    test('deleteCard → cards 列表更新', () async {
      final card = MemberCard(
        id: 'del-1', storeName: '將刪除', barcodeValue: 'DEL',
        barcodeFormat: BarcodeFormatType.qr,
      );
      await controller.addCard(card);
      expect(controller.cards.length, 1);

      await controller.deleteCard('del-1');
      expect(controller.cards, isEmpty);
    });

    test('addCard 後 notifyListeners 觸發', () async {
      var notified = false;
      controller.addListener(() => notified = true);

      await controller.addCard(MemberCard(
        id: 'notify-1', storeName: 'N', barcodeValue: 'N',
        barcodeFormat: BarcodeFormatType.qr,
      ));

      expect(notified, isTrue);
    });

    test('deleteCard 後 notifyListeners 觸發', () async {
      await controller.addCard(MemberCard(
        id: 'notify-del', storeName: 'N', barcodeValue: 'N',
        barcodeFormat: BarcodeFormatType.qr,
      ));

      var notified = false;
      controller.addListener(() => notified = true);

      await controller.deleteCard('notify-del');
      expect(notified, isTrue);
    });

    test('updateCard → 卡片資料更新', () async {
      final card = MemberCard(
        id: 'upd-1', storeName: '原始', barcodeValue: 'UPD',
        barcodeFormat: BarcodeFormatType.qr,
      );
      await controller.addCard(card);

      final updated = card.copyWith(storeName: '已更新');
      await controller.updateCard(updated);

      expect(controller.cards.first.storeName, '已更新');
    });

    test('deleteAllCards → 清空所有卡片', () async {
      await controller.addCard(MemberCard(
        id: 'clr-1', storeName: 'A', barcodeValue: 'A',
        barcodeFormat: BarcodeFormatType.qr,
      ));
      await controller.addCard(MemberCard(
        id: 'clr-2', storeName: 'B', barcodeValue: 'B',
        barcodeFormat: BarcodeFormatType.qr,
      ));
      expect(controller.cards.length, 2);

      await controller.deleteAllCards();
      expect(controller.cards, isEmpty);
    });

    test('reorderCards → 順序更新', () async {
      await controller.addCard(MemberCard(
        id: 'ro-a', storeName: '店A', barcodeValue: 'A',
        barcodeFormat: BarcodeFormatType.qr, sortOrder: 0,
      ));
      await controller.addCard(MemberCard(
        id: 'ro-b', storeName: '店B', barcodeValue: 'B',
        barcodeFormat: BarcodeFormatType.qr, sortOrder: 1,
      ));

      await controller.reorderCards(['ro-b', 'ro-a']);

      expect(controller.cards[0].storeName, '店B');
      expect(controller.cards[1].storeName, '店A');
    });

    test('getCardById 回傳正確卡片', () async {
      await controller.addCard(MemberCard(
        id: 'get-1', storeName: '查詢店', barcodeValue: 'GET',
        barcodeFormat: BarcodeFormatType.qr,
      ));

      final found = controller.getCardById('get-1');
      expect(found?.storeName, '查詢店');
      expect(controller.getCardById('nonexistent'), isNull);
    });

    test('updateSettings 更新設定', () async {
      final newSettings = AppSettings(
        enableWifi: false,
        enableGps: false,
        updateIntervalMinutes: 30,
      );
      await controller.updateSettings(newSettings);

      expect(controller.settings.enableWifi, isFalse);
      expect(controller.settings.enableGps, isFalse);
      expect(controller.settings.updateIntervalMinutes, 30);
    });
  });
}
