// ============================================================
// MapPickerScreen — 全螢幕地圖選點頁面
// ============================================================
// 使用 flutter_map + OpenStreetMap tiles 讓使用者在地圖上選取位置。
// 支援：中央十字準星、長按放置標記、即時顯示經緯度、搜尋地址。
// ============================================================

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

/// 地圖選點結果
class MapPickerResult {
  final double latitude;
  final double longitude;

  const MapPickerResult({required this.latitude, required this.longitude});
}

/// 全螢幕地圖選點頁面
class MapPickerScreen extends StatefulWidget {
  /// 初始位置（編輯時帶入既有座標）
  final LatLng? initialPosition;

  const MapPickerScreen({super.key, this.initialPosition});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  // 台北市中心（預設 fallback）
  static const _defaultCenter = LatLng(25.0330, 121.5654);
  static const _defaultZoom = 16.0;

  final _mapController = MapController();
  final _searchController = TextEditingController();

  late LatLng _center;
  LatLng? _marker;
  bool _isLoadingLocation = true;
  bool _isSearching = false;
  List<_SearchResult> _searchResults = [];
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _center = widget.initialPosition ?? _defaultCenter;
    if (widget.initialPosition != null) {
      _marker = widget.initialPosition;
      _isLoadingLocation = false;
    } else {
      _locateUser();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  /// 取得使用者目前位置
  Future<void> _locateUser() async {
    try {
      var status = await Permission.location.status;
      if (!status.isGranted) {
        status = await Permission.location.request();
      }

      if (!status.isGranted) {
        if (mounted) setState(() => _isLoadingLocation = false);
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _isLoadingLocation = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (!mounted) return;
      final userPos = LatLng(position.latitude, position.longitude);
      setState(() {
        _center = userPos;
        _isLoadingLocation = false;
      });
      _mapController.move(userPos, _defaultZoom);
    } catch (_) {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  /// 搜尋地址（Nominatim）
  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 600), () {
      _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isSearching = true);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}'
        '&format=json&limit=5&countrycodes=tw',
      );
      final response = await http.get(uri, headers: {
        'User-Agent': 'SmartCard/1.0',
      });

      if (!mounted) return;
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        setState(() {
          _searchResults = data.map((item) {
            return _SearchResult(
              displayName: item['display_name'] as String,
              lat: double.parse(item['lat'] as String),
              lng: double.parse(item['lon'] as String),
            );
          }).toList();
        });
      }
    } catch (_) {
      // 搜尋失敗靜默處理
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectSearchResult(_SearchResult result) {
    final pos = LatLng(result.lat, result.lng);
    setState(() {
      _center = pos;
      _marker = pos;
      _searchResults = [];
      _searchController.clear();
    });
    _mapController.move(pos, _defaultZoom);
    FocusScope.of(context).unfocus();
  }

  /// 長按地圖放置標記
  void _onLongPress(TapPosition tapPosition, LatLng point) {
    setState(() {
      _marker = point;
      _center = point;
    });
  }

  /// 地圖移動時更新中心座標
  void _onMapEvent(MapCamera camera, bool hasGesture) {
    setState(() {
      _center = camera.center;
    });
  }

  /// 確認選擇
  void _confirmSelection() {
    final selected = _marker ?? _center;
    Navigator.pop(
      context,
      MapPickerResult(
        latitude: selected.latitude,
        longitude: selected.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedPoint = _marker ?? _center;

    return Scaffold(
      body: Stack(
        children: [
          // 地圖
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: _defaultZoom,
              onLongPress: _onLongPress,
              onMapEvent: (event) =>
                  _onMapEvent(event.camera, event.source != MapEventSource.nonRotatedSizeChange),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ddouwill.smartcard',
              ),
              // 長按標記
              if (_marker != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _marker!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // 中央十字準星（只在沒有標記時顯示）
          if (_marker == null)
            const Center(
              child: IgnorePointer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.my_location, size: 36, color: Colors.black87),
                    SizedBox(height: 36),
                  ],
                ),
              ),
            ),

          // 頂部：返回按鈕 + 搜尋欄
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: Column(
              children: [
                Row(
                  children: [
                    // 返回按鈕
                    Material(
                      elevation: 2,
                      shape: const CircleBorder(),
                      color: Theme.of(context).colorScheme.surface,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 搜尋欄
                    Expanded(
                      child: Material(
                        elevation: 2,
                        borderRadius: BorderRadius.circular(28),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText: '搜尋地址或地標...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _isSearching
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                : _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchResults = []);
                                        },
                                      )
                                    : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // 搜尋結果列表
                if (_searchResults.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 48, top: 4),
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(12),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final result = _searchResults[index];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.place, size: 20),
                            title: Text(
                              result.displayName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                            onTap: () => _selectSearchResult(result),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Loading 狀態
          if (_isLoadingLocation)
            const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('正在取得目前位置...'),
                    ],
                  ),
                ),
              ),
            ),

          // 底部：經緯度顯示 + 確認按鈕
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                // 目前位置按鈕
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FloatingActionButton.small(
                      heroTag: 'locate_me',
                      onPressed: _locateUser,
                      child: const Icon(Icons.my_location),
                    ),
                  ),
                ),
                // 經緯度 + 確認按鈕
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(16),
                  color: Theme.of(context).colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          '${selectedPoint.latitude.toStringAsFixed(6)}, '
                          '${selectedPoint.longitude.toStringAsFixed(6)}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontFamily: 'monospace',
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _marker != null ? '已選取標記位置' : '地圖中心位置',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _confirmSelection,
                            icon: const Icon(Icons.check),
                            label: const Text('確認選擇'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResult {
  final String displayName;
  final double lat;
  final double lng;

  const _SearchResult({
    required this.displayName,
    required this.lat,
    required this.lng,
  });
}
