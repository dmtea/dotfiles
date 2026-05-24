# Bluetooth A2DP: Headphones Connect in Headset Mode

**Status**: Open
**Date**: 2026-05-21
**Devices**: Headphones `<HEADPHONES_MAC>`, Mouse `<MOUSE_MAC>`

## Problem

When connecting Bluetooth headphones via `bt-toggle.sh`, they sometimes default to HFP/HSP (headset) profile instead of A2DP (high-quality audio). Requires manual disconnect/reconnect to fix.

Root cause: WirePlumber auto-switches to HFP/HSP when it detects an audio input stream. This is a known bug — WirePlumber issue #634, #645, #630, #629, #613.

## Solution Options

### Option A: WirePlumber Config (recommended — permanent fix)

Disable HFP/HSP auto-switching globally. Headphones always connect in A2DP.

**File**: `~/.config/wireplumber/wireplumber.conf.d/51-disable-bt-autoswitch.conf`

```conf
wireplumber.settings = {
  bluetooth.autoswitch-to-headset-profile = false
}

monitor.bluez.properties = {
  bluez5.roles = [ a2dp_sink a2dp_source ]
}
```

**Pros**: Set-and-forget. Works for all Bluetooth audio devices.
**Cons**: Headset microphone won't work (no HFP/HSP). If you need the mic for calls, this is a problem.
**Apply**: `systemctl --user restart wireplumber`

### Option B: In-Script Profile Switch (fallback)

After `bluetoothctl connect`, force A2DP profile via `pactl`:

```bash
MAC_NORM=$(echo "$device_address" | tr ':' '_')
sleep 2
pactl set-card-profile "bluez_card.${MAC_NORM}" a2dp_sink
```

**Pros**: Per-device control. Can keep HFP available for other use cases.
**Cons**: May fail if A2DP profile is not exposed yet (BlueZ bug). Needs `sleep` for race conditions.

### Option C: WirePlumber Rule + In-Script Recovery

Combine A + B:
1. WirePlumber rule disables auto-switch (prevents the problem in 99% of cases)
2. Script detects if profile is wrong and attempts `pactl` fix
3. If `pactl` fails → restart bluetooth → reconnect → retry

## Script Structure Decision

Current script handles both headphones and mouse with the same logic. Options:

1. **Keep unified script** — detect device type by checking if `bluez_card.$MAC` exists after connect (audio devices create a card, mice don't), then apply A2DP logic only for audio devices.
2. **Separate scripts** — `bt-headphones.sh` (with A2DP logic) and `bt-mouse.sh` (simple toggle). Simpler but more files.

Recommendation: **Separate scripts**. Mouse doesn't need any audio logic. Cleaner separation.

## Relevant Commands

```bash
# Check current profile
pactl list cards | grep -A 20 "bluez_card"

# List available profiles for a device
pactl list cards | grep -A 30 "bluez_card.<HEADPHONES_MAC_NORM>"

# Force A2DP
pactl set-card-profile bluez_card.<HEADPHONES_MAC_NORM> a2dp_sink

# WirePlumber: disable auto-switch
wpctl settings --save bluetooth.autoswitch-to-headset-profile false

# Restart audio services
systemctl --user restart wireplumber pipewire
```

## Sources

- WirePlumber Bluetooth docs: https://julian.pages.freedesktop.org/wireplumber/daemon/configuration/bluetooth.html
- ArchWiki Bluetooth Headset: https://wiki.archlinux.org/title/Bluetooth_headset
- PipeWire docs: https://docs.pipewire.org/page_man_pipewire-props_7.html
- Omarchy PR #5336 (A2DP auto-connect rule): https://github.com/basecamp/omarchy/pull/5336
