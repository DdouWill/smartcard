/// 編譯時決定是否啟用 debug log
/// Debug build: true, Release build: false
/// 使用方式：flutter run --dart-define=ENABLE_DEBUG_LOG=true
const bool kEnableDebugLog =
    bool.fromEnvironment('ENABLE_DEBUG_LOG', defaultValue: false);
