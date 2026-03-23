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
  const AddCardScreen({super.key});

  @override
  State<AddCardScreen> createState() => _AddCardScreenState();
}

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // 監聽條碼輸入，即時更新預覽
    _barcodeValueController.addListener(() {
      setState(() => _previewBarcodeValue = _barcodeValueController.text.trim());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _storeNameController.dispose();
    _barcodeValueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('新增會員卡'),
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

  Widget _buildCameraScanTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 相機預覽佔位
          Container(
            width: double.infinity,
            height: 240,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.camera_alt, color: Colors.white54, size: 64),
                SizedBox(height: 8),
                Text(
                  '相機掃描',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _isProcessing ? null : _startCameraScanner,
            icon: const Icon(Icons.camera),
            label: const Text('開啟相機掃描'),
          ),
          const SizedBox(height: 12),
          Text(
            '對準實體會員卡的條碼，自動辨識後填入',
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
          // 店家名稱輸入
          TextFormField(
            controller: _storeNameController,
            decoration: const InputDecoration(
              labelText: '店家名稱 *',
              hintText: '例：全聯福利中心',
              prefixIcon: Icon(Icons.store),
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
            validator: (v) =>
                (v?.trim().isEmpty ?? true) ? '請輸入店家名稱' : null,
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
          label: const Text('儲存卡片'),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  // 動作處理
  // ──────────────────────────────────────────

  /// 開啟相機掃描
  Future<void> _startCameraScanner() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('相機掃描功能開發中')),
    );
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

      final newCard = MemberCard(
        id: _uuid.v4(),
        storeName: storeName,
        barcodeValue: barcodeValue,
        barcodeFormat: format,
        cardColor: colorHex,
        sortOrder: _controller.cards.length, // 新增到最後
        ssidKeywords: _ssidKeywords,
      );

      // 使用 AppController 新增卡片（取代直接呼叫 DatabaseService）
      await _controller.addCard(newCard);

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
