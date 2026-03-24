import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard/models/member_card.dart';
import 'package:smartcard/services/barcode_service.dart';

void main() {
  final service = BarcodeService();

  // ──────────────────────────────────────────
  // U1: BarcodeService EAN13 驗證
  // ──────────────────────────────────────────
  group('U1: EAN13 驗證', () {
    test('合法 EAN13 回傳 null', () {
      expect(service.validateBarcode('5901234123457', BarcodeFormatType.ean13), isNull);
    });

    test('合法 EAN13（4006381333931）', () {
      expect(service.validateBarcode('4006381333931', BarcodeFormatType.ean13), isNull);
    });

    test('長度不足 → 錯誤訊息', () {
      final result = service.validateBarcode('12345', BarcodeFormatType.ean13);
      expect(result, contains('13 位數字'));
    });

    test('長度過長 → 錯誤訊息', () {
      final result = service.validateBarcode('12345678901234', BarcodeFormatType.ean13);
      expect(result, contains('13 位數字'));
    });

    test('非數字 → 錯誤訊息', () {
      final result = service.validateBarcode('590123412345A', BarcodeFormatType.ean13);
      expect(result, contains('13 位數字'));
    });

    test('校驗碼錯誤 → 錯誤訊息', () {
      // 正確 checksum 是 7，改成 0
      final result = service.validateBarcode('5901234123450', BarcodeFormatType.ean13);
      expect(result, contains('校驗碼錯誤'));
    });

    test('空值 → 錯誤訊息', () {
      final result = service.validateBarcode('', BarcodeFormatType.ean13);
      expect(result, isNotNull);
    });

    test('純空白 → 錯誤訊息', () {
      final result = service.validateBarcode('   ', BarcodeFormatType.ean13);
      expect(result, isNotNull);
    });
  });

  // ──────────────────────────────────────────
  // U2: BarcodeService EAN8 驗證
  // ──────────────────────────────────────────
  group('U2: EAN8 驗證', () {
    test('合法 EAN8（8 位數字）回傳 null', () {
      expect(service.validateBarcode('12345670', BarcodeFormatType.ean8), isNull);
    });

    test('合法 EAN8（全為零）', () {
      expect(service.validateBarcode('00000000', BarcodeFormatType.ean8), isNull);
    });

    test('長度不足 → 錯誤訊息', () {
      final result = service.validateBarcode('1234', BarcodeFormatType.ean8);
      expect(result, contains('8 位數字'));
    });

    test('長度過長 → 錯誤訊息', () {
      final result = service.validateBarcode('123456789', BarcodeFormatType.ean8);
      expect(result, contains('8 位數字'));
    });

    test('非數字 → 錯誤訊息', () {
      final result = service.validateBarcode('1234567A', BarcodeFormatType.ean8);
      expect(result, contains('8 位數字'));
    });
  });

  // ──────────────────────────────────────────
  // U3: BarcodeService UPC-A 驗證
  // ──────────────────────────────────────────
  group('U3: UPC-A 驗證', () {
    test('合法 UPC-A（12 位數字）回傳 null', () {
      expect(service.validateBarcode('012345678905', BarcodeFormatType.upca), isNull);
    });

    test('長度不足 → 錯誤訊息', () {
      final result = service.validateBarcode('1234567890', BarcodeFormatType.upca);
      expect(result, contains('12 位數字'));
    });

    test('長度過長 → 錯誤訊息', () {
      final result = service.validateBarcode('0123456789012', BarcodeFormatType.upca);
      expect(result, contains('12 位數字'));
    });

    test('非數字 → 錯誤訊息', () {
      final result = service.validateBarcode('01234567890A', BarcodeFormatType.upca);
      expect(result, contains('12 位數字'));
    });
  });

  // ──────────────────────────────────────────
  // U4: BarcodeService 格式轉換
  // ──────────────────────────────────────────
  group('U4: 格式轉換 toBarcodeWidgetType', () {
    final expectedMappings = <BarcodeFormatType, String>{
      BarcodeFormatType.ean13: 'EAN13',
      BarcodeFormatType.ean8: 'EAN8',
      BarcodeFormatType.qr: 'QrCode',
      BarcodeFormatType.code128: 'Code128',
      BarcodeFormatType.code39: 'Code39',
      BarcodeFormatType.pdf417: 'PDF417',
      BarcodeFormatType.aztec: 'Aztec',
      BarcodeFormatType.dataMatrix: 'DataMatrix',
      BarcodeFormatType.itf: 'ITF',
      BarcodeFormatType.upca: 'UpcA',
      BarcodeFormatType.upce: 'UpcE',
      BarcodeFormatType.codabar: 'Codabar',
      BarcodeFormatType.unknown: 'QrCode', // 未知格式預設 QR
    };

    for (final entry in expectedMappings.entries) {
      test('${entry.key.name} → ${entry.value}', () {
        expect(service.toBarcodeWidgetType(entry.key), entry.value);
      });
    }
  });

  // ──────────────────────────────────────────
  // 其他格式驗證（default 分支）
  // ──────────────────────────────────────────
  group('其他格式驗證不限制', () {
    test('QR 格式接受任意字串', () {
      expect(service.validateBarcode('任何文字', BarcodeFormatType.qr), isNull);
    });

    test('Code128 格式接受任意字串', () {
      expect(service.validateBarcode('abc-123', BarcodeFormatType.code128), isNull);
    });

    test('Code39 格式接受任意字串', () {
      expect(service.validateBarcode('HELLO', BarcodeFormatType.code39), isNull);
    });
  });

  // ──────────────────────────────────────────
  // U5: BarcodeService scanFromImage
  // ──────────────────────────────────────────
  group('U5: scanFromImage', () {
    test('圖片檔案不存在 → 回傳失敗結果', () async {
      final nonExistentFile = File('/tmp/non_existent_barcode_image.png');
      final result = await service.scanFromImage(nonExistentFile);

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('圖片檔案不存在'));
      expect(result.value, isEmpty);
      expect(result.format, BarcodeFormatType.unknown);
    });

    test('BarcodeScanResult.failure 建構正確', () {
      final result = BarcodeScanResult.failure('測試錯誤');

      expect(result.success, isFalse);
      expect(result.value, isEmpty);
      expect(result.format, BarcodeFormatType.unknown);
      expect(result.errorMessage, '測試錯誤');
    });

    test('BarcodeScanResult 成功建構正確', () {
      const result = BarcodeScanResult(
        value: '4710088020019',
        format: BarcodeFormatType.ean13,
        success: true,
      );

      expect(result.success, isTrue);
      expect(result.value, '4710088020019');
      expect(result.format, BarcodeFormatType.ean13);
      expect(result.errorMessage, isNull);
    });
  });
}
