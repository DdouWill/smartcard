// ============================================================
// AddCardScreen — 新增卡片頁面
// ============================================================
// 提供 相機掃描、圖片辨識、手動輸入 三種模式。
// 使用 TabView 進行功能切換，並實作 Hero 動畫過場。
// ============================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart' show ImagePicker, ImageSource;
import 'package:mobile_scanner/mobile_scanner.dart' as ms;

import '../app_controller.dart';
import '../models/member_card.dart';
import '../services/barcode_service.dart';
import '../widgets/barcode_display_widget.dart';
import '../widgets/store_color_picker.dart';
import '../widgets/ssid_keyword_editor.dart';

/// 新增卡片頁面
///
/// 提供三種條碼輸入方式，整合顏色選擇、SSID 關鍵字與條碼即時預覽。
class AddCardScreen extends StatefulWidget {
  final MemberCard? editingCard;
  const AddCardScreen({super.key, this.editingCard});

  @override
  State<AddCardScreen> createState() => _AddCardScreenState();
}

// 台灣常見連鎖店家（用於自動補全）
const _commonStores = [
  '全聯福利中心',
  '家樂福',
  '大潤發',
  '好市多 Costco',
  '屈臣氏',
  '康是美',
  '寶雅',
  '小北百貨',
  '統一超商 7-ELEVEN',
  '全家便利商店',
  '萊爾富',
  'OK 超商',
  '星巴克',
  '路易莎咖啡',
  '摩斯漢堡',
  '麥當勞',
  '肯德基',
  '丹丹漢堡',
  '鼎泰豐',
  '誠品書店',
  '光南大批發',
  '無印良品 MUJI',
  'UNIQLO',
  'NET',
  '愛買',
  '美廉社',
  '頂好超市',
  '全國電子',
  '燦坤',
  'IKEA',
];

