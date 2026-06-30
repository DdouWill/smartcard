/// 台灣常見店家清單（含離島）
class KnownStore {
  final String name;
  final String? defaultBarcodeFormat;
  final String emoji;

  /// 品牌主色（ARGB hex，例如 'FF006400'）；null 表示使用卡片自訂色或主題色
  final String? brandColor;

  /// Android 桌面 Widget logo badge 使用的短文字（避免 Widget 只能顯示 App icon）
  final String? logoLabel;

  const KnownStore(
    this.name, {
    this.defaultBarcodeFormat,
    this.emoji = '💳',
    this.brandColor,
    this.logoLabel,
  });
}

const List<KnownStore> knownStores = [
  // 超商
  KnownStore('7-ELEVEN',
      defaultBarcodeFormat: 'CODE128',
      emoji: '🏪',
      brandColor: 'FFEE4422',
      logoLabel: '7'),
  KnownStore('全家 FamilyMart',
      defaultBarcodeFormat: 'CODE128',
      emoji: '🏪',
      brandColor: 'FF006B3C',
      logoLabel: '全家'),
  KnownStore('萊爾富 Hi-Life',
      defaultBarcodeFormat: 'CODE128',
      emoji: '🏪',
      brandColor: 'FF0057A8',
      logoLabel: '萊'),
  KnownStore('OK 超商',
      defaultBarcodeFormat: 'CODE128',
      emoji: '🏪',
      brandColor: 'FF1B5E20',
      logoLabel: 'OK'),

  // 量販超市
  KnownStore('全聯福利中心',
      defaultBarcodeFormat: 'EAN13',
      emoji: '🛒',
      brandColor: 'FFCC0000',
      logoLabel: 'PX'),
  KnownStore('家樂福 Carrefour',
      defaultBarcodeFormat: 'EAN13',
      emoji: '🛒',
      brandColor: 'FF0063B8',
      logoLabel: 'C'),
  KnownStore('大潤發',
      defaultBarcodeFormat: 'EAN13',
      emoji: '🛒',
      brandColor: 'FFD71920',
      logoLabel: 'RT'),
  KnownStore('大全聯',
      defaultBarcodeFormat: 'EAN13',
      emoji: '🛒',
      brandColor: 'FFCC0000',
      logoLabel: 'PX'),
  KnownStore('好市多 Costco',
      defaultBarcodeFormat: 'CODE128',
      emoji: '🛒',
      brandColor: 'FF005DAA',
      logoLabel: 'COST'),
  KnownStore('美廉社',
      defaultBarcodeFormat: 'EAN13',
      emoji: '🛒',
      brandColor: 'FF2E7D32',
      logoLabel: '美'),
  KnownStore('頂好 Wellcome',
      defaultBarcodeFormat: 'EAN13',
      emoji: '🛒',
      brandColor: 'FF1565C0',
      logoLabel: 'W'),
  KnownStore('愛買',
      defaultBarcodeFormat: 'EAN13',
      emoji: '🛒',
      brandColor: 'FFAA0000',
      logoLabel: '愛'),

  // 藥妝美妝
  KnownStore('屈臣氏 Watsons',
      defaultBarcodeFormat: 'CODE128',
      emoji: '💊',
      brandColor: 'FF00B5AD',
      logoLabel: 'W'),
  KnownStore('康是美 COSMED',
      defaultBarcodeFormat: 'CODE128',
      emoji: '💊',
      brandColor: 'FFD32F2F',
      logoLabel: '康'),
  KnownStore('寶雅 POYA',
      defaultBarcodeFormat: 'CODE128',
      emoji: '💄',
      brandColor: 'FF880E4F',
      logoLabel: 'POYA'),
  KnownStore('小三美日',
      defaultBarcodeFormat: 'CODE128',
      emoji: '💄',
      brandColor: 'FFE91E63',
      logoLabel: '小三'),

  // 百貨購物
  KnownStore('新光三越',
      defaultBarcodeFormat: 'CODE128',
      emoji: '🏬',
      brandColor: 'FFB71C1C',
      logoLabel: '新光'),
  KnownStore('SOGO',
      defaultBarcodeFormat: 'CODE128',
      emoji: '🏬',
      brandColor: 'FFB00020',
      logoLabel: 'SOGO'),
  KnownStore('遠東百貨',
      defaultBarcodeFormat: 'CODE128',
      emoji: '🏬',
      brandColor: 'FF0D47A1',
      logoLabel: '遠百'),
  KnownStore('微風廣場',
      defaultBarcodeFormat: 'CODE128',
      emoji: '🏬',
      brandColor: 'FF6A1B9A',
      logoLabel: '微風'),
  KnownStore('統一時代',
      defaultBarcodeFormat: 'CODE128',
      emoji: '🏬',
      brandColor: 'FF37474F',
      logoLabel: '時代'),
  KnownStore('三井', emoji: '🏬', brandColor: 'FF0D47A1', logoLabel: 'M'),
  KnownStore('LaLaport', emoji: '🏬', brandColor: 'FF005BAC', logoLabel: 'La'),
  KnownStore('漢神百貨', emoji: '🏬', brandColor: 'FF7B1FA2', logoLabel: '漢神'),

  // 服飾 / 生活
  KnownStore('GU', emoji: '👕', brandColor: 'FF0D47A1', logoLabel: 'GU'),
  KnownStore('UNIQLO', emoji: '👕', brandColor: 'FFE60012', logoLabel: 'UQ'),
  KnownStore('MUJI', emoji: '🏠', brandColor: 'FF7F0019', logoLabel: 'MUJI'),

  // 生活百貨 / 五金
  KnownStore('小北百貨',
      defaultBarcodeFormat: 'CODE128',
      emoji: '🏠',
      brandColor: 'FFFF8F00',
      logoLabel: '小北'),
  KnownStore('大創 DAISO',
      defaultBarcodeFormat: 'EAN13',
      emoji: '🏠',
      brandColor: 'FFEC008C',
      logoLabel: '大創'),
  KnownStore('九乘九',
      defaultBarcodeFormat: 'CODE128',
      emoji: '✏️',
      brandColor: 'FFFF9800',
      logoLabel: '9x9'),
  KnownStore('振宇五金', emoji: '🛠️', brandColor: 'FFFFA000', logoLabel: '振宇'),

  // 書店
  KnownStore('誠品',
      defaultBarcodeFormat: 'CODE128',
      emoji: '📚',
      brandColor: 'FF2E2E2E',
      logoLabel: '誠品'),
  KnownStore('金石堂',
      defaultBarcodeFormat: 'CODE128',
      emoji: '📚',
      brandColor: 'FFD32F2F',
      logoLabel: '金石'),

  // 餐飲
  KnownStore('路易莎 Louisa',
      defaultBarcodeFormat: 'CODE128',
      emoji: '☕',
      brandColor: 'FF5D4037',
      logoLabel: 'L'),
  KnownStore('星巴克 Starbucks',
      defaultBarcodeFormat: 'CODE128',
      emoji: '☕',
      brandColor: 'FF00704A',
      logoLabel: '★'),
  KnownStore('cama café',
      defaultBarcodeFormat: 'CODE128',
      emoji: '☕',
      brandColor: 'FF6D4C41',
      logoLabel: 'cama'),
  KnownStore('摩斯漢堡',
      defaultBarcodeFormat: 'CODE128',
      emoji: '🍔',
      brandColor: 'FF2E7D32',
      logoLabel: 'MOS'),
  KnownStore('麥當勞',
      defaultBarcodeFormat: 'CODE128',
      emoji: '🍔',
      brandColor: 'FFDA1F1F',
      logoLabel: 'M'),
  KnownStore('肯德基 KFC',
      defaultBarcodeFormat: 'CODE128',
      emoji: '🍗',
      brandColor: 'FFB71C1C',
      logoLabel: 'KFC'),
  KnownStore('八方雲集',
      defaultBarcodeFormat: 'CODE128',
      emoji: '🥟',
      brandColor: 'FFEF6C00',
      logoLabel: '八方'),

  // 電器 3C
  KnownStore('全國電子',
      defaultBarcodeFormat: 'CODE128',
      emoji: '🔌',
      brandColor: 'FF0D47A1',
      logoLabel: '全國'),
  KnownStore('燦坤 3C',
      defaultBarcodeFormat: 'CODE128',
      emoji: '🔌',
      brandColor: 'FFFF6F00',
      logoLabel: '燦坤'),

  // 交通
  KnownStore('台灣高鐵', emoji: '🚄', brandColor: 'FFFF8F00', logoLabel: '高鐵'),

  // 加油站
  KnownStore('中油 CPC',
      defaultBarcodeFormat: 'CODE128',
      emoji: '⛽',
      brandColor: 'FF1565C0',
      logoLabel: 'CPC'),
  KnownStore('台塑 FPCC',
      defaultBarcodeFormat: 'CODE128',
      emoji: '⛽',
      brandColor: 'FF2E7D32',
      logoLabel: '台塑'),

  // 離島
  KnownStore('金門良金牧場',
      defaultBarcodeFormat: 'CODE128',
      emoji: '🐄',
      brandColor: 'FF6D4C41',
      logoLabel: '良金'),
  KnownStore('澎湖免稅商店',
      defaultBarcodeFormat: 'CODE128',
      emoji: '🏝️',
      brandColor: 'FF00838F',
      logoLabel: '澎湖'),
];

