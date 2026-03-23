// 條碼服務
// 使用 mobile_scanner 進行條碼掃描與圖片辨識
// 支援三種輸入方式：相機掃描（即時）、圖片辨識、手動輸入

import 'dart:io';
import 'package:mobile_scanner/mobile_scanner.dart' as ms;

import '../models/member_card.dart';

/// 條碼掃描結果
class BarcodeScanResult {
  final String value;
  final BarcodeFormatType format;
  final bool success;
  final String? errorMessage;

  const BarcodeScanResult({
    required this.value,
    required this.format,
    required this.success,
    this.errorMessage,
  });

  factory BarcodeScanResult.failure(String message) => BarcodeScanResult(
        value: '',
        format: BarcodeFormatType.unknown,
        success: false,
        errorMessage: message,
      );
}

/// 條碼服務（Singleton）
class BarcodeService {
  static final BarcodeService _instance = BarcodeService._internal();
  factory BarcodeService() => _instance;
  BarcodeService._internal();

  // 用於圖片辨識的 controller
  ms.MobileScannerController? _imageController;

  // ──────────────────────────────────────────
  // 圖片條碼辨識
  // ──────────────────────────────────────────

  /// 從圖片檔案辨識條碼
  Future<BarcodeScanResult> scanFromImage(File imageFile) async {
    try {
      if (!await imageFile.exists()) {
        return BarcodeScanResult.failure('圖片檔案不存在');
      }

      _imageController ??= ms.MobileScannerController();
      final capture = await _imageController!.analyzeImage(imageFile.path);

      if (capture == null || capture.barcodes.isEmpty) {
        return BarcodeScanResult.failure('圖片中未偵測到條碼，請確認圖片包含清晰的條碼');
      }

      final barcode = _selectPreferredBarcode(capture.barcodes);

      return BarcodeScanResult(
        value: barcode.displayValue ?? barcode.rawValue ?? '',
        format: convertMsFormat(barcode.format),
        success: true,
      );
    } catch (e) {
      return BarcodeScanResult.failure('條碼辨識失敗：$e');
    }
  }

  /// 從圖片路徑辨識條碼
  Future<BarcodeScanResult> scanFromImagePath(String imagePath) async {
    return scanFromImage(File(imagePath));
  }

  // ──────────────────────────────────────────
  // 格式轉換
  // ──────────────────────────────────────────

  /// mobile_scanner BarcodeFormat → 本地 BarcodeFormatType
  static BarcodeFormatType convertMsFormat(ms.BarcodeFormat format) {
    switch (format) {
      case ms.BarcodeFormat.ean13: return BarcodeFormatType.ean13;
      case ms.BarcodeFormat.ean8: return BarcodeFormatType.ean8;
      case ms.BarcodeFormat.qrCode: return BarcodeFormatType.qr;
      case ms.BarcodeFormat.code128: return BarcodeFormatType.code128;
      case ms.BarcodeFormat.code39: return BarcodeFormatType.code39;
      case ms.BarcodeFormat.pdf417: return BarcodeFormatType.pdf417;
      case ms.BarcodeFormat.aztec: return BarcodeFormatType.aztec;
      case ms.BarcodeFormat.dataMatrix: return BarcodeFormatType.dataMatrix;
      case ms.BarcodeFormat.itf: return BarcodeFormatType.itf;
      case ms.BarcodeFormat.upcA: return BarcodeFormatType.upca;
      case ms.BarcodeFormat.upcE: return BarcodeFormatType.upce;
      default: return BarcodeFormatType.unknown;
    }
  }

  /// 本地 BarcodeFormatType → barcode_widget 格式字串
  String toBarcodeWidgetType(BarcodeFormatType format) {
    switch (format) {
      case BarcodeFormatType.ean13: return 'EAN13';
      case BarcodeFormatType.ean8: return 'EAN8';
      case BarcodeFormatType.qr: return 'QrCode';
      case BarcodeFormatType.code128: return 'Code128';
      case BarcodeFormatType.code39: return 'Code39';
      case BarcodeFormatType.pdf417: return 'PDF417';
      case BarcodeFormatType.aztec: return 'Aztec';
      case BarcodeFormatType.dataMatrix: return 'DataMatrix';
      case BarcodeFormatType.itf: return 'ITF';
      case BarcodeFormatType.upca: return 'UpcA';
      case BarcodeFormatType.upce: return 'UpcE';
      case BarcodeFormatType.codabar: return 'Codabar';
      default: return 'QrCode';
    }
  }

  // ──────────────────────────────────────────
  // 驗證
  // ──────────────────────────────────────────

  String? validateBarcode(String value, BarcodeFormatType format) {
    if (value.trim().isEmpty) return '條碼不能為空';

    switch (format) {
      case BarcodeFormatType.ean13:
        if (!RegExp(r'^\d{13}$').hasMatch(value)) return 'EAN-13 必須是 13 位數字';
        if (!_validateEan13Checksum(value)) return 'EAN-13 校驗碼錯誤';
        return null;
      case BarcodeFormatType.ean8:
        if (!RegExp(r'^\d{8}$').hasMatch(value)) return 'EAN-8 必須是 8 位數字';
        return null;
      case BarcodeFormatType.upca:
        if (!RegExp(r'^\d{12}$').hasMatch(value)) return 'UPC-A 必須是 12 位數字';
        return null;
      default:
        return null;
    }
  }

  bool _validateEan13Checksum(String ean13) {
    if (ean13.length != 13) return false;
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      final digit = int.tryParse(ean13[i]) ?? 0;
      sum += (i % 2 == 0) ? digit : digit * 3;
    }
    final checksum = (10 - (sum % 10)) % 10;
    return checksum == (int.tryParse(ean13[12]) ?? -1);
  }

  // ──────────────────────────────────────────
  // 輔助
  // ──────────────────────────────────────────

  ms.Barcode _selectPreferredBarcode(List<ms.Barcode> barcodes) {
    const preferredOrder = [
      ms.BarcodeFormat.ean13,
      ms.BarcodeFormat.code128,
      ms.BarcodeFormat.qrCode,
      ms.BarcodeFormat.ean8,
      ms.BarcodeFormat.code39,
    ];

    for (final format in preferredOrder) {
      final found = barcodes.where((b) => b.format == format);
      if (found.isNotEmpty) return found.first;
    }
    return barcodes.first;
  }

  Future<void> dispose() async {
    await _imageController?.dispose();
    _imageController = null;
  }
}
