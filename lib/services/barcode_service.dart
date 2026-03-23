// 條碼服務
// 使用 Google ML Kit 進行條碼掃描與圖片辨識
// 支援三種輸入方式：相機掃描、圖片辨識、手動輸入

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size; // InputImageMetadata.size 需要此型別
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

import '../models/member_card.dart';

/// 條碼掃描結果
class BarcodeScanResult {
  final String value; // 條碼數值
  final BarcodeFormatType format; // 偵測到的格式
  final bool success; // 是否成功
  final String? errorMessage; // 錯誤訊息

  const BarcodeScanResult({
    required this.value,
    required this.format,
    required this.success,
    this.errorMessage,
  });

  /// 建立失敗結果
  factory BarcodeScanResult.failure(String message) => BarcodeScanResult(
        value: '',
        format: BarcodeFormatType.unknown,
        success: false,
        errorMessage: message,
      );
}

/// 條碼服務（Singleton）
/// 封裝 ML Kit 條碼掃描邏輯
class BarcodeService {
  static final BarcodeService _instance = BarcodeService._internal();
  factory BarcodeService() => _instance;
  BarcodeService._internal();

  // ML Kit 條碼掃描器實例（支援所有格式）
  late final BarcodeScanner _scanner = BarcodeScanner(
    formats: [
      BarcodeFormat.all, // 掃描所有支援的格式
    ],
  );

  // ──────────────────────────────────────────
  // 圖片條碼辨識（截圖 / 相簿圖片）
  // ──────────────────────────────────────────

  /// 從圖片檔案辨識條碼
  ///
  /// [imageFile] 要辨識的圖片檔案（截圖或相簿選取）
  /// 回傳辨識到的第一個條碼（優先選擇會員卡常見格式）
  Future<BarcodeScanResult> scanFromImage(File imageFile) async {
    try {
      if (!await imageFile.exists()) {
        return BarcodeScanResult.failure('圖片檔案不存在');
      }

      // 建立 ML Kit 輸入圖片
      final inputImage = InputImage.fromFile(imageFile);

      // 執行條碼掃描
      final barcodes = await _scanner.processImage(inputImage);

      if (barcodes.isEmpty) {
        debugPrint('[BarcodeService] 圖片中未找到條碼');
        return BarcodeScanResult.failure('圖片中未偵測到條碼，請確認圖片包含清晰的條碼');
      }

      // 優先選擇會員卡常見格式（EAN-13, Code128, QR）
      final preferred = _selectPreferredBarcode(barcodes);

      debugPrint('[BarcodeService] 圖片辨識成功：${preferred.displayValue} '
          '(${preferred.format.name})');

      return BarcodeScanResult(
        value: preferred.displayValue ?? preferred.rawValue ?? '',
        format: _convertMlKitFormat(preferred.format),
        success: true,
      );
    } catch (e) {
      debugPrint('[BarcodeService] 圖片辨識失敗：$e');
      return BarcodeScanResult.failure('條碼辨識失敗：$e');
    }
  }

  /// 從圖片路徑辨識條碼（便利方法）
  Future<BarcodeScanResult> scanFromImagePath(String imagePath) async {
    return scanFromImage(File(imagePath));
  }

