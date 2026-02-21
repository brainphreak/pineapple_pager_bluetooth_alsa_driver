#!/bin/sh
# Play an MP3 file over Bluetooth A2DP using BlueALSA
# Wraps mp3decode (PCM decoder) + aplay (ALSA output)
#
# Usage: sh play-mp3.sh <file.mp3>
#        sh play-mp3.sh /mmc/music/*.mp3

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export LD_LIBRARY_PATH="$SCRIPT_DIR/lib:${LD_LIBRARY_PATH:-/usr/lib}"
export ALSA_PLUGIN_DIR="$SCRIPT_DIR/lib"
export ALSA_CONFIG_PATH="$SCRIPT_DIR/config/asound.conf"
export PATH="$SCRIPT_DIR/bin:$PATH"

if [ $# -eq 0 ]; then
    echo "Usage: $0 <file.mp3> [file2.mp3 ...]"
    exit 1
fi

# Check that bluealsad is running
if ! pidof bluealsad >/dev/null 2>&1; then
    echo "ERROR: bluealsad is not running. Run bt-pair.sh first."
    exit 1
fi

for FILE in "$@"; do
    if [ ! -f "$FILE" ]; then
        echo "SKIP: $FILE not found"
        continue
    fi

    BASENAME=$(basename "$FILE")
    echo "Playing: $BASENAME"

    # Decode MP3 and capture format info from stderr
    # mp3decode prints "INFO: <rate> Hz, <channels> channels" to stderr
    INFO_FILE=$(mktemp)
    "$SCRIPT_DIR/bin/mp3decode" "$FILE" 2>"$INFO_FILE" | \
        "$SCRIPT_DIR/bin/aplay" -D bluealsa -f S16_LE -r 44100 -c 2 - 2>/dev/null

    # Show what was detected
    if [ -f "$INFO_FILE" ]; then
        DETECTED=$(cat "$INFO_FILE")
        [ -n "$DETECTED" ] && echo "  $DETECTED"
        rm -f "$INFO_FILE"
    fi
done
