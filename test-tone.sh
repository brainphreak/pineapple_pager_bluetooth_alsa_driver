#!/bin/sh
# Generate and play a dual-tone test sound on the Pager
# Uses Python to create a WAV with two simultaneous frequencies

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TONE_FILE="/tmp/bt-test-tone.wav"

# Use bundled aplay if available, otherwise system aplay
if [ -x "$SCRIPT_DIR/bin/aplay" ]; then
    APLAY="$SCRIPT_DIR/bin/aplay"
elif command -v aplay >/dev/null 2>&1; then
    APLAY="aplay"
else
    echo "ERROR: aplay not found (check bin/ folder)"
    exit 1
fi

# Generate a 2-second dual-tone WAV (440Hz + 554Hz = A major third)
python3 -c "
import struct, math

sample_rate = 44100
duration = 2
freq1 = 440    # A4
freq2 = 554    # C#5
volume = 0.4

num_samples = sample_rate * duration
samples = []
for i in range(num_samples):
    t = i / sample_rate
    val = volume * (math.sin(2 * math.pi * freq1 * t) + math.sin(2 * math.pi * freq2 * t)) / 2
    samples.append(int(val * 32767))

# Write WAV file
data = struct.pack('<' + 'h' * len(samples), *samples)
with open('$TONE_FILE', 'wb') as f:
    f.write(b'RIFF')
    f.write(struct.pack('<I', 36 + len(data)))
    f.write(b'WAVE')
    f.write(b'fmt ')
    f.write(struct.pack('<IHHIIHH', 16, 1, 1, sample_rate, sample_rate * 2, 2, 16))
    f.write(b'data')
    f.write(struct.pack('<I', len(data)))
    f.write(data)

print('Generated: $TONE_FILE')
" 2>/dev/null

if [ -f "$TONE_FILE" ]; then
    echo "Playing dual-tone (440Hz + 554Hz) for 2 seconds..."
    $APLAY -D bluealsa "$TONE_FILE" 2>&1
    rm -f "$TONE_FILE"
else
    echo "ERROR: Could not generate test tone (needs python3)"
fi