  /// 從圖片 bytes 辨識條碼（用於相機截圖）
  Future<BarcodeScanResult> scanFromImageBytes({
    required Uint8List bytes,
    required int width,
    required int height,
    required InputImageRotation rotation,
  }) async {
    try {
      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(width.toDouble(), height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21, // Android 相機常見格式
          bytesPerRow: width, // NV21 格式的行寬
        ),
      );

      final barcodes = await _scanner.processImage(inputImage);

      if (barcodes.isEmpty) {
        return BarcodeScanResult.failure('未偵測到條碼');
      }

      final preferred = _selectPreferredBarcode(barcodes);
      return BarcodeScanResult(
        value: preferred.displayValue ?? preferred.rawValue ?? '',
        format: _convertMlKitFormat(preferred.format),
        success: true,
      );
    } catch (e) {
      debugPrint('[BarcodeService] 相機辨識失敗：$e');
      return BarcodeScanResult.failure('條碼辨識失敗：$e');
    }
  }

  // ──────────────────────────────────────────
  // 格式轉換
  // ──────────────────────────────────────────

  /// 將 ML Kit BarcodeFormat 轉換為本地 BarcodeFormatType
  BarcodeFormatType _convertMlKitFormat(BarcodeFormat mlKitFormat) {
    switch (mlKitFormat) {
      case BarcodeFormat.ean13:
        return BarcodeFormatType.ean13;
      case BarcodeFormat.ean8:
        return BarcodeFormatType.ean8;
      case BarcodeFormat.qrCode:
        return BarcodeFormatType.qr;
      case BarcodeFormat.code128:
        return BarcodeFormatType.code128;
      case BarcodeFormat.code39:
        return BarcodeFormatType.code39;
      case BarcodeFormat.pdf417:
        return BarcodeFormatType.pdf417;
      case BarcodeFormat.aztec:
        return BarcodeFormatType.aztec;
      case BarcodeFormat.dataMatrix:
        return BarcodeFormatType.dataMatrix;
      case BarcodeFormat.itf:
        return BarcodeFormatType.itf;
      case BarcodeFormat.upca:
        return BarcodeFormatType.upca;
      case BarcodeFormat.upce:
        return BarcodeFormatType.upce;
      case BarcodeFormat.codabar:
        return BarcodeFormatType.codabar;
      default:
        return BarcodeFormatType.unknown;
    }
  }

  /// 將本地 BarcodeFormatType 轉換為 barcode_widget 格式字串
  /// 用於 BarcodeWidget 顯示條碼
  String toBarcodeWidgetType(BarcodeFormatType format) {
    switch (format) {
      case BarcodeFormatType.ean13:
        return 'EAN13';
      case BarcodeFormatType.ean8:
        return 'EAN8';
      case BarcodeFormatType.qr:
        return 'QrCode';
      case BarcodeFormatType.code128:
        return 'Code128';
      case BarcodeFormatType.code39:
        return 'Code39';
      case BarcodeFormatType.pdf417:
        return 'PDF417';
      case BarcodeFormatType.aztec:
        return 'Aztec';
      case BarcodeFormatType.dataMatrix:
        return 'DataMatrix';
      case BarcodeFormatType.itf:
        return 'ITF';
      case BarcodeFormatType.upca:
        return 'UpcA';
      case BarcodeFormatType.upce:
        return 'UpcE';
      case BarcodeFormatType.codabar:
        return 'Codabar';
      default:
        return 'QrCode'; // 未知格式預設用 QR
    }
  }

  // ──────────────────────────────────────────
  // 驗證
  // ──────────────────────────────────────────

  /// 驗證手動輸入的條碼格式是否合法
  ///
  /// [value] 條碼數值
  /// [format] 指定格式
  /// 回傳 null 表示合法，否則回傳錯誤訊息
  String? validateBarcode(String value, BarcodeFormatType format) {
    if (value.trim().isEmpty) return '條碼不能為空';

    switch (format) {
      case BarcodeFormatType.ean13:
        if (!RegExp(r'^\d{13}$').hasMatch(value)) {
          return 'EAN-13 必須是 13 位數字';
        }
        if (!_validateEan13Checksum(value)) {
          return 'EAN-13 校驗碼錯誤';
        }
        return null;

      case BarcodeFormatType.ean8:
        if (!RegExp(r'^\d{8}$').hasMatch(value)) {
          return 'EAN-8 必須是 8 位數字';
        }
        return null;

      case BarcodeFormatType.upca:
        if (!RegExp(r'^\d{12}$').hasMatch(value)) {
          return 'UPC-A 必須是 12 位數字';
        }
        return null;

      case BarcodeFormatType.code128:
      case BarcodeFormatType.code39:
      case BarcodeFormatType.codabar:
        // 英數字混合格式，無固定長度限制（已在函式開頭檢查空值）
        return null;

      case BarcodeFormatType.qr:
      case BarcodeFormatType.dataMatrix:
      case BarcodeFormatType.aztec:
      case BarcodeFormatType.pdf417:
        // 2D 條碼無特殊格式限制
        return null;

      default:
        return null;
    }
  }

  /// 驗證 EAN-13 校驗碼
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
  // 輔助方法
  // ──────────────────────────────────────────

  /// 從多個條碼中選擇最適合的一個
  /// 優先順序：EAN-13 > Code128 > QR > 其他
  Barcode _selectPreferredBarcode(List<Barcode> barcodes) {
    const preferredOrder = [
      BarcodeFormat.ean13,
      BarcodeFormat.code128,
      BarcodeFormat.qrCode,
      BarcodeFormat.ean8,
      BarcodeFormat.code39,
    ];

    for (final format in preferredOrder) {
      final found = barcodes.where((b) => b.format == format);
      if (found.isNotEmpty) return found.first;
    }

    return barcodes.first; // 回傳第一個找到的條碼
  }

  /// 釋放 ML Kit 資源（App 關閉時呼叫）
  Future<void> dispose() async {
    await _scanner.close();
    debugPrint('[BarcodeService] ML Kit 資源已釋放');
  }
}

