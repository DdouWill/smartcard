// GENERATED CODE - DO NOT MODIFY BY HAND
// 此檔案由 build_runner + hive_generator 自動生成
// 執行 `dart run build_runner build` 重新生成
// ignore_for_file: type=lint

part of 'app_settings.dart';

// ──────────────────────────────────────────
// ScreenBrightnessMode TypeAdapter
// ──────────────────────────────────────────

class ScreenBrightnessModeAdapter extends TypeAdapter<ScreenBrightnessMode> {
  @override
  final int typeId = 3;

  @override
  ScreenBrightnessMode read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ScreenBrightnessMode.system;
      case 1:
        return ScreenBrightnessMode.maximum;
      case 2:
        return ScreenBrightnessMode.keepOn;
      default:
        return ScreenBrightnessMode.system;
    }
  }

  @override
  void write(BinaryWriter writer, ScreenBrightnessMode obj) {
    switch (obj) {
      case ScreenBrightnessMode.system:
        writer.writeByte(0);
      case ScreenBrightnessMode.maximum:
        writer.writeByte(1);
      case ScreenBrightnessMode.keepOn:
        writer.writeByte(2);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScreenBrightnessModeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// ──────────────────────────────────────────
// AppSettings TypeAdapter
// ──────────────────────────────────────────

class AppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override
  final int typeId = 4;

  @override
  AppSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppSettings(
      enableWifi: fields[0] as bool,
      enableGps: fields[1] as bool,
      updateIntervalMinutes: fields[2] as int,
      screenBrightnessMode: fields[3] as int,
      showRecentOnEmpty: fields[4] as bool,
      maxWidgetCards: fields[5] as int,
    );
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(6) // 欄位數量
      ..writeByte(0)
      ..write(obj.enableWifi)
      ..writeByte(1)
      ..write(obj.enableGps)
      ..writeByte(2)
      ..write(obj.updateIntervalMinutes)
      ..writeByte(3)
      ..write(obj.screenBrightnessMode)
      ..writeByte(4)
      ..write(obj.showRecentOnEmpty)
      ..writeByte(5)
      ..write(obj.maxWidgetCards);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
