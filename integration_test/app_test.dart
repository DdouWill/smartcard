import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smartcard/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('SmartCard E2E', () {
    testWidgets('1. App 啟動 → HomeScreen', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // FAB「新增卡片」存在
      expect(find.text('新增卡片'), findsOneWidget);
      // Settings icon 存在
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('2. 新增卡片 → 手動輸入 → 儲存 → 回到 Home', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 點 FAB
      await tester.tap(find.text('新增卡片'));
      await tester.pumpAndSettle();

      // 進入 AddCardScreen
      expect(find.text('新增會員卡'), findsOneWidget);
      expect(find.text('掃描'), findsOneWidget);
      expect(find.text('圖片辨識'), findsOneWidget);
      expect(find.text('手動輸入'), findsOneWidget);

      // 切到手動輸入
      await tester.tap(find.text('手動輸入'));
      await tester.pumpAndSettle();

      // 填店名（labelText: '店家名稱 *'）
      await tester.enterText(
        find.widgetWithText(TextFormField, '店家名稱 *'),
        'TestStore',
      );
      await tester.pumpAndSettle();

      // 關 autocomplete — 點標題
      await tester.tap(find.text('新增會員卡'));
      await tester.pumpAndSettle();

      // 填條碼號碼（labelText: '條碼號碼 *'）
      final barcodeField = find.widgetWithText(TextFormField, '條碼號碼 *');
      await tester.ensureVisible(barcodeField);
      await tester.pumpAndSettle();
      await tester.enterText(barcodeField, '4710088020019');
      await tester.pumpAndSettle();

      // 預覽條碼應該出現
      // 滑到底部找儲存按鈕
      final saveBtn = find.text('儲存卡片');
      await tester.ensureVisible(saveBtn);
      await tester.pumpAndSettle();
      await tester.tap(saveBtn);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 回到 HomeScreen，卡片出現
      expect(find.text('TestStore'), findsOneWidget);
    });

    testWidgets('3. 卡片點擊 → 詳情頁', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final card = find.text('TestStore');
      if (card.evaluate().isEmpty) {
        // 沒有測試資料，跳過
        return;
      }

      await tester.tap(card.first);
      await tester.pumpAndSettle();

      // 詳情頁顯示條碼
      expect(find.text('4710088020019'), findsOneWidget);
    });

    testWidgets('4. 設定頁面', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      expect(find.text('設定'), findsOneWidget);
    });

    testWidgets('5. 刪除卡片（Dismissible 滑動）', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final card = find.text('TestStore');
      if (card.evaluate().isEmpty) return;

      // 左滑刪除
      await tester.drag(card.first, const Offset(-500, 0));
      await tester.pumpAndSettle();

      // 確認 dialog
      expect(find.text('刪除卡片'), findsOneWidget);
      await tester.tap(find.text('刪除'));
      await tester.pumpAndSettle();

      // 卡片消失
      expect(find.text('TestStore'), findsNothing);
    });
  });
}
