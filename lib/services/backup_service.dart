// 備份服務
// 提供加密備份匯出/匯入功能
// 使用 AES-256-CBC 加密，PBKDF2 從使用者密碼導出金鑰

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/export.dart';

import '../models/member_card.dart';
import 'database_service.dart';

/// 備份檔案格式版本
const int _backupVersion = 1;

/// PBKDF2 參數
const int _pbkdf2Iterations = 100000;
const int _saltLength = 32;
const int _keyLength = 32; // AES-256
const int _ivLength = 16; // AES block size

/// 備份匯入結果
class BackupImportResult {
  final int imported;
  final int skipped;

  const BackupImportResult({required this.imported, required this.skipped});
}

/// 備份服務例外
class BackupException implements Exception {
  final String message;
  const BackupException(this.message);

  @override
  String toString() => message;
}

/// 備份服務
class BackupService {
  final DatabaseService _db = DatabaseService();

  /// 匯出加密備份，回傳備份檔案路徑
  Future<File> exportBackup(String password) async {
    final cards = _db.getAllCards();

    // 序列化卡片為 JSON
    final cardsJson = cards.map(_cardToJson).toList();

    final backupData = {
      'version': _backupVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'cardCount': cardsJson.length,
      'cards': cardsJson,
    };

    final plaintext = utf8.encode(jsonEncode(backupData));

    // 加密
    final encrypted = _encrypt(Uint8List.fromList(plaintext), password);

    // 寫入暫存檔案
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/smartcard_backup_$timestamp.smartcard-backup');
    await file.writeAsBytes(encrypted);

    debugPrint('[BackupService] 已匯出 ${cards.length} 張卡片');
    return file;
  }

  /// 匯入加密備份
  /// [merge] true = 合併（跳過已存在的），false = 覆蓋（清空後匯入）
  Future<BackupImportResult> importBackup(File file, String password, {required bool merge}) async {
    final encrypted = await file.readAsBytes();

    // 解密
    final Uint8List plaintext;
    try {
      plaintext = _decrypt(Uint8List.fromList(encrypted), password);
    } catch (e) {
      throw const BackupException('密碼錯誤或檔案已損毀');
    }

    // 解析 JSON
    final Map<String, dynamic> backupData;
    try {
      backupData = jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;
    } catch (e) {
      throw const BackupException('備份檔案格式不正確');
    }

    // 檢查版本
    final version = backupData['version'] as int?;
    if (version == null || version > _backupVersion) {
      throw BackupException(
        '備份版本不相容（檔案版本: $version，支援版本: $_backupVersion）',
      );
    }

    final cardsList = backupData['cards'] as List<dynamic>? ?? [];

    int imported = 0;
    int skipped = 0;

    if (!merge) {
      // 覆蓋模式：清空現有資料
      await _db.clearAll();
    }

    // 取得現有卡片的 barcodeValue 集合（用於合併模式比對）
    final existingBarcodes = merge
        ? _db.getAllCards().map((c) => c.barcodeValue).toSet()
        : <String>{};

    for (final cardJson in cardsList) {
      try {
        final card = _cardFromJson(cardJson as Map<String, dynamic>);

        if (merge && existingBarcodes.contains(card.barcodeValue)) {
          skipped++;
          continue;
        }

        await _db.addCard(card);
        imported++;
      } catch (e) {
        debugPrint('[BackupService] 匯入卡片失敗，跳過: $e');
        skipped++;
      }
    }

    debugPrint('[BackupService] 匯入完成: 匯入 $imported 張, 跳過 $skipped 張');
    return BackupImportResult(imported: imported, skipped: skipped);
  }

  // ─── 加密/解密 ─────────────────────────────────

  /// AES-256-CBC 加密
  /// 輸出格式: [salt(32)] [iv(16)] [ciphertext...]
  Uint8List _encrypt(Uint8List plaintext, String password) {
    final salt = _secureRandom(_saltLength);
    final iv = _secureRandom(_ivLength);
    final key = _deriveKey(password, salt);

    final cipher = PaddedBlockCipher('AES/CBC/PKCS7')
      ..init(
        true,
        PaddedBlockCipherParameters(
          ParametersWithIV(KeyParameter(key), iv),
          null,
        ),
      );

    final ciphertext = cipher.process(plaintext);

    // 組合: salt + iv + ciphertext
    final result = Uint8List(salt.length + iv.length + ciphertext.length);
    result.setAll(0, salt);
    result.setAll(salt.length, iv);
    result.setAll(salt.length + iv.length, ciphertext);

    return result;
  }

  /// AES-256-CBC 解密
  Uint8List _decrypt(Uint8List data, String password) {
    if (data.length < _saltLength + _ivLength + 16) {
      throw const BackupException('備份檔案格式不正確');
    }

    final salt = data.sublist(0, _saltLength);
    final iv = data.sublist(_saltLength, _saltLength + _ivLength);
    final ciphertext = data.sublist(_saltLength + _ivLength);
    final key = _deriveKey(password, Uint8List.fromList(salt));

    final cipher = PaddedBlockCipher('AES/CBC/PKCS7')
      ..init(
        false,
        PaddedBlockCipherParameters(
          ParametersWithIV(KeyParameter(key), Uint8List.fromList(iv)),
          null,
        ),
      );

    return cipher.process(Uint8List.fromList(ciphertext));
  }

  /// 用 PBKDF2-HMAC-SHA256 從密碼導出 AES key
  Uint8List _deriveKey(String password, Uint8List salt) {
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, _pbkdf2Iterations, _keyLength));

    return pbkdf2.process(Uint8List.fromList(utf8.encode(password)));
  }

  /// 產生密碼學安全的隨機位元組
  Uint8List _secureRandom(int length) {
    final rng = math.Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => rng.nextInt(256)));
  }

  // ─── JSON 序列化 ───────────────────────────────

  Map<String, dynamic> _cardToJson(MemberCard card) {
    return {
      'id': card.id,
      'storeName': card.storeName,
      'barcodeValue': card.barcodeValue,
      'barcodeFormat': card.barcodeFormat.index,
      'cardColor': card.cardColor,
      'iconPath': card.iconPath,
      'sortOrder': card.sortOrder,
      'ssidKeywords': card.ssidKeywords,
      'gpsZones': card.gpsZones.map((z) => {
        'latitude': z.latitude,
        'longitude': z.longitude,
        'radiusMeters': z.radiusMeters,
        'label': z.label,
      }).toList(),
      'createdAt': card.createdAt.toIso8601String(),
      'updatedAt': card.updatedAt.toIso8601String(),
    };
  }

  MemberCard _cardFromJson(Map<String, dynamic> json) {
    final gpsZones = (json['gpsZones'] as List<dynamic>?)
        ?.map((z) => GpsZone(
              latitude: (z['latitude'] as num).toDouble(),
              longitude: (z['longitude'] as num).toDouble(),
              radiusMeters: (z['radiusMeters'] as num?)?.toDouble() ?? 100.0,
              label: z['label'] as String?,
            ))
        .toList();

    return MemberCard(
      id: json['id'] as String,
      storeName: json['storeName'] as String,
      barcodeValue: json['barcodeValue'] as String,
      barcodeFormat: BarcodeFormatType.values[json['barcodeFormat'] as int],
      cardColor: json['cardColor'] as String?,
      iconPath: json['iconPath'] as String?,
      sortOrder: json['sortOrder'] as int? ?? 0,
      ssidKeywords: (json['ssidKeywords'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      gpsZones: gpsZones,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }
}
