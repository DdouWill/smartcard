// Android 桌面小工具服務
// 使用 home_widget 套件更新 Android App Widget
// 根據定位結果動態顯示對應的會員卡條碼

import 'dart:async';
import 'package:home_widget/home_widget.dart';

import '../models/member_card.dart';

/// Widget 顯示模式
/// 對應 SPEC.md 的 Widget 行為定義
enum WidgetDisplayMode {
  noMatch, // 0 家符合 → 顯示最近使用
  singleCard, // 1 家符合 → 直接顯示條碼
  multipleCards, // 2~5 家符合 → 顯示店家按鈕
}

/// Widget 服務（Singleton）
/// 負責更新 Android 桌面小工具的顯示內容
class WidgetService {
  static final WidgetService _instance = WidgetService._internal();
  factory WidgetService() => _instance;
  WidgetService._internal();

  // Android Widget Provider 類別名稱（對應 SmartCardWidgetProvider.kt）
  static const String _widgetProviderClass =
      'SmartCardWidgetProvider';

  // ──────────────────────────────────────────
  // 初始化
  // ──────────────────────────────────────────

  /// 初始化 home_widget 設定
  Future<void> initialize() async {
  }

  // ──────────────────────────────────────────
  // 主要更新邏輯
  // ──────────────────────────────────────────

  /// 根據定位結果更新 Widget 顯示
  /// 增加防呆：確保資料格式正確，避免原生層崩潰
  Future<void> updateWidget({
    required List<MemberCard> matchedCards,
    MemberCard? recentCard,
  }) async {
    try {
      if (matchedCards.isEmpty) {
        // 無符合 → 顯示最近使用的卡片
        await _updateWithNoMatch(recentCard);
      } else if (matchedCards.length == 1) {
        // 1 張符合 → 直接顯示條碼
        await _updateWithSingleCard(matchedCards.first);
      } else {
        // 多張符合 → 顯示店家選擇按鈕
        await _updateWithMultipleCards(matchedCards);
      }

      // 通知 Android 重繪 Widget
      await _notifyWidgetUpdate();
    } catch (_) {
    }
  }

  /// 無符合時：顯示最近使用的卡片
  Future<void> _updateWithNoMatch(MemberCard? recentCard) async {
    await HomeWidget.saveWidgetData<String>(
      'widget_mode',
      WidgetDisplayMode.noMatch.name,
    );

    if (recentCard != null) {
      await _saveCardData('primary', recentCard);
      await HomeWidget.saveWidgetData<String>(
        'widget_title',
        '最近使用',
      );
    } else {
      // 完全沒有卡片時顯示引導文字
      await HomeWidget.saveWidgetData<String>('widget_title', '點擊新增會員卡');
      await HomeWidget.saveWidgetData<String>('primary_store_name', '');
      await HomeWidget.saveWidgetData<String>('primary_barcode_value', '');
      await HomeWidget.saveWidgetData<String>('primary_card_id', '');
    }

  }

  /// 單張卡片符合：直接顯示條碼
  Future<void> _updateWithSingleCard(MemberCard card) async {
    await HomeWidget.saveWidgetData<String>(
      'widget_mode',
      WidgetDisplayMode.singleCard.name,
    );
    await HomeWidget.saveWidgetData<String>(
      'widget_title',
      card.storeName,
    );
    await _saveCardData('primary', card);

  }

  /// 多張卡片符合：顯示店家按鈕清單
  Future<void> _updateWithMultipleCards(List<MemberCard> cards) async {
    await HomeWidget.saveWidgetData<String>(
      'widget_mode',
      WidgetDisplayMode.multipleCards.name,
    );
    await HomeWidget.saveWidgetData<String>(
      'widget_title',
      '附近 ${cards.length} 家店',
    );

    // 儲存最多 5 張卡片資料（Widget 空間限制）
    final displayCards = cards.take(5).toList();
    await HomeWidget.saveWidgetData<int>(
      'card_count',
      displayCards.length,
    );

    for (int i = 0; i < 5; i++) {
      if (i < displayCards.length) {
        await _saveCardData('card_$i', displayCards[i]);
      } else {
        // 清理剩餘槽位資料
        await HomeWidget.saveWidgetData<String>('card_${i}_store_name', '');
        await HomeWidget.saveWidgetData<String>('card_${i}_card_id', '');
      }
    }

  }

  /// 儲存單張卡片資料到 Widget 共享儲存
  Future<void> _saveCardData(String prefix, MemberCard card) async {
    await HomeWidget.saveWidgetData<String>(
      '${prefix}_store_name',
      card.storeName,
    );
    await HomeWidget.saveWidgetData<String>(
      '${prefix}_barcode_value',
      card.barcodeValue,
    );
    await HomeWidget.saveWidgetData<String>(
      '${prefix}_barcode_format',
      card.barcodeFormat.name,
    );
    await HomeWidget.saveWidgetData<String>(
      '${prefix}_card_color',
      card.cardColor ?? '#2196F3', // 預設藍色
    );
    await HomeWidget.saveWidgetData<String>(
      '${prefix}_card_id',
      card.id,
    );
  }

  /// 通知 Android 系統更新 Widget UI
  Future<void> _notifyWidgetUpdate() async {
    await HomeWidget.updateWidget(
      androidName: _widgetProviderClass,
    );
  }

  // ──────────────────────────────────────────
  // Widget 互動回調
  // ──────────────────────────────────────────

  StreamSubscription<Uri?>? _widgetClickSubscription;

  void setWidgetClickCallback(
    void Function(Uri? uri) onWidgetClicked,
  ) {
    _widgetClickSubscription?.cancel();
    _widgetClickSubscription = HomeWidget.widgetClicked.listen(onWidgetClicked);
  }

  void dispose() {
    _widgetClickSubscription?.cancel();
    _widgetClickSubscription = null;
  }

  Future<void> handleInitialWidgetUri([
    void Function(Uri? uri)? onWidgetClicked,
  ]) async {
    final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    if (uri != null) {
      onWidgetClicked?.call(uri);
    }
  }
}
