// ============================================================
// GpsZoneEditor — GPS 圍欄區域編輯器
// ============================================================
// 允許使用者管理 GPS 地理圍欄區域清單。
// 顯示已新增的區域（座標 + 半徑 + 名稱），並提供新增、編輯、刪除功能。
// ============================================================

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/member_card.dart';
import '../screens/map_picker_screen.dart';

/// GPS 圍欄區域編輯器
///
/// 使用範例：
/// ```dart
/// GpsZoneEditor(
///   zones: _gpsZones,
///   onZonesChanged: (updated) => setState(() => _gpsZones = updated),
/// )
/// ```
class GpsZoneEditor extends StatelessWidget {
  /// 目前的 GPS zone 清單
  final List<GpsZone> zones;

  /// zone 變更回調（傳出更新後的完整清單）
  final ValueChanged<List<GpsZone>> onZonesChanged;

  const GpsZoneEditor({
    super.key,
    required this.zones,
    required this.onZonesChanged,
  });

  /// 刪除指定索引的 zone
  void _removeZone(int index) {
    final updated = List<GpsZone>.from(zones)..removeAt(index);
    onZonesChanged(updated);
  }

  /// 新增 zone
  void _addZone(BuildContext context) async {
    final zone = await _showZoneDialog(context);
    if (zone != null) {
      onZonesChanged([...zones, zone]);
    }
  }

  /// 編輯指定索引的 zone
  void _editZone(BuildContext context, int index) async {
    final zone = await _showZoneDialog(context, existing: zones[index]);
    if (zone != null) {
      final updated = List<GpsZone>.from(zones);
      updated[index] = zone;
      onZonesChanged(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 標題與說明
        Row(
          children: [
            Text(
              'GPS 圍欄區域',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: '當手機位於設定的 GPS 區域內時，自動顯示此卡片',
              triggerMode: TooltipTriggerMode.tap,
              child: Icon(
                Icons.help_outline,
                size: 16,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '設定店家附近的 GPS 座標與範圍',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
        const SizedBox(height: 12),

        // 已新增的 zone 列表
        if (zones.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '尚未設定 GPS 區域（可選填）',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          )
        else
          ...List.generate(zones.length, (index) {
            final zone = zones[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.location_on),
                title: Text(
                  zone.label?.isNotEmpty == true
                      ? zone.label!
                      : '${zone.latitude.toStringAsFixed(5)}, ${zone.longitude.toStringAsFixed(5)}',
                ),
                subtitle: Text(
                  '${zone.latitude.toStringAsFixed(5)}, ${zone.longitude.toStringAsFixed(5)}｜'
                  '半徑 ${zone.radiusMeters.round()}m',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      tooltip: '編輯區域',
                      onPressed: () => _editZone(context, index),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20),
                      tooltip: '刪除區域',
                      onPressed: () => _removeZone(index),
                    ),
                  ],
                ),
              ),
            );
          }),

        const SizedBox(height: 8),

        // 新增區域按鈕
        OutlinedButton.icon(
          onPressed: () => _addZone(context),
          icon: const Icon(Icons.add_location_alt),
          label: const Text('新增區域'),
        ),
      ],
    );
  }
}

/// 顯示新增/編輯 GPS zone 的 dialog
Future<GpsZone?> _showZoneDialog(
  BuildContext context, {
  GpsZone? existing,
}) {
  return showDialog<GpsZone>(
    context: context,
    builder: (ctx) => _GpsZoneDialog(existing: existing),
  );
}

class _GpsZoneDialog extends StatefulWidget {
  final GpsZone? existing;
  const _GpsZoneDialog({this.existing});

  @override
  State<_GpsZoneDialog> createState() => _GpsZoneDialogState();
}

