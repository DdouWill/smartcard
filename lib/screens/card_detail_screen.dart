import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../app_controller.dart';
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

  @override
  void initState() {
    super.initState();
    _applyBrightnessMode();
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
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: '編輯卡片',
            onPressed: () async {
              await AppRouter.pushEditCard(context, card: widget.card);
              if (mounted) Navigator.pop(context); // 回到 HomeScreen 重新載入
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
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
