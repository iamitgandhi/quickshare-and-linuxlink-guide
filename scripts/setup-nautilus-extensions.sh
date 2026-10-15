#!/usr/bin/env bash
# ==============================================================================
# Nautilus Context Menu Integration for Quick Share & Linux Link
# ==============================================================================

set -euo pipefail

EXT_DIR="$HOME/.local/share/nautilus-python/extensions"
SCRIPT_DIR="$HOME/.local/share/nautilus/scripts"

mkdir -p "$EXT_DIR" "$SCRIPT_DIR"

echo "==> Setting up Nautilus Python Extensions..."

# Linux Link top-level extension
if [ -f "$HOME/linux-link/linkd/desktop/send_to_phone.py" ]; then
    cp "$HOME/linux-link/linkd/desktop/send_to_phone.py" "$EXT_DIR/send_to_phone.py"
    echo "[+] Installed Linux Link extension: $EXT_DIR/send_to_phone.py"
fi

# Linux Link script fallback
if [ -f "$HOME/linux-link/linkd/desktop/Send to phone" ]; then
    cp "$HOME/linux-link/linkd/desktop/Send to phone" "$SCRIPT_DIR/Send to phone"
    chmod +x "$SCRIPT_DIR/Send to phone"
    echo "[+] Installed Linux Link script: $SCRIPT_DIR/Send to phone"
fi

# Packet (Quick Share) script
cat > "$SCRIPT_DIR/Send via Quick Share" <<'EOF'
#!/usr/bin/env bash
# Send selected files via Packet Quick Share
packet "$@"
EOF
chmod +x "$SCRIPT_DIR/Send via Quick Share"
echo "[+] Installed Quick Share script: $SCRIPT_DIR/Send via Quick Share"

echo "==> Restarting Nautilus to apply changes..."
nautilus -q || true

echo "[✔] Nautilus integration ready! Right-click any file to test."
