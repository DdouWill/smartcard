// SmartCard App 入口
import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'app_router.dart';
import 'package:home_widget/home_widget.dart';
import 'services/database_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. 初始化 Hive 加密資料庫 (含 KeyStore 金鑰處理)
  await DatabaseService().initialize();

  // 2. 初始化 AppController (載入卡片與設定，啟動計時器)
  await AppController().initialize();

  runApp(const SmartCardApp());
}

class SmartCardApp extends StatefulWidget {
  const SmartCardApp({super.key});

  @override
  State<SmartCardApp> createState() => _SmartCardAppState();
}

class _SmartCardAppState extends State<SmartCardApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // 處理 Widget deep link（App 從 Widget 啟動時）
    _handleIncomingDeepLink();
  }

  Future<void> _handleIncomingDeepLink() async {
    // 延遲等 Navigator 初始化完成
    await Future.delayed(const Duration(milliseconds: 500));
    // 透過 home_widget 取得啟動 URI
    try {
      final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (uri != null) {
        _navigateByUri(uri);
      }
    } catch (_) {}
  }

  void _navigateByUri(Uri uri) {
    final pathSegments = uri.pathSegments;
    if (pathSegments.isNotEmpty) {
      final cardId = pathSegments.last;
      final card = AppController().getCardById(cardId);
      if (card != null) {
        _navigatorKey.currentState?.pushNamed('/card/$cardId');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'SmartCard 智慧會員卡',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: const CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      onGenerateRoute: AppRouter.onGenerateRoute,
      initialRoute: AppRouter.home,
    );
  }
}
