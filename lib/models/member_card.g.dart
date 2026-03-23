// GENERATED CODE - DO NOT MODIFY BY HAND
// 此檔案由 build_runner + hive_generator 自動生成
// 執行 `dart run build_runner build` 重新生成
// ignore_for_file: type=lint

part of 'member_card.dart';

// ──────────────────────────────────────────
// MemberCard TypeAdapter
// ──────────────────────────────────────────

class MemberCardAdapter extends TypeAdapter<MemberCard> {
  @override
  final int typeId = 0;

  @override
  MemberCard read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MemberCard(
      id: fields[0] as String,
      storeName: fields[1] as String,
      barcodeValue: fields[2] as String,
      barcodeFormat: fields[3] as BarcodeFormatType,
      cardColor: fields[4] as String?,
      iconPath: fields[5] as String?,
      sortOrder: fields[6] as int,
      ssidKeywords: (fields[7] as List?)?.cast<String>(),
      gpsZones: (fields[8] as List?)?.cast<GpsZone>(),
      createdAt: fields[9] as DateTime?,
      updatedAt: fields[10] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, MemberCard obj) {
    writer
      ..writeByte(11) // 欄位數量
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.storeName)
      ..writeByte(2)
      ..write(obj.barcodeValue)
      ..writeByte(3)
      ..write(obj.barcodeFormat)
      ..writeByte(4)
      ..write(obj.cardColor)
      ..writeByte(5)
      ..write(obj.iconPath)
      ..writeByte(6)
      ..write(obj.sortOrder)
      ..writeByte(7)
      ..write(obj.ssidKeywords)
      ..writeByte(8)
      ..write(obj.gpsZones)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemberCardAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// ──────────────────────────────────────────
// GpsZone TypeAdapter
// ──────────────────────────────────────────

class GpsZoneAdapter extends TypeAdapter<GpsZone> {
  @override
  final int typeId = 1;

  @override
  GpsZone read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GpsZone(
      latitude: fields[0] as double,
      longitude: fields[1] as double,
      radiusMeters: fields[2] as double,
      label: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, GpsZone obj) {
    writer
      ..writeByte(4) // 欄位數量
      ..writeByte(0)
      ..write(obj.latitude)
      ..writeByte(1)
      ..write(obj.longitude)
      ..writeByte(2)
      ..write(obj.radiusMeters)
      ..writeByte(3)
      ..write(obj.label);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GpsZoneAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// ──────────────────────────────────────────
// BarcodeFormatType TypeAdapter
// ──────────────────────────────────────────

class BarcodeFormatTypeAdapter extends TypeAdapter<BarcodeFormatType> {
  @override
  final int typeId = 2;

  @override
  BarcodeFormatType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return BarcodeFormatType.unknown;
      case 1:
        return BarcodeFormatType.ean13;
      case 2:
        return BarcodeFormatType.ean8;
      case 3:
        return BarcodeFormatType.qr;
      case 4:
        return BarcodeFormatType.code128;
      case 5:
        return BarcodeFormatType.code39;
      case 6:
        return BarcodeFormatType.pdf417;
      case 7:
        return BarcodeFormatType.aztec;
      case 8:
        return BarcodeFormatType.dataMatrix;
      case 9:
        return BarcodeFormatType.itf;
      case 10:
        return BarcodeFormatType.upca;
      case 11:
        return BarcodeFormatType.upce;
      case 12:
        return BarcodeFormatType.codabar;
      default:
        return BarcodeFormatType.unknown;
    }
  }

  @override
  void write(BinaryWriter writer, BarcodeFormatType obj) {
    switch (obj) {
      case BarcodeFormatType.unknown:
        writer.writeByte(0);
      case BarcodeFormatType.ean13:
        writer.writeByte(1);
      case BarcodeFormatType.ean8:
        writer.writeByte(2);
      case BarcodeFormatType.qr:
        writer.writeByte(3);
      case BarcodeFormatType.code128:
        writer.writeByte(4);
      case BarcodeFormatType.code39:
        writer.writeByte(5);
      case BarcodeFormatType.pdf417:
        writer.writeByte(6);
      case BarcodeFormatType.aztec:
        writer.writeByte(7);
      case BarcodeFormatType.dataMatrix:
        writer.writeByte(8);
      case BarcodeFormatType.itf:
        writer.writeByte(9);
      case BarcodeFormatType.upca:
        writer.writeByte(10);
      case BarcodeFormatType.upce:
        writer.writeByte(11);
      case BarcodeFormatType.codabar:
        writer.writeByte(12);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BarcodeFormatTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
