#!/bin/sh
# BlueALSA installer for WiFi Pineapple Pager
# Requires: external USB Bluetooth dongle (CSR8510, RTL8761B, etc.)
# The built-in MT7961 Bluetooth has a broken ACL data path and cannot stream audio.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== BlueALSA Installer for WiFi Pineapple Pager ==="
echo ""

# Check architecture
ARCH=$(uname -m 2>/dev/null || echo "unknown")
if [ "$ARCH" != "mips" ] && ! grep -q "mipsel" /etc/openwrt_release 2>/dev/null; then
    echo "WARNING: This device may not be a WiFi Pineapple Pager"
    echo "These binaries are compiled for mipsel_24kc (OpenWrt 24.10.1)"
    echo ""
fi

# Install binaries
echo "[1/5] Installing bluealsad..."
mkdir -p /mmc/usr/bin
cp "$SCRIPT_DIR/bin/bluealsad" /mmc/usr/bin/bluealsad
chmod +x /mmc/usr/bin/bluealsad

echo "[2/5] Installing ALSA plugins..."
mkdir -p /mmc/usr/lib/alsa-lib
cp "$SCRIPT_DIR/lib/libasound_module_pcm_bluealsa.so" /mmc/usr/lib/alsa-lib/
cp "$SCRIPT_DIR/lib/libasound_module_ctl_bluealsa.so" /mmc/usr/lib/alsa-lib/

echo "[3/5] Installing configs..."
cp "$SCRIPT_DIR/config/bluealsa-dbus.conf" /etc/dbus-1/system.d/bluealsa.conf
cp "$SCRIPT_DIR/config/asound.conf" /etc/asound.conf

echo "[4/5] Creating library symlinks..."
# ALSA plugins directory
ln -sf /mmc/usr/lib/alsa-lib /usr/lib/alsa-lib 2>/dev/null

# Required library symlinks (if not already present)
for lib in libasound.so.2 libsbc.so.1 libatopology.so.2; do
    if [ ! -e "/usr/lib/$lib" ]; then
        src=$(find /mmc/usr/lib/ -name "$lib*" 2>/dev/null | head -1)
        if [ -n "$src" ]; then
            ln -sf "$src" "/usr/lib/$lib"
            echo "  Linked $lib"
        fi
    fi
done

# ALSA config
if [ ! -e "/usr/share/alsa/alsa.conf" ]; then
    mkdir -p /usr/share/alsa
    if [ -f "/mmc/usr/share/alsa/alsa.conf" ]; then
        ln -sf /mmc/usr/share/alsa/alsa.conf /usr/share/alsa/alsa.conf
        echo "  Linked alsa.conf"
    fi
fi

echo "[5/5] Verifying installation..."
if [ -x /mmc/usr/bin/bluealsad ]; then
    echo ""
    echo "=== Installation complete! ==="
    echo ""
    echo "To use:"
    echo "  1. Plug in a USB Bluetooth dongle"
    echo "  2. Run: hciconfig hci0 up  (or hci1 if built-in BT is active)"
    echo "  3. Run: bluetoothctl pairable on"
    echo "  4. Run: /mmc/usr/bin/bluealsad -p a2dp-source -p a2dp-sink -S &"
    echo "  5. Pair your speaker: bluetoothctl scan on / pair XX:XX:XX:XX:XX:XX"
    echo "  6. Connect: bluetoothctl connect XX:XX:XX:XX:XX:XX"
    echo "  7. Play audio: aplay -D bluealsa test.wav"
    echo ""
    echo "NOTE: The built-in MT7961 Bluetooth CANNOT stream audio."
    echo "      You MUST use an external USB Bluetooth dongle."
else
    echo "ERROR: Installation failed"
    exit 1
fi
