#!/usr/bin/env bash
set -euo pipefail

MODULES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(dirname "$MODULES_DIR")"
source "$MODULES_DIR/lib.sh"

log_info "Setting up keybindings..."

BT_CONF="$HOME/.config/bt-devices.conf"
mkdir -p "$(dirname "$BT_CONF")"

if [ ! -f "$BT_CONF" ]; then
    HEADPHONES_MAC="${BT_HEADPHONES:-}"
    MOUSE_MAC="${BT_MOUSE:-}"

    if command -v bluetoothctl >/dev/null 2>&1; then
        PAIRED=$(bluetoothctl devices Paired 2>/dev/null || true)

        if [ -n "$PAIRED" ]; then
            echo ""
            echo "  Paired Bluetooth devices found:"
            echo "$PAIRED" | while read -r line; do
                echo "    $line"
            done
            echo ""
        fi
    fi

    if [ -z "$HEADPHONES_MAC" ]; then
        HEADPHONES_MAC="$(ask_value "Headphones BT MAC (leave empty to skip)" "")"
    fi
    if [ -z "$MOUSE_MAC" ]; then
        MOUSE_MAC="$(ask_value "Mouse BT MAC (leave empty to skip)" "")"
    fi

    [ -n "$HEADPHONES_MAC" ] && echo "headphones=${HEADPHONES_MAC}" >> "$BT_CONF"
    [ -n "$MOUSE_MAC" ] && echo "mouse=${MOUSE_MAC}" >> "$BT_CONF"

    if [ -f "$BT_CONF" ]; then
        log_info "BT config written: $BT_CONF"
    else
        log_info "No BT devices configured, skipping keybindings"
        exit 0
    fi
else
    log_info "BT config already exists: $BT_CONF"
fi

LOCAL_BIN="$HOME/.local/bin"
CUSTOM_KB_BASE="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"
KBCURRENT=$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings 2>/dev/null)

add_keybinding() {
    local name="$1" binding="$2" command="$3" idx="$4"
    local path="${CUSTOM_KB_BASE}/custom${idx}/"
    if ! echo "$KBCURRENT" | grep -q "custom${idx}"; then
        KBCURRENT=$(echo "$KBCURRENT" | sed "s|]|, '${path}']|" | sed 's|\[, |[|')
    fi
    dconf write "${path}name" "'${name}'"
    dconf write "${path}command" "'${command}'"
    dconf write "${path}binding" "'${binding}'"
}

if grep -q "^headphones=" "$BT_CONF" 2>/dev/null; then
    add_keybinding "headphones on/off" "<Primary><Super>p" "/bin/bash ${LOCAL_BIN}/bt-toggle.sh headphones &" "0"
fi

if grep -q "^mouse=" "$BT_CONF" 2>/dev/null; then
    add_keybinding "mouse on/off" "<Primary><Super>m" "/bin/bash ${LOCAL_BIN}/bt-toggle.sh mouse &" "1"
fi

add_keybinding "WiFi" "Launch1" "gnome-control-center wifi" "PopLaunch1"

gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$KBCURRENT"
log_info "Custom keybindings configured."
