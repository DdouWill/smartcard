// ============================================================
// SettingsScreen — 設定頁
// ============================================================
// 提供 App 全域設定的讀寫介面，使用 AppController 進行持久化。
// 設定項目：WiFi 偵測、GPS 偵測、Widget 更新間隔、螢幕亮度模式、
// 資料管理（清除所有卡片）、關於 App（版本號）。
// ============================================================

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../models/app_settings.dart';

/// 設定頁
///
/// 使用 AppController 讀寫設定，所有修改即時持久化。
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppController();

    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
        centerTitle: false,
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final settings = controller.settings;

          return ListView(
            children: [
              // ── 定位偵測區塊 ──
              _SectionHeader(title: '位置偵測'),

              // WiFi 偵測開關
              SwitchListTile(
                secondary: const Icon(Icons.wifi),
                title: const Text('WiFi SSID 偵測'),
                subtitle: const Text('連線至特定 WiFi 時自動顯示對應卡片'),
                value: settings.enableWifi,
                onChanged: (_) => controller.toggleWifi(),
              ),

              // GPS 偵測開關
              SwitchListTile(
                secondary: const Icon(Icons.location_on),
                title: const Text('GPS 地理圍欄偵測'),
                subtitle: const Text('進入店家附近時自動顯示對應卡片'),
                value: settings.enableGps,
                onChanged: (_) => controller.toggleGps(),
              ),

              const Divider(),

              // ── Widget 設定區塊 ──
              _SectionHeader(title: '桌面 Widget'),

              // Widget 更新間隔
              ListTile(
                leading: const Icon(Icons.update),
                title: const Text('Widget 更新間隔'),
                subtitle: Text('每 ${settings.updateIntervalMinutes} 分鐘更新一次'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showIntervalDialog(context, controller, settings),
              ),

              const Divider(),

              // ── 顯示設定區塊 ──
              _SectionHeader(title: '顯示設定'),

              // 螢幕亮度模式
              ListTile(
                leading: const Icon(Icons.brightness_6),
                title: const Text('條碼顯示亮度'),
                subtitle: Text(_brightnessModeName(settings.brightnessMode)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showBrightnessDialog(context, controller, settings),
              ),

              // 無符合時顯示最近使用
              SwitchListTile(
                secondary: const Icon(Icons.history),
                title: const Text('無符合時顯示最近使用'),
                subtitle: const Text('附近無店家時顯示上次使用的卡片'),
                value: settings.showRecentOnEmpty,
                onChanged: (value) {
                  controller.updateSettings(AppSettings(
                    enableWifi: settings.enableWifi,
                    enableGps: settings.enableGps,
                    updateIntervalMinutes: settings.updateIntervalMinutes,
                    screenBrightnessMode: settings.screenBrightnessMode,
                    showRecentOnEmpty: value,
                    maxWidgetCards: settings.maxWidgetCards,
                  ));
                },
              ),

              const Divider(),

              // ── 資料管理區塊 ──
              _SectionHeader(title: '資料管理'),

              // 匯出加密備份
              ListTile(
                leading: const Icon(Icons.backup_outlined),
                title: const Text('匯出加密備份'),
                subtitle: const Text('將所有卡片匯出為加密檔案'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('匯出功能將在 Phase 3 實作'),
                    ),
                  );
                },
              ),

              // 匯入備份
              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('匯入備份'),
                subtitle: const Text('從加密備份檔案還原卡片'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('匯入功能將在 Phase 3 實作'),
                    ),
                  );
                },
              ),

              const Divider(),

              // 清除所有卡片
              ListTile(
                leading: Icon(
                  Icons.delete_sweep_outlined,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  '清除所有卡片',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                subtitle: Text(
                  '共 ${controller.cards.length} 張卡片',
                  style: TextStyle(color: Theme.of(context).colorScheme.outline),
                ),
                onTap: () => _showClearAllDialog(context, controller),
              ),

              const Divider(),

              // ── 關於區塊 ──
              _SectionHeader(title: '關於'),

              // App 版本號
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('SmartCard'),
                subtitle: Text('版本 1.0.0'),
              ),

              // 開發者資訊
              const ListTile(
                leading: Icon(Icons.code),
                title: Text('技術說明'),
                subtitle: Text('完全離線 · Material Design 3 · Flutter'),
              ),

              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  // ──────────────────────────────────────────
  // Widget 更新間隔選擇對話框
  // ──────────────────────────────────────────

  Future<void> _showIntervalDialog(
    BuildContext context,
    AppController controller,
    AppSettings settings,
  ) async {
    // 可選的更新間隔（分鐘）
    const intervals = [1, 5, 10, 30];

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Widget 更新間隔'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: intervals.map((minutes) {
            return RadioListTile<int>(
              value: minutes,
              groupValue: settings.updateIntervalMinutes,
              title: Text('$minutes 分鐘'),
              onChanged: (value) {
                if (value != null) {
                  controller.updateSettings(AppSettings(
                    enableWifi: settings.enableWifi,
                    enableGps: settings.enableGps,
                    updateIntervalMinutes: value,
                    screenBrightnessMode: settings.screenBrightnessMode,
                    showRecentOnEmpty: settings.showRecentOnEmpty,
                    maxWidgetCards: settings.maxWidgetCards,
                  ));
                }
                Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  // 螢幕亮度模式選擇對話框
  // ──────────────────────────────────────────

  Future<void> _showBrightnessDialog(
    BuildContext context,
    AppController controller,
    AppSettings settings,
  ) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('條碼顯示亮度'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ScreenBrightnessMode.values.map((mode) {
            return RadioListTile<ScreenBrightnessMode>(
              value: mode,
              groupValue: settings.brightnessMode,
              title: Text(_brightnessModeName(mode)),
              subtitle: Text(_brightnessModeDesc(mode)),
              onChanged: (value) {
                if (value != null) {
                  controller.updateSettings(AppSettings(
                    enableWifi: settings.enableWifi,
                    enableGps: settings.enableGps,
                    updateIntervalMinutes: settings.updateIntervalMinutes,
                    screenBrightnessMode: value.index,
                    showRecentOnEmpty: settings.showRecentOnEmpty,
                    maxWidgetCards: settings.maxWidgetCards,
                  ));
                }
                Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  // 清除所有卡片確認對話框
  // ──────────────────────────────────────────

  Future<void> _showClearAllDialog(
    BuildContext context,
    AppController controller,
  ) async {
    if (controller.cards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('目前沒有任何卡片')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Theme.of(ctx).colorScheme.error,
          size: 32,
        ),
        title: const Text('清除所有卡片'),
        content: Text(
          '確定要刪除全部 ${controller.cards.length} 張卡片嗎？\n此操作無法復原。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('全部刪除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await controller.deleteAllCards();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已清除所有卡片')),
        );
      }
    }
  }

  // ──────────────────────────────────────────
  // 輔助方法
  // ──────────────────────────────────────────

  /// 亮度模式名稱
  String _brightnessModeName(ScreenBrightnessMode mode) {
    switch (mode) {
      case ScreenBrightnessMode.system:
        return '系統亮度';
      case ScreenBrightnessMode.maximum:
        return '最大亮度';
      case ScreenBrightnessMode.keepOn:
        return '螢幕常亮';
    }
  }

  /// 亮度模式說明
  String _brightnessModeDesc(ScreenBrightnessMode mode) {
    switch (mode) {
      case ScreenBrightnessMode.system:
        return '使用目前系統亮度設定';
      case ScreenBrightnessMode.maximum:
        return '顯示條碼時自動調至最亮，方便掃描';
      case ScreenBrightnessMode.keepOn:
        return '顯示條碼時保持螢幕不熄滅';
    }
  }
}

// ──────────────────────────────────────────
// 區塊標題元件
// ──────────────────────────────────────────

/// 設定頁區塊標題
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
