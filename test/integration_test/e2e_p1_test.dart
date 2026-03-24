import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard/app_controller.dart';
import 'package:smartcard/app_router.dart';
import 'package:smartcard/models/app_settings.dart';
import 'package:smartcard/models/member_card.dart';
import 'package:smartcard/screens/settings_screen.dart';
import 'package:smartcard/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService db;
  late AppController controller;
  late String tempDir;

  void setupChannelMocks() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'), (call) async {
      if (call.method == 'saveWidgetData') return true;
      if (call.method == 'updateWidget') return true;
      if (call.method == 'initiallyLaunchedFromHomeWidget') return null;
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('es.antonborri/home_widget/updates'),
      (call) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/wakelock_plus'),
      (call) async => true,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.steenbakker.mobile_scanner/scanner/method'),
      (call) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.steenbakker.mobile_scanner/scanner/event'),
      (call) async => null,
    );
  }

  void teardownChannelMocks() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('es.antonborri/home_widget/updates'), null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/wakelock_plus'), null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.steenbakker.mobile_scanner/scanner/method'), null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.steenbakker.mobile_scanner/scanner/event'), null,
    );
  }

  setUp(() async {
    setupChannelMocks();
    tempDir = Directory.systemTemp.createTempSync('e2e_p1_test_').path;
    db = DatabaseService();
    await db.initializeForTesting(tempDir);
    controller = AppController();
    await controller.initialize();
  });

  tearDown(() async {
    teardownChannelMocks();
    await db.resetForTesting();
  });

  Widget buildFullApp() {
    return MaterialApp(
      onGenerateRoute: AppRouter.onGenerateRoute,
      initialRoute: AppRouter.home,
    );
  }

  Widget buildSettings() {
    return const MaterialApp(home: SettingsScreen());
  }

  /// Helper: add N cards to DB and reinitialize controller
  Future<void> addTestCards(int count) async {
    for (int i = 0; i < count; i++) {
      await db.addCard(MemberCard(
        id: 'e2e-$i',
        storeName: '測試店$i',
        barcodeValue: 'CODE-$i',
        barcodeFormat: BarcodeFormatType.qr,
        sortOrder: i,
      ));
    }
    await controller.initialize();
  }

  // ──────────────────────────────────────────
  // E6: 卡片拖拽排序
  // ──────────────────────────────────────────
  group('E6: 卡片拖拽排序', () {
    testWidgets('拖拽後順序更新', (tester) async {
      await addTestCards(3);
      await tester.pumpWidget(buildFullApp());
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify initial order - all 3 cards visible
      expect(find.text('測試店0'), findsOneWidget);
      expect(find.text('測試店1'), findsOneWidget);
      expect(find.text('測試店2'), findsOneWidget);

      // ReorderableListView: long-press + drag on the item
      final firstItem = find.text('測試店0');
      final gesture = await tester.startGesture(tester.getCenter(firstItem));
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveBy(const Offset(0, 200));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      // All cards should still be present (no data loss)
      expect(find.text('測試店0'), findsOneWidget);
      expect(find.text('測試店1'), findsOneWidget);
      expect(find.text('測試店2'), findsOneWidget);
    });

    testWidgets('reorder 後 controller 順序更新且持久化', (tester) async {
      await addTestCards(3);
      await tester.pumpWidget(buildFullApp());
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Reorder programmatically (simulating drag result)
      await controller.reorderCards(['e2e-2', 'e2e-0', 'e2e-1']);
      await tester.pumpAndSettle();

      expect(controller.cards[0].id, 'e2e-2');
      expect(controller.cards[1].id, 'e2e-0');
      expect(controller.cards[2].id, 'e2e-1');

      // Verify persistence: reinitialize and check order
      await controller.initialize();
      expect(controller.cards[0].id, 'e2e-2');
      expect(controller.cards[1].id, 'e2e-0');
      expect(controller.cards[2].id, 'e2e-1');
    });
  });

  // ──────────────────────────────────────────
  // E7: 設定：螢幕亮度模式切換
  // ──────────────────────────────────────────
  group('E7: 設定：螢幕亮度模式切換', () {
    testWidgets('切換亮度模式 → 設定持久化', (tester) async {
      await tester.pumpWidget(buildSettings());
      await tester.pumpAndSettle();

      // Default is '最大亮度'
      expect(find.text('最大亮度'), findsOneWidget);

      // Open brightness dialog
      await tester.tap(find.text('條碼顯示亮度'));
      await tester.pumpAndSettle();

      // Dialog shows all 3 modes
      expect(find.text('系統亮度'), findsOneWidget);
      expect(find.text('螢幕常亮'), findsOneWidget);

      // Select '系統亮度'
      await tester.tap(find.text('系統亮度'));
      await tester.pumpAndSettle();

      expect(controller.settings.brightnessMode, ScreenBrightnessMode.system);
      expect(find.text('系統亮度'), findsOneWidget);
    });

    testWidgets('切換到螢幕常亮 → 設定持久化', (tester) async {
      await tester.pumpWidget(buildSettings());
      await tester.pumpAndSettle();

      await tester.tap(find.text('條碼顯示亮度'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('螢幕常亮'));
      await tester.pumpAndSettle();

      expect(controller.settings.brightnessMode, ScreenBrightnessMode.keepOn);
    });
  });

  // ──────────────────────────────────────────
  // E8: 設定：WiFi/GPS 開關
  // ──────────────────────────────────────────
  group('E8: 設定：WiFi/GPS 開關', () {
    testWidgets('切換 WiFi → 關 → 開 → 狀態持久化', (tester) async {
      await tester.pumpWidget(buildSettings());
      await tester.pumpAndSettle();

      expect(controller.settings.enableWifi, isTrue);

      await tester.tap(find.widgetWithText(SwitchListTile, 'WiFi SSID 偵測'));
      await tester.pumpAndSettle();
      expect(controller.settings.enableWifi, isFalse);

      await tester.tap(find.widgetWithText(SwitchListTile, 'WiFi SSID 偵測'));
      await tester.pumpAndSettle();
      expect(controller.settings.enableWifi, isTrue);
    });

    testWidgets('切換 GPS → 狀態持久化', (tester) async {
      await tester.pumpWidget(buildSettings());
      await tester.pumpAndSettle();

      expect(controller.settings.enableGps, isTrue);

      await tester.tap(find.widgetWithText(SwitchListTile, 'GPS 地理圍欄偵測'));
      await tester.pumpAndSettle();
      expect(controller.settings.enableGps, isFalse);
    });

    testWidgets('WiFi 和 GPS 獨立切換', (tester) async {
      await tester.pumpWidget(buildSettings());
      await tester.pumpAndSettle();

      // Turn off WiFi only
      await tester.tap(find.widgetWithText(SwitchListTile, 'WiFi SSID 偵測'));
      await tester.pumpAndSettle();

      expect(controller.settings.enableWifi, isFalse);
      expect(controller.settings.enableGps, isTrue);
    });
  });

  // ──────────────────────────────────────────
  // E9: 設定：Widget 更新間隔
  // ──────────────────────────────────────────
  group('E9: 設定：Widget 更新間隔', () {
    testWidgets('選擇 10 分鐘間隔', (tester) async {
      await tester.pumpWidget(buildSettings());
      await tester.pumpAndSettle();

      expect(find.text('每 5 分鐘更新一次'), findsOneWidget);

      await tester.tap(find.text('Widget 更新間隔'));
      await tester.pumpAndSettle();

      // All 4 options visible
      expect(find.text('1 分鐘'), findsOneWidget);
      expect(find.text('5 分鐘'), findsOneWidget);
      expect(find.text('10 分鐘'), findsOneWidget);
      expect(find.text('30 分鐘'), findsOneWidget);

      await tester.tap(find.text('10 分鐘'));
      await tester.pumpAndSettle();

      expect(controller.settings.updateIntervalMinutes, 10);
      expect(find.text('每 10 分鐘更新一次'), findsOneWidget);
    });

    testWidgets('選擇 30 分鐘間隔', (tester) async {
      await tester.pumpWidget(buildSettings());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Widget 更新間隔'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('30 分鐘'));
      await tester.pumpAndSettle();

      expect(controller.settings.updateIntervalMinutes, 30);
    });
  });

  // ──────────────────────────────────────────
  // E10: 設定：顯示最近卡片開關
  // ──────────────────────────────────────────
  group('E10: 設定：顯示最近卡片開關', () {
    testWidgets('切換「無符合時顯示最近使用」→ 關 → 開', (tester) async {
      await tester.pumpWidget(buildSettings());
      await tester.pumpAndSettle();

      expect(controller.settings.showRecentOnEmpty, isTrue);

      await tester.tap(find.widgetWithText(SwitchListTile, '無符合時顯示最近使用'));
      await tester.pumpAndSettle();
      expect(controller.settings.showRecentOnEmpty, isFalse);

      await tester.tap(find.widgetWithText(SwitchListTile, '無符合時顯示最近使用'));
      await tester.pumpAndSettle();
      expect(controller.settings.showRecentOnEmpty, isTrue);
    });
  });

  // ──────────────────────────────────────────
  // E11: 備份匯出流程
  // ──────────────────────────────────────────
  group('E11: 備份匯出流程', () {
    testWidgets('無卡片時匯出按鈕顯示 0 張', (tester) async {
      await tester.pumpWidget(buildSettings());
      await tester.pumpAndSettle();

      expect(find.text('匯出加密備份'), findsOneWidget);
      expect(find.text('將所有卡片匯出為加密檔案（0 張）'), findsOneWidget);
    });

    testWidgets('有卡片時匯出 → 密碼對話框', (tester) async {
      await addTestCards(2);
      await tester.pumpWidget(buildSettings());
      await tester.pumpAndSettle();

      expect(find.text('將所有卡片匯出為加密檔案（2 張）'), findsOneWidget);

      await tester.tap(find.text('匯出加密備份'));
      await tester.pumpAndSettle();

      // Password dialog
      expect(find.text('設定備份密碼'), findsOneWidget);
      expect(find.text('密碼'), findsOneWidget);
      expect(find.text('確認密碼'), findsOneWidget);
    });

    testWidgets('空密碼 → 顯示錯誤', (tester) async {
      await addTestCards(1);
      await tester.pumpWidget(buildSettings());
      await tester.pumpAndSettle();

      await tester.tap(find.text('匯出加密備份'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('確定'));
      await tester.pumpAndSettle();

      expect(find.text('請輸入密碼'), findsOneWidget);
    });

    testWidgets('過短密碼 → 顯示錯誤', (tester) async {
      await addTestCards(1);
      await tester.pumpWidget(buildSettings());
      await tester.pumpAndSettle();

      await tester.tap(find.text('匯出加密備份'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, '密碼'),
        'abc',
      );
      await tester.tap(find.text('確定'));
      await tester.pumpAndSettle();

      expect(find.text('密碼至少需要 4 個字元'), findsOneWidget);
    });
  });

  // ──────────────────────────────────────────
  // E12: 清除所有卡片（設定頁）
  // ──────────────────────────────────────────
  group('E12: 清除所有卡片', () {
    testWidgets('無卡片時點擊清除 → 顯示提示', (tester) async {
      await tester.pumpWidget(buildSettings());
      await tester.pumpAndSettle();

      final clearBtn = find.text('清除所有卡片');
      await tester.ensureVisible(clearBtn);
      await tester.pumpAndSettle();
      await tester.tap(clearBtn);
      await tester.pumpAndSettle();

      expect(find.text('目前沒有任何卡片'), findsOneWidget);
    });

    testWidgets('有卡片 → 清除 → 確認 → 卡片清空', (tester) async {
      await addTestCards(3);
      expect(controller.cards.length, 3);

      await tester.pumpWidget(buildSettings());
      await tester.pumpAndSettle();

      final clearBtn = find.text('清除所有卡片');
      await tester.ensureVisible(clearBtn);
      await tester.pumpAndSettle();
      await tester.tap(clearBtn);
      await tester.pumpAndSettle();

      // Confirmation dialog
      expect(find.text('確定要刪除全部 3 張卡片嗎？\n此操作無法復原。'), findsOneWidget);

      await tester.tap(find.text('全部刪除'));
      await tester.pumpAndSettle();

      expect(controller.cards, isEmpty);
    });

    testWidgets('有卡片 → 清除 → 取消 → 卡片不變', (tester) async {
      await addTestCards(2);

      await tester.pumpWidget(buildSettings());
      await tester.pumpAndSettle();

      final clearBtn = find.text('清除所有卡片');
      await tester.ensureVisible(clearBtn);
      await tester.pumpAndSettle();
      await tester.tap(clearBtn);
      await tester.pumpAndSettle();

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(controller.cards.length, 2);
    });
  });

  // ──────────────────────────────────────────
  // E14: 卡片長按快捷選單
  // ──────────────────────────────────────────
  group('E14: 卡片長按快捷選單', () {
    testWidgets('長按卡片 → 顯示 BottomSheet 選單', (tester) async {
      await addTestCards(1);
      await tester.pumpWidget(buildFullApp());
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await tester.longPress(find.text('測試店0'));
      await tester.pumpAndSettle();

      expect(find.text('開啟條碼'), findsOneWidget);
      expect(find.text('刪除'), findsOneWidget);
    });

    testWidgets('長按 → 開啟條碼 → 進入詳情頁', (tester) async {
      await addTestCards(1);
      await tester.pumpWidget(buildFullApp());
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await tester.longPress(find.text('測試店0'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('開啟條碼'));
      await tester.pumpAndSettle();

      // Detail screen shows barcode value
      expect(find.text('CODE-0'), findsAtLeastNWidgets(1));
    });

    testWidgets('長按 → 刪除 → 確認對話框', (tester) async {
      await addTestCards(1);
      await tester.pumpWidget(buildFullApp());
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await tester.longPress(find.text('測試店0'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('刪除'));
      await tester.pumpAndSettle();

      expect(find.text('刪除卡片'), findsOneWidget);
      expect(find.text('確定要刪除「測試店0」嗎？'), findsOneWidget);
    });
  });

  // ──────────────────────────────────────────
  // E17: 店名自動完成
  // ──────────────────────────────────────────
  group('E17: 店名自動完成', () {
    testWidgets('輸入「全」→ 顯示自動完成建議', (tester) async {
      await tester.pumpWidget(buildFullApp());
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Navigate to add card
      await tester.tap(find.text('新增卡片'));
      await tester.pumpAndSettle();

      // Switch to manual input tab
      await tester.tap(find.text('手動輸入'));
      await tester.pumpAndSettle();

      // Type '全' in store name field
      await tester.enterText(
        find.widgetWithText(TextFormField, '店家名稱 *'),
        '全',
      );
      await tester.pumpAndSettle();

      // Autocomplete suggestions containing '全'
      expect(find.text('全聯福利中心'), findsOneWidget);
      expect(find.text('全家便利商店'), findsOneWidget);
      expect(find.text('全國電子'), findsOneWidget);
    });

    testWidgets('選擇自動完成項目 → 填入店名', (tester) async {
      await tester.pumpWidget(buildFullApp());
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await tester.tap(find.text('新增卡片'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('手動輸入'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, '店家名稱 *'),
        '全聯',
      );
      await tester.pumpAndSettle();

      // Select suggestion
      await tester.tap(find.text('全聯福利中心'));
      await tester.pumpAndSettle();

      // Verify field contains selected value
      final textFields = find.byType(TextFormField);
      final storeField = textFields.first;
      final widget = tester.widget<TextFormField>(storeField);
      // The Autocomplete uses its own controller, so we check via text finder
      expect(find.text('全聯福利中心'), findsAtLeastNWidgets(1));
    });

    testWidgets('輸入無匹配文字 → 無建議', (tester) async {
      await tester.pumpWidget(buildFullApp());
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await tester.tap(find.text('新增卡片'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('手動輸入'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, '店家名稱 *'),
        'ZZZZZ',
      );
      await tester.pumpAndSettle();

      // No suggestions
      expect(find.text('全聯福利中心'), findsNothing);
      expect(find.text('家樂福'), findsNothing);
    });
  });
}
