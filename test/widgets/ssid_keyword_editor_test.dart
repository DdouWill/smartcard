import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard/widgets/ssid_keyword_editor.dart';

void main() {
  group('W11: SsidKeywordEditor 新增/刪除', () {
    testWidgets('輸入關鍵字並新增 → Chip 出現', (tester) async {
      var currentKeywords = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SsidKeywordEditor(
                  keywords: currentKeywords,
                  onKeywordsChanged: (updated) {
                    setState(() => currentKeywords = updated);
                  },
                );
              },
            ),
          ),
        ),
      );

      // 初始無 Chip
      expect(find.byType(Chip), findsNothing);
      expect(find.text('尚未設定關鍵字（可選填）'), findsOneWidget);

      // 輸入關鍵字
      await tester.enterText(find.byType(TextField), 'PX_Mart');
      // 點擊新增按鈕
      await tester.tap(find.text('新增'));
      await tester.pumpAndSettle();

      // Chip 出現
      expect(find.byType(Chip), findsOneWidget);
      expect(find.text('PX_Mart'), findsOneWidget);
      expect(find.text('尚未設定關鍵字（可選填）'), findsNothing);
    });

    testWidgets('新增多個關鍵字 → 多個 Chip', (tester) async {
      var currentKeywords = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SsidKeywordEditor(
                  keywords: currentKeywords,
                  onKeywordsChanged: (updated) {
                    setState(() => currentKeywords = updated);
                  },
                );
              },
            ),
          ),
        ),
      );

      // 新增第一個
      await tester.enterText(find.byType(TextField), '全聯');
      await tester.tap(find.text('新增'));
      await tester.pumpAndSettle();

      // 新增第二個
      await tester.enterText(find.byType(TextField), 'ibon');
      await tester.tap(find.text('新增'));
      await tester.pumpAndSettle();

      expect(find.byType(Chip), findsNWidgets(2));
      expect(find.text('全聯'), findsOneWidget);
      expect(find.text('ibon'), findsOneWidget);
    });

    testWidgets('刪除 Chip → Chip 消失', (tester) async {
      var currentKeywords = ['TestWiFi', 'AnotherWiFi'];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SsidKeywordEditor(
                  keywords: currentKeywords,
                  onKeywordsChanged: (updated) {
                    setState(() => currentKeywords = updated);
                  },
                );
              },
            ),
          ),
        ),
      );

      // 初始有 2 個 Chip
      expect(find.byType(Chip), findsNWidgets(2));

      // 點擊第一個 Chip 的刪除圖示
      final deleteIcons = find.byIcon(Icons.close);
      await tester.tap(deleteIcons.first);
      await tester.pumpAndSettle();

      // 剩 1 個 Chip
      expect(find.byType(Chip), findsOneWidget);
      expect(find.text('AnotherWiFi'), findsOneWidget);
    });

    testWidgets('空輸入不新增', (tester) async {
      var currentKeywords = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SsidKeywordEditor(
                  keywords: currentKeywords,
                  onKeywordsChanged: (updated) {
                    setState(() => currentKeywords = updated);
                  },
                );
              },
            ),
          ),
        ),
      );

      // 不輸入直接按新增
      await tester.tap(find.text('新增'));
      await tester.pumpAndSettle();

      expect(find.byType(Chip), findsNothing);
    });
  });

  group('W12: SsidKeywordEditor 重複偵測', () {
    testWidgets('輸入已存在的關鍵字 → 不新增且顯示 SnackBar 提示', (tester) async {
      var currentKeywords = ['PX_Mart'];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SsidKeywordEditor(
                  keywords: currentKeywords,
                  onKeywordsChanged: (updated) {
                    setState(() => currentKeywords = updated);
                  },
                );
              },
            ),
          ),
        ),
      );

      // 初始有 1 個 Chip
      expect(find.byType(Chip), findsOneWidget);

      // 輸入重複的關鍵字
      await tester.enterText(find.byType(TextField), 'PX_Mart');
      await tester.tap(find.text('新增'));
      await tester.pumpAndSettle();

      // 仍然只有 1 個 Chip
      expect(find.byType(Chip), findsOneWidget);
      // SnackBar 提示已存在
      expect(find.text('「PX_Mart」已存在'), findsOneWidget);
    });

    testWidgets('輸入不同關鍵字 → 正常新增', (tester) async {
      var currentKeywords = ['PX_Mart'];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SsidKeywordEditor(
                  keywords: currentKeywords,
                  onKeywordsChanged: (updated) {
                    setState(() => currentKeywords = updated);
                  },
                );
              },
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'ibon');
      await tester.tap(find.text('新增'));
      await tester.pumpAndSettle();

      expect(find.byType(Chip), findsNWidgets(2));
      expect(find.text('PX_Mart'), findsOneWidget);
      expect(find.text('ibon'), findsOneWidget);
    });
  });
}
