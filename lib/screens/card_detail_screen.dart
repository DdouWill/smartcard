import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../app_controller.dart';
import '../data/known_stores.dart';
import '../models/app_settings.dart';
import '../app_router.dart';
import '../models/member_card.dart';
import '../widgets/barcode_display_widget.dart';

class CardDetailScreen extends StatefulWidget {
  final MemberCard card;
  const CardDetailScreen({super.key, required this.card});

  @override
  State<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends State<CardDetailScreen> {
  final _controller = AppController();

  /// 2D 條碼格式不需要強制橫向
  bool get _is2DBarcode {
    const twoDFormats = {
      BarcodeFormatType.qr,
      BarcodeFormatType.dataMatrix,
      BarcodeFormatType.aztec,
      BarcodeFormatType.pdf417,
    };
    return twoDFormats.contains(widget.card.barcodeFormat);
  }

  @override
  void initState() {
    super.initState();
    _applyBrightnessMode();
    if (!_is2DBarcode) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  void _applyBrightnessMode() {
    final mode = _controller.settings.brightnessMode;
    switch (mode) {
      case ScreenBrightnessMode.maximum:
      case ScreenBrightnessMode.keepOn:
        WakelockPlus.enable();
      case ScreenBrightnessMode.system:
        break;
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    WakelockPlus.disable();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;

    // 橫向時條碼佔滿寬度；直向維持原比例
    final barcodeWidth = isLandscape
        ? screenSize.width * 0.90
        : screenSize.width * 0.85;
    final barcodeHeight = isLandscape
        ? screenSize.height * 0.50
        : screenSize.height * 0.60;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text('${getStoreEmoji(widget.card.storeName)} ${widget.card.storeName}'),

      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Hero(
                  tag: 'barcode_${widget.card.id}',
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 3.0,
                    child: Container(
                      width: barcodeWidth,
                      height: barcodeHeight,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: BarcodeDisplayWidget(
                        barcodeValue: widget.card.barcodeValue,
                        barcodeFormat: widget.card.barcodeFormat,
                        width: barcodeWidth - 40,
                        height: barcodeHeight - 40,
                        showText: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildBottomInfo(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomInfo(BuildContext context) {
    return Column(
      children: [
        SelectableText(
          widget.card.barcodeValue,
          style: const TextStyle(
              color: Colors.white, fontSize: 22, letterSpacing: 2),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity( 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity( 0.3)),
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
