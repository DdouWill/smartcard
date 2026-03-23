# SmartCard ProGuard 規則
# 防止 R8 混淆時誤刪重要類別

# Flutter 相關（必要）
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Hive（純 Dart 實作，不需 native ProGuard 規則）
# flutter_secure_storage（Android Keystore 相關）
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# ML Kit（Google 服務）
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }

# home_widget
-keep class es.antonborri.home_widget.** { *; }

# Kotlin Coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}

# SmartCard 本體（Widget Provider 由系統反射呼叫）
-keep class com.example.smartcard.SmartCardWidgetProvider { *; }
-keep class com.example.smartcard.MainActivity { *; }
