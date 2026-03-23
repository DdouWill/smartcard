// 會員卡資料模型
// 使用 Hive 進行本地加密儲存
// 包含 GPS 地理圍欄區域與 WiFi SSID 關鍵字匹配

import 'package:hive/hive.dart';

part 'member_card.g.dart';

const _sentinel = Object();

/// 支援的條碼格式類型
@HiveType(typeId: 2)
enum BarcodeFormatType {
  @HiveField(0) unknown,
  @HiveField(1) ean13,
  @HiveField(2) ean8,
  @HiveField(3) qr,
  @HiveField(4) code128,
  @HiveField(5) code39,
  @HiveField(6) pdf417,
  @HiveField(7) aztec,
  @HiveField(8) dataMatrix,
  @HiveField(9) itf,
  @HiveField(10) upca,
  @HiveField(11) upce,
  @HiveField(12) codabar,
}

/// GPS 地理圍欄區域
@HiveType(typeId: 1)
class GpsZone extends HiveObject {
  @HiveField(0) double latitude;
  @HiveField(1) double longitude;
  @HiveField(2) double radiusMeters;
  @HiveField(3) String? label;

  GpsZone({
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 100.0,
    this.label,
  });
}

/// 會員卡主資料模型
@HiveType(typeId: 0)
class MemberCard extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String storeName;
  @HiveField(2) String barcodeValue;
  @HiveField(3) BarcodeFormatType barcodeFormat;
  @HiveField(4) String? cardColor;
  @HiveField(5) String? iconPath;
  @HiveField(6) int sortOrder;
  @HiveField(7) List<String> ssidKeywords;
  @HiveField(8) List<GpsZone> gpsZones;
  @HiveField(9) DateTime createdAt;
  @HiveField(10) DateTime updatedAt;

  MemberCard({
    required this.id,
    required this.storeName,
    required this.barcodeValue,
    required this.barcodeFormat,
    this.cardColor,
    this.iconPath,
    this.sortOrder = 0,
    List<String>? ssidKeywords,
    List<GpsZone>? gpsZones,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : ssidKeywords = ssidKeywords ?? [],
        gpsZones = gpsZones ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  MemberCard copyWith({
    String? storeName,
    String? barcodeValue,
    BarcodeFormatType? barcodeFormat,
    Object? cardColor = _sentinel,
    Object? iconPath = _sentinel,
    int? sortOrder,
    List<String>? ssidKeywords,
    List<GpsZone>? gpsZones,
  }) {
    return MemberCard(
      id: id,
      storeName: storeName ?? this.storeName,
      barcodeValue: barcodeValue ?? this.barcodeValue,
      barcodeFormat: barcodeFormat ?? this.barcodeFormat,
      cardColor: cardColor == _sentinel ? this.cardColor : cardColor as String?,
      iconPath: iconPath == _sentinel ? this.iconPath : iconPath as String?,
      sortOrder: sortOrder ?? this.sortOrder,
      ssidKeywords: ssidKeywords ?? List.from(this.ssidKeywords),
      gpsZones: gpsZones ?? List.from(this.gpsZones),
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
