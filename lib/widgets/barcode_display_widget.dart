// ============================================================
// BarcodeDisplayWidget — 條碼顯示元件
// ============================================================
// 接收條碼數值與格式，使用 barcode_widget 套件渲染條碼。
// 支援 1D（EAN13、Code128、Code39 等）與 2D（QR、DataMatrix、Aztec）。
// 若條碼值不合法，顯示錯誤提示而非崩潰。
// ============================================================

import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';

import '../models/member_card.dart';

/// 條碼顯示元件
///
/// 使用範例：
/// ```dart
/// BarcodeDisplayWidget(
///   barcodeValue: '4710088020019',
///   barcodeFormat: BarcodeFormatType.ean13,
///   width: 300,
///   height: 120,
/// )
/// ```
class BarcodeDisplayWidget extends StatelessWidget {
  /// 條碼數值
  final String barcodeValue;

  /// 條碼格式（對應 BarcodeFormatType）
  final BarcodeFormatType barcodeFormat;

  /// 寬度
  final double width;

  /// 高度
  final double height;

  /// 是否顯示條碼數值文字（預設 true）
  final bool showText;

  const BarcodeDisplayWidget({
    super.key,
    required this.barcodeValue,
    required this.barcodeFormat,
    required this.width,
    required this.height,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    // 空值保護
    if (barcodeValue.trim().isEmpty) {
      return _buildPlaceholder(context, '請輸入條碼');
    }

    // 嘗試渲染條碼，錯誤時顯示 placeholder
    try {
      final barcode = _resolveBarcode(barcodeFormat);

      return Container(
        width: width,
        height: height,
        color: Colors.white, // 條碼需要白底確保對比
        padding: const EdgeInsets.all(8),
        child: BarcodeWidget(
          data: barcodeValue,
          barcode: barcode,
          drawText: showText,
          errorBuilder: (context, error) =>
              _buildErrorWidget(context, error.toString()),
        ),
      );
    } catch (e) {
      // 格式不支援或數值不合法時顯示錯誤提示
      return _buildErrorWidget(context, e.toString());
    }
  }

  /// 將 BarcodeFormatType 對應至 barcode_widget 的 Barcode 類別
  Barcode _resolveBarcode(BarcodeFormatType format) {
    switch (format) {
      case BarcodeFormatType.qr:
        return Barcode.qrCode(); // 2D QR Code
      case BarcodeFormatType.dataMatrix:
        return Barcode.dataMatrix(); // 2D Data Matrix
      case BarcodeFormatType.aztec:
        return Barcode.aztec(); // 2D Aztec
      case BarcodeFormatType.pdf417:
        return Barcode.pdf417(); // 2D PDF417
      case BarcodeFormatType.ean13:
        return Barcode.ean13(); // 1D EAN-13
      case BarcodeFormatType.ean8:
        return Barcode.ean8(); // 1D EAN-8
      case BarcodeFormatType.code128:
        return Barcode.code128(); // 1D Code128
      case BarcodeFormatType.code39:
        return Barcode.code39(); // 1D Code39
      case BarcodeFormatType.itf:
        return Barcode.itf(); // 1D ITF
      case BarcodeFormatType.upca:
        return Barcode.upcA(); // 1D UPC-A
      case BarcodeFormatType.upce:
        return Barcode.upcE(); // 1D UPC-E
      case BarcodeFormatType.codabar:
        return Barcode.codabar(); // 1D Codabar
      case BarcodeFormatType.unknown:
        return Barcode.code128(); // 未知格式預設 Code128
    }
  }

  /// 空值佔位元件
  Widget _buildPlaceholder(BuildContext context, String message) {
    return Container(
      width: width,
      height: height,
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.barcode_reader,
              color: Colors.grey[400],
              size: 32,
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  /// 錯誤提示元件（條碼數值不合法時顯示）
  Widget _buildErrorWidget(BuildContext context, String error) {
    return Container(
      width: width,
      height: height,
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red[300], size: 28),
            const SizedBox(height: 4),
            Text(
              '條碼格式錯誤',
              style: TextStyle(
                color: Colors.red[400],
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              barcodeValue,
              style: TextStyle(color: Colors.grey[500], fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
