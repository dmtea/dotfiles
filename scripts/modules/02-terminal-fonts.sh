#!/usr/bin/env bash
set -euo pipefail

MODULES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$MODULES_DIR/lib.sh"
source "$MODULES_DIR/versions.sh"

log_step "02" "Terminal & Fonts"

KITTY_DIR="$HOME/.local/kitty.app"

if [ -x "$KITTY_DIR/bin/kitty" ] && [[ "$(kitty --version 2>/dev/null)" == "kitty ${KITTY_VERSION}"* ]]; then
    log_info "kitty already installed: $(kitty --version)"
else
    log_info "Installing kitty ${KITTY_VERSION}..."
    curl -fsSL "https://sw.kovidgoyal.net/kitty/installer.sh" | sh /dev/stdin launch=n installer=version-${KITTY_VERSION}
    log_info "kitty installed: $($KITTY_DIR/bin/kitty --version)"
fi

mkdir -p ~/.local/share/applications
if compgen -G "$KITTY_DIR/share/applications/*.desktop" >/dev/null 2>&1; then
    cp "$KITTY_DIR"/share/applications/*.desktop ~/.local/share/applications/
    log_info "kitty desktop files installed"
fi
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database ~/.local/share/applications 2>&1 || log_warn "update-desktop-database failed (non-critical)"
fi

add_to_path "$KITTY_DIR/bin"

if command -v cosmic-settings >/dev/null 2>&1 || dpkg -l cosmic-session >/dev/null 2>&1; then
    log_info "Configuring COSMIC default terminal..."

    SHORTCUTS_DIR="$HOME/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1"
    mkdir -p "$SHORTCUTS_DIR"

    if [ ! -f "$SHORTCUTS_DIR/system_actions" ]; then
        cat > "$SHORTCUTS_DIR/system_actions" << 'EOF'
{
    Terminal: "cosmic-term",
}
EOF
    fi

    sed -i 's/"cosmic-term"/"kitty"/' "$SHORTCUTS_DIR/system_actions" 2>&1 || log_warn "COSMIC shortcut file not found"

    cat > "$SHORTCUTS_DIR/custom" << 'RON'
(
    modifiers: [
        Super,
    ],
    key: "t",
): System(Terminal),
RON

    xdg-mime default kitty.desktop x-scheme-handler/terminal
    xdg-mime default kitty.desktop application/x-terminal-emulator

    log_info "COSMIC: Super+T → kitty"
fi

FONT_DIR="$HOME/.local/share/fonts"
mkdir -p "$FONT_DIR"

if [ -d "$FONT_DIR/FiraCode" ]; then
    log_info "FiraCode Nerd Font already installed"
else
    log_info "Installing FiraCode Nerd Font..."
    curl -fLo /tmp/FiraCode.zip "https://github.com/ryanoasis/nerd-fonts/releases/download/v${NERD_FONTS_VERSION}/FiraCode.zip"
    unzip -o /tmp/FiraCode.zip -d "$FONT_DIR/FiraCode/"
    rm -f /tmp/FiraCode.zip
    log_info "FiraCode Nerd Font installed"
fi

if [ -d "$FONT_DIR/FiraMono" ]; then
    log_info "FiraMono Nerd Font already installed"
else
    log_info "Installing FiraMono Nerd Font..."
    curl -fLo /tmp/FiraMono.zip "https://github.com/ryanoasis/nerd-fonts/releases/download/v${NERD_FONTS_VERSION}/FiraMono.zip"
    unzip -o /tmp/FiraMono.zip -d "$FONT_DIR/FiraMono/"
    rm -f /tmp/FiraMono.zip
    log_info "FiraMono Nerd Font installed"
fi

fc-cache -fv "$FONT_DIR" 2>/dev/null || true

write_marker "02-terminal-fonts"
