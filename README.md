# BlueALSA for WiFi Pineapple Pager

Pre-compiled Bluetooth A2DP audio for the Hak5 WiFi Pineapple Pager (mipsel_24kc, OpenWrt 24.10.1).

**IMPORTANT:** The built-in MT7961 Bluetooth adapter has a broken ACL data path and **cannot stream audio**. You need an external USB Bluetooth dongle.

## Requirements

- WiFi Pineapple Pager
- **External USB Bluetooth dongle** (CSR8510, RTL8761B, or similar)
- Bluetooth speaker/headphones
- Python3 (optional, for test tone generation)

## Recommended Dongles

- **CSR8510** (~$3-5) — BT 4.0, plug-and-play, no firmware needed
- **RTL8761B** (~$5-8) — BT 5.0, firmware included in this bundle

Both are available as tiny USB nubs that barely protrude from the port.

## Quick Start

```bash
# 1. Copy this folder to the Pager
scp -r bt-audio-pager root@172.16.52.1:/root/

# 2. SSH in
ssh root@172.16.52.1
cd /root/bt-audio-pager

# 3. Plug in your USB BT dongle, put speaker in pairing mode, then:
sh bt-pair.sh

# Or pair a specific device directly:
sh bt-pair.sh 60:AB:D2:CF:1A:23
```

The script is **self-contained** — it runs entirely from this folder using local libraries. The only temporary system change is a D-Bus config file which is removed when the script exits.

The pairing script will:
- Find your USB dongle automatically (skips the broken built-in adapter)
- Explicitly select the USB dongle (not the broken built-in MT7961)
- Start bluetoothd and bluealsad in the correct order
- Scan for nearby speakers (BR/EDR classic scan)
- Pair, trust, and connect
- Auto-configure the audio device address
- Play a test tone to confirm audio works
- Clean up on exit (stop bluealsad, remove D-Bus config)

## MP3 Playback

After pairing with `bt-pair.sh`, you can play MP3 files over Bluetooth:

```bash
# Play a single file
sh play-mp3.sh /mmc/music/song.mp3

# Play multiple files
sh play-mp3.sh /mmc/music/*.mp3

# Or use mp3decode directly for custom pipelines
./bin/mp3decode song.mp3 | aplay -D bluealsa -f S16_LE -r 44100 -c 2 -
```

The `mp3decode` binary is a tiny (84KB) static MIPS binary that decodes MP3 to raw PCM. It prints the detected sample rate and channel count to stderr.

## What's Included

```
bt-pair.sh             # Self-contained pairing + audio test
play-mp3.sh            # MP3 playback wrapper (decode + aplay)
test-tone.sh           # Generate and play a dual-tone test
bin/
  bluealsad            # BlueALSA v4.3.1 daemon (255KB, MIPS)
  aplay                # ALSA audio player (66KB, MIPS)
  mp3decode            # MP3-to-PCM decoder (84KB, MIPS, static)
lib/                   # ALSA libraries + BlueALSA plugins
  libasound.so.2.0.0
  libatopology.so.2.0.0
  libsbc.so.1.3.1
  libasound_module_pcm_bluealsa.so
  libasound_module_ctl_bluealsa.so
config/                # ALSA and D-Bus configs
firmware/rtl_bt/       # RTL8761B firmware (auto-installed if needed)
```

## Built With

- BlueALSA v4.3.1
- minimp3 (single-header MP3 decoder)
- Cross-compiled for mipsel_24kc using OpenWrt SDK
- Targets: BlueZ 5.72, ALSA 1.2.11, SBC 2.0, D-Bus 1.14, GLib 2.78

## Why Not the Built-In Bluetooth?

The Pager's MT7961 combo WiFi+BT chip has a broken USB bulk IN endpoint for ACL data. Pairing works (uses HCI commands) but any profile requiring data transfer (A2DP, PAN, etc.) fails because the controller never delivers received packets to the host. Firmware updates don't help — it's a driver/platform issue with btmtk on MIPS.
