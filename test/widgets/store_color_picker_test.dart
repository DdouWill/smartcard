import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard/widgets/store_color_picker.dart';

void main() {
  group('W16: StoreColorPicker 選擇', () {
    testWidgets('顯示所有 8 種預設顏色', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StoreColorPicker(
              selectedColor: null,
              onColorSelected: (_) {},
            ),
          ),
        ),
      );

      // 標題
      expect(find.text('卡片顏色'), findsOneWidget);

      // 8 個 Tooltip（對應 8 種顏色名稱）
      for (final name in StoreColorPicker.colorNames) {
        expect(find.byTooltip(name), findsOneWidget);
      }
    });

    testWidgets('點擊顏色觸發 onColorSelected 回調', (tester) async {
      Color? selectedColor;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StoreColorPicker(
              selectedColor: null,
              onColorSelected: (color) => selectedColor = color,
            ),
          ),
        ),
      );

      // 點擊紅色（第 2 個，index 1）
      await tester.tap(find.byTooltip('紅色'));
      await tester.pumpAndSettle();

      expect(selectedColor, equals(StoreColorPicker.presetColors[1]));
      expect(selectedColor, equals(const Color(0xFFF44336)));
    });

    testWidgets('選中的顏色顯示勾選標記', (tester) async {
      const blueColor = Color(0xFF2196F3);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StoreColorPicker(
              selectedColor: blueColor,
              onColorSelected: (_) {},
            ),
          ),
        ),
      );

      // 選中的藍色應顯示勾選 icon
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('切換選擇 → 勾選標記移動', (tester) async {
      Color currentColor = StoreColorPicker.presetColors[0]; // 藍色

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return StoreColorPicker(
                  selectedColor: currentColor,
                  onColorSelected: (color) {
                    setState(() => currentColor = color);
                  },
                );
              },
            ),
          ),
        ),
      );

      // 初始選藍色，有 1 個勾選
      expect(find.byIcon(Icons.check), findsOneWidget);

      // 點擊綠色
      await tester.tap(find.byTooltip('綠色'));
      await tester.pumpAndSettle();

      // 仍然只有 1 個勾選（移到了綠色）
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(currentColor, equals(StoreColorPicker.presetColors[2]));
    });
  });
}
