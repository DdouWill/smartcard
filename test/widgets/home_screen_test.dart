import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard/app_controller.dart';
import 'package:smartcard/models/member_card.dart';
import 'package:smartcard/screens/home_screen.dart';
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
  }

  void teardownChannelMocks() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('es.antonborri/home_widget/updates'), null,
    );
  }

  setUp(() async {
    setupChannelMocks();
    tempDir = Directory.systemTemp.createTempSync('home_test_').path;
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
    return const MaterialApp(home: HomeScreen());
  }

  // ──────────────────────────────────────────
  // W17: HomeScreen 空狀態
  // ──────────────────────────────────────────
  group('W17: HomeScreen 空狀態', () {
    testWidgets('無卡片時顯示空狀態提示', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('還沒有會員卡'), findsOneWidget);
      expect(find.text('新增會員卡'), findsOneWidget);
    });

    testWidgets('無卡片時 FAB 存在', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('新增卡片'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('AppBar 標題為 SmartCard', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('SmartCard'), findsOneWidget);
    });

    testWidgets('設定按鈕存在', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.byIcon(Icons.settings), findsOneWidget);
    });
  });

  // ──────────────────────────────────────────
  // W18: HomeScreen 有卡片列表
  // ──────────────────────────────────────────
  group('W18: HomeScreen 有卡片列表', () {
    testWidgets('3 張卡片 → 列表顯示 3 項', (tester) async {
      for (int i = 0; i < 3; i++) {
        await db.addCard(MemberCard(
          id: 'list-$i',
          storeName: '店家$i',
          barcodeValue: 'CODE-$i',
          barcodeFormat: BarcodeFormatType.qr,
          sortOrder: i,
        ));
      }
      await controller.initialize();

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('店家0'), findsOneWidget);
      expect(find.text('店家1'), findsOneWidget);
      expect(find.text('店家2'), findsOneWidget);
      // 空狀態不顯示
      expect(find.text('還沒有會員卡'), findsNothing);
    });

    testWidgets('有卡片時不顯示空狀態', (tester) async {
      await db.addCard(MemberCard(
        id: 'one-card',
        storeName: '唯一店家',
        barcodeValue: 'ONLY',
        barcodeFormat: BarcodeFormatType.qr,
      ));
      await controller.initialize();

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('唯一店家'), findsOneWidget);
      expect(find.text('還沒有會員卡'), findsNothing);
    });
  });
}
