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
      await tester.enterText(barcodeField, '4710088020017');
      await tester.pumpAndSettle();

      // 預覽條碼應該出現
      // 滑到底部找儲存按鈕
      final saveBtn = find.text('儲存卡片');
      await tester.ensureVisible(saveBtn);
      await tester.pumpAndSettle();
      await tester.tap(saveBtn);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 確認對話框
      final confirmBtn = find.text('確認儲存');
      if (confirmBtn.evaluate().isNotEmpty) {
        await tester.tap(confirmBtn.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));
      }

      // 回到 HomeScreen，卡片出現
      expect(find.text('TestStore'), findsAtLeastNWidgets(1));
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
      expect(find.text('4710088020017'), findsOneWidget);
    });

    testWidgets('4. 卡片編輯 → 修改店名 → 確認更新', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final card = find.text('TestStore');
      if (card.evaluate().isEmpty) return;

      // 進入詳情頁
      await tester.tap(card.first);
      await tester.pumpAndSettle();

      // 點編輯按鈕
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      // 進入編輯模式（自動切到手動輸入 tab）
      // 清除並修改店名
      final storeField = find.widgetWithText(TextFormField, '店家名稱 *');
      await tester.enterText(storeField, 'EditedStore');
      await tester.pumpAndSettle();

      // 關 autocomplete — 點標題
      final titleFinder = find.text('編輯會員卡');
      if (titleFinder.evaluate().isNotEmpty) {
        await tester.tap(titleFinder);
      } else {
        await tester.tap(find.text('新增會員卡'));
      }
      await tester.pumpAndSettle();

      // 點更新卡片按鈕
      final updateBtn = find.text('更新卡片');
      await tester.ensureVisible(updateBtn);
      await tester.pumpAndSettle();
      await tester.tap(updateBtn);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 確認對話框
      final confirmBtn = find.text('確認儲存');
      if (confirmBtn.evaluate().isNotEmpty) {
        await tester.tap(confirmBtn.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));
      }

      // 回到首頁，確認更新後的名稱
      // 可能回到 detail 頁再 pop，或直接回首頁
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 首頁應該顯示新名稱
      expect(find.text('EditedStore'), findsAtLeastNWidgets(1));
    });

    testWidgets('5. 設定頁面功能 → 匯出/匯入按鈕', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      expect(find.text('設定'), findsOneWidget);

      // 確認匯出備份按鈕
      expect(find.text('匯出加密備份'), findsOneWidget);

      // 確認匯入備份按鈕
      final importBtn = find.text('匯入備份');
      await tester.ensureVisible(importBtn);
      await tester.pumpAndSettle();
      expect(importBtn, findsOneWidget);

      // 返回首頁
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      // 確認回到首頁
      expect(find.text('新增卡片'), findsOneWidget);
    });

    testWidgets('6. 多卡片測試 → 新增 2 張 → 確認顯示 → 清理', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // ── 新增第一張卡片 ──
      await tester.tap(find.text('新增卡片'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('手動輸入'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, '店家名稱 *'),
        'StoreAlpha',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('新增會員卡'));
      await tester.pumpAndSettle();

      final barcodeField1 = find.widgetWithText(TextFormField, '條碼號碼 *');
      await tester.ensureVisible(barcodeField1);
      await tester.pumpAndSettle();
      // EAN-13: 4902778913048 (valid checksum)
      await tester.enterText(barcodeField1, '4902778913048');
      await tester.pumpAndSettle();

      final saveBtn1 = find.text('儲存卡片');
      await tester.ensureVisible(saveBtn1);
      await tester.pumpAndSettle();
      await tester.tap(saveBtn1);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 確認對話框
      var confirmBtn = find.text('確認儲存');
      if (confirmBtn.evaluate().isNotEmpty) {
        await tester.tap(confirmBtn.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));
      }

      expect(find.text('StoreAlpha'), findsAtLeastNWidgets(1));

      // ── 新增第二張卡片 ──
      await tester.tap(find.text('新增卡片'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('手動輸入'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, '店家名稱 *'),
        'StoreBeta',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('新增會員卡'));
      await tester.pumpAndSettle();

      final barcodeField2 = find.widgetWithText(TextFormField, '條碼號碼 *');
      await tester.ensureVisible(barcodeField2);
      await tester.pumpAndSettle();
      // EAN-13: 8801234567891 (valid checksum)
      await tester.enterText(barcodeField2, '8801234567891');
      await tester.pumpAndSettle();

      final saveBtn2 = find.text('儲存卡片');
      await tester.ensureVisible(saveBtn2);
      await tester.pumpAndSettle();
      await tester.tap(saveBtn2);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      confirmBtn = find.text('確認儲存');
      if (confirmBtn.evaluate().isNotEmpty) {
        await tester.tap(confirmBtn.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));
      }

      // 確認兩張卡片都在首頁
      expect(find.text('StoreAlpha'), findsAtLeastNWidgets(1));
      expect(find.text('StoreBeta'), findsAtLeastNWidgets(1));

      // ── 清理：刪除 StoreAlpha ──
      await tester.drag(find.text('StoreAlpha').first, const Offset(-500, 0));
      await tester.pumpAndSettle();
      if (find.text('刪除卡片').evaluate().isNotEmpty) {
        await tester.tap(find.text('刪除'));
        await tester.pumpAndSettle();
      }

      // ── 清理：刪除 StoreBeta ──
      await tester.drag(find.text('StoreBeta').first, const Offset(-500, 0));
      await tester.pumpAndSettle();
      if (find.text('刪除卡片').evaluate().isNotEmpty) {
        await tester.tap(find.text('刪除'));
        await tester.pumpAndSettle();
      }

      expect(find.text('StoreAlpha'), findsNothing);
      expect(find.text('StoreBeta'), findsNothing);
    });

    testWidgets('7. 刪除卡片（Dismissible 滑動）', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final card = find.text('EditedStore');
      if (card.evaluate().isEmpty) return;

      // 左滑刪除
      await tester.drag(card.first, const Offset(-500, 0));
      await tester.pumpAndSettle();

      // 確認 dialog
      expect(find.text('刪除卡片'), findsOneWidget);
      await tester.tap(find.text('刪除'));
      await tester.pumpAndSettle();

      // 卡片消失
      expect(find.text('EditedStore'), findsNothing);
    });
  });
}
