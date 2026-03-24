// GitHub Release 更新檢查服務
// App 啟動時檢查最新版本，每 24 小時最多提醒一次

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static const _repoApiUrl =
      'https://api.github.com/repos/DdouWill/smartcard/releases/latest';
  static const _prefKeyLastCheck = 'update_last_check_time';
  static const _checkIntervalMs = 24 * 60 * 60 * 1000; // 24 hours

  /// 當前 App 版本（從 pubspec.yaml version 欄位而來）
  final String currentVersion;

  UpdateService({required this.currentVersion});

  /// 啟動時呼叫：檢查是否有新版本，有則顯示對話框
  Future<void> checkForUpdate(BuildContext context) async {
    try {
      // 24 小時內不重複檢查
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getInt(_prefKeyLastCheck) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - lastCheck < _checkIntervalMs) return;

      // 發送 GET 請求
      final response = await http
          .get(
            Uri.parse(_repoApiUrl),
            headers: {'Accept': 'application/vnd.github.v3+json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = (data['tag_name'] as String?) ?? '';
      final body = (data['body'] as String?) ?? '';

      // 移除 tag 前綴 v
      final latestVersion = tagName.startsWith('v') ? tagName.substring(1) : tagName;

      if (!_isNewer(latestVersion, currentVersion)) {
        // 沒有新版本，記錄檢查時間
        await prefs.setInt(_prefKeyLastCheck, now);
        return;
      }

      // 找 APK 下載連結
      String? apkUrl;
      final assets = data['assets'] as List<dynamic>? ?? [];
      for (final asset in assets) {
        final name = (asset['name'] as String?) ?? '';
        if (name.endsWith('.apk')) {
          apkUrl = asset['browser_download_url'] as String?;
          break;
        }
      }
      // 如果沒有 APK，用 release 頁面
      final downloadUrl = apkUrl ?? (data['html_url'] as String?) ?? '';

      if (!context.mounted) return;

      // 記錄檢查時間
      await prefs.setInt(_prefKeyLastCheck, now);

      // 顯示更新對話框
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('有新版本可用'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'v$latestVersion',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(body),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('稍後再說'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (downloadUrl.isNotEmpty) {
                  launchUrl(
                    Uri.parse(downloadUrl),
                    mode: LaunchMode.externalApplication,
                  );
                }
              },
              child: const Text('前往下載'),
            ),
          ],
        ),
      );
    } catch (_) {
      // 無網路或任何錯誤 → 靜默跳過
    }
  }

  /// 比較版本號：latestVersion > currentVersion 時回傳 true
  bool _isNewer(String latest, String current) {
    final latestParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final len = latestParts.length > currentParts.length
        ? latestParts.length
        : currentParts.length;

    for (var i = 0; i < len; i++) {
      final l = i < latestParts.length ? latestParts[i] : 0;
      final c = i < currentParts.length ? currentParts[i] : 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }
}
