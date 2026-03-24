// ============================================================
// AppRouter — 路由設定
// ============================================================

import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'models/member_card.dart';
import 'screens/home_screen.dart';
import 'screens/card_detail_screen.dart';
import 'screens/add_card_screen.dart';
import 'screens/settings_screen.dart';

class AppRouter {
  static const String home = '/';
  static const String cardDetail = '/card';
  static const String addCard = '/add-card';
  static const String editCard = '/edit-card';
  static const String settings = '/settings';

  /// 從 deep link URI（smartcard://card/$cardId）解析出 cardId
  static String? _parseCardIdFromDeepLink(String uriString) {
    try {
      final uri = Uri.parse(uriString);
      if (uri.scheme == 'smartcard' && uri.host == 'card') {
        // smartcard://card/$cardId → host=card, pathSegments=[cardId]
        if (uri.pathSegments.isNotEmpty) return uri.pathSegments.first;
        // smartcard://card → no cardId
        return null;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Route<dynamic> onGenerateRoute(RouteSettings routeSettings) {
    final name = routeSettings.name ?? '/';
    final args = routeSettings.arguments;

    // Deep link URI (smartcard://...) 統一由 HomeWidget plugin 處理
    // 若 Flutter 將 intent URI 當作 route name，直接導向首頁
    if (name.startsWith('smartcard://')) {
      return _buildRoute(routeSettings, const HomeScreen());
    }

    if (name == home) {
      return _buildRoute(routeSettings, const HomeScreen());
    }

    if (name == addCard) {
      final editingCard = args is MemberCard ? args : null;
      return _buildRoute(routeSettings, AddCardScreen(editingCard: editingCard));
    }

    if (name == editCard) {
      if (args is MemberCard) {
        return _buildRoute(routeSettings, AddCardScreen(editingCard: args));
      }
    }

    if (name == settings) {
      return _buildRoute(routeSettings, const SettingsScreen());
    }

    if (name.startsWith('$cardDetail/') || name == cardDetail) {
      if (args is _CardDetailArgs) {
        return _buildRoute(
          routeSettings,
          CardDetailScreen(card: args.card),
          withSlideTransition: true,
        );
      }

      final segments = name.split('/');
      final id = segments.length >= 3 ? segments[2] : null;
      if (id != null) {
        final card = AppController().getCardById(id);
        if (card != null) {
          return _buildRoute(
            routeSettings,
            CardDetailScreen(card: card),
            withSlideTransition: true,
          );
        }
      }
      // cardDetail 路由但找不到卡片 → 回首頁
      return _buildRoute(routeSettings, const HomeScreen());
    }

    // 未知路由 fallback 到首頁，避免顯示錯誤頁面
    return _buildRoute(routeSettings, const HomeScreen());
  }

  static Future<void> pushCardDetail(BuildContext context, {required MemberCard card}) {
    return Navigator.pushNamed(context, cardDetail, arguments: _CardDetailArgs(card: card));
  }

  static Future<void> pushAddCard(BuildContext context) {
    return Navigator.pushNamed(context, addCard);
  }

  static Future<void> pushEditCard(BuildContext context, {required MemberCard card}) {
    return Navigator.pushNamed(context, editCard, arguments: card);
  }

  static Future<void> pushSettings(BuildContext context) {
    return Navigator.pushNamed(context, settings);
  }

  static Route<dynamic> _buildRoute(
    RouteSettings settings,
    Widget page, {
    bool withSlideTransition = false,
  }) {
    if (withSlideTransition) {
      return PageRouteBuilder(
        settings: settings,
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutQuart;

          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      );
    }
    return MaterialPageRoute(settings: settings, builder: (_) => page);
  }
}

class _CardDetailArgs {
  final MemberCard card;
  const _CardDetailArgs({required this.card});
}

class _NotFoundPage extends StatelessWidget {
  final String routeName;
  const _NotFoundPage({required this.routeName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('頁面不存在')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('找不到頁面'),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false),
              child: const Text('返回主畫面'),
            ),
          ],
        ),
      ),
    );
  }
}
