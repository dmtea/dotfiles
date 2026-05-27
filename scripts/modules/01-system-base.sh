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

write_marker "01-system-base"
