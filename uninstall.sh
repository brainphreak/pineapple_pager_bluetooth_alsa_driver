#!/bin/sh
# BlueALSA uninstaller for WiFi Pineapple Pager
# Removes all files installed by install.sh

echo "=== BlueALSA Uninstaller ==="
echo ""

# Stop running processes
if pidof bluealsad >/dev/null 2>&1; then
    echo "Stopping bluealsad..."
    kill $(pidof bluealsad) 2>/dev/null
    sleep 1
fi

# Remove binaries
echo "[1/4] Removing binaries..."
rm -f /mmc/usr/bin/bluealsad

echo "[2/4] Removing ALSA plugins..."
rm -f /mmc/usr/lib/alsa-lib/libasound_module_pcm_bluealsa.so
rm -f /mmc/usr/lib/alsa-lib/libasound_module_ctl_bluealsa.so
rmdir /mmc/usr/lib/alsa-lib 2>/dev/null

echo "[3/4] Removing configs..."
rm -f /etc/dbus-1/system.d/bluealsa.conf
rm -f /etc/asound.conf

echo "[4/4] Removing symlinks..."
# Only remove if they point to /mmc/
if [ -L /usr/lib/alsa-lib ] && readlink /usr/lib/alsa-lib | grep -q mmc; then
    rm -f /usr/lib/alsa-lib
fi
for lib in libasound.so.2 libsbc.so.1 libatopology.so.2; do
    if [ -L "/usr/lib/$lib" ] && readlink "/usr/lib/$lib" | grep -q mmc; then
        rm -f "/usr/lib/$lib"
        echo "  Removed $lib symlink"
    fi
done
if [ -L /usr/share/alsa/alsa.conf ] && readlink /usr/share/alsa/alsa.conf | grep -q mmc; then
    rm -f /usr/share/alsa/alsa.conf
fi

echo ""
echo "=== Uninstall complete ==="
echo "System restored to pre-install state."
