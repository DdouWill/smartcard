// ============================================================
// CardWidget — 卡片列表項目元件
// ============================================================
// 顯示單張會員卡的摘要資訊：顏色背景、店名、條碼格式、條碼縮圖。
// 支援左滑刪除（Dismissible）與長按快速操作選單（編輯/刪除）。
// ============================================================

import 'package:flutter/material.dart';

import '../models/member_card.dart';
import '../utils/color_utils.dart';
import 'barcode_display_widget.dart';

/// 卡片列表項目
///
/// 使用範例：
/// ```dart
/// CardWidget(
///   card: memberCard,
///   onTap: () => Navigator.push(...),
///   onDelete: () => controller.deleteCard(card.id),
/// )
/// ```
class CardWidget extends StatelessWidget {
  /// 會員卡資料
  final MemberCard card;

  /// 點擊卡片回調（導航至 CardDetailScreen）
  final VoidCallback onTap;

  /// 刪除卡片回調
  final VoidCallback onDelete;

  /// 編輯卡片回調（選填）
  final VoidCallback? onEdit;

  const CardWidget({
    super.key,
    required this.card,
    required this.onTap,
    required this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    // 解析卡片自訂顏色
    final cardColor = parseHexColor(card.cardColor) ??
        Theme.of(context).colorScheme.primaryContainer;

    return Dismissible(
      // 唯一 key（用 card.id 確保無衝突）
      key: ValueKey('card_${card.id}'),
      direction: DismissDirection.endToStart, // 左滑刪除

      // 滑動時背景（紅色垃圾桶）
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.onErrorContainer,
          size: 28,
        ),
      ),

      // 確認刪除對話框
      confirmDismiss: (_) async {
        return await _showDeleteConfirm(context);
      },
      onDismissed: (_) => onDelete(),

      child: GestureDetector(
        // 長按顯示快速操作選單
        onLongPress: () => _showQuickActionMenu(context),
        child: Card(
          margin: const EdgeInsets.only(bottom: 8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            onLongPress: () => _showQuickActionMenu(context),
            child: Row(
              children: [
                // ── 左側顏色色塊 ──
                Container(
                  width: 8,
                  height: 80,
                  color: cardColor,
                ),

                // ── 卡片主要資訊 ──
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        // 店家名稱頭字圓形
                        CircleAvatar(
                          backgroundColor: cardColor,
                          radius: 22,
                          child: Text(
                            card.storeName.isNotEmpty
                                ? card.storeName[0]
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // 店名與條碼格式
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                card.storeName,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  // 條碼格式標籤
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondaryContainer,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      card.barcodeFormat.name.toUpperCase(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSecondaryContainer,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // 條碼數值（截短）
                                  Expanded(
                                    child: Text(
                                      card.barcodeValue,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .outline,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── 右側條碼縮圖 ──
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Hero(
                    tag: 'barcode_${card.id}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: BarcodeDisplayWidget(
                        barcodeValue: card.barcodeValue,
                        barcodeFormat: card.barcodeFormat,
                        width: 60,
                        height: 40,
                        showText: false, // 縮圖不顯示文字
                      ),
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

  /// 顯示刪除確認對話框
  Future<bool> _showDeleteConfirm(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除卡片'),
        content: Text('確定要刪除「${card.storeName}」嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// 顯示長按快速操作選單
  void _showQuickActionMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖把指示條
            Container(
              width: 32,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.outline.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 卡片標題
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                card.storeName,
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            const Divider(),
            // 開啟操作
            ListTile(
              leading: const Icon(Icons.open_in_full),
              title: const Text('開啟條碼'),
              onTap: () {
                Navigator.pop(ctx);
                onTap();
              },
            ),
            // 編輯操作（如有提供）
            if (onEdit != null)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('編輯'),
                onTap: () {
                  Navigator.pop(ctx);
                  onEdit!();
                },
              ),
            // 刪除操作
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(ctx).colorScheme.error,
              ),
              title: Text(
                '刪除',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                final confirmed = await _showDeleteConfirm(context);
                if (confirmed) onDelete();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

}
