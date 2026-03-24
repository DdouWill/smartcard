import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard/app_controller.dart';
import 'package:smartcard/models/member_card.dart';
import 'package:smartcard/screens/card_detail_screen.dart';
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
    // Mock wakelock_plus
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/wakelock_plus'),
      (call) async => true,
    );
  }

  void teardownChannelMocks() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/wakelock_plus'), null,
    );
  }

  setUp(() async {
    setupChannelMocks();
    tempDir = Directory.systemTemp.createTempSync('detail_test_').path;
    db = DatabaseService();
    await db.initializeForTesting(tempDir);
    controller = AppController();
    await controller.initialize();
  });

  tearDown(() async {
    teardownChannelMocks();
    await db.resetForTesting();
  });

  // ──────────────────────────────────────────
  // W21: CardDetailScreen 基本渲染
  // ──────────────────────────────────────────
  group('W21: CardDetailScreen 基本渲染', () {
    testWidgets('顯示店名', (tester) async {
      final card = MemberCard(
        id: 'detail-1',
        storeName: '全聯福利中心',
        barcodeValue: 'DETAIL-123',
        barcodeFormat: BarcodeFormatType.qr,
      );

      await tester.pumpWidget(
        MaterialApp(home: CardDetailScreen(card: card)),
      );
      await tester.pumpAndSettle();

      expect(find.text('全聯福利中心'), findsOneWidget);
    });

    testWidgets('顯示條碼值', (tester) async {
      final card = MemberCard(
        id: 'detail-2',
        storeName: '測試店',
        barcodeValue: '4710088020019',
        barcodeFormat: BarcodeFormatType.qr,
      );

      await tester.pumpWidget(
        MaterialApp(home: CardDetailScreen(card: card)),
      );
      await tester.pumpAndSettle();

      expect(find.text('4710088020019'), findsAtLeastNWidgets(1));
    });

    testWidgets('顯示條碼格式標籤', (tester) async {
      final card = MemberCard(
        id: 'detail-3',
        storeName: '測試',
        barcodeValue: 'TEST',
        barcodeFormat: BarcodeFormatType.code128,
      );

      await tester.pumpWidget(
        MaterialApp(home: CardDetailScreen(card: card)),
      );
      await tester.pumpAndSettle();

      expect(find.text('CODE128'), findsOneWidget);
    });

    testWidgets('黑色背景', (tester) async {
      final card = MemberCard(
        id: 'detail-4',
        storeName: '測試',
        barcodeValue: 'TEST',
        barcodeFormat: BarcodeFormatType.qr,
      );

      await tester.pumpWidget(
        MaterialApp(home: CardDetailScreen(card: card)),
      );
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, Colors.black);
    });

    testWidgets('編輯按鈕存在', (tester) async {
      final card = MemberCard(
        id: 'detail-5',
        storeName: '測試',
        barcodeValue: 'TEST',
        barcodeFormat: BarcodeFormatType.qr,
      );

      await tester.pumpWidget(
        MaterialApp(home: CardDetailScreen(card: card)),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit), findsOneWidget);
    });
  });
}