class _GpsZoneDialogState extends State<_GpsZoneDialog> {
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _labelController = TextEditingController();
  double _radius = 100.0;
  bool _isLocating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _latController.text = widget.existing!.latitude.toString();
      _lngController.text = widget.existing!.longitude.toString();
      _labelController.text = widget.existing!.label ?? '';
      _radius = widget.existing!.radiusMeters;
    }
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isLocating = true;
      _errorMessage = null;
    });

    try {
      // 檢查位置權限
      var status = await Permission.location.status;
      if (!status.isGranted) {
        status = await Permission.location.request();
        if (!status.isGranted) {
          setState(() => _errorMessage = '需要位置權限才能取得目前位置');
          return;
        }
      }

      // 檢查位置服務是否開啟
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _errorMessage = '請開啟裝置的定位服務');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      if (!mounted) return;
      setState(() {
        _latController.text = position.latitude.toString();
        _lngController.text = position.longitude.toString();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '無法取得位置：$e');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  /// 開啟全螢幕地圖選點
  Future<void> _openMapPicker() async {
    // 如果已有座標，帶入地圖初始位置
    LatLng? initial;
    final lat = double.tryParse(_sanitizeCoord(_latController.text));
    final lng = double.tryParse(_sanitizeCoord(_lngController.text));
    if (lat != null && lng != null && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
      initial = LatLng(lat, lng);
    }

    final result = await Navigator.push<MapPickerResult>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MapPickerScreen(initialPosition: initial),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _latController.text = result.latitude.toString();
        _lngController.text = result.longitude.toString();
        _errorMessage = null;
      });
    }
  }

  /// Sanitize text field value: strip non-numeric chars except .- and normalize decimal separator
  String _sanitizeCoord(String text) {
    // Replace comma decimal separator with period
    var s = text.trim().replaceAll(',', '.');
    // Remove any invisible/non-ASCII characters
    s = s.replaceAll(RegExp(r'[^\d.\-]'), '');
    // Remove duplicate dots (keep only first)
    final parts = s.split('.');
    if (parts.length > 2) {
      s = '${parts[0]}.${parts.sublist(1).join('')}';
    }
    return s;
  }

  void _confirm() {
    var lat = double.tryParse(_sanitizeCoord(_latController.text));
    var lng = double.tryParse(_sanitizeCoord(_lngController.text));

    // Auto-swap if lat/lng appear to be reversed
    if (lat != null && lng != null && lat.abs() > 90 && lng.abs() <= 90) {
      final tmp = lat;
      lat = lng;
      lng = tmp;
    }

    if (lat == null || lat < -90 || lat > 90) {
      setState(() => _errorMessage = '請輸入有效的緯度（-90 ~ 90）');
      return;
    }
    if (lng == null || lng < -180 || lng > 180) {
      setState(() => _errorMessage = '請輸入有效的經度（-180 ~ 180）');
      return;
    }

    final label = _labelController.text.trim();
    Navigator.pop(
      context,
      GpsZone(
        latitude: lat,
        longitude: lng,
        radiusMeters: _radius,
        label: label.isNotEmpty ? label : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;

    return AlertDialog(
      title: Text(isEditing ? '編輯 GPS 區域' : '新增 GPS 區域'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 使用目前位置 / 地圖選點按鈕
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: _isLocating ? null : _useCurrentLocation,
                    child: _isLocating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.my_location, size: 18),
                              SizedBox(width: 6),
                              Text('目前位置'),
                            ],
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: _openMapPicker,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('🗺', style: TextStyle(fontSize: 16)),
                        SizedBox(width: 6),
                        Text('地圖選點'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 緯度
            TextField(
              controller: _latController,
              decoration: const InputDecoration(
                labelText: '緯度',
                hintText: '例：25.0330',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true, signed: true),
            ),
            const SizedBox(height: 12),

            // 經度
            TextField(
              controller: _lngController,
              decoration: const InputDecoration(
                labelText: '經度',
                hintText: '例：121.5654',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true, signed: true),
            ),
            const SizedBox(height: 12),

            // 區域名稱
            TextField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: '區域名稱（選填）',
                hintText: '例：全聯中和店',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),

            // 半徑 slider
            Text(
              '半徑：${_radius.round()}m',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Slider(
              value: _radius,
              min: 50,
              max: 500,
              divisions: 18,
              label: '${_radius.round()}m',
              onChanged: (v) => setState(() => _radius = v),
            ),

            // 錯誤訊息
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _confirm,
          child: Text(isEditing ? '更新' : '新增'),
        ),
      ],
    );
  }
}
