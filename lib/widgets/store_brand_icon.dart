// ============================================================
// StoreBrandIcon — 店家品牌 icon/mark 元件
// ============================================================
// 依品牌名稱顯示對應的品牌色 + emoji badge，讓地圖標記與卡片列表
// 視覺上更直覺辨識品牌。
//
// 設計原則：
// - 不引入外部圖片資產，使用本地定義的品牌色 + emoji
// - 優先用 known_stores.dart 的 brandColor；無資料時 fallback 至卡片自訂色或主題色
// - 支援不同尺寸（radius）
// ============================================================

import 'package:flutter/material.dart';

import '../data/known_stores.dart';
import '../utils/color_utils.dart'; // parseHexColor

/// 店家品牌 icon badge
///
/// 使用範例：
/// ```dart
/// StoreBrandIcon(storeName: card.storeName, radius: 22, cardColor: cardColor)
/// StoreBrandIcon(storeName: '星巴克 Starbucks', radius: 18)
/// ```
class StoreBrandIcon extends StatelessWidget {
  /// 店家名稱（用於查詢品牌色與 emoji）
  final String storeName;

  /// 圓形半徑（預設 22）
  final double radius;

  /// 卡片自訂顏色（fallback 用，當品牌無預設色時使用）
  final Color? cardColor;

  const StoreBrandIcon({
    super.key,
    required this.storeName,
    this.radius = 22,
    this.cardColor,
  });

  @override
  Widget build(BuildContext context) {
    final emoji = getStoreEmoji(storeName);
    final brandColorHex = getStoreBrandColor(storeName);

    // 解析品牌色：brandColor > cardColor > 主題 primaryContainer
    // brandColorHex 格式為 8碼 ARGB hex，轉為 # + 8碼後用 parseHexColor 解析
    Color bgColor;
    if (brandColorHex != null) {
      final parsedBrand =
          parseHexColor('#$brandColorHex'); // parseHexColor 支援 AARRGGBB
      bgColor = parsedBrand ??
          cardColor ??
          Theme.of(context).colorScheme.primaryContainer;
    } else {
      bgColor = cardColor ?? Theme.of(context).colorScheme.primaryContainer;
    }

    // 計算對比文字色（確保 emoji 在深色/淺色背景均可辨識）
    final luminance = bgColor.computeLuminance();
    final shadowColor = luminance > 0.5 ? Colors.black26 : Colors.white24;

    final fontSize = radius * 0.9;

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Text(
          emoji,
          style: TextStyle(fontSize: fontSize, height: 1.0),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

}
