# Linux Link & Quick Share: Complete Linux & Android Continuity Guide

A comprehensive, production-grade tutorial and setup toolkit for seamless continuity, high-speed file sharing, clipboard synchronization, notification mirroring, and peripheral sharing between **Linux (Ubuntu / GNOME / Wayland)** and **Android (including Samsung One UI, Android 14, 15, and 16)**.

---

## 📑 Table of Contents
1. [Overview & Feature Matrix](#overview--feature-matrix)
2. [When to Use What?](#when-to-use-what)
3. [Part 1: Quick Share (Packet) on Linux](#part-1-quick-share-packet-on-linux)
4. [Part 2: Linux Link Full Continuity Setup](#part-2-linux-link-full-continuity-setup)
5. [Part 3: Solving the Android 14+ FGS Crash](#part-3-solving-the-android-14-fgs-crash)
6. [Part 4: Nautilus File Manager (Right-Click) Integration](#part-4-nautilus-file-manager-right-click-integration)
7. [Automated Scripts](#automated-scripts)
8. [Troubleshooting & FAQs](#troubleshooting--faqs)

---

## Overview & Feature Matrix

| Feature | Quick Share ([Packet](https://github.com/nozwock/packet)) | [Linux Link](https://github.com/ArvinKavaskov/linux-link) |
| :--- | :---: | :---: |
| **Protocol** | Google Nearby Share / Quick Share | QUIC (TLS 1.3) + BLE + mDNS |
| **Phone App Required?** | ❌ None (Native to Android) |  Linux Link APK |
| **Direct Wi-Fi / Hotspot Sharing** |  High-speed peer-to-peer |  LAN / Wi-Fi peer-to-peer |
| **Bidirectional Clipboard Sync** | ❌ No |  Real-time / event-driven |
| **Notification Mirroring & Quick Reply** | ❌ No |  Native desktop notifications |
| **Media Playback & Volume Control** | ❌ No |  MPRIS integration |
| **Use Phone as PC Mic / Speaker** | ❌ No |  PulseAudio / PipeWire |
| **Use Phone as Second Monitor** | ❌ No |  Ultra low-latency H.264 stream |
| **Proximity Lock** | ❌ No |  BLE RSSI auto-lock |
| **Ad-hoc Guest Transfers** |  Send to any nearby Android phone | ❌ Requires pairing |

---

## When to Use What?
- **Use Quick Share (Packet)** when you simply want to beam files, photos, or videos to/from any Android device without installing special apps on the phone. It acts just like AirDrop.
- **Use Linux Link** when you want an integrated ecosystem experience: shared clipboard, replying to WhatsApp/SMS from your desktop, controlling PC music from your phone, and sending files right-click from Nautilus.

---

## Part 1: Quick Share (Packet) on Linux

### 1. Installation
Packet is a modern Rust GTK4 client for Google's Quick Share protocol:

```bash
# Install Flatpak if needed
sudo apt install -y flatpak

# Install Packet from Flathub
flatpak install -y flathub io.github.nozwock.Packet
```

*Or compile from source:*
```bash
git clone https://github.com/nozwock/packet.git
cd packet
cargo build --release
sudo cp target/release/packet /usr/local/bin/
```

### 2. Firewall Requirements
Quick Share relies on mDNS and local TCP/UDP ports:
```bash
sudo ufw allow 5353/udp comment 'mDNS discovery'
sudo ufw allow from 192.168.1.0/24 to any port 5353 proto udp
```

---

## Part 2: Linux Link Full Continuity Setup

### 1. Build & Runtime Dependencies (Ubuntu 24.04 / 26.04)
Install the system development headers, graphics libraries, and audio tools:

```bash
sudo apt update
sudo apt install -y \
    build-essential clang pkg-config libssl-dev libdbus-1-dev \
    libbluetooth-dev libx11-dev libxext-dev libxrandr-dev \
    libxcursor-dev libxi-dev libxinerama-dev libgl1-mesa-dev \
    playerctl wl-clipboard pulseaudio-utils \
    gstreamer1.0-tools gstreamer1.0-plugins-ugly gstreamer1.0-pipewire \
    python3-nautilus
```

### 2. Install Rust
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
source "$HOME/.cargo/env"
```

### 3. Clone & Compile Linux Link
```bash
git clone https://github.com/ArvinKavaskov/linux-link.git ~/linux-link
cd ~/linux-link

# Build all release binaries
cargo build --release --manifest-path linkd/Cargo.toml \
    --bin linkd --bin linux-link-gui --bin linux-link-pair \
    --bin linux-link-settings --bin linux-link-message

# Install binaries to ~/.local/bin
mkdir -p ~/.local/bin
install -m755 linkd/target/release/linkd ~/.local/bin/
install -m755 linkd/target/release/linux-link-gui ~/.local/bin/
install -m755 linkd/target/release/linux-link-pair ~/.local/bin/
install -m755 linkd/target/release/linux-link-settings ~/.local/bin/
install -m755 linkd/target/release/linux-link-message ~/.local/bin/
```

### 4. Background Systemd Services
Create persistent systemd user units so the daemon and tray indicator start automatically upon login and restart on failures:

**`~/.config/systemd/user/linkd.service`**:
```ini
[Unit]
Description=Linux Link daemon (Linux <-> Android continuity)
After=network-online.target bluetooth.target graphical-session.target
PartOf=graphical-session.target

[Service]
ExecStart=%h/.local/bin/linkd run
Restart=always
RestartSec=2
Environment=RUST_LOG=info
Nice=5
IOSchedulingClass=idle

[Install]
WantedBy=graphical-session.target
```

**`~/.config/systemd/user/linux-link-gui.service`**:
```ini
[Unit]
Description=Linux Link Tray Icon
After=graphical-session.target linkd.service
PartOf=graphical-session.target

[Service]
ExecStart=%h/.local/bin/linux-link-gui
Restart=always
RestartSec=3

[Install]
WantedBy=graphical-session.target
```

Enable and start them:
```bash
systemctl --user daemon-reload
systemctl --user enable --now linkd.service
systemctl --user enable --now linux-link-gui.service
```

### 5. Firewall Configuration
Linux Link operates via QUIC (TLS 1.3) over UDP:
```bash
sudo ufw allow 47100/udp comment 'Linux Link QUIC'
sudo ufw allow 47101/udp comment 'Linux Link Discovery'
```

---

## Part 3: Solving the Android 14+ FGS Crash

### The Problem
When running the Linux Link Android APK on Android 14, 15, or 16 (Samsung One UI 6 / 7 / 8), the app **crashes repeatedly** with:
```
java.lang.SecurityException: Starting FGS with type connectedDevice 
callerApp=ProcessRecord{... org.linuxlink.app} targetSDK=35 
requires permissions: [android.permission.BLUETOOTH_CONNECT, ...]
```
Because the app targets API 35 with a `connectedDevice` Foreground Service, Android kills the process if "Nearby Devices" (Bluetooth) runtime permission has not been granted.

### The Fix (via ADB)
Connect your phone with USB Debugging enabled and run:

```bash
# 1. Grant Nearby Devices / Bluetooth (fixes the FGS crash)
adb shell pm grant org.linuxlink.app android.permission.BLUETOOTH_CONNECT
adb shell pm grant org.linuxlink.app android.permission.BLUETOOTH_SCAN

# 2. Grant Notifications & Audio
adb shell pm grant org.linuxlink.app android.permission.POST_NOTIFICATIONS
adb shell pm grant org.linuxlink.app android.permission.RECORD_AUDIO

# 3. Allow All Files & Overlay Access
adb shell appops set org.linuxlink.app MANAGE_EXTERNAL_STORAGE allow
adb shell appops set org.linuxlink.app SYSTEM_ALERT_WINDOW allow

# 4. Whitelist from Samsung Battery Sleeping Restrictions
adb shell dumpsys deviceidle whitelist +org.linuxlink.app

# 5. Enable Notification Mirroring Service
CURR=$(adb shell settings get secure enabled_notification_listeners)
adb shell settings put secure enabled_notification_listeners "${CURR}:org.linuxlink.app/org.linuxlink.app.NotificationRelayService"
```

*Or simply run the automated script:*
```bash
chmod +x scripts/fix-android-permissions.sh
./scripts/fix-android-permissions.sh
```

---

## Part 4: Nautilus File Manager (Right-Click) Integration

To enable a top-level **"Send to phone"** entry directly when right-clicking files in GNOME Files (Nautilus):

1. **Install python3-nautilus**:
   ```bash
   sudo apt install -y python3-nautilus
   ```

2. **Install the Extension**:
   ```bash
   mkdir -p ~/.local/share/nautilus-python/extensions
   cp ~/linux-link/linkd/desktop/send_to_phone.py ~/.local/share/nautilus-python/extensions/
   ```

3. **Install the Scripts Fallback**:
   ```bash
   mkdir -p ~/.local/share/nautilus/scripts
   cp ~/linux-link/linkd/desktop/Send\ to\ phone ~/.local/share/nautilus/scripts/
   chmod +x ~/.local/share/nautilus/scripts/Send\ to\ phone
   ```

4. **Restart Nautilus**:
   ```bash
   nautilus -q
   ```

---

## Automated Scripts

This repository includes turnkey shell scripts:
- **`scripts/setup-linuxlink-pc.sh`**: One-click dependency installation, compilation, systemd service configuration, and firewall rules on PC.
- **`scripts/fix-android-permissions.sh`**: Automatic ADB permission granter and One UI battery optimizer.
- **`scripts/setup-nautilus-extensions.sh`**: Installs right-click menu items in Nautilus for both Linux Link and Quick Share.

---

## Troubleshooting & FAQs

### Q: Why does `linkd doctor` report missing dependencies?
Run:
```bash
linkd doctor
```
This built-in diagnostic utility checks binaries, Bluetooth state, audio players (`pw-cat`), and firewall rules, printing exact remediation commands for any failing component.

### Q: The pairing window timed out. How do I reopen it?
Run:
```bash
linux-link-pair
```
Or click the tray indicator icon in your GNOME top bar and select **"Pair a device…"**.

### Q: Does clipboard sync work without Shizuku?
Yes! With `SYSTEM_ALERT_WINDOW` permitted, Linux Link uses an invisible overlay. For completely background operation on newer Android versions, connecting [Shizuku](https://shizuku.rikka.app/) provides 100% reliable clipboard access.

---

## License
MIT License. Feel free to use, modify, and distribute.