const Map<String, String> _knownStoreAliases = {
  '7-11': '7-ELEVEN',
  '711': '7-ELEVEN',
  '小七': '7-ELEVEN',
  '7eleven': '7-ELEVEN',
  '7-eleven': '7-ELEVEN',
  'seven': '7-ELEVEN',
  'seven eleven': '7-ELEVEN',
  '全家': '全家 FamilyMart',
  'familymart': '全家 FamilyMart',
  'family mart': '全家 FamilyMart',
  '萊爾富': '萊爾富 Hi-Life',
  'hilife': '萊爾富 Hi-Life',
  'hi-life': '萊爾富 Hi-Life',
  'ok': 'OK 超商',
  'ok超商': 'OK 超商',
  '全聯': '全聯福利中心',
  '大全聯': '大潤發',
  'mega pxmart': '大潤發',
  '大潤發': '大潤發',
  '大潤發 rt-mart': '大潤發',
  'rt-mart': '大潤發',
  'rt mart': '大潤發',
  '家樂福': '家樂福 Carrefour',
  'carrefour': '家樂福 Carrefour',
  '好市多': '好市多 Costco',
  'costco': '好市多 Costco',
  '屈臣氏': '屈臣氏 Watsons',
  'watsons': '屈臣氏 Watsons',
  '康是美': '康是美 COSMED',
  'cosmed': '康是美 COSMED',
  '寶雅': '寶雅 POYA',
  'poya': '寶雅 POYA',
  'gu': 'GU',
  'uniqlo': 'UNIQLO',
  '優衣庫': 'UNIQLO',
  'muji': 'MUJI',
  '無印良品': 'MUJI',
  '無印': 'MUJI',
  '振宇': '振宇五金',
  '三井 outlet': '三井',
  '三井outlet': '三井',
  'mitsui outlet park': '三井',
  'mitsui outlet': '三井',
  'lalaport': 'LaLaport',
  '三井 lalaport': 'LaLaport',
  '三井lalaport': 'LaLaport',
  '漢神': '漢神百貨',
  '漢神巨蛋': '漢神百貨',
  '漢神洲際': '漢神百貨',
  '新濱町': '漢神百貨',
  'hanshin': '漢神百貨',
  '林口三井': '三井',
  '台南三井': '三井',
  '台中港三井': '三井',
  '台灣高鐵': '台灣高鐵',
  '高鐵': '台灣高鐵',
  'thsr': '台灣高鐵',
  '台灣高鐵 thsr': '台灣高鐵',
  '美廉社 simple mart': '美廉社',
  '美廉社': '美廉社',
  '大創': '大創 DAISO',
  'daiso': '大創 DAISO',
  '路易莎': '路易莎 Louisa',
  'louisa': '路易莎 Louisa',
  '星巴克': '星巴克 Starbucks',
  'starbucks': '星巴克 Starbucks',
  'cama': 'cama café',
  '摩斯': '摩斯漢堡',
  '摩斯漢堡 mos': '摩斯漢堡',
  'mos': '摩斯漢堡',
  '麥當勞 mcdonald': '麥當勞',
  'mcdonalds': '麥當勞',
  "mcdonald's": '麥當勞',
  '肯德基': '肯德基 KFC',
  'kfc': '肯德基 KFC',
  '八方': '八方雲集',
  '全國電子 elife': '全國電子',
  '燦坤': '燦坤 3C',
  '誠品書店': '誠品',
  '誠品生活': '誠品',
  '中油': '中油 CPC',
  'cpc': '中油 CPC',
  '台塑': '台塑 FPCC',
  '新光': '新光三越',
  '遠百': '遠東百貨',
};

