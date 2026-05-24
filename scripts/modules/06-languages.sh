#!/usr/bin/env bash
set -euo pipefail

MODULES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(dirname "$MODULES_DIR")"
STATE_DIR="$HOME/.local/state/bootstrap"

source "$MODULES_DIR/lib.sh"
source "$MODULES_DIR/versions.sh"

log_step "06" "Languages & Runtimes"

# --- Python 3 ---
if check_cmd python3; then
    log_info "Python 3 already installed: $(get_version python3)"
else
    log_info "Installing Python 3..."
    sudo apt install -y python3 python3-venv python3-full
    log_info "Python 3 installed: $(get_version python3)"
fi

# --- uv ---
if check_cmd uv; then
    log_info "uv already installed: $(get_version uv)"
else
    log_info "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    add_to_path "$HOME/.local/bin"
    export PATH="$HOME/.local/bin:$PATH"
    log_info "uv installed: $(get_version uv)"
fi

# --- Node.js + npm ---
if check_cmd node && check_cmd npm; then
    log_info "Node.js already installed: $(get_version node)"
    log_info "npm already installed: $(get_version npm)"
else
    log_info "Installing Node.js via NodeSource (LTS)..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt install -y nodejs
    log_info "Node.js installed: $(get_version node)"
    log_info "npm installed: $(get_version npm)"
fi

# --- Bun ---
if check_cmd bun; then
    log_info "Bun already installed: $(get_version bun)"
else
    log_info "Installing Bun..."
    curl -fsSL https://bun.sh/install | bash
    export PATH="$HOME/.bun/bin:$PATH"
    log_info "Bun installed: $(get_version bun)"
fi

write_marker "06-languages"
