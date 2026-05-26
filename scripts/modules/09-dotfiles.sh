#!/usr/bin/env bash
set -euo pipefail

MODULES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(dirname "$MODULES_DIR")"
source "$MODULES_DIR/lib.sh"

log_step "09" "Dotfiles Setup"

source "$MODULES_DIR/setup-git.sh"
source "$MODULES_DIR/setup-keybindings.sh"

if [ -d "$HOME/.config/tmux/plugins/tpm" ] && [ -f "$HOME/.config/tmux/tmux.conf" ]; then
    log_info "Installing tmux plugins..."
    if TMUX_PLUGIN_MANAGER_PATH="$HOME/.config/tmux/plugins/" \
        "$HOME/.config/tmux/plugins/tpm/bin/install_plugins" 2>&1; then
        log_info "tmux plugins installed"
    else
        log_warn "tmux plugins will install on first launch (prefix+I)"
    fi
fi

if [ -d "$HOME/.config/xkb/symbols" ]; then
    gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('xkb', 'ru+ruu')]" \
        && log_info "Keyboard layout set: us + ruu" \
        || log_warn "Failed to set keyboard layout via gsettings"
fi

write_marker "09-dotfiles"
