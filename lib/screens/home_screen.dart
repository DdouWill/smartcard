import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../app_controller.dart';
import '../app_router.dart';
import '../models/member_card.dart';
import '../services/update_service.dart';
import '../widgets/card_widget.dart';
import '../widgets/location_status_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _controller = AppController();


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 延後 widget callback 設定，確保 Navigator 已就緒
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.setupWidgetCallbacks(_handleWidgetClick);
    });
    _controller.runLocationDetection();
    _checkPermissions();
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    // 延遲讓畫面先渲染完成
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;
    await UpdateService(currentVersion: packageInfo.version).checkForUpdate(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.runLocationDetection();
    }
  }

  Future<void> _checkPermissions() async {
    // 延遲一幀，確保 context 可用
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final location = await Permission.location.status;
    final notification = await Permission.notification.status;

    final missing = <String>[];
    if (!location.isGranted) {
      missing.add('📍 位置權限 — 用於偵測附近店家、自動顯示對應會員卡');
    }
    if (!notification.isGranted) {
      missing.add('🔔 通知權限 — 用於背景定位服務的持續通知');
    }

    if (missing.isEmpty) return;

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('需要授權'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SmartCard 需要以下權限才能正常運作：'),
            const SizedBox(height: 12),
            ...missing.map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(m, style: const TextStyle(fontSize: 14)),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('稍後再說'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // 依序請求權限
              if (!location.isGranted) {
                await Permission.location.request();
              }
              if (!notification.isGranted) {
                await Permission.notification.request();
              }
              // 權限更新後重新啟動背景服務
              _controller.startBackgroundUpdates();
            },
            child: const Text('前往授權'),
          ),
        ],
      ),
    );
  }

  void _handleWidgetClick(Uri? uri) {
    if (uri == null || !mounted) return;

    // 解析 cardId：smartcard://card/$cardId → host=card, pathSegments=[cardId]
    String? id;
    if (uri.host == 'card' && uri.pathSegments.isNotEmpty) {
      id = uri.pathSegments.first;
    } else if (uri.pathSegments.isNotEmpty) {
      id = uri.pathSegments.last;
    }
    if (id == null || id.isEmpty) return;

    // 延後一幀確保 Navigator 狀態穩定
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final card = _controller.getCardById(id!);
      if (card != null) {
        AppRouter.pushCardDetail(context, card: card);
      }
      // 卡片不存在時不做任何事，留在首頁即可
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.credit_card,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text('SmartCard'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _controller.runLocationDetection,
            icon: const Icon(Icons.my_location),
            tooltip: '重新偵測位置',
          ),
          IconButton(
            onPressed: () => AppRouter.pushSettings(context),
            icon: const Icon(Icons.settings),
            tooltip: '設定',
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return Column(
            children: [
              LocationStatusCard(
                locationResult: _controller.locationResult,
                isDetecting: _controller.isDetecting,
                recentCard: _controller.mostRecentCard,
                onCardTap: (card) =>
                    AppRouter.pushCardDetail(context, card: card),
              ),
              Expanded(
                child: _controller.cards.isEmpty
                    ? _buildEmptyState(context)
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                        itemCount: _controller.cards.length,
                        itemBuilder: (context, index) {
                          final card = _controller.cards[index];
                          return CardWidget(
                            key: ValueKey(card.id),
                            card: card,
                            onTap: () => AppRouter.pushCardDetail(
                                context,
                                card: card),
                            onEdit: () async {
                              await AppRouter.pushEditCard(context, card: card);
                              _controller.initialize();
                            },
                            onDelete: () => _deleteCard(card),
                          );
                        },
                        onReorder: (oldIndex, newIndex) {
                          if (newIndex > oldIndex) newIndex--;
                          final ids =
                              _controller.cards.map((c) => c.id).toList();
                          final moved = ids.removeAt(oldIndex);
                          ids.insert(newIndex, moved);
                          _controller.reorderCards(ids);
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AppRouter.pushAddCard(context),
        icon: const Icon(Icons.add),
        label: const Text('新增卡片'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.credit_card_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.outline.withOpacity( 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              '還沒有會員卡',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '點擊下方按鈕新增你的第一張會員卡\n支援掃描、圖片辨識或手動輸入',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.tonalIcon(
              onPressed: () => AppRouter.pushAddCard(context),
              icon: const Icon(Icons.add),
              label: const Text('新增會員卡'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteCard(MemberCard card) async {
    final confirmed = await showDialog<bool>(
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
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _controller.deleteCard(card.id);
  }
}
