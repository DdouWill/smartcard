// App 全域設定資料模型
import 'package:hive/hive.dart';

part 'app_settings.g.dart';

@HiveType(typeId: 3)
enum ScreenBrightnessMode {
  @HiveField(0) system,
  @HiveField(1) maximum,
  @HiveField(2) keepOn,
}

@HiveType(typeId: 4)
class AppSettings extends HiveObject {
  @HiveField(0) bool enableWifi;
  @HiveField(1) bool enableGps;
  @HiveField(2) int updateIntervalMinutes;
  @HiveField(3) int screenBrightnessMode;
  @HiveField(4) bool showRecentOnEmpty;
  @HiveField(5) int maxWidgetCards;

  AppSettings({
    this.enableWifi = true,
    this.enableGps = true,
    this.updateIntervalMinutes = 5,
    this.screenBrightnessMode = 1,
    this.showRecentOnEmpty = true,
    this.maxWidgetCards = 5,
  });

  factory AppSettings.defaults() => AppSettings();

  ScreenBrightnessMode get brightnessMode =>
      ScreenBrightnessMode.values[screenBrightnessMode.clamp(
        0,
        ScreenBrightnessMode.values.length - 1,
      )];
}
