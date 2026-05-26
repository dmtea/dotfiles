#!/usr/bin/env bash
set -euo pipefail

MODULES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$MODULES_DIR/lib.sh"
source "$MODULES_DIR/versions.sh"

log_step "01" "System Base"

BASE_PACKAGES=(
    curl
    wget
    git
    ca-certificates
    gnupg
    software-properties-common
    stow
    unzip
    ripgrep
    jq
    fd-find
    bat
    tree
    zip
    xclip
    wl-clipboard
)

install_apt_packages "${BASE_PACKAGES[@]}"

install_apt_packages build-essential

mkdir -p ~/.local/bin

if check_cmd fdfind && ! check_cmd fd; then
    ln -sf "$(command -v fdfind)" ~/.local/bin/fd
    log_info "fd symlink created → $(command -v fdfind)"
fi

SCRIPT_BIN_DIR="$SCRIPT_DIR/bin"
if [ -d "$SCRIPT_BIN_DIR" ]; then
    for script in "$SCRIPT_BIN_DIR"/*; do
        [ -f "$script" ] || continue
        name=$(basename "$script")
        chmod +x "$script"
        cp "$script" "$HOME/.local/bin/$name"
        log_info "installed: $name → $HOME/.local/bin/$name"
    done
fi

REPO_DIR="$(cd "$MODULES_DIR/../.." && pwd)"
XKB_RU_SRC="$REPO_DIR/docs/research/xkb-unipunct-layout/ru"

if [ -f "$XKB_RU_SRC" ]; then
    log_info "Deploying custom keyboard layout (unipunct)..."
    sudo cp "$XKB_RU_SRC" /usr/share/X11/xkb/symbols/ru
    log_info "Replaced system symbols/ru with unipunct layout"

    # GNOME reads variants from evdev.xml; COSMIC reads directly from symbols/ru
    if ! grep -qw 'unipunct' /usr/share/X11/xkb/rules/evdev.xml 2>/dev/null; then
        sudo python3 -c "
import xml.etree.ElementTree as ET
path = '/usr/share/X11/xkb/rules/evdev.xml'
tree = ET.parse(path)
root = tree.getroot()
for layout in root.iter('layout'):
    ci = layout.find('configItem')
    if ci is not None:
        name = ci.find('name')
        if name is not None and name.text == 'ru':
            vl = layout.find('variantList')
            nv = ET.SubElement(vl, 'variant')
            nci = ET.SubElement(nv, 'configItem')
            ET.SubElement(nci, 'name').text = 'unipunct'
            ET.SubElement(nci, 'description').text = 'Russian (with US punctuation)'
            ll = ET.SubElement(nci, 'languageList')
            ET.SubElement(ll, 'iso639Id').text = 'rus'
            tree.write(path, xml_declaration=True, encoding='UTF-8')
            break
"
        log_info "Patched evdev.xml with unipunct variant"
    else
        log_info "evdev.xml already has unipunct variant"
    fi

    if command -v gsettings &>/dev/null; then
        gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('xkb', 'ru+unipunct')]"
        gsettings set org.gnome.desktop.input-sources xkb-options "['caps:none', 'lv3:ralt_switch']"
        gsettings set org.gnome.desktop.wm.keybindings switch-input-source "['Caps_Lock']"
        gsettings set org.gnome.desktop.wm.keybindings switch-input-source-backward "['<Shift>Caps_Lock']"
        log_info "Keyboard layout set: us + ru+unipunct (CapsLock=GNOME switch, AltGr level3)"
    fi
else
    log_warn "Custom keyboard layout source not found: $XKB_RU_SRC"
fi

write_marker "01-system-base"
