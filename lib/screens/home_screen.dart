import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../app_router.dart';
import '../models/member_card.dart';
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
    _controller.setupWidgetCallbacks(_handleWidgetClick);
    _controller.runLocationDetection();
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

  void _handleWidgetClick(Uri? uri) {
    if (uri == null) return;
    final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : null;
    if (id == null) return;

    final card = _controller.getCardById(id);
    if (card != null && mounted) {
      AppRouter.pushCardDetail(context, card: card);
    }
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
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
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
