/// 台灣常見店家清單（含離島）
class KnownStore {
  final String name;
  final String? defaultBarcodeFormat;
  final String emoji;

  const KnownStore(this.name, {this.defaultBarcodeFormat, this.emoji = '💳'});
}

const List<KnownStore> knownStores = [
  // 超商
  KnownStore('7-ELEVEN', defaultBarcodeFormat: 'CODE128', emoji: '🏪'),
  KnownStore('全家 FamilyMart', defaultBarcodeFormat: 'CODE128', emoji: '🏪'),
  KnownStore('萊爾富 Hi-Life', defaultBarcodeFormat: 'CODE128', emoji: '🏪'),
  KnownStore('OK 超商', defaultBarcodeFormat: 'CODE128', emoji: '🏪'),

  // 量販超市
  KnownStore('全聯福利中心', defaultBarcodeFormat: 'EAN13', emoji: '🛒'),
  KnownStore('家樂福 Carrefour', defaultBarcodeFormat: 'EAN13', emoji: '🛒'),
  KnownStore('大潤發', defaultBarcodeFormat: 'EAN13', emoji: '🛒'),
  KnownStore('好市多 Costco', defaultBarcodeFormat: 'CODE128', emoji: '🛒'),
  KnownStore('美廉社', defaultBarcodeFormat: 'EAN13', emoji: '🛒'),
  KnownStore('頂好 Wellcome', defaultBarcodeFormat: 'EAN13', emoji: '🛒'),
  KnownStore('愛買', defaultBarcodeFormat: 'EAN13', emoji: '🛒'),

  // 藥妝美妝
  KnownStore('屈臣氏 Watsons', defaultBarcodeFormat: 'CODE128', emoji: '💊'),
  KnownStore('康是美 COSMED', defaultBarcodeFormat: 'CODE128', emoji: '💊'),
  KnownStore('寶雅 POYA', defaultBarcodeFormat: 'CODE128', emoji: '💄'),
  KnownStore('小三美日', defaultBarcodeFormat: 'CODE128', emoji: '💄'),

  // 百貨購物
  KnownStore('新光三越', defaultBarcodeFormat: 'CODE128', emoji: '🏬'),
  KnownStore('SOGO', defaultBarcodeFormat: 'CODE128', emoji: '🏬'),
  KnownStore('遠東百貨', defaultBarcodeFormat: 'CODE128', emoji: '🏬'),
  KnownStore('微風廣場', defaultBarcodeFormat: 'CODE128', emoji: '🏬'),
  KnownStore('統一時代', defaultBarcodeFormat: 'CODE128', emoji: '🏬'),

  // 生活百貨
  KnownStore('小北百貨', defaultBarcodeFormat: 'CODE128', emoji: '🏠'),
  KnownStore('大創 DAISO', defaultBarcodeFormat: 'EAN13', emoji: '🏠'),
  KnownStore('九乘九', defaultBarcodeFormat: 'CODE128', emoji: '✏️'),

  // 書店
  KnownStore('誠品', defaultBarcodeFormat: 'CODE128', emoji: '📚'),
  KnownStore('金石堂', defaultBarcodeFormat: 'CODE128', emoji: '📚'),

  // 餐飲
  KnownStore('路易莎 Louisa', defaultBarcodeFormat: 'CODE128', emoji: '☕'),
  KnownStore('星巴克 Starbucks', defaultBarcodeFormat: 'CODE128', emoji: '☕'),
  KnownStore('cama café', defaultBarcodeFormat: 'CODE128', emoji: '☕'),
  KnownStore('摩斯漢堡', defaultBarcodeFormat: 'CODE128', emoji: '🍔'),
  KnownStore('麥當勞', defaultBarcodeFormat: 'CODE128', emoji: '🍔'),
  KnownStore('肯德基 KFC', defaultBarcodeFormat: 'CODE128', emoji: '🍗'),
  KnownStore('八方雲集', defaultBarcodeFormat: 'CODE128', emoji: '🥟'),

  // 電器 3C
  KnownStore('全國電子', defaultBarcodeFormat: 'CODE128', emoji: '🔌'),
  KnownStore('燦坤 3C', defaultBarcodeFormat: 'CODE128', emoji: '🔌'),

  // 加油站
  KnownStore('中油 CPC', defaultBarcodeFormat: 'CODE128', emoji: '⛽'),
  KnownStore('台塑 FPCC', defaultBarcodeFormat: 'CODE128', emoji: '⛽'),

  // 離島
  KnownStore('金門良金牧場', defaultBarcodeFormat: 'CODE128', emoji: '🐄'),
  KnownStore('澎湖免稅商店', defaultBarcodeFormat: 'CODE128', emoji: '🏝️'),
];

/// 根據店家名稱取得對應的 emoji
String getStoreEmoji(String storeName) {
  for (final store in knownStores) {
    if (store.name == storeName) return store.emoji;
  }
  return '💳';
}
