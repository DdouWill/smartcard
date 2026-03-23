// ============================================================
// AppController — 全域狀態管理器
// ============================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

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
  MemberCard? get mostRecentCard => _cards.isNotEmpty ? _cards.first : null;
  bool get hasCards => _cards.isNotEmpty;

  ValueListenable<Box<MemberCard>> get cardsListenable => _db.cardsListenable;

  Future<void> initialize() async {
    try {
      _settings = _db.getSettings();
      _refreshCards();
      _initError = null;
      
      await startBackgroundUpdates();
    } catch (e) {
      _initError = '初始化失敗：$e';
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
    await _updateWidgetSilently();
  }

  Future<void> updateCard(MemberCard card) async {
    await _db.updateCard(card);
    _refreshCards();
    await _updateWidgetSilently();
  }

  Future<void> deleteCard(String id) async {
    await _db.deleteCard(id);
    _refreshCards();
    await _updateWidgetSilently();
  }

  Future<void> deleteAllCards() async {
    await _db.clearAll();
    _refreshCards();
    await _updateWidgetSilently();
  }

  Future<void> reorderCards(List<String> orderedIds) async {
    await _db.reorderCards(orderedIds);
    _refreshCards();
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
        recentCard: mostRecentCard,
      );
    } catch (_) {
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
    _widgetService.setWidgetClickCallback(onWidgetClicked);
    await _widgetService.handleInitialWidgetUri(onWidgetClicked);
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
        recentCard: mostRecentCard,
      );
    } catch (_) {
    }
  }

  @override
  void dispose() {
    _backgroundTimer?.cancel();
    _widgetService.dispose();
    super.dispose();
  }
}
