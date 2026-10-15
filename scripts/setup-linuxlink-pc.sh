#!/usr/bin/env bash
# ==============================================================================
# Linux Link - PC Setup & Installer Script (Ubuntu / Debian)
# ==============================================================================

set -euo pipefail

echo "==> Step 1: Installing build & system dependencies..."
sudo apt update
sudo apt install -y \
    build-essential clang pkg-config libssl-dev libdbus-1-dev \
    libbluetooth-dev libx11-dev libxext-dev libxrandr-dev \
    libxcursor-dev libxi-dev libxinerama-dev libgl1-mesa-dev \
    playerctl wl-clipboard xclip pulseaudio-utils \
    gstreamer1.0-tools gstreamer1.0-plugins-ugly gstreamer1.0-pipewire \
    python3-nautilus

echo "==> Step 2: Checking Rust toolchain..."
if ! command -v cargo >/dev/null 2>&1; then
    echo "[*] Installing Rust via rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
    source "$HOME/.cargo/env"
fi

export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"

echo "==> Step 3: Cloning Linux Link..."
SRC_DIR="$HOME/linux-link"
if [ ! -d "$SRC_DIR" ]; then
    git clone https://github.com/ArvinKavaskov/linux-link.git "$SRC_DIR"
else
    git -C "$SRC_DIR" pull || true
fi

cd "$SRC_DIR"

# Ensure Nautilus 4.1 support in install.sh check if running on Ubuntu 24.04/26.04
sed -i "s/import gi; gi.require_version('Nautilus', '4.0')/import gi; gi.require_version('Nautilus', '4.1')\" >\/dev\/null 2>\&1 || python3 -c \"import gi; gi.require_version('Nautilus', '4.0')/" install.sh || true

# Apply GNOME Wayland clipboard flicker fix patch if needed
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_FILE="$SCRIPT_DIR/../patches/gnome-wayland-clipboard-flicker.patch"
if [ -f "$PATCH_FILE" ]; then
    echo "[*] Applying GNOME Wayland clipboard flicker fix..."
    git apply "$PATCH_FILE" 2>/dev/null || echo "[!] Patch already applied or skipped."
fi

echo "==> Step 4: Running installer..."
./install.sh

echo "==> Step 5: Configuring Systemd User Services..."
mkdir -p "$HOME/.config/systemd/user"
cat > "$HOME/.config/systemd/user/linux-link-gui.service" <<EOF
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
EOF

systemctl --user daemon-reload
systemctl --user enable --now linkd.service
systemctl --user enable --now linux-link-gui.service

echo "==> Step 6: Opening Firewall Ports..."
if command -v ufw >/dev/null 2>&1 && sudo ufw status | grep -q "Status: active"; then
    sudo ufw allow 47100/udp comment 'Linux Link QUIC'
    sudo ufw allow 47101/udp comment 'Linux Link Discovery'
fi

echo ""
echo "[✔] Linux Link PC setup complete!"
echo "    Run 'linux-link-pair' to open the QR code scanner."
