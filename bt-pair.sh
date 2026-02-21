#!/bin/sh
# BlueALSA Bluetooth pairing and audio test for WiFi Pineapple Pager
# Self-contained — runs entirely from this folder, no system modifications
# Only temporary D-Bus config is placed (removed on exit)
#
# Usage: sh bt-pair.sh [speaker MAC]
# If no MAC given, scans and lets you pick a device

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MAC="$1"
DBUS_CONF="/etc/dbus-1/system.d/bluealsa.conf"
DBUS_INSTALLED=0

# --- Cleanup on exit ---
cleanup() {
    echo ""
    echo "Cleaning up..."
    if [ -n "$BLUEALSAD_PID" ] && kill -0 "$BLUEALSAD_PID" 2>/dev/null; then
        kill "$BLUEALSAD_PID" 2>/dev/null
        echo "  Stopped bluealsad"
    fi
    if [ "$DBUS_INSTALLED" = "1" ]; then
        rm -f "$DBUS_CONF"
        echo "  Removed D-Bus config"
    fi
    echo "Done."
}
trap cleanup EXIT INT TERM

# --- Set up library paths (no system install needed) ---
export LD_LIBRARY_PATH="$SCRIPT_DIR/lib:${LD_LIBRARY_PATH:-/usr/lib}"
export ALSA_PLUGIN_DIR="$SCRIPT_DIR/lib"
export ALSA_CONFIG_PATH="$SCRIPT_DIR/config/asound.conf"
export PATH="$SCRIPT_DIR/bin:$PATH"

# --- Install RTL8761B firmware if bundled and not already present ---
if [ -d "$SCRIPT_DIR/firmware/rtl_bt" ] && [ ! -f /lib/firmware/rtl_bt/rtl8761b_fw.bin ]; then
    echo "Installing RTL8761B Bluetooth firmware..."
    mkdir -p /lib/firmware/rtl_bt
    cp "$SCRIPT_DIR/firmware/rtl_bt/"*.bin /lib/firmware/rtl_bt/ 2>/dev/null
fi

# --- Find USB Bluetooth adapter (skip built-in MT7961) ---
HCI=""
ADAPTER_MAC=""
for h in hci1 hci0; do
    if hciconfig "$h" 2>/dev/null | grep -q "Bus: USB"; then
        # Get the BD address of this adapter
        ADDR=$(hciconfig "$h" 2>/dev/null | grep "BD Address" | awk '{print $3}')
        HCI="$h"
        ADAPTER_MAC="$ADDR"
        break
    fi
done

if [ -z "$HCI" ]; then
    echo "ERROR: No Bluetooth adapter found."
    echo "Plug in a USB Bluetooth dongle and try again."
    exit 1
fi

echo "=== BlueALSA Bluetooth Audio ==="
echo "Using adapter: $HCI ($ADAPTER_MAC)"
hciconfig "$HCI" up 2>/dev/null
hciconfig "$HCI" auth encrypt 2>/dev/null

# --- Install D-Bus config FIRST (required for bluealsad) ---
if [ ! -f "$DBUS_CONF" ]; then
    cp "$SCRIPT_DIR/config/bluealsa-dbus.conf" "$DBUS_CONF"
    DBUS_INSTALLED=1
    # Reload D-Bus to pick up the new config
    if [ -x /etc/init.d/dbus ]; then
        /etc/init.d/dbus restart 2>/dev/null
        sleep 2
    fi
fi

# --- Start bluetoothd (must be running before bluealsad) ---
if pidof bluetoothd >/dev/null 2>&1; then
    # If dbus was restarted, bluetoothd needs restarting too
    if [ "$DBUS_INSTALLED" = "1" ]; then
        killall bluetoothd 2>/dev/null
        sleep 1
    fi
fi
if ! pidof bluetoothd >/dev/null 2>&1; then
    echo "Starting bluetoothd..."
    bluetoothd -n &
    sleep 2
fi
bluetoothctl pairable on 2>/dev/null

# --- Select the USB dongle adapter in bluetoothctl ---
if [ -n "$ADAPTER_MAC" ]; then
    echo "Selecting adapter $ADAPTER_MAC..."
    bluetoothctl select "$ADAPTER_MAC" 2>/dev/null