KnownStore? findKnownStore(String storeName) {
  final normalized = normalizeKnownStoreName(storeName);
  if (normalized.isEmpty) return null;
  for (final store in knownStores) {
    if (store.name == normalized) return store;
  }

  final lower = storeName.trim().toLowerCase();
  for (final store in knownStores) {
    final storeLower = store.name.toLowerCase();
    if (storeLower == lower ||
        storeLower.contains(lower) ||
        lower.contains(storeLower)) {
      return store;
    }
  }
  return null;
}

String normalizeKnownStoreName(String storeName) {
  final trimmed = storeName.trim();
  if (trimmed.isEmpty) return trimmed;

  final lower = trimmed.toLowerCase();
  if (_knownStoreAliases.containsKey(lower)) {
    return _knownStoreAliases[lower]!;
  }

  final sortedAliasEntries = _knownStoreAliases.entries.toList()
    ..sort((a, b) => b.key.length.compareTo(a.key.length));
  for (final entry in sortedAliasEntries) {
    if (lower.contains(entry.key)) return entry.value;
  }

  for (final store in knownStores) {
    final storeLower = store.name.toLowerCase();
    if (storeLower == lower ||
        storeLower.contains(lower) ||
        lower.contains(storeLower)) {
      return store.name;
    }
  }

  return trimmed;
}

