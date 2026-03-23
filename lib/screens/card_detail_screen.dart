import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:barcode_widget/barcode_widget.dart';

import '../models/member_card.dart';

class CardDetailScreen extends StatefulWidget {
  final MemberCard card;
  const CardDetailScreen({super.key, required this.card});

  @override
  State<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends State<CardDetailScreen> {
  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final barcodeWidth = screenSize.width * 0.85;
    final barcodeHeight = screenSize.height * 0.60;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(widget.card.storeName),
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Hero(
              tag: 'barcode_${widget.card.id}',
              child: _BarcodeDisplay(
                card: widget.card,
                width: barcodeWidth,
                height: barcodeHeight,
              ),
            ),
            const SizedBox(height: 40),
            _buildBottomInfo(context),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomInfo(BuildContext context) {
    return Column(
      children: [
        SelectableText(
          widget.card.barcodeValue,
          style: const TextStyle(color: Colors.white, fontSize: 22, letterSpacing: 2),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Text(
            widget.card.barcodeFormat.name.toUpperCase(),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _BarcodeDisplay extends StatelessWidget {
  final MemberCard card;
  final double width;
  final double height;

  const _BarcodeDisplay({required this.card, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: _buildBarcodeWidget(),
    );
  }

  Widget _buildBarcodeWidget() {
    if (card.barcodeValue.trim().isEmpty) return const Center(child: Text('條碼不能為空'));
    try {
      final barcode = _resolveBarcode(card.barcodeFormat);
      return BarcodeWidget(
        data: card.barcodeValue,
        barcode: barcode,
        drawText: true,
        errorBuilder: (context, error) => Center(child: Text('條碼錯誤: $error')),
      );
    } catch (e) {
      return Center(child: Text('顯示失敗: $e'));
    }
  }

  Barcode _resolveBarcode(BarcodeFormatType format) {
    switch (format) {
      case BarcodeFormatType.qr: return Barcode.qrCode();
      case BarcodeFormatType.dataMatrix: return Barcode.dataMatrix();
      case BarcodeFormatType.aztec: return Barcode.aztec();
      case BarcodeFormatType.pdf417: return Barcode.pdf417();
      case BarcodeFormatType.ean13: return Barcode.ean13();
      case BarcodeFormatType.ean8: return Barcode.ean8();
      case BarcodeFormatType.code128: return Barcode.code128();
      case BarcodeFormatType.code39: return Barcode.code39();
      case BarcodeFormatType.itf: return Barcode.itf();
      case BarcodeFormatType.upca: return Barcode.upcA();
      case BarcodeFormatType.upce: return Barcode.upcE();
      case BarcodeFormatType.codabar: return Barcode.codabar();
      default: return Barcode.code128();
    }
  }
}
