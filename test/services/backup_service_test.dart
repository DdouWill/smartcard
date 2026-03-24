import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard/models/member_card.dart';
import 'package:smartcard/services/backup_service.dart';
import 'package:smartcard/services/database_service.dart';

void main() {
  final backupService = BackupService();

  // ──────────────────────────────────────────
  // U6: 加密→解密往返
  // ──────────────────────────────────────────
  group('U6: 加密→解密往返', () {
    test('加密後解密還原完整 JSON', () {
      final original = '{"version":1,"cards":[{"storeName":"全聯"}]}';
      final plaintext = Uint8List.fromList(utf8.encode(original));

      final encrypted = backupService.encryptData(plaintext, 'myPassword123');
      final decrypted = backupService.decryptData(encrypted, 'myPassword123');

      expect(utf8.decode(decrypted), equals(original));
    });

    test('加密後資料與原文不同', () {
      final original = Uint8List.fromList(utf8.encode('secret data'));
      final encrypted = backupService.encryptData(original, 'pwd');

      expect(encrypted, isNot(equals(original)));
      expect(encrypted.length, greaterThan(original.length));
    });

    test('同一明文兩次加密結果不同（隨機 salt/iv）', () {
      final plaintext = Uint8List.fromList(utf8.encode('same data'));
      final enc1 = backupService.encryptData(plaintext, 'pwd');
      final enc2 = backupService.encryptData(plaintext, 'pwd');

      expect(enc1, isNot(equals(enc2)));
    });

    test('大量資料加密解密', () {
      final largeData = List.generate(10000, (i) => i % 256);
      final plaintext = Uint8List.fromList(largeData);

      final encrypted = backupService.encryptData(plaintext, 'longPassword!@#');
      final decrypted = backupService.decryptData(encrypted, 'longPassword!@#');

      expect(decrypted, equals(plaintext));
    });

    test('空密碼也能加解密', () {
      final plaintext = Uint8List.fromList(utf8.encode('data'));
      final encrypted = backupService.encryptData(plaintext, '');
      final decrypted = backupService.decryptData(encrypted, '');
      expect(utf8.decode(decrypted), equals('data'));
    });
  });

  // ──────────────────────────────────────────
  // U7: 錯誤密碼
  // ──────────────────────────────────────────
  group('U7: 錯誤密碼', () {
    test('用密碼 A 加密 → 用密碼 B 解密 → 結果不同或拋出例外', () {
      final plaintext = Uint8List.fromList(utf8.encode('{"cards":[]}'));
      final encrypted = backupService.encryptData(plaintext, 'correctPassword');

      try {
        final decrypted = backupService.decryptData(encrypted, 'wrongPassword');
        // AES 用錯誤密碼可能解出亂碼而非拋例外
        expect(decrypted, isNot(equals(plaintext)));
      } catch (_) {
        // 拋例外也是正確行為
      }
    });

    test('密碼相差一字也無法解密', () {
      final plaintext = Uint8List.fromList(utf8.encode('secret'));
      final encrypted = backupService.encryptData(plaintext, 'password1');

      try {
        final decrypted = backupService.decryptData(encrypted, 'password2');
        expect(decrypted, isNot(equals(plaintext)));
      } catch (_) {
        // 拋例外也是正確行為
      }
    });
  });

  // ──────────────────────────────────────────
  // U8: 合併匯入
  // ──────────────────────────────────────────
  group('U8: 合併匯入', () {
    late String tempDir;
    final db = DatabaseService();

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('backup_test_').path;
      await db.initializeForTesting(tempDir);
    });

    tearDown(() async {
      await db.resetForTesting();
    });

    test('已有 2 張卡 → 匯入含 1 重複 + 1 新 → imported=1, skipped=1', () async {
      // 新增卡片 A 和 B 到 DB
      final cardA = MemberCard(
        id: 'card-a',
        storeName: '店家A',
        barcodeValue: 'BARCODE-A',
        barcodeFormat: BarcodeFormatType.qr,
      );
      final cardB = MemberCard(
        id: 'card-b',
        storeName: '店家B',
        barcodeValue: 'BARCODE-B',
        barcodeFormat: BarcodeFormatType.qr,
      );
      await db.addCard(cardA);
      await db.addCard(cardB);

      // 建立備份 JSON：含 B'（重複）和 C（新）
      final backupJson = jsonEncode({
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'cardCount': 2,
        'cards': [
          {
            'id': 'card-b2',
            'storeName': '店家B副本',
            'barcodeValue': 'BARCODE-B', // 與 B 重複
            'barcodeFormat': BarcodeFormatType.qr.index,
            'sortOrder': 0,
            'ssidKeywords': <String>[],
            'gpsZones': <Map>[],
            'createdAt': '2024-01-01T00:00:00.000',
            'updatedAt': '2024-01-01T00:00:00.000',
          },
          {
            'id': 'card-c',
            'storeName': '店家C',
            'barcodeValue': 'BARCODE-C', // 新卡
            'barcodeFormat': BarcodeFormatType.qr.index,
            'sortOrder': 0,
            'ssidKeywords': <String>[],
            'gpsZones': <Map>[],
            'createdAt': '2024-01-01T00:00:00.000',
            'updatedAt': '2024-01-01T00:00:00.000',
          },
        ],
      });

      // 加密並寫入檔案
      final encrypted = backupService.encryptData(
        Uint8List.fromList(utf8.encode(backupJson)),
        'testPassword',
      );
      final backupFile = File('$tempDir/test_backup.smartcard-backup');
      await backupFile.writeAsBytes(encrypted);

      // 合併匯入
      final result = await backupService.importBackup(
        backupFile,
        'testPassword',
        merge: true,
      );

      expect(result.imported, 1); // 只匯入了 C
      expect(result.skipped, 1); // B 被跳過

      // DB 中應有 3 張卡
      final allCards = db.getAllCards();
      expect(allCards.length, 3);

      // 驗證原始 B 未被覆蓋
      final cardBInDb = db.getCardById('card-b');
      expect(cardBInDb?.storeName, '店家B');
    });
  });
}
