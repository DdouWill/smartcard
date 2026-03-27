# iOS TestFlight 測試打包準備清單

## 一、Apple 帳號

### 1. Apple Developer Program（必要）
- 費用：USD $99 / 年
- 註冊：https://developer.apple.com/programs/enroll/
- 需要 Apple ID（建議用 aki.terminal.leaf@gmail.com 或專用帳號）
- 驗證：需要信用卡 + 手機驗證
- 審核時間：通常 24-48 小時

### 2. Apple ID 雙重認證
- 必須啟用才能用於 Developer Program
- 設定：Apple ID → 登入與安全性 → 雙重認證

---

## 二、憑證與描述檔

### 3. 開發者憑證（Distribution Certificate）
- 類型：**Apple Distribution**（用於 TestFlight + App Store）
- 建立方式：
  - Xcode → Settings → Accounts → Manage Certificates → + Apple Distribution
  - 或在 Apple Developer Portal → Certificates → +
- 每個帳號最多 3 個 Distribution Certificate
- 有效期：1 年

### 4. App ID（Bundle Identifier）
- 在 Apple Developer Portal → Identifiers → + 
- Bundle ID 建議：`com.ddouwill.smartcard`（跟 Android 一致）
- 勾選需要的 Capabilities（目前：Location Updates）

### 5. Provisioning Profile
- 類型：**App Store Distribution**（涵蓋 TestFlight）
- 在 Apple Developer Portal → Profiles → +
- 選擇 App Store → 選擇 App ID → 選擇 Certificate → 下載

---

## 三、Flutter 專案設定

### 6. iOS 專案基本設定
```
ios/Runner.xcodeproj → Build Settings:
- Bundle Identifier: com.ddouwill.smartcard
- Display Name: SmartCard
- Deployment Target: iOS 14.0（建議最低）
- Signing: 選擇 Team + Automatic Signing 或手動指定 Profile
```

### 7. Info.plist 權限宣告
```xml
<!-- 定位（前景） -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>需要您的位置來匹配附近的門市</string>

<!-- 定位（背景，如果需要） -->
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>需要背景定位來更新 Widget 顯示的門市卡片</string>
```

### 8. Podfile 確認
```bash
cd ios && pod install
```
確認所有 Flutter plugin 的 iOS 依賴正確安裝。

---

## 四、打包流程

### 9. 本地打包（Xcode）
```bash
# 1. 清理 + 取得依賴
flutter clean
flutter pub get
cd ios && pod install && cd ..

# 2. Build iOS release
flutter build ipa --release

# 3. 產出位置
# build/ios/ipa/smartcard.ipa
```

### 10. 上傳到 TestFlight
**方式 A：Xcode**
- Xcode → Product → Archive → Distribute App → App Store Connect → Upload

**方式 B：命令列**
```bash
xcrun altool --upload-app -f build/ios/ipa/smartcard.ipa \
  -t ios \
  -u "apple-id@email.com" \
  -p "app-specific-password"
```

**方式 C：Codemagic CI/CD**
- 設定 Codemagic workflow → 自動 build + 上傳 TestFlight
- 需要上傳 Certificate (.p12) + Provisioning Profile 到 Codemagic

---

## 五、TestFlight 設定

### 11. App Store Connect
- https://appstoreconnect.apple.com/
- 建立新 App → 選擇 Bundle ID → 填寫基本資訊
- 不需要完成 App Store 審核就能用 TestFlight

### 12. 內部測試（Internal Testing）
- 最多 100 人
- 不需要 Apple 審核
- 受邀者需要有 Apple ID + 安裝 TestFlight app
- 上傳後幾分鐘就能測試

### 13. 外部測試（External Testing）
- 最多 10,000 人
- 需要 Apple Beta App Review（通常 24-48 小時）
- 可以用公開連結邀請

---

## 六、iOS 特有注意事項

### 14. Widget（WidgetKit）
- iOS Widget 用 WidgetKit（Swift/SwiftUI），不能直接複用 Android 的 RemoteViews
- 需要新建 Widget Extension target
- Flutter 的 `home_widget` plugin 有基本的 iOS 支援

### 15. Geofence
- iOS 的 geofence 用 `CLLocationManager.startMonitoring(for:)`
- 限制：每個 app 最多 20 個 region（Android 是 100 個）
- 需要 `Always` 定位權限

### 16. 無 Google Play Services
- iOS 沒有 Firebase Crashlytics 的 Gradle plugin → 用 `firebase_crashlytics` Flutter plugin 即可
- Google Maps API 在 iOS 上也可用，但需要額外的 API key

---

## 七、費用總覽

| 項目 | 費用 |
|------|------|
| Apple Developer Program | $99 USD / 年 |
| Codemagic（免費方案） | $0（500 build min / 月） |
| Codemagic（付費） | $49 USD / 月起 |
| TestFlight | 免費 |

---

## 八、時程預估

| 步驟 | 時間 |
|------|------|
| Apple Developer 帳號審核 | 1-2 天 |
| 憑證 + Profile 設定 | 30 分鐘 |
| Flutter iOS 專案設定 | 1-2 小時 |
| 首次 build + 上傳 | 1-2 小時 |
| 內部 TestFlight 測試 | 上傳後即可 |
| 外部 TestFlight 審核 | 1-2 天 |

---

## 九、前置條件確認清單

- [ ] Apple Developer Program 帳號已建立
- [ ] Apple ID 雙重認證已啟用
- [ ] Distribution Certificate 已建立
- [ ] App ID (com.ddouwill.smartcard) 已註冊
- [ ] Provisioning Profile 已建立並下載
- [ ] Mac 設備可用（Xcode 只能在 macOS 上跑）
- [ ] Xcode 已安裝最新版
- [ ] `flutter build ipa` 在本地可以成功
- [ ] App Store Connect 已建立 App
- [ ] TestFlight 內部測試群組已設定