class _AddCardScreenState extends State<AddCardScreen>
    with SingleTickerProviderStateMixin {
  /// 使用 AppController 取代直接呼叫 DatabaseService
  final _controller = AppController();
  final _barcodeService = BarcodeService();
  final _uuid = const Uuid();

  // Tab 控制器（三種輸入方式）
  late final TabController _tabController;

  // 表單 Key
  final _formKey = GlobalKey<FormState>();

  // 輸入控制器
  final _storeNameController = TextEditingController();
  final _barcodeValueController = TextEditingController();

  // 表單狀態
  BarcodeFormatType _selectedFormat = BarcodeFormatType.ean13;
  Color? _selectedColor; // 卡片背景色（null 表示使用預設）
  List<String> _ssidKeywords = []; // SSID 關鍵字清單
  bool _isProcessing = false;
  String? _scannedValue; // 掃描結果暫存
  BarcodeFormatType? _scannedFormat; // 掃描格式暫存

  // 即時條碼預覽觸發器
  String _previewBarcodeValue = '';

  bool get _isEditing => widget.editingCard != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // 監聽條碼輸入，即時更新預覽
    _barcodeValueController.addListener(() {
      setState(() => _previewBarcodeValue = _barcodeValueController.text.trim());
    });

    // 編輯模式：預填現有卡片資料
    if (_isEditing) {
      final card = widget.editingCard!;
      _storeNameController.text = card.storeName;
      _barcodeValueController.text = card.barcodeValue;
      _selectedFormat = card.barcodeFormat;
      _selectedColor = card.cardColor != null
          ? Color(int.parse(card.cardColor!.replaceFirst('#', 'FF'), radix: 16))
          : null;
      _ssidKeywords = List<String>.from(card.ssidKeywords);
      _previewBarcodeValue = card.barcodeValue;
      // 編輯模式直接跳到手動輸入 Tab
      _tabController.index = 2;
    }
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    _tabController.dispose();
    _storeNameController.dispose();
    _barcodeValueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '編輯會員卡' : '新增會員卡'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.camera_alt), text: '掃描'),
            Tab(icon: Icon(Icons.image), text: '圖片辨識'),
            Tab(icon: Icon(Icons.keyboard), text: '手動輸入'),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // ── 三種輸入方式 Tab 內容 ──
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildCameraScanTab(),
                  _buildImageScanTab(),
                  _buildManualInputTab(),
                ],
              ),
            ),

            // ── 掃描結果預覽 ──
            if (_scannedValue != null) _buildScanResultPreview(),

            // ── 存檔按鈕 ──
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  // Tab 1：相機掃描
  // ──────────────────────────────────────────

  ms.MobileScannerController? _scannerController;
  bool _scannerPaused = false;

  Widget _buildCameraScanTab() {
    _scannerController ??= ms.MobileScannerController(
      detectionSpeed: ms.DetectionSpeed.normal,
      facing: ms.CameraFacing.back,
      torchEnabled: false,
    );

    return Stack(
      children: [
        // 相機預覽
        ms.MobileScanner(
          controller: _scannerController!,
          onDetect: _onBarcodeDetected,
        ),
        // 掃描框 overlay
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white54, width: 1),
          ),
        ),
        // 頂部工具列
        Positioned(
          top: 16,
          right: 16,
          child: Row(
            children: [
              // 手電筒
              IconButton(
                icon: Icon(
                  _scannerController!.torchEnabled ? Icons.flash_on : Icons.flash_off,
                  color: Colors.white,
                ),
                onPressed: () => _scannerController!.toggleTorch(),
              ),
              // 切換前後鏡頭
              IconButton(
                icon: const Icon(Icons.cameraswitch, color: Colors.white),
                onPressed: () => _scannerController!.switchCamera(),
              ),
            ],
          ),
        ),
        // 底部提示
        Positioned(
          bottom: 24,
          left: 24,
          right: 24,
          child: Text(
            _scannerPaused ? '已偵測到條碼' : '對準條碼自動掃描',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              shadows: [Shadow(blurRadius: 8, color: Colors.black)],
            ),
          ),
        ),
      ],
    );
  }

  void _onBarcodeDetected(ms.BarcodeCapture capture) {
    if (_scannerPaused) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    setState(() => _scannerPaused = true);
    _scannerController?.stop();

    final value = barcode.rawValue!;
    final format = _msFormatToLocal(barcode.format);

    // 預填到表單
    _barcodeValueController.text = value;
    _scannedValue = value;
    _scannedFormat = format;
    _selectedFormat = format;

    // 顯示結果 + 跳到手動輸入完善資料
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('偵測到條碼：$value'),
        action: SnackBarAction(
          label: '重新掃描',
          onPressed: _resumeScanner,
        ),
      ),
    );

    // 切到手動輸入 Tab 讓使用者填店名
    _tabController.animateTo(2);
  }

  void _resumeScanner() {
    setState(() => _scannerPaused = false);
    _scannerController?.start();
  }

  BarcodeFormatType _msFormatToLocal(ms.BarcodeFormat format) {
    switch (format) {
      case ms.BarcodeFormat.ean13: return BarcodeFormatType.ean13;
      case ms.BarcodeFormat.ean8: return BarcodeFormatType.ean8;
      case ms.BarcodeFormat.qrCode: return BarcodeFormatType.qr;
      case ms.BarcodeFormat.code128: return BarcodeFormatType.code128;
      case ms.BarcodeFormat.code39: return BarcodeFormatType.code39;
      case ms.BarcodeFormat.pdf417: return BarcodeFormatType.pdf417;
      case ms.BarcodeFormat.dataMatrix: return BarcodeFormatType.dataMatrix;
      case ms.BarcodeFormat.aztec: return BarcodeFormatType.aztec;
      default: return BarcodeFormatType.code128;
    }
  }

  // ──────────────────────────────────────────
  // Tab 2：圖片辨識
  // ──────────────────────────────────────────

  Widget _buildImageScanTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 圖片預覽佔位
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 8),
                Text(
                  '選取圖片後顯示於此',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              OutlinedButton.icon(
                onPressed: _isProcessing ? null : _pickImageFromGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('從相簿選取'),
              ),
              OutlinedButton.icon(
                onPressed: _isProcessing ? null : _pickImageFromCamera,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('拍照'),
              ),
            ],
          ),
          if (_isProcessing) ...[
            const SizedBox(height: 16),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('辨識中...'),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Text(
            '選取包含條碼的截圖或圖片，ML Kit 自動辨識條碼內容',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  // Tab 3：手動輸入
  // ──────────────────────────────────────────

  Widget _buildManualInputTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 店家名稱輸入（帶自動補全常見店家）
          Autocomplete<String>(
            optionsBuilder: (textEditingValue) {
              if (textEditingValue.text.isEmpty) return const [];
              final query = textEditingValue.text.toLowerCase();
              return _commonStores.where(
                (store) => store.toLowerCase().contains(query),
              );
            },
            onSelected: (selection) {
              _storeNameController.text = selection;
            },
            fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
              // Sync the autocomplete controller with our form controller
              if (controller.text != _storeNameController.text) {
                controller.text = _storeNameController.text;
              }
              controller.addListener(() {
                if (_storeNameController.text != controller.text) {
                  _storeNameController.text = controller.text;
                }
              });
              return TextFormField(
                controller: controller,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  labelText: '店家名稱 *',
                  hintText: '例：全聯福利中心',
                  prefixIcon: Icon(Icons.store),
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => onSubmitted(),
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? '請輸入店家名稱' : null,
              );
            },
          ),
          const SizedBox(height: 16),

          // 條碼號碼輸入
          TextFormField(
            controller: _barcodeValueController,
            decoration: const InputDecoration(
              labelText: '條碼號碼 *',
              hintText: '例：4710088020019',
              prefixIcon: Icon(Icons.barcode_reader),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.text,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\-]')),
            ],
            validator: (v) {
              if (v?.trim().isEmpty ?? true) return '請輸入條碼號碼';
              return _barcodeService.validateBarcode(
                v!.trim(),
                _selectedFormat,
              );
            },
          ),
          const SizedBox(height: 16),

          // ── 即時條碼預覽 ──
          if (_previewBarcodeValue.isNotEmpty) ...[
            Text('條碼預覽', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: BarcodeDisplayWidget(
                  barcodeValue: _previewBarcodeValue,
                  barcodeFormat: _selectedFormat,
                  width: MediaQuery.of(context).size.width - 48,
                  height: 100,
                  showText: true,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 條碼格式選擇
          Text('條碼格式', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          _buildFormatSelector(),
          const SizedBox(height: 24),

          // ── 卡片顏色選擇 ──
          StoreColorPicker(
            selectedColor: _selectedColor,
            onColorSelected: (color) => setState(() => _selectedColor = color),
          ),
          const SizedBox(height: 24),

          // ── SSID 關鍵字編輯器 ──
          SsidKeywordEditor(
            keywords: _ssidKeywords,
            onKeywordsChanged: (updated) =>
                setState(() => _ssidKeywords = updated),
          ),
          const SizedBox(height: 24),

          // 說明文字
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '不確定格式請選 QR Code 或 Code128，'
                    '大部分條碼掃描器都能辨識',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 條碼格式選擇器（Wrap 排列）
  Widget _buildFormatSelector() {
    const commonFormats = [
      BarcodeFormatType.ean13,
      BarcodeFormatType.qr,
      BarcodeFormatType.code128,
      BarcodeFormatType.ean8,
      BarcodeFormatType.code39,
      BarcodeFormatType.pdf417,
      BarcodeFormatType.dataMatrix,
      BarcodeFormatType.aztec,
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: commonFormats.map((format) {
        final isSelected = _selectedFormat == format;
        return ChoiceChip(
          label: Text(format.name.toUpperCase()),
          selected: isSelected,
          onSelected: (_) {
            setState(() {
              _selectedFormat = format;
              // 格式變更 → 刷新預覽
              _previewBarcodeValue = _barcodeValueController.text.trim();
            });
          },
        );
      }).toList(),
    );
  }

  // ──────────────────────────────────────────
  // 掃描結果預覽
  // ──────────────────────────────────────────

  Widget _buildScanResultPreview() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '已辨識：$_scannedValue',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '格式：${_scannedFormat?.name.toUpperCase() ?? "未知"}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _applyScannedResult,
            child: const Text('套用'),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  // 存檔按鈕
  // ──────────────────────────────────────────

  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _isProcessing ? null : _saveCard,
          icon: const Icon(Icons.save),
          label: Text(_isEditing ? '更新卡片' : '儲存卡片'),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  // 動作處理
  // ──────────────────────────────────────────

  /// 開啟相機掃描（已由即時預覽取代，保留方法避免引用錯誤）
  Future<void> _startCameraScanner() async {
    _tabController.animateTo(0); // 切回掃描 Tab
  }

  /// 從相簿選取圖片
  Future<void> _pickImageFromGallery() async {
    await _pickAndScanImage(ImageSource.gallery);
  }

  /// 拍照辨識
  Future<void> _pickImageFromCamera() async {
    await _pickAndScanImage(ImageSource.camera);
  }

  /// 選取圖片並執行 ML Kit 條碼辨識
  Future<void> _pickAndScanImage(ImageSource source) async {
    setState(() => _isProcessing = true);

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source);

      if (picked == null) {
        setState(() => _isProcessing = false);
        return;
      }

      final result = await _barcodeService.scanFromImage(File(picked.path));

      if (!mounted) return;

      if (result.success) {
        setState(() {
          _scannedValue = result.value;
          _scannedFormat = result.format;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('辨識成功：${result.value}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? '辨識失敗'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// 將掃描結果套用到手動輸入欄位
  void _applyScannedResult() {
    if (_scannedValue == null) return;
    _barcodeValueController.text = _scannedValue!;
    if (_scannedFormat != null) {
      setState(() => _selectedFormat = _scannedFormat!);
    }
    // 切換到手動輸入 Tab 讓使用者補填店家名稱
    _tabController.animateTo(2);
  }

  /// 儲存卡片（帶確認對話框）
  Future<void> _saveCard() async {
    // 手動輸入模式需驗證表單
    if (_tabController.index == 2 &&
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    // 確認有條碼數值
    final barcodeValue = _barcodeValueController.text.trim().isNotEmpty
        ? _barcodeValueController.text.trim()
        : _scannedValue;

    if (barcodeValue == null || barcodeValue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先掃描或輸入條碼')),
      );
      return;
    }

    // 確認有店家名稱
    final storeName = _storeNameController.text.trim();
    if (storeName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請切換到「手動輸入」填入店家名稱')),
      );
      _tabController.animateTo(2);
      return;
    }

    final format = _scannedFormat ?? _selectedFormat;

    // 顯示確認對話框（含條碼預覽）
    final confirmed = await _showConfirmDialog(
      storeName: storeName,
      barcodeValue: barcodeValue,
      format: format,
    );

    if (!confirmed) return;

    setState(() => _isProcessing = true);

    try {
      // 顏色轉 hex 字串
      final colorHex = _selectedColor != null
          ? '#${_selectedColor!.value.toRadixString(16).substring(2).toUpperCase()}'
          : null;

      if (_isEditing) {
        // 編輯模式：更新現有卡片
        final updatedCard = widget.editingCard!.copyWith(
          storeName: storeName,
          barcodeValue: barcodeValue,
          barcodeFormat: format,
          cardColor: colorHex,
          ssidKeywords: _ssidKeywords,
        );
        await _controller.updateCard(updatedCard);
      } else {
        // 新增模式
        final newCard = MemberCard(
          id: _uuid.v4(),
          storeName: storeName,
          barcodeValue: barcodeValue,
          barcodeFormat: format,
          cardColor: colorHex,
          sortOrder: _controller.cards.length,
          ssidKeywords: _ssidKeywords,
        );
        await _controller.addCard(newCard);
      }

      if (!mounted) return;
      Navigator.pop(context); // 返回主畫面
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ──────────────────────────────────────────
  // 確認對話框（含條碼預覽）
  // ──────────────────────────────────────────

  /// 存檔確認對話框
  /// 顯示店家名稱、條碼格式與條碼預覽圖
  Future<bool> _showConfirmDialog({
    required String storeName,
    required String barcodeValue,
    required BarcodeFormatType format,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('確認儲存'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 店家資訊
              Text(
                storeName,
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                format.name.toUpperCase(),
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: Theme.of(ctx).colorScheme.outline,
                    ),
              ),
              const SizedBox(height: 16),

              // 條碼預覽
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: BarcodeDisplayWidget(
                    barcodeValue: barcodeValue,
                    barcodeFormat: format,
                    width: 240,
                    height: 120,
                    showText: true,
                  ),
                ),
              ),

              // SSID 關鍵字（若有）
              if (_ssidKeywords.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'WiFi 關鍵字：${_ssidKeywords.join(", ")}',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('繼續編輯'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('確認儲存'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
