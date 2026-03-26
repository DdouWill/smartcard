// ============================================================
// AppController — 全域狀態管理器
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:home_widget/home_widget.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'models/member_card.dart';
import 'models/app_settings.dart';
import 'services/database_service.dart';
import 'services/location_service.dart';
import 'services/widget_service.dart';

class AppController extends ChangeNotifier {
  static final AppController _instance = AppController._internal();
  factory AppController() => _instance;
  AppController._internal();

  final DatabaseService _db = DatabaseService();
  final LocationService _locationService = LocationService();
  final WidgetService _widgetService = WidgetService();

  List<MemberCard> _cards = [];
  AppSettings _settings = AppSettings.defaults();
  LocationResult? _locationResult;
  bool _isDetecting = false;
  String? _initError;
  Timer? _backgroundTimer;

  List<MemberCard> get cards => List.unmodifiable(_cards);
  AppSettings get settings => _settings;
  LocationResult? get locationResult => _locationResult;
  bool get isDetecting => _isDetecting;
  String? get initError => _initError;
  bool get hasCards => _cards.isNotEmpty;

  ValueListenable<Box<MemberCard>> get cardsListenable => _db.cardsListenable;

  Future<void> initialize() async {
    try {
      _settings = _db.getSettings();
      _refreshCards();
      _initError = null;

      // 同步卡片清單到原生端供 WidgetMatchHelper 使用
      await _syncCardsToNative();

      await startBackgroundUpdates();
    } catch (e, stackTrace) {
      _initError = '初始化失敗：$e';
      debugPrint("initialize error: $e");
      FirebaseCrashlytics.instance.recordError(e, stackTrace);
    }
  }

  Future<void> startBackgroundUpdates() async {
    _backgroundTimer?.cancel();
    await _locationService.startBackgroundService();

    final interval = Duration(minutes: _settings.updateIntervalMinutes);
    _backgroundTimer = Timer.periodic(interval, (_) {
      runLocationDetection();
    });

    runLocationDetection();
  }

  Future<void> stopBackgroundUpdates() async {
    _backgroundTimer?.cancel();
    await _locationService.stopBackgroundService();
  }

  Future<void> addCard(MemberCard card) async {
    await _db.addCard(card);
    _refreshCards();
    await _syncCardsToNative();
    await _updateWidgetSilently();
    FirebaseAnalytics.instance.logEvent(
      name: 'card_added',
      parameters: {'store_name': card.storeName},
    );
  }

  Future<void> updateCard(MemberCard card) async {
    await _db.updateCard(card);
    _refreshCards();
    await _syncCardsToNative();
    await _updateWidgetSilently();
  }

  Future<void> deleteCard(String id) async {
    await _db.deleteCard(id);
    _refreshCards();
    await _syncCardsToNative();
    await _updateWidgetSilently();
    FirebaseAnalytics.instance.logEvent(name: 'card_deleted');
  }

  Future<void> deleteAllCards() async {
    await _db.clearAll();
    _refreshCards();
    await _syncCardsToNative();
    await _updateWidgetSilently();
  }

  Future<void> reorderCards(List<String> orderedIds) async {
    await _db.reorderCards(orderedIds);
    _refreshCards();
    await _syncCardsToNative();
  }

  MemberCard? getCardById(String id) => _db.getCardById(id);

  Future<void> runLocationDetection() async {
    if (_isDetecting) return;

    _isDetecting = true;
    notifyListeners();

    try {
      final result = await _locationService.matchCardsByLocation(
        allCards: _cards,
        enableWifi: _settings.enableWifi,
        enableGps: _settings.enableGps,
      );

      _locationResult = result;

      await _widgetService.updateWidget(
        matchedCards: result.matchedCards,
        allCards: _cards,
        nearestStore: result.nearestStore,
      );
    } catch (e, stackTrace) {
      FirebaseCrashlytics.instance.recordError(e, stackTrace);
    } finally {
      _isDetecting = false;
      notifyListeners();
    }
  }

  Future<void> updateSettings(AppSettings newSettings) async {
    final oldInterval = _settings.updateIntervalMinutes;
    
    await _db.saveSettings(newSettings);
    _settings = newSettings;
    
    if (oldInterval != newSettings.updateIntervalMinutes) {
      await startBackgroundUpdates();
    }
    
    notifyListeners();
  }

  Future<void> toggleWifi() async {
    await updateSettings(AppSettings(
      enableWifi: !_settings.enableWifi,
      enableGps: _settings.enableGps,
      updateIntervalMinutes: _settings.updateIntervalMinutes,
      screenBrightnessMode: _settings.screenBrightnessMode,
      showRecentOnEmpty: _settings.showRecentOnEmpty,
      maxWidgetCards: _settings.maxWidgetCards,
    ));
  }

  Future<void> toggleGps() async {
    await updateSettings(AppSettings(
      enableWifi: _settings.enableWifi,
      enableGps: !_settings.enableGps,
      updateIntervalMinutes: _settings.updateIntervalMinutes,
      screenBrightnessMode: _settings.screenBrightnessMode,
      showRecentOnEmpty: _settings.showRecentOnEmpty,
      maxWidgetCards: _settings.maxWidgetCards,
    ));
  }

  Future<void> setupWidgetCallbacks(void Function(Uri? uri) onWidgetClicked) async {
    _widgetService.setWidgetClickCallback((uri) {
      // Firebase Analytics: widget_clicked
      final cardId = uri?.pathSegments.isNotEmpty == true ? uri!.pathSegments.last : '';
      FirebaseAnalytics.instance.logEvent(
        name: 'widget_clicked',
        parameters: {'card_id': cardId},
      );
      onWidgetClicked(uri);
    });
    await _widgetService.handleInitialWidgetUri(onWidgetClicked);
  }

  /// 同步簡化卡片清單到原生端 SharedPreferences
  /// 供 Kotlin WidgetMatchHelper 在背景獨立匹配使用
  Future<void> _syncCardsToNative() async {
    try {
      final list = _cards.map((card) => {
        'id': card.id,
        'storeName': card.storeName,
        'barcodeValue': card.barcodeValue,
        'barcodeFormat': card.barcodeFormat.name,
        'cardColor': card.cardColor ?? '#2196F3',
      }).toList();
      await HomeWidget.saveWidgetData<String>(
        'native_card_list',
        jsonEncode(list),
      );
    } catch (e, stackTrace) {
      FirebaseCrashlytics.instance.recordError(e, stackTrace);
    }
  }

  void _refreshCards() {
    _cards = _db.getAllCards();
    notifyListeners();
  }

  Future<void> _updateWidgetSilently() async {
    try {
      final matched = _locationResult?.matchedCards ?? [];
      final validMatched = matched
          .where((c) => _cards.any((card) => card.id == c.id))
          .toList();

      await _widgetService.updateWidget(
        matchedCards: validMatched,
        allCards: _cards,
        nearestStore: _locationResult?.nearestStore,
      );
    } catch (e, stackTrace) {
      FirebaseCrashlytics.instance.recordError(e, stackTrace);
    }
  }

  @override
  void dispose() {
    _backgroundTimer?.cancel();
    _widgetService.dispose();
    super.dispose();
  }
}
