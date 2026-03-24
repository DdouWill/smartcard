import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard/models/member_card.dart';
import 'package:smartcard/widgets/gps_zone_editor.dart';

void main() {
  group('W13: GpsZoneEditor 新增 Zone', () {
    testWidgets('點擊新增 → 填入經緯度 → 確認 → 列表新增一筆', (tester) async {
      var currentZones = <GpsZone>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SingleChildScrollView(
                  child: GpsZoneEditor(
                    zones: currentZones,
                    onZonesChanged: (updated) {
                      setState(() => currentZones = updated);
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      // 初始無 zone
      expect(find.text('尚未設定 GPS 區域（可選填）'), findsOneWidget);

      // 點擊新增區域按鈕
      await tester.tap(find.text('新增區域'));
      await tester.pumpAndSettle();

      // Dialog 出現
      expect(find.text('新增 GPS 區域'), findsOneWidget);

      // 找到 dialog 中的 TextField 並填入
      final textFields = find.byType(TextField);
      // 順序: 緯度, 經度, 區域名稱
      await tester.enterText(textFields.at(0), '25.0330');
      await tester.enterText(textFields.at(1), '121.5654');
      await tester.enterText(textFields.at(2), '台北101');

      // 點擊新增確認
      await tester.tap(find.widgetWithText(FilledButton, '新增'));
      await tester.pumpAndSettle();

      // 列表中出現新的 zone
      expect(find.text('台北101'), findsOneWidget);
      expect(find.text('尚未設定 GPS 區域（可選填）'), findsNothing);
    });

    testWidgets('新增 Zone 後列表顯示座標與半徑', (tester) async {
      var currentZones = <GpsZone>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SingleChildScrollView(
                  child: GpsZoneEditor(
                    zones: currentZones,
                    onZonesChanged: (updated) {
                      setState(() => currentZones = updated);
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('新增區域'));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), '24.16270');
      await tester.enterText(textFields.at(1), '120.64760');

      await tester.tap(find.widgetWithText(FilledButton, '新增'));
      await tester.pumpAndSettle();

      // 副標題包含座標與半徑
      expect(find.textContaining('24.16270'), findsWidgets);
      expect(find.textContaining('120.64760'), findsWidgets);
      expect(find.textContaining('100m'), findsOneWidget);
    });

    testWidgets('無效緯度顯示錯誤', (tester) async {
      var currentZones = <GpsZone>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SingleChildScrollView(
                  child: GpsZoneEditor(
                    zones: currentZones,
                    onZonesChanged: (updated) {
                      setState(() => currentZones = updated);
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('新增區域'));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      // 超出範圍的緯度
      await tester.enterText(textFields.at(0), '91.0');
      await tester.enterText(textFields.at(1), '121.0');

      await tester.tap(find.widgetWithText(FilledButton, '新增'));
      await tester.pumpAndSettle();

      // Dialog 仍然開啟，顯示錯誤
      expect(find.text('請輸入有效的緯度（-90 ~ 90）'), findsOneWidget);
    });
  });

  group('W14: GpsZoneEditor 驗證', () {
    testWidgets('緯度 < -90 → 顯示驗證錯誤', (tester) async {
      var currentZones = <GpsZone>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SingleChildScrollView(
                  child: GpsZoneEditor(
                    zones: currentZones,
                    onZonesChanged: (updated) {
                      setState(() => currentZones = updated);
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('新增區域'));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), '-91.0');
      await tester.enterText(textFields.at(1), '121.0');

      await tester.tap(find.widgetWithText(FilledButton, '新增'));
      await tester.pumpAndSettle();

      expect(find.text('請輸入有效的緯度（-90 ~ 90）'), findsOneWidget);
    });

    testWidgets('經度 > 180 → 顯示驗證錯誤', (tester) async {
      var currentZones = <GpsZone>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SingleChildScrollView(
                  child: GpsZoneEditor(
                    zones: currentZones,
                    onZonesChanged: (updated) {
                      setState(() => currentZones = updated);
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('新增區域'));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), '25.0');
      await tester.enterText(textFields.at(1), '181.0');

      await tester.tap(find.widgetWithText(FilledButton, '新增'));
      await tester.pumpAndSettle();

      expect(find.text('請輸入有效的經度（-180 ~ 180）'), findsOneWidget);
    });

    testWidgets('經度 < -180 → 顯示驗證錯誤', (tester) async {
      var currentZones = <GpsZone>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SingleChildScrollView(
                  child: GpsZoneEditor(
                    zones: currentZones,
                    onZonesChanged: (updated) {
                      setState(() => currentZones = updated);
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('新增區域'));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), '25.0');
      await tester.enterText(textFields.at(1), '-181.0');

      await tester.tap(find.widgetWithText(FilledButton, '新增'));
      await tester.pumpAndSettle();

      expect(find.text('請輸入有效的經度（-180 ~ 180）'), findsOneWidget);
    });

    testWidgets('非數字緯度 → 顯示驗證錯誤', (tester) async {
      var currentZones = <GpsZone>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SingleChildScrollView(
                  child: GpsZoneEditor(
                    zones: currentZones,
                    onZonesChanged: (updated) {
                      setState(() => currentZones = updated);
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('新增區域'));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'abc');
      await tester.enterText(textFields.at(1), '121.0');

      await tester.tap(find.widgetWithText(FilledButton, '新增'));
      await tester.pumpAndSettle();

      expect(find.text('請輸入有效的緯度（-90 ~ 90）'), findsOneWidget);
    });
  });

  group('W15: GpsZoneEditor 刪除 Zone', () {
    testWidgets('列表中有 2 個 zone → 刪除其中一個 → 列表剩 1 個', (tester) async {
      var currentZones = [
        GpsZone(latitude: 25.0330, longitude: 121.5654, label: '台北101'),
        GpsZone(latitude: 24.1627, longitude: 120.6476, label: '中港店'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SingleChildScrollView(
                  child: GpsZoneEditor(
                    zones: currentZones,
                    onZonesChanged: (updated) {
                      setState(() => currentZones = updated);
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      // 初始有 2 個 zone
      expect(find.text('台北101'), findsOneWidget);
      expect(find.text('中港店'), findsOneWidget);
      expect(find.byIcon(Icons.delete), findsNWidgets(2));

      // 點擊第一個刪除按鈕
      await tester.tap(find.byIcon(Icons.delete).first);
      await tester.pumpAndSettle();

      // 剩 1 個 zone
      expect(find.byIcon(Icons.delete), findsOneWidget);
      expect(find.text('中港店'), findsOneWidget);
    });

    testWidgets('刪除全部 zone → 顯示空狀態', (tester) async {
      var currentZones = [
        GpsZone(latitude: 25.0, longitude: 121.0, label: '僅有一個'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SingleChildScrollView(
                  child: GpsZoneEditor(
                    zones: currentZones,
                    onZonesChanged: (updated) {
                      setState(() => currentZones = updated);
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('僅有一個'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete));
      await tester.pumpAndSettle();

      expect(find.text('尚未設定 GPS 區域（可選填）'), findsOneWidget);
    });
  });
}
