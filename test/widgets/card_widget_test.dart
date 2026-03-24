import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard/models/member_card.dart';
import 'package:smartcard/widgets/card_widget.dart';

void main() {
  MemberCard createTestCard({
    String id = 'test-id',
    String storeName = '測試店家',
    String barcodeValue = 'TEST123',
    BarcodeFormatType format = BarcodeFormatType.qr,
    String? cardColor = '#2196F3',
  }) {
    return MemberCard(
      id: id,
      storeName: storeName,
      barcodeValue: barcodeValue,
      barcodeFormat: format,
      cardColor: cardColor,
    );
  }

  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));
  }

  group('W1: CardWidget 基本渲染', () {
    testWidgets('顯示店名', (tester) async {
      final card = createTestCard(storeName: '全聯福利中心');
      await tester.pumpWidget(wrap(
        CardWidget(card: card, onTap: () {}, onDelete: () {}),
      ));
      expect(find.text('全聯福利中心'), findsOneWidget);
    });

    testWidgets('顯示條碼值', (tester) async {
      final card = createTestCard(barcodeValue: 'MY-BARCODE-123');
      await tester.pumpWidget(wrap(
        CardWidget(card: card, onTap: () {}, onDelete: () {}),
      ));
      expect(find.text('MY-BARCODE-123'), findsOneWidget);
    });

    testWidgets('顯示格式標籤', (tester) async {
      final card = createTestCard(format: BarcodeFormatType.code128);
      await tester.pumpWidget(wrap(
        CardWidget(card: card, onTap: () {}, onDelete: () {}),
      ));
      expect(find.text('CODE128'), findsOneWidget);
    });

    testWidgets('顯示頭字圓形', (tester) async {
      final card = createTestCard(storeName: '全聯');
      await tester.pumpWidget(wrap(
        CardWidget(card: card, onTap: () {}, onDelete: () {}),
      ));
      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(find.text('全'), findsOneWidget);
    });
  });

  group('W2: CardWidget 長按選單', () {
    testWidgets('長按顯示操作選單含三個選項', (tester) async {
      final card = createTestCard(storeName: '7-ELEVEN');
      await tester.pumpWidget(wrap(
        CardWidget(
          card: card,
          onTap: () {},
          onDelete: () {},
          onEdit: () {},
        ),
      ));

      await tester.longPress(find.text('7-ELEVEN'));
      await tester.pumpAndSettle();

      expect(find.text('開啟條碼'), findsOneWidget);
      expect(find.text('編輯'), findsOneWidget);
      expect(find.text('刪除'), findsOneWidget);
    });

    testWidgets('長按選單顯示卡片名稱標題', (tester) async {
      final card = createTestCard(storeName: '家樂福');
      await tester.pumpWidget(wrap(
        CardWidget(
          card: card,
          onTap: () {},
          onDelete: () {},
          onEdit: () {},
        ),
      ));

      await tester.longPress(find.text('家樂福'));
      await tester.pumpAndSettle();

      // 卡片本身 + 選單標題 = 2
      expect(find.text('家樂福'), findsNWidgets(2));
    });

    testWidgets('點擊開啟條碼觸發 onTap', (tester) async {
      var tapped = false;
      final card = createTestCard();
      await tester.pumpWidget(wrap(
        CardWidget(
          card: card,
          onTap: () => tapped = true,
          onDelete: () {},
          onEdit: () {},
        ),
      ));

      await tester.longPress(find.text('測試店家'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('開啟條碼'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('無 onEdit 時不顯示編輯選項', (tester) async {
      final card = createTestCard();
      await tester.pumpWidget(wrap(
        CardWidget(
          card: card,
          onTap: () {},
          onDelete: () {},
          // onEdit not provided
        ),
      ));

      await tester.longPress(find.text('測試店家'));
      await tester.pumpAndSettle();

      expect(find.text('開啟條碼'), findsOneWidget);
      expect(find.text('編輯'), findsNothing);
      expect(find.text('刪除'), findsOneWidget);
    });
  });
}
