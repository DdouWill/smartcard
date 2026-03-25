// Android 桌面小工具服務
// 使用 home_widget 套件更新 Android App Widget
// 根據定位結果動態顯示對應的會員卡條碼
//
// 多卡模式：儲存所有匹配卡片的完整資料（含條碼），
// 由原生端透過 ◀ ▶ 箭頭切換顯示

import 'dart:async';
import 'package:home_widget/home_widget.dart';

import '../models/member_card.dart';
import 'store_location_service.dart';

/// Widget 顯示模式
/// 對應 SPEC.md 的 Widget 行為定義
enum WidgetDisplayMode {
  noMatch, // 0 家符合 → 顯示最近使用
  singleCard, // 1 家符合 → 直接顯示條碼
  multipleCards, // 2+ 家符合 → 顯示條碼 + ◀ ▶ 切換
}

/// Widget 服務（Singleton）
/// 負責更新 Android 桌面小工具的顯示內容
class WidgetService {
  static final WidgetService _instance = WidgetService._internal();
  factory WidgetService() => _instance;
  WidgetService._internal();

  // Android Widget Provider 類別名稱（對應 SmartCardWidgetProvider.kt）
  static const String _widgetProviderClass = 'SmartCardWidgetProvider';

  // 支援的最大卡片數量（Widget 空間限制）
  static const int _maxCards = 10;

  // ──────────────────────────────────────────
  // 初始化
  // ──────────────────────────────────────────

  /// 初始化 home_widget 設定
  Future<void> initialize() async {}

  // ──────────────────────────────────────────
  // 主要更新邏輯
  // ──────────────────────────────────────────

  /// 根據定位結果更新 Widget 顯示
  /// 增加防呆：確保資料格式正確，避免原生層崩潰
  Future<void> updateWidget({
    required List<MemberCard> matchedCards,
    List<MemberCard> allCards = const [],
    MemberCard? recentCard,
    NearestStoreInfo? nearestStore,
  }) async {
    try {
      // 每次資料更新都重設導航索引為 0
      await HomeWidget.saveWidgetData<int>('widget_current_index', 0);

      if (matchedCards.isEmpty) {
        // 無符合 → 優先顯示最近門市的卡片，否則顯示最近使用
        await _updateWithNoMatch(recentCard, nearestStore, allCards);
      } else if (matchedCards.length == 1) {
        // 1 張符合 → 直接顯示條碼
        await _updateWithSingleCard(matchedCards.first);
      } else {
        // 多張符合 → 儲存所有卡片，由原生端 ◀ ▶ 切換
        await _updateWithMultipleCards(matchedCards);
      }

      // 通知 Android 重繪 Widget
      await _notifyWidgetUpdate();
    } catch (_) {}
  }

  /// 無符合時：優先顯示最近門市對應的卡片，否則顯示最近使用
  Future<void> _updateWithNoMatch(
    MemberCard? recentCard,
    NearestStoreInfo? nearestStore,
    List<MemberCard> allCards,
  ) async {
    await HomeWidget.saveWidgetData<String>(
      'widget_mode',
      WidgetDisplayMode.noMatch.name,
    );

    // 優先：找最近門市品牌對應的卡片
    MemberCard? nearestCard;
    if (nearestStore != null) {
      final brandLower = nearestStore.brandName.toLowerCase();
      nearestCard = allCards.cast<MemberCard?>().firstWhere(
        (card) => card!.storeName.toLowerCase().contains(brandLower) ||
                   brandLower.contains(card.storeName.toLowerCase()),
        orElse: () => null,
      );
    }

    final displayCard = nearestCard ?? recentCard;

    if (displayCard != null) {
      await _saveCardData('primary', displayCard);
      if (nearestCard != null && nearestStore != null) {
        // 顯示最近門市距離
        await HomeWidget.saveWidgetData<String>(
          'widget_title',
          '${nearestStore.brandName}（${nearestStore.distanceText}）',
        );
      } else {
        await HomeWidget.saveWidgetData<String>(
          'widget_title',
          '最近使用',
        );
      }
    } else {
      // 完全沒有卡片時顯示引導文字
      await HomeWidget.saveWidgetData<String>('widget_title', '點擊新增會員卡');
      await HomeWidget.saveWidgetData<String>('primary_store_name', '');
      await HomeWidget.saveWidgetData<String>('primary_barcode_value', '');
      await HomeWidget.saveWidgetData<String>('primary_card_id', '');
    }

    // 儲存最近門市資訊供 Widget 顯示
    if (nearestStore != null) {
      await HomeWidget.saveWidgetData<String>(
        'nearest_store_text',
        '${nearestStore.brandName}（${nearestStore.distanceText}）',
      );
    } else {
      await HomeWidget.saveWidgetData<String>('nearest_store_text', '');
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

  /// 多張卡片符合：儲存所有卡片的完整資料供原生端切換
  Future<void> _updateWithMultipleCards(List<MemberCard> cards) async {
    await HomeWidget.saveWidgetData<String>(
      'widget_mode',
      WidgetDisplayMode.multipleCards.name,
    );
    await HomeWidget.saveWidgetData<String>(
      'widget_title',
      '附近 ${cards.length} 家店',
    );

    // 儲存卡片資料（含條碼值和格式，供原生端直接生成條碼圖）
    final displayCards = cards.take(_maxCards).toList();
    await HomeWidget.saveWidgetData<int>(
      'card_count',
      displayCards.length,
    );

    for (int i = 0; i < _maxCards; i++) {
      if (i < displayCards.length) {
        await _saveCardData('card_$i', displayCards[i]);
      } else {
        // 清理未使用的槽位（避免殘留舊資料）
        await _clearCardData('card_$i');
      }
    }
  }

  /// 儲存單張卡片的完整資料到 Widget 共享儲存
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

  /// 清理指定前綴的卡片資料
  Future<void> _clearCardData(String prefix) async {
    await HomeWidget.saveWidgetData<String>('${prefix}_store_name', '');
    await HomeWidget.saveWidgetData<String>('${prefix}_barcode_value', '');
    await HomeWidget.saveWidgetData<String>('${prefix}_barcode_format', '');
    await HomeWidget.saveWidgetData<String>('${prefix}_card_color', '');
    await HomeWidget.saveWidgetData<String>('${prefix}_card_id', '');
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
