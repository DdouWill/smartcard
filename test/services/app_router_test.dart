import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard/app_controller.dart';
import 'package:smartcard/app_router.dart';
import 'package:smartcard/models/member_card.dart';
import 'package:smartcard/screens/add_card_screen.dart';
import 'package:smartcard/screens/home_screen.dart';
import 'package:smartcard/screens/settings_screen.dart';
import 'package:smartcard/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService db;
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
    tempDir = Directory.systemTemp.createTempSync('router_test_').path;
    db = DatabaseService();
    await db.initializeForTesting(tempDir);
    final controller = AppController();
    await controller.initialize();
  });

  tearDown(() async {
    teardownChannelMocks();
    await db.resetForTesting();
  });

  // ──────────────────────────────────────────
  // U25: AppRouter 路由解析
  // ──────────────────────────────────────────
  group('U25: AppRouter 路由解析', () {
    test('AppRouter 定義正確的 named route 常數', () {
      expect(AppRouter.home, '/');
      expect(AppRouter.cardDetail, '/card');
      expect(AppRouter.addCard, '/add-card');
      expect(AppRouter.editCard, '/edit-card');
      expect(AppRouter.settings, '/settings');
    });

    testWidgets('"/" 路由 → HomeScreen', (tester) async {
      await tester.pumpWidget(MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        initialRoute: AppRouter.home,
      ));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('"/add-card" 路由 → AddCardScreen', (tester) async {
      await tester.pumpWidget(MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        initialRoute: AppRouter.addCard,
      ));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(AddCardScreen), findsOneWidget);
    });

    testWidgets('"/settings" 路由 → SettingsScreen', (tester) async {
      await tester.pumpWidget(MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        initialRoute: AppRouter.settings,
      ));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('"/edit-card" 帶 MemberCard 參數 → AddCardScreen', (tester) async {
      final card = MemberCard(
        id: 'route-edit',
        storeName: '路由測試',
        barcodeValue: 'ROUTE-123',
        barcodeFormat: BarcodeFormatType.qr,
      );

      await tester.pumpWidget(MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () => Navigator.pushNamed(
                context,
                AppRouter.editCard,
                arguments: card,
              ),
              child: const Text('Go Edit'),
            );
          },
        ),
      ));
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Go Edit'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(AddCardScreen), findsOneWidget);
    });

    testWidgets('未知路由 → 顯示找不到頁面', (tester) async {
      await tester.pumpWidget(MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        initialRoute: '/nonexistent',
      ));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('找不到頁面'), findsOneWidget);
    });
  });
}
