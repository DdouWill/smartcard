# iOS 設定指南

在 Mac 上生成並設定 iOS 平台支援的步驟。

## 前置需求

- macOS + Xcode（最新穩定版）
- Flutter SDK（>=3.4.0）
- CocoaPods（`gem install cocoapods`）
- Apple Developer 帳號

## 步驟

### 1. Clone repo

```bash
git clone <repo-url>
cd smartcard
git checkout ios/initial-setup
```

### 2. 生成 ios/ 資料夾

```bash
flutter create .
```

這會在專案根目錄下生成 `ios/` 資料夾及所有必要的 Xcode 專案檔案。

### 3. 修改 Info.plist

編輯 `ios/Runner/Info.plist`，在 `<dict>` 內加入定位權限描述：

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>SmartCard 需要您的位置來自動偵測附近門市並顯示對應的會員卡。</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>SmartCard 需要背景定位來在您進入門市範圍時自動更新 Widget 上的會員卡。</string>
```

### 4. 設定 Bundle ID

編輯 `ios/Runner.xcodeproj/project.pbxproj`，將 `PRODUCT_BUNDLE_IDENTIFIER` 改為：

```
com.ddouwill.smartcard
```

或在 Xcode 中開啟專案，選擇 Runner target → General → Bundle Identifier 修改。

### 5. 設定 Signing & Capabilities

在 Xcode 中：

1. 選擇 Runner target → Signing & Capabilities
2. 選擇你的 Team（Apple Developer 帳號）
3. 確認 Automatically manage signing 已勾選
4. 確認 Bundle Identifier 為 `com.ddouwill.smartcard`

### 6. 安裝 CocoaPods 依賴

```bash
cd ios
pod install
cd ..
```

### 7. Widget 支援（如需要）

若要支援桌面 Widget：

1. 在 Xcode 中 File → New → Target
2. 選擇 Widget Extension
3. 命名為 `SmartCardWidget`
4. 設定 Widget 的 Bundle ID 為 `com.ddouwill.smartcard.widget`
5. 確保 App Group 設定一致，以便主 App 與 Widget 共享資料

### 8. Geofence 支援（如需要）

若要支援背景 Geofence：

1. 在 Xcode 中選擇 Runner target → Signing & Capabilities
2. 點擊 + Capability
3. 新增 **Background Modes**，勾選：
   - Location updates
4. 確認 Info.plist 中已包含 `NSLocationAlwaysAndWhenInUseUsageDescription`

### 9. 首次 Build

```bash
# 開發測試
flutter run -d <ios-device-id>

# 正式打包（IPA）
flutter build ipa --release
```

打包完成後，IPA 檔案位於 `build/ios/ipa/` 目錄下。

## 注意事項

- `GoogleService-Info.plist` 需要從 Firebase Console 下載並放入 `ios/Runner/`
- 此檔案已加入 `.gitignore`，不會被 commit
- iOS 最低部署版本建議設為 iOS 15.0
