import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard/models/member_card.dart';
import 'package:smartcard/widgets/barcode_display_widget.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  group('W4: BarcodeDisplayWidget 各格式渲染', () {
    final testCases = <String, (BarcodeFormatType, String)>{
      'EAN13': (BarcodeFormatType.ean13, '5901234123457'),
      'QR': (BarcodeFormatType.qr, 'Hello World'),
      'Code128': (BarcodeFormatType.code128, 'Hello-123'),
      'EAN8': (BarcodeFormatType.ean8, '12345670'),
      'Code39': (BarcodeFormatType.code39, 'HELLO'),
    };

    for (final entry in testCases.entries) {
      testWidgets('${entry.key} 格式渲染不報錯', (tester) async {
        await tester.pumpWidget(wrap(
          BarcodeDisplayWidget(
            barcodeValue: entry.value.$2,
            barcodeFormat: entry.value.$1,
            width: 200,
            height: 100,
          ),
        ));

        // 不應顯示錯誤提示
        expect(find.text('條碼格式錯誤'), findsNothing);
        expect(find.text('請輸入條碼'), findsNothing);
      });
    }
  });

  group('W5: BarcodeDisplayWidget 無效條碼', () {
    testWidgets('空條碼顯示 placeholder', (tester) async {
      await tester.pumpWidget(wrap(
        const BarcodeDisplayWidget(
          barcodeValue: '',
          barcodeFormat: BarcodeFormatType.ean13,
          width: 200,
          height: 100,
        ),
      ));

      expect(find.text('請輸入條碼'), findsOneWidget);
    });

    testWidgets('空白條碼顯示 placeholder', (tester) async {
      await tester.pumpWidget(wrap(
        const BarcodeDisplayWidget(
          barcodeValue: '   ',
          barcodeFormat: BarcodeFormatType.ean13,
          width: 200,
          height: 100,
        ),
      ));

      expect(find.text('請輸入條碼'), findsOneWidget);
    });

    testWidgets('無效 EAN13 值顯示錯誤而非 crash', (tester) async {
      await tester.pumpWidget(wrap(
        const BarcodeDisplayWidget(
          barcodeValue: 'ABC',
          barcodeFormat: BarcodeFormatType.ean13,
          width: 200,
          height: 100,
        ),
      ));

      // BarcodeWidget errorBuilder 觸發，顯示錯誤文字
      expect(find.text('條碼格式錯誤'), findsOneWidget);
      // 同時顯示原始值
      expect(find.text('ABC'), findsOneWidget);
    });

    testWidgets('無效 EAN8 值顯示錯誤而非 crash', (tester) async {
      await tester.pumpWidget(wrap(
        const BarcodeDisplayWidget(
          barcodeValue: 'XYZ',
          barcodeFormat: BarcodeFormatType.ean8,
          width: 200,
          height: 100,
        ),
      ));

      expect(find.text('條碼格式錯誤'), findsOneWidget);
    });
  });
}
