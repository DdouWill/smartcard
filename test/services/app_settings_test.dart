import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard/models/app_settings.dart';

void main() {
  // ──────────────────────────────────────────
  // U18: AppSettings 預設值
  // ──────────────────────────────────────────
  group('U18: AppSettings 預設值', () {
    test('AppSettings.defaults() 所有欄位有合理預設值', () {
      final settings = AppSettings.defaults();

      expect(settings.enableWifi, isTrue);
      expect(settings.enableGps, isTrue);
      expect(settings.updateIntervalMinutes, 5);
      expect(settings.screenBrightnessMode, 1); // maximum
      expect(settings.showRecentOnEmpty, isTrue);
      expect(settings.maxWidgetCards, 5);
    });

    test('AppSettings() 建構式與 defaults() 一致', () {
      final fromConstructor = AppSettings();
      final fromFactory = AppSettings.defaults();

      expect(fromConstructor.enableWifi, fromFactory.enableWifi);
      expect(fromConstructor.enableGps, fromFactory.enableGps);
      expect(fromConstructor.updateIntervalMinutes, fromFactory.updateIntervalMinutes);
      expect(fromConstructor.screenBrightnessMode, fromFactory.screenBrightnessMode);
      expect(fromConstructor.showRecentOnEmpty, fromFactory.showRecentOnEmpty);
      expect(fromConstructor.maxWidgetCards, fromFactory.maxWidgetCards);
    });

    test('brightnessMode getter 正確轉換所有模式', () {
      expect(
        AppSettings(screenBrightnessMode: 0).brightnessMode,
        ScreenBrightnessMode.system,
      );
      expect(
        AppSettings(screenBrightnessMode: 1).brightnessMode,
        ScreenBrightnessMode.maximum,
      );
      expect(
        AppSettings(screenBrightnessMode: 2).brightnessMode,
        ScreenBrightnessMode.keepOn,
      );
    });

    test('brightnessMode getter 超出範圍時 clamp 到有效值', () {
      // screenBrightnessMode = 999 → clamp 到 2 (keepOn)
      final settings = AppSettings(screenBrightnessMode: 999);
      expect(settings.brightnessMode, ScreenBrightnessMode.keepOn);

      // screenBrightnessMode = -1 → clamp 到 0 (system)
      final settingsNeg = AppSettings(screenBrightnessMode: -1);
      expect(settingsNeg.brightnessMode, ScreenBrightnessMode.system);
    });

    test('自訂值正確設定', () {
      final settings = AppSettings(
        enableWifi: false,
        enableGps: false,
        updateIntervalMinutes: 30,
        screenBrightnessMode: 0,
        showRecentOnEmpty: false,
        maxWidgetCards: 3,
      );

      expect(settings.enableWifi, isFalse);
      expect(settings.enableGps, isFalse);
      expect(settings.updateIntervalMinutes, 30);
      expect(settings.screenBrightnessMode, 0);
      expect(settings.showRecentOnEmpty, isFalse);
      expect(settings.maxWidgetCards, 3);
    });

    test('ScreenBrightnessMode enum 有 3 個值', () {
      expect(ScreenBrightnessMode.values.length, 3);
      expect(ScreenBrightnessMode.values[0], ScreenBrightnessMode.system);
      expect(ScreenBrightnessMode.values[1], ScreenBrightnessMode.maximum);
      expect(ScreenBrightnessMode.values[2], ScreenBrightnessMode.keepOn);
    });
  });
}