/// 根據店家名稱取得對應的 emoji
String getStoreEmoji(String storeName) {
  final store = findKnownStore(storeName);
  return store?.emoji ?? '💳';
}

/// 根據店家名稱取得品牌主色（ARGB hex 字串），無資料回傳 null
String? getStoreBrandColor(String storeName) {
  final store = findKnownStore(storeName);
  return store?.brandColor;
}

/// 根據店家名稱取得 Android 桌面 Widget logo badge 短文字
String getStoreLogoLabel(String storeName) {
  final store = findKnownStore(storeName);
  final label = store?.logoLabel?.trim();
  if (label != null && label.isNotEmpty) return label;
  return _fallbackStoreLogoLabel(storeName);
}

String _fallbackStoreLogoLabel(String storeName) {
  final normalized = normalizeKnownStoreName(storeName).trim();
  if (normalized.isEmpty) return '卡';

  final cjkMatches = RegExp('[一-鿿]').allMatches(normalized).toList();
  if (cjkMatches.isNotEmpty) {
    return cjkMatches.take(2).map((match) => match.group(0)!).join();
  }

  final asciiWords = RegExp(r'[A-Za-z0-9]+')
      .allMatches(normalized)
      .map((match) => match.group(0)!)
      .toList();
  if (asciiWords.isNotEmpty) {
    final firstWord = asciiWords.first.toUpperCase();
    if (firstWord.length <= 4) return firstWord;
    if (asciiWords.length > 1) {
      return asciiWords
          .take(4)
          .map((word) => String.fromCharCode(word.runes.first).toUpperCase())
          .join();
    }
    return firstWord.substring(0, 4);
  }

  return String.fromCharCodes(normalized.runes.take(2));
}
