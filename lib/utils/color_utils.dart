import 'package:flutter/material.dart';

/// Parse hex color string to Color.
/// Supports #RGB / #RRGGBB / #AARRGGBB formats.
/// Returns null if parsing fails.
Color? parseHexColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  try {
    final cleaned = hex.replaceAll('#', '');
    final withAlpha = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
    return Color(int.parse(withAlpha, radix: 16));
  } catch (_) {
    return null;
  }
}

/// Convert Color to hex string (e.g. #FF2196F3).
String colorToHex(Color color) {
  return '#${color.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
}
