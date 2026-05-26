#!/usr/bin/env bash
set -euo pipefail

MODULES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(dirname "$MODULES_DIR")"
source "$MODULES_DIR/lib.sh"

log_step "01b" "Dotfiles Stow"

REPO_DIR="$(dirname "$SCRIPT_DIR")"
DOTFILES_DIR=""

if [ -d "$REPO_DIR/zsh" ]; then
    DOTFILES_DIR="$REPO_DIR"
    log_info "Using dotfiles from repo: $DOTFILES_DIR"
elif [ -d "$HOME/dotfiles/zsh" ]; then
    DOTFILES_DIR="$HOME/dotfiles"
    log_info "Using dotfiles from ~/dotfiles"
fi

if [ -z "$DOTFILES_DIR" ]; then
    log_warn "No dotfiles found. Apply dotfiles manually after bootstrap."
    write_marker "01b-dotfiles-stow"
    exit 0
fi

STOW_PACKAGES="zsh kitty opencode nvim tmux"

for pkg in $STOW_PACKAGES; do
    if [ -d "$DOTFILES_DIR/$pkg" ]; then
        cd "$DOTFILES_DIR"
        if stow "$pkg" 2>&1; then
            log_info "stowed: $pkg"
        else
            log_warn "stow $pkg failed — removing conflicts and retrying..."
            stow "$pkg" 2>&1 | grep -oP "existing target is neither a link nor a directory: \K.*" | while read -r conflict; do
                rm -f "$conflict"
            done
            if stow "$pkg" 2>&1; then
                log_info "stowed: $pkg (after conflict removal)"
            else
                log_warn "stow $pkg failed — check for conflicts"
            fi
        fi
    fi
done

cd - > /dev/null

write_marker "01b-dotfiles-stow"
