import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard/models/member_card.dart';
import 'package:smartcard/models/app_settings.dart';
import 'package:smartcard/services/database_service.dart';

void main() {
  late DatabaseService db;
  late String tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('db_test_').path;
    db = DatabaseService();
    await db.initializeForTesting(tempDir);
  });

  tearDown(() async {
    await db.resetForTesting();
  });

  // ──────────────────────────────────────────
  // U11: DatabaseService CRUD
  // ──────────────────────────────────────────
  group('U11: DatabaseService CRUD', () {
    test('addCard → getCardById 回傳正確卡片', () async {
      final card = MemberCard(
        id: 'crud-1',
        storeName: '全聯福利中心',
        barcodeValue: '5901234123457',
        barcodeFormat: BarcodeFormatType.ean13,
        cardColor: '#FF0000',
      );

      await db.addCard(card);
      final retrieved = db.getCardById('crud-1');

      expect(retrieved, isNotNull);
      expect(retrieved!.storeName, '全聯福利中心');
      expect(retrieved.barcodeValue, '5901234123457');
      expect(retrieved.barcodeFormat, BarcodeFormatType.ean13);
      expect(retrieved.cardColor, '#FF0000');
    });

    test('updateCard → 更新後讀取正確', () async {
      final card = MemberCard(
        id: 'crud-2',
        storeName: '原始名稱',
        barcodeValue: 'CODE123',
        barcodeFormat: BarcodeFormatType.qr,
      );
      await db.addCard(card);

      final updated = card.copyWith(storeName: '更新後名稱');
      await db.updateCard(updated);

      final retrieved = db.getCardById('crud-2');
      expect(retrieved!.storeName, '更新後名稱');
    });

    test('deleteCard → getCardById 回傳 null', () async {
      final card = MemberCard(
        id: 'crud-3',
        storeName: '將被刪除',
        barcodeValue: 'DEL',
        barcodeFormat: BarcodeFormatType.qr,
      );
      await db.addCard(card);
      expect(db.getCardById('crud-3'), isNotNull);

      await db.deleteCard('crud-3');
      expect(db.getCardById('crud-3'), isNull);
    });

    test('getAllCards 回傳所有卡片並依 sortOrder 排序', () async {
      final card1 = MemberCard(
        id: 'sort-1',
        storeName: '第三',
        barcodeValue: 'C',
        barcodeFormat: BarcodeFormatType.qr,
        sortOrder: 2,
      );
      final card2 = MemberCard(
        id: 'sort-2',
        storeName: '第一',
        barcodeValue: 'A',
        barcodeFormat: BarcodeFormatType.qr,
        sortOrder: 0,
      );
      final card3 = MemberCard(
        id: 'sort-3',
        storeName: '第二',
        barcodeValue: 'B',
        barcodeFormat: BarcodeFormatType.qr,
        sortOrder: 1,
      );

      await db.addCard(card1);
      await db.addCard(card2);
      await db.addCard(card3);

      final all = db.getAllCards();
      expect(all.length, 3);
      expect(all[0].storeName, '第一');
      expect(all[1].storeName, '第二');
      expect(all[2].storeName, '第三');
    });

    test('getCardById 不存在的 id 回傳 null', () {
      expect(db.getCardById('nonexistent'), isNull);
    });

    test('clearAll 清空所有卡片', () async {
      await db.addCard(MemberCard(
        id: 'clear-1',
        storeName: 'A',
        barcodeValue: 'A',
        barcodeFormat: BarcodeFormatType.qr,
      ));
      await db.addCard(MemberCard(
        id: 'clear-2',
        storeName: 'B',
        barcodeValue: 'B',
        barcodeFormat: BarcodeFormatType.qr,
      ));

      expect(db.getAllCards().length, 2);

      await db.clearAll();
      expect(db.getAllCards(), isEmpty);
    });

    test('完整 CRUD 流程', () async {
      // Create
      final card = MemberCard(
        id: 'flow-1',
        storeName: '建立',
        barcodeValue: 'FLOW',
        barcodeFormat: BarcodeFormatType.code128,
      );
      await db.addCard(card);

      // Read
      var read = db.getCardById('flow-1');
      expect(read!.storeName, '建立');

      // Update
      await db.updateCard(read.copyWith(storeName: '更新'));
      read = db.getCardById('flow-1');
      expect(read!.storeName, '更新');

      // Delete
      await db.deleteCard('flow-1');
      expect(db.getCardById('flow-1'), isNull);

      // List should be empty
      expect(db.getAllCards(), isEmpty);
    });
  });

  // ──────────────────────────────────────────
  // Settings 操作（附帶測試）
  // ──────────────────────────────────────────
  group('Settings 操作', () {
    test('getSettings 回傳預設值', () {
      final settings = db.getSettings();
      expect(settings.enableWifi, isTrue);
      expect(settings.enableGps, isTrue);
      expect(settings.updateIntervalMinutes, 5);
    });

    test('saveSettings → getSettings 回傳更新值', () async {
      final settings = AppSettings(
        enableWifi: false,
        enableGps: false,
        updateIntervalMinutes: 10,
      );
      await db.saveSettings(settings);

      final retrieved = db.getSettings();
      expect(retrieved.enableWifi, isFalse);
      expect(retrieved.enableGps, isFalse);
      expect(retrieved.updateIntervalMinutes, 10);
    });
  });

  // ──────────────────────────────────────────
  // U12: DatabaseService reorderCards
  // ──────────────────────────────────────────
  group('U12: DatabaseService reorderCards', () {
    test('3 張卡 → reorder → sortOrder 正確更新', () async {
      final card1 = MemberCard(
        id: 'reorder-a', storeName: '店A', barcodeValue: 'A',
        barcodeFormat: BarcodeFormatType.qr, sortOrder: 0,
      );
      final card2 = MemberCard(
        id: 'reorder-b', storeName: '店B', barcodeValue: 'B',
        barcodeFormat: BarcodeFormatType.qr, sortOrder: 1,
      );
      final card3 = MemberCard(
        id: 'reorder-c', storeName: '店C', barcodeValue: 'C',
        barcodeFormat: BarcodeFormatType.qr, sortOrder: 2,
      );

      await db.addCard(card1);
      await db.addCard(card2);
      await db.addCard(card3);

      // 原始順序：A(0), B(1), C(2)
      var all = db.getAllCards();
      expect(all[0].storeName, '店A');
      expect(all[1].storeName, '店B');
      expect(all[2].storeName, '店C');

      // 重新排序為 C, A, B
      await db.reorderCards(['reorder-c', 'reorder-a', 'reorder-b']);

      all = db.getAllCards();
      expect(all[0].storeName, '店C');
      expect(all[0].sortOrder, 0);
      expect(all[1].storeName, '店A');
      expect(all[1].sortOrder, 1);
      expect(all[2].storeName, '店B');
      expect(all[2].sortOrder, 2);
    });

    test('reorder 不存在的 id → 跳過不報錯', () async {
      final card1 = MemberCard(
        id: 'reorder-x', storeName: '店X', barcodeValue: 'X',
        barcodeFormat: BarcodeFormatType.qr, sortOrder: 0,
      );
      await db.addCard(card1);

      // 包含不存在的 id
      await db.reorderCards(['nonexistent', 'reorder-x']);

      final all = db.getAllCards();
      expect(all.length, 1);
      expect(all[0].sortOrder, 1); // index 1 in the list
    });
  });

  // ──────────────────────────────────────────
  // U13: DatabaseService Settings
  // ──────────────────────────────────────────
  group('U13: DatabaseService Settings 完整', () {
    test('saveSettings 所有欄位 → getSettings 回傳一致', () async {
      final settings = AppSettings(
        enableWifi: false,
        enableGps: false,
        updateIntervalMinutes: 30,
        screenBrightnessMode: 2,
        showRecentOnEmpty: false,
        maxWidgetCards: 3,
      );
      await db.saveSettings(settings);

      final retrieved = db.getSettings();
      expect(retrieved.enableWifi, isFalse);
      expect(retrieved.enableGps, isFalse);
      expect(retrieved.updateIntervalMinutes, 30);
      expect(retrieved.screenBrightnessMode, 2);
      expect(retrieved.showRecentOnEmpty, isFalse);
      expect(retrieved.maxWidgetCards, 3);
    });

    test('多次 saveSettings → 最後一次為準', () async {
      await db.saveSettings(AppSettings(updateIntervalMinutes: 1));
      await db.saveSettings(AppSettings(updateIntervalMinutes: 10));
      await db.saveSettings(AppSettings(updateIntervalMinutes: 30));

      final retrieved = db.getSettings();
      expect(retrieved.updateIntervalMinutes, 30);
    });

    test('brightnessMode getter 正確轉換', () async {
      final settings = AppSettings(screenBrightnessMode: 0);
      await db.saveSettings(settings);
      final retrieved = db.getSettings();
      expect(retrieved.brightnessMode, ScreenBrightnessMode.system);

      await db.saveSettings(AppSettings(screenBrightnessMode: 1));
      expect(db.getSettings().brightnessMode, ScreenBrightnessMode.maximum);

      await db.saveSettings(AppSettings(screenBrightnessMode: 2));
      expect(db.getSettings().brightnessMode, ScreenBrightnessMode.keepOn);
    });
  });
}