fi

# --- Start bluealsad BEFORE scanning/pairing (must register A2DP endpoints first) ---
if ! pidof bluealsad >/dev/null 2>&1; then
    echo "Starting bluealsad..."
    "$SCRIPT_DIR/bin/bluealsad" -i "$HCI" -p a2dp-source -p a2dp-sink -S &
    BLUEALSAD_PID=$!
    sleep 3
    if ! kill -0 "$BLUEALSAD_PID" 2>/dev/null; then
        echo "ERROR: bluealsad failed to start"
        echo "Check D-Bus config and libraries in $SCRIPT_DIR/lib/"
        exit 1
    fi
    echo "bluealsad running (PID $BLUEALSAD_PID)"
else
    echo "bluealsad already running"
    BLUEALSAD_PID=$(pidof bluealsad)
fi

# --- Scan and pair ---
if [ -z "$MAC" ]; then
    echo ""
    echo "Scanning for Bluetooth audio devices (15 seconds)..."
    echo "Put your speaker/headphones in pairing mode now!"
    echo ""
    # Use hcitool for BR/EDR classic scan (bluetoothctl defaults to BLE only)
    hcitool -i "$HCI" scan --length=8 2>&1 | grep -v "^Scanning" | while read addr name; do
        [ -n "$addr" ] && echo "  $addr  $name"
    done
    echo ""
    echo "Enter the MAC address of your device (e.g., 60:AB:D2:CF:1A:23):"
    read MAC
fi

if [ -z "$MAC" ]; then
    echo "No MAC address provided. Exiting."
    exit 1
fi

echo ""
echo "=== Pairing with $MAC ==="

# Disconnect first in case device auto-connected to wrong adapter
bluetoothctl disconnect "$MAC" 2>/dev/null
sleep 1
bluetoothctl remove "$MAC" 2>/dev/null
sleep 1

# Re-select adapter (in case remove reset it)
if [ -n "$ADAPTER_MAC" ]; then
    bluetoothctl select "$ADAPTER_MAC" 2>/dev/null
fi

# Scan to discover device in bluetoothctl's cache (BR/EDR)
echo "Discovering device..."
hcitool -i "$HCI" scan --length=5 2>/dev/null &
SCAN_PID=$!
# Also run bluetoothctl scan to populate its device cache
{
    echo "menu scan"
    sleep 0.5
    echo "transport bredr"
    sleep 0.5
    echo "back"
    sleep 0.5
    echo "scan on"
    sleep 8
    echo "scan off"
    sleep 0.5
    echo "quit"
} | bluetoothctl 2>&1 | grep -q "$MAC" || true
kill $SCAN_PID 2>/dev/null
wait $SCAN_PID 2>/dev/null

echo "Pairing..."
bluetoothctl pair "$MAC" 2>&1
sleep 3

echo "Trusting..."
bluetoothctl trust "$MAC" 2>&1
sleep 1

# --- Write paired MAC into asound.conf before connecting ---
echo "Configuring audio for $MAC..."
sed -i "s/device \".*\"/device \"$MAC\"/" "$SCRIPT_DIR/config/asound.conf"

echo "Connecting..."
bluetoothctl connect "$MAC" 2>&1
sleep 5

# --- Check connection and play test tone ---
CONNECTED=$(bluetoothctl info "$MAC" 2>/dev/null | grep "Connected: yes")
if [ -n "$CONNECTED" ]; then
    echo ""
    echo "=== Connected! ==="
    bluetoothctl info "$MAC" 2>/dev/null | grep -E "Name|Connected|Paired|Trusted"
    echo ""
    echo "Playing test tone..."
    sh "$SCRIPT_DIR/test-tone.sh"
else
    echo ""
    echo "Connection failed. Check:"
    echo "  - Is the speaker in pairing mode?"
    echo "  - Is the USB Bluetooth dongle plugged in (not the built-in MT7961)?"
    echo "  - Try running again: sh bt-pair.sh $MAC"
fi

echo ""
echo "Press Enter to stop bluealsad and clean up..."
read _
