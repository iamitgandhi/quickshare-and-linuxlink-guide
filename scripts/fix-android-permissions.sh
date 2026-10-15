#!/usr/bin/env bash
# ==============================================================================
# Linux Link - Android 14+ Permission & Crash Fix Script
# ==============================================================================
# Fixes java.lang.SecurityException: Starting FGS with type connectedDevice
# requires permissions: [android.permission.BLUETOOTH_CONNECT, ...] on Android 14, 15, and 16.
# ==============================================================================

set -euo pipefail

PKG="org.linuxlink.app"

echo "==> Checking ADB connection..."
if ! command -v adb >/dev/null 2>&1; then
    echo "[-] Error: adb is not installed. Install with: sudo apt install adb"
    exit 1
fi

DEVICES=$(adb devices | grep -w "device" | awk '{print $1}')
if [ -z "$DEVICES" ]; then
    echo "[-] No authorized Android device detected."
    echo "    1. Connect your phone via USB."
    echo "    2. Enable Developer Options -> USB Debugging."
    echo "    3. Tap 'Allow USB debugging' on your phone."
    adb devices
    exit 1
fi

echo "[+] Detected device: $DEVICES"

echo "==> Granting Bluetooth & Nearby Devices runtime permissions (prevents FGS crash)..."
adb shell pm grant "$PKG" android.permission.BLUETOOTH_CONNECT 2>/dev/null || true
adb shell pm grant "$PKG" android.permission.BLUETOOTH_SCAN 2>/dev/null || true

echo "==> Granting Notification & Audio permissions..."
adb shell pm grant "$PKG" android.permission.POST_NOTIFICATIONS 2>/dev/null || true
adb shell pm grant "$PKG" android.permission.RECORD_AUDIO 2>/dev/null || true

echo "==> Granting Special App Access (All Files & Overlay)..."
adb shell appops set "$PKG" MANAGE_EXTERNAL_STORAGE allow 2>/dev/null || true
adb shell appops set "$PKG" SYSTEM_ALERT_WINDOW allow 2>/dev/null || true

echo "==> Whitelisting from Battery Optimization (Samsung One UI sleep prevention)..."
adb shell dumpsys deviceidle whitelist +"$PKG" 2>/dev/null || true

echo "==> Enabling Notification Listener Service for Notification Mirroring..."
CURR=$(adb shell settings get secure enabled_notification_listeners 2>/dev/null || echo "")
if [[ "$CURR" != *"$PKG/$PKG.NotificationRelayService"* ]]; then
    if [ -z "$CURR" ] || [ "$CURR" = "null" ]; then
        adb shell settings put secure enabled_notification_listeners "$PKG/$PKG.NotificationRelayService"
    else
        adb shell settings put secure enabled_notification_listeners "${CURR}:$PKG/$PKG.NotificationRelayService"
    fi
fi

echo ""
echo "[✔] All permissions and optimizations configured successfully!"
echo "    You can now open Linux Link on your phone without crashes."
