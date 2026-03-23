// 資料庫服務
// 使用 Hive 進行加密本地儲存
// 提供 MemberCard 和 AppSettings 的 CRUD 操作

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart'; 
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/member_card.dart';
import '../models/app_settings.dart';

/// Hive Box 名稱常數
class _BoxNames {
  static const String memberCards = 'member_cards';
  static const String appSettings = 'app_settings';
}

/// 設定 key 常數
class _SettingsKeys {
  static const String settings = 'settings';
  static const String aesKey = 'hive_aes_key'; // flutter_secure_storage key
}

/// 資料庫服務（Singleton）
/// 封裝所有 Hive 操作，提供統一的 CRUD 介面
class DatabaseService {
  // Singleton 實例
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  // Hive Box 實例
  late Box<MemberCard> _cardsBox;
  late Box<AppSettings> _settingsBox;

  // 安全儲存（AES 金鑰存入 Android Keystore/iOS Keychain，而非明文 Hive Box）
  // 使用加密 Shared Preferences (Android 6.0+)
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  bool _initialized = false;

  /// 初始化 Hive 資料庫
  /// 必須在 main() 中 runApp 之前呼叫
  Future<void> initialize() async {
    if (_initialized) return;

    // 初始化 Hive 儲存路徑
    await Hive.initFlutter();

    // 註冊所有 TypeAdapter
    _registerAdapters();

    // 取得或生成 AES 加密金鑰（安全儲存於 Android Keystore）
    final encryptionKey = await _getOrCreateEncryptionKey();

    // 開啟加密的 Box
    _cardsBox = await Hive.openBox<MemberCard>(
      _BoxNames.memberCards,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );

    _settingsBox = await Hive.openBox<AppSettings>(
      _BoxNames.appSettings,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );

    _initialized = true;
  }

  /// 註冊 Hive TypeAdapter
  void _registerAdapters() {
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(MemberCardAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(GpsZoneAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(BarcodeFormatTypeAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(ScreenBrightnessModeAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(AppSettingsAdapter());
  }

  /// 取得或建立 32 bytes AES 加密金鑰
  /// 金鑰安全儲存於系統 KeyStore/Keychain，而非明文
  Future<List<int>> _getOrCreateEncryptionKey() async {
    const keyName = _SettingsKeys.aesKey;

    try {
      final existingKey = await _secureStorage.read(key: keyName);
      if (existingKey != null) {
        return base64.decode(existingKey);
      }
    } catch (_) {
    }

    // 首次執行：生成新的 256-bit (32 bytes) 隨機金鑰
    final keyBytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    await _secureStorage.write(key: keyName, value: base64.encode(keyBytes));

    return keyBytes;
  }

  // ──────────────────────────────────────────
  // MemberCard CRUD 操作
  // ──────────────────────────────────────────

  List<MemberCard> getAllCards() {
    final cards = _cardsBox.values.toList();
    cards.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return cards;
  }

  MemberCard? getCardById(String id) {
    try {
      return _cardsBox.get(id); // 使用 key (UUID) 直接存取效能更好
    } catch (_) {
      return null;
    }
  }

  Future<void> addCard(MemberCard card) async {
    await _cardsBox.put(card.id, card);
  }

  Future<void> updateCard(MemberCard card) async {
    await _cardsBox.put(card.id, card);
  }

  Future<void> deleteCard(String id) async {
    await _cardsBox.delete(id);
  }

  Future<void> reorderCards(List<String> orderedIds) async {
    for (int i = 0; i < orderedIds.length; i++) {
      final card = getCardById(orderedIds[i]);
      if (card != null) {
        final updated = card.copyWith(sortOrder: i);
        await _cardsBox.put(updated.id, updated);
      }
    }
  }

  ValueListenable<Box<MemberCard>> get cardsListenable => _cardsBox.listenable();

  // ──────────────────────────────────────────
  // AppSettings 操作
  // ──────────────────────────────────────────

  AppSettings getSettings() {
    return _settingsBox.get(
      _SettingsKeys.settings,
      defaultValue: AppSettings.defaults(),
    )!;
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _settingsBox.put(_SettingsKeys.settings, settings);
  }

  Future<void> clearAll() async {
    await _cardsBox.clear();
  }

  Future<void> close() async {
    await _cardsBox.close();
    await _settingsBox.close();
  }
}
