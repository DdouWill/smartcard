import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard/app_controller.dart';
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
  }

  void teardownChannelMocks() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'), null);
  }

  setUp(() async {
    setupChannelMocks();
    tempDir = Directory.systemTemp.createTempSync('settings_test_').path;
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
    return const MaterialApp(home: SettingsScreen());
  }

  // ──────────────────────────────────────────
  // W19: SettingsScreen 所有開關
  // ──────────────────────────────────────────
  group('W19: SettingsScreen 所有開關', () {
    testWidgets('WiFi 偵測開關可見且預設開啟', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('WiFi SSID 偵測'), findsOneWidget);
      // SwitchListTile 中的 Switch 預設開啟
      final wifiSwitch = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'WiFi SSID 偵測'),
      );
      expect(wifiSwitch.value, isTrue);
    });

    testWidgets('GPS 偵測開關可見且預設開啟', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('GPS 地理圍欄偵測'), findsOneWidget);
      final gpsSwitch = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'GPS 地理圍欄偵測'),
      );
      expect(gpsSwitch.value, isTrue);
    });

    testWidgets('無符合時顯示最近使用開關可見且預設開啟', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      final recentSwitch = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, '無符合時顯示最近使用'),
      );
      expect(recentSwitch.value, isTrue);
    });

    testWidgets('Widget 更新間隔顯示 5 分鐘', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Widget 更新間隔'), findsOneWidget);
      expect(find.text('每 5 分鐘更新一次'), findsOneWidget);
    });

    testWidgets('條碼顯示亮度顯示最大亮度', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('條碼顯示亮度'), findsOneWidget);
      expect(find.text('最大亮度'), findsOneWidget);
    });

    testWidgets('切換 WiFi 開關 → 狀態更新', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      // 切換 WiFi 開關
      await tester.tap(find.widgetWithText(SwitchListTile, 'WiFi SSID 偵測'));
      await tester.pump(const Duration(milliseconds: 500));

      // 確認已關閉
      final wifiSwitch = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'WiFi SSID 偵測'),
      );
      expect(wifiSwitch.value, isFalse);
    });

    testWidgets('清除所有卡片按鈕可見', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      final clearBtn = find.text('清除所有卡片');
      await tester.ensureVisible(clearBtn);
      await tester.pump(const Duration(milliseconds: 500));
      expect(clearBtn, findsOneWidget);
    });

    testWidgets('匯出與匯入按鈕可見', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('匯出加密備份'), findsOneWidget);
      expect(find.text('匯入備份'), findsOneWidget);
    });

    testWidgets('版本號顯示', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));

      final versionTile = find.text('版本 1.0.0');
      await tester.ensureVisible(versionTile);
      await tester.pump(const Duration(milliseconds: 500));
      expect(versionTile, findsOneWidget);
    });
  });
}
