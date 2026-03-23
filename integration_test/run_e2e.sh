#!/bin/bash
# SmartCard E2E Test Runner
# 自動授權 → 跑測試 → 清理

PACKAGE="com.example.smartcard"

echo "=== 預授權 ==="
D:\Dev\AndroidSDK\platform-tools\adb shell pm grant $PACKAGE android.permission.ACCESS_FINE_LOCATION
D:\Dev\AndroidSDK\platform-tools\adb shell pm grant $PACKAGE android.permission.ACCESS_COARSE_LOCATION
D:\Dev\AndroidSDK\platform-tools\adb shell pm grant $PACKAGE android.permission.CAMERA
D:\Dev\AndroidSDK\platform-tools\adb shell pm grant $PACKAGE android.permission.POST_NOTIFICATIONS

echo "=== 跑 E2E ==="
flutter test integration_test/app_test.dart -d emulator-5554

echo "=== 完成 ==="
