// ============================================================
// SsidKeywordEditor — SSID 關鍵字編輯器
// ============================================================
// 允許使用者管理 WiFi SSID 關鍵字清單。
// 顯示已新增的關鍵字 Chip，並提供輸入框新增或刪除關鍵字。
// ============================================================

import 'package:flutter/material.dart';

/// SSID 關鍵字編輯器
///
/// 使用範例：
/// ```dart
/// SsidKeywordEditor(
///   keywords: ['PX Mart', '全聯'],
///   onKeywordsChanged: (updated) => setState(() => _keywords = updated),
/// )
/// ```
class SsidKeywordEditor extends StatefulWidget {
  /// 目前的關鍵字清單
  final List<String> keywords;

  /// 關鍵字變更回調（傳出更新後的完整清單）
  final ValueChanged<List<String>> onKeywordsChanged;

  const SsidKeywordEditor({
    super.key,
    required this.keywords,
    required this.onKeywordsChanged,
  });

  @override
  State<SsidKeywordEditor> createState() => _SsidKeywordEditorState();
}

class _SsidKeywordEditorState extends State<SsidKeywordEditor> {
  final _inputController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// 新增關鍵字
  void _addKeyword() {
    final keyword = _inputController.text.trim();

    // 空值或重複則忽略
    if (keyword.isEmpty) return;
    if (widget.keywords.contains(keyword)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('「$keyword」已存在'),
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }

    // 新增並通知父元件
    final updated = [...widget.keywords, keyword];
    widget.onKeywordsChanged(updated);
    _inputController.clear();
    _focusNode.requestFocus();
  }

  /// 刪除指定索引的關鍵字
  void _removeKeyword(int index) {
    final updated = List<String>.from(widget.keywords)..removeAt(index);
    widget.onKeywordsChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 標題與說明
        Row(
          children: [
            Text(
              'WiFi SSID 關鍵字',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: '當手機連線至包含此關鍵字的 WiFi 時，自動顯示此卡片',
              triggerMode: TooltipTriggerMode.tap,
              child: Icon(
                Icons.help_outline,
                size: 16,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '輸入 WiFi 名稱關鍵字（例：全聯、PX Mart）',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
        const SizedBox(height: 12),

        // 輸入框 + 新增按鈕
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                focusNode: _focusNode,
                decoration: const InputDecoration(
                  hintText: '輸入 WiFi 名稱關鍵字',
                  prefixIcon: Icon(Icons.wifi),
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addKeyword(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: _addKeyword,
              child: const Text('新增'),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 已新增的關鍵字 Chip 清單
        if (widget.keywords.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '尚未設定關鍵字（可選填）',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(widget.keywords.length, (index) {
              return Chip(
                label: Text(widget.keywords[index]),
                avatar: const Icon(Icons.wifi, size: 16),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => _removeKeyword(index),
                deleteButtonTooltipMessage: '移除關鍵字',
              );
            }),
          ),
      ],
    );
  }
}
