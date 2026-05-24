#!/usr/bin/env bash
set -euo pipefail

MODULES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(dirname "$MODULES_DIR")"
source "$MODULES_DIR/lib.sh"

log_step "09" "Dotfiles"

REPO_DIR="$(dirname "$SCRIPT_DIR")"
DOTFILES_DIR=""

if [ -d "$REPO_DIR/zsh" ]; then
    DOTFILES_DIR="$REPO_DIR"
    log_info "Using dotfiles from repo: $DOTFILES_DIR"
else
    if [ -d "$HOME/dotfiles/zsh" ]; then
        DOTFILES_DIR="$HOME/dotfiles"
        log_info "Using dotfiles from ~/dotfiles"
    fi
fi

if [ -z "$DOTFILES_DIR" ]; then
    log_warn "No dotfiles found. Apply dotfiles manually after bootstrap."
    write_marker "09-dotfiles"
    exit 0
fi

rm -f ~/.fzf.zsh 2>/dev/null

for f in ~/.zshrc ~/.config/tmux/tmux.conf; do
    if [ -f "$f" ] && [ ! -L "$f" ]; then
        mv "$f" "${f}.bootstrap-backup"
        log_info "Backed up existing: $f → ${f}.bootstrap-backup"
    fi
done

STOW_PACKAGES="zsh kitty opencode nvim tmux"

for pkg in $STOW_PACKAGES; do
    if [ -d "$DOTFILES_DIR/$pkg" ]; then
        cd "$DOTFILES_DIR"
        if stow "$pkg" 2>/dev/null; then
            log_info "stowed: $pkg"
        else
            stow --adopt "$pkg" 2>/dev/null && log_info "stowed (adopted): $pkg" || log_warn "stow $pkg failed"
        fi
    fi
done

cd - > /dev/null

source "$MODULES_DIR/setup-git.sh"
source "$MODULES_DIR/setup-keybindings.sh"

if [ -d "$HOME/.config/tmux/plugins/tpm" ] && [ -L "$HOME/.config/tmux/tmux.conf" ]; then
    log_info "Installing tmux plugins..."
    TMUX_PLUGIN_MANAGER_PATH="$HOME/.config/tmux/plugins/" \
        "$HOME/.config/tmux/plugins/tpm/bin/install_plugins" 2>/dev/null \
        && log_info "tmux plugins installed" \
        || log_warn "tmux plugins will install on first launch (prefix+I)"
fi

if [ -d "$HOME/.config/xkb/symbols" ]; then
    gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('xkb', 'ru+ruu')]" \
        && log_info "Keyboard layout set: us + ruu" \
        || log_warn "Failed to set keyboard layout via gsettings"
fi

write_marker "09-dotfiles"
