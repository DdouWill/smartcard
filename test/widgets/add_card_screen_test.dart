import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard/app_controller.dart';
import 'package:smartcard/screens/add_card_screen.dart';
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
    // Mock mobile_scanner channel
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
      const MethodChannel('dev.steenbakker.mobile_scanner/scanner/method'), null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.steenbakker.mobile_scanner/scanner/event'), null,
    );
  }

  setUp(() async {
    setupChannelMocks();
    tempDir = Directory.systemTemp.createTempSync('addcard_test_').path;
    db = DatabaseService();
    await db.initializeForTesting(tempDir);
    controller = AppController();
    await controller.initialize();
  });

  tearDown(() async {
    teardownChannelMocks();
    await db.resetForTesting();
  });

  Widget buildApp() {
    return const MaterialApp(home: AddCardScreen());
  }

  // ──────────────────────────────────────────
  // W20: AddCardScreen Tab 切換
  // ──────────────────────────────────────────
  group('W20: AddCardScreen Tab 切換', () {
    testWidgets('3 個 Tab 可見', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('掃描'), findsOneWidget);
      expect(find.text('圖片辨識'), findsOneWidget);
      expect(find.text('手動輸入'), findsOneWidget);
    });

    testWidgets('點擊手動輸入 Tab → 顯示表單', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('手動輸入'));
      await tester.pumpAndSettle();

      // 手動輸入 Tab 應有店家名稱和條碼號碼輸入框
      expect(find.text('店家名稱 *'), findsOneWidget);
      expect(find.text('條碼號碼 *'), findsOneWidget);
    });

    testWidgets('點擊圖片辨識 Tab → 顯示選取按鈕', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('圖片辨識'));
      await tester.pumpAndSettle();

      expect(find.text('從相簿選取'), findsOneWidget);
      expect(find.text('拍照'), findsOneWidget);
    });

    testWidgets('手動輸入 Tab 有儲存按鈕', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('手動輸入'));
      await tester.pumpAndSettle();

      expect(find.text('儲存卡片'), findsOneWidget);
    });

    testWidgets('手動輸入 Tab 有條碼格式選擇', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('手動輸入'));
      await tester.pumpAndSettle();

      // 找到條碼格式區域
      final formatLabel = find.text('條碼格式');
      await tester.ensureVisible(formatLabel);
      await tester.pumpAndSettle();
      expect(formatLabel, findsOneWidget);

      // 有 ChoiceChip（至少有 EAN13）
      expect(find.text('EAN13'), findsOneWidget);
    });
  });
}
