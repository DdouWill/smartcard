// ============================================================
// StoreColorPicker — 店家顏色選擇器
// ============================================================
// 提供 8 種預設顏色供使用者選擇卡片背景色。
// 橫向排列圓形色票，選中時顯示勾選標記。
// ============================================================

import 'package:flutter/material.dart';

/// 店家顏色選擇器
///
/// 提供 8 種預設顏色，橫向排列圓形色票。
/// 使用範例：
/// ```dart
/// StoreColorPicker(
///   selectedColor: Colors.blue,
///   onColorSelected: (color) => setState(() => _cardColor = color),
/// )
/// ```
class StoreColorPicker extends StatelessWidget {
  /// 目前選中的顏色
  final Color? selectedColor;

  /// 顏色選擇回調
  final ValueChanged<Color> onColorSelected;

  /// 預設 8 種卡片顏色
  static const List<Color> presetColors = [
    Color(0xFF2196F3), // 藍
    Color(0xFFF44336), // 紅
    Color(0xFF4CAF50), // 綠
    Color(0xFFFF9800), // 橙
    Color(0xFF9C27B0), // 紫
    Color(0xFF00BCD4), // 青
    Color(0xFFE91E63), // 粉
    Color(0xFF1565C0), // 深藍
  ];

  /// 顏色對應名稱（無障礙用途）
  static const List<String> colorNames = [
    '藍色',
    '紅色',
    '綠色',
    '橙色',
    '紫色',
    '青色',
    '粉色',
    '深藍色',
  ];

  const StoreColorPicker({
    super.key,
    required this.selectedColor,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 標題
        Text(
          '卡片顏色',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 12),

        // 色票橫向排列
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(presetColors.length, (index) {
              final color = presetColors[index];
              final isSelected = selectedColor == color;

              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _ColorCircle(
                  color: color,
                  label: colorNames[index],
                  isSelected: isSelected,
                  onTap: () => onColorSelected(color),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

/// 單個圓形色票元件
class _ColorCircle extends StatelessWidget {
  final Color color;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorCircle({
    required this.color,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: isSelected
                ? Border.all(
                    color: Theme.of(context).colorScheme.onSurface,
                    width: 3,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: isSelected
              ? const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 20,
                )
              : null,
        ),
      ),
    );
  }
}
