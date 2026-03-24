import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard/app_controller.dart';
import 'package:smartcard/app_router.dart';
import 'package:smartcard/models/member_card.dart';
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
    tempDir = Directory.systemTemp.createTempSync('e2e_p2_test_').path;
    db = DatabaseService();
    await db.initializeForTesting(tempDir);
    controller = AppController();
    await controller.initialize();
  });

  tearDown(() async {
    teardownChannelMocks();
    await controller.stopBackgroundUpdates();
    controller.dispose();
    await db.resetForTesting();
  });

  Widget buildFullApp() {
    return MaterialApp(
      onGenerateRoute: AppRouter.onGenerateRoute,
      initialRoute: AppRouter.home,
    );
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
  // E13: 卡片詳情頁縮放
  // ──────────────────────────────────────────
  group('E13: 卡片詳情頁縮放', () {
    testWidgets('詳情頁包含 InteractiveViewer 可縮放', (tester) async {
      await addTestCards(1);
      await tester.pumpWidget(buildFullApp());
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      // Tap card to enter detail
      await tester.tap(find.text('測試店0'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      // InteractiveViewer should be present for pinch-to-zoom
      expect(find.byType(InteractiveViewer), findsOneWidget);
    });

    testWidgets('模擬縮放手勢後 InteractiveViewer 仍正常', (tester) async {
      await addTestCards(1);
      await tester.pumpWidget(buildFullApp());
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('測試店0'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      // Simulate a scale gesture on the InteractiveViewer
      final viewer = find.byType(InteractiveViewer);
      expect(viewer, findsOneWidget);

      final center = tester.getCenter(viewer);
      final gesture1 = await tester.startGesture(center + const Offset(-20, 0));
      final gesture2 = await tester.startGesture(center + const Offset(20, 0));

      // Spread fingers apart (zoom in)
      await gesture1.moveBy(const Offset(-30, 0));
      await gesture2.moveBy(const Offset(30, 0));
      await tester.pump(const Duration(seconds: 1));

      // Release
      await gesture1.up();
      await gesture2.up();
      await tester.pump(const Duration(seconds: 1));

      // Barcode and store name should still be visible
      expect(find.text('CODE-0'), findsAtLeastNWidgets(1));
    });
  });

  // ──────────────────────────────────────────
  // E16: 空狀態顯示
  // ──────────────────────────────────────────
  group('E16: 空狀態顯示', () {
    testWidgets('無卡片時顯示空狀態提示文字', (tester) async {
      await tester.pumpWidget(buildFullApp());
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('還沒有會員卡'), findsOneWidget);
    });

    testWidgets('無卡片時顯示新增按鈕', (tester) async {
      await tester.pumpWidget(buildFullApp());
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('新增卡片'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('有卡片時不顯示空狀態', (tester) async {
      await addTestCards(1);
      await tester.pumpWidget(buildFullApp());
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('測試店0'), findsOneWidget);
      expect(find.text('還沒有會員卡'), findsNothing);
    });
  });
}
