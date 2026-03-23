// ============================================================
// LocationStatusCard — 定位狀態卡片元件
// ============================================================
// 顯示目前定位偵測狀態與匹配的卡片資訊。
// 依照狀態顯示不同內容：
//   - 偵測中：進度條 + "正在偵測附近店家..."
//   - 偵測到單一店家：店家名稱 + 條碼縮圖（Hero 動畫）
//   - 偵測到多家：多家名稱橫向滾動列表
//   - 無符合：顯示最近使用卡片（半透明樣式）
// ============================================================

import 'package:flutter/material.dart';

import '../models/member_card.dart';
import '../services/location_service.dart';
import 'barcode_display_widget.dart';

/// 定位狀態卡片
///
/// 使用範例：
/// ```dart
/// LocationStatusCard(
///   locationResult: controller.locationResult,
///   isDetecting: controller.isDetecting,
///   recentCard: controller.mostRecentCard,
///   onCardTap: (card) => Navigator.push(...),
/// )
/// ```
class LocationStatusCard extends StatelessWidget {
  /// 最近一次定位結果（null 表示尚未偵測）
  final LocationResult? locationResult;

  /// 是否正在偵測中
  final bool isDetecting;

  /// 最近使用的卡片（無符合時顯示）
  final MemberCard? recentCard;

  /// 點擊卡片回調（導航至對應卡片詳情）
  final void Function(MemberCard card) onCardTap;

  const LocationStatusCard({
    super.key,
    required this.locationResult,
    required this.isDetecting,
    required this.onCardTap,
    this.recentCard,
  });

  @override
  Widget build(BuildContext context) {
    // 偵測中狀態
    if (isDetecting) {
      return _buildDetectingCard(context);
    }

    // 尚未偵測（初始狀態）
    if (locationResult == null) {
      return _buildIdleCard(context);
    }

    final matched = locationResult!.matchedCards;

    // 偵測到單一店家
    if (matched.length == 1) {
      return _buildSingleMatchCard(context, matched.first);
    }

    // 偵測到多家
    if (matched.length > 1) {
      return _buildMultiMatchCard(context, matched);
    }

    // 無符合 → 顯示最近使用
    return _buildNoMatchCard(context);
  }

  // ──────────────────────────────────────────
  // 偵測中
  // ──────────────────────────────────────────

  Widget _buildDetectingCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_searching,
                  color: Theme.of(context).colorScheme.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  '正在偵測附近店家...',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 進度條
            LinearProgressIndicator(
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  // 初始閒置
  // ──────────────────────────────────────────

  Widget _buildIdleCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.location_off,
              color: Theme.of(context).colorScheme.outline,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              '尚未偵測位置',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  // 偵測到單一店家（帶 Hero 動畫）
  // ──────────────────────────────────────────

  Widget _buildSingleMatchCard(BuildContext context, MemberCard card) {
    final cardColor = _parseColor(card.cardColor) ??
        Theme.of(context).colorScheme.primaryContainer;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onCardTap(card),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cardColor,
                cardColor.withValues(alpha: 0.7),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 偵測圖示
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: Colors.white.withValues(alpha: 0.9),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '附近的店家',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      card.storeName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '點擊出示條碼',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const Spacer(),

                // 條碼縮圖（帶 Hero 動畫，tag 對應 CardDetailScreen）
                Hero(
                  tag: 'barcode_${card.id}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: BarcodeDisplayWidget(
                      barcodeValue: card.barcodeValue,
                      barcodeFormat: card.barcodeFormat,
                      width: 100,
                      height: 60,
                      showText: false,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  // 偵測到多家（橫向滾動）
  // ──────────────────────────────────────────

  Widget _buildMultiMatchCard(BuildContext context, List<MemberCard> cards) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 標題
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: Theme.of(context).colorScheme.primary,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '附近有 ${cards.length} 家店',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 橫向可滾動店家清單
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: cards.length,
                itemBuilder: (context, index) {
                  final card = cards[index];
                  final color = _parseColor(card.cardColor) ??
                      Theme.of(context).colorScheme.primaryContainer;

                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: InkWell(
                      onTap: () => onCardTap(card),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 120,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          border: Border.all(
                            color: color.withValues(alpha: 0.4),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              backgroundColor: color,
                              radius: 16,
                              child: Text(
                                card.storeName.isNotEmpty
                                    ? card.storeName[0]
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              card.storeName,
                              style: Theme.of(context).textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  // 無符合（顯示最近使用，半透明樣式）
  // ──────────────────────────────────────────

  Widget _buildNoMatchCard(BuildContext context) {
    // 如果沒有最近使用卡片，顯示簡單提示
    if (recentCard == null) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.location_off,
                color: Theme.of(context).colorScheme.outline,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                '附近無符合店家',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    // 顯示最近使用卡片（半透明）
    final card = recentCard!;
    final cardColor = _parseColor(card.cardColor) ??
        Theme.of(context).colorScheme.primaryContainer;

    return Opacity(
      opacity: 0.7, // 半透明表示非精確匹配
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: InkWell(
          onTap: () => onCardTap(card),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 最近使用標示
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.history,
                          size: 14,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '最近使用',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      card.storeName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const Spacer(),
                // 條碼縮圖
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: BarcodeDisplayWidget(
                    barcodeValue: card.barcodeValue,
                    barcodeFormat: card.barcodeFormat,
                    width: 80,
                    height: 48,
                    showText: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 解析 hex 顏色字串
  Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    try {
      final cleaned = hex.replaceAll('#', '');
      final withAlpha = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
      return Color(int.parse(withAlpha, radix: 16));
    } catch (_) {
      return null;
    }
  }
}
