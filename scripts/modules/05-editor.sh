#!/usr/bin/env bash
set -euo pipefail

MODULES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$MODULES_DIR/lib.sh"
source "$MODULES_DIR/versions.sh"

log_step "05" "Editor"

if check_cmd nvim && [[ "$(nvim --version 2>/dev/null | head -1)" == "NVIM ${NVIM_VERSION#v}" ]]; then
    log_info "Neovim already installed: $(nvim --version | head -1)"
else
    log_info "Installing Neovim ${NVIM_VERSION}..."
    curl -fsSL "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux-x86_64.tar.gz" -o /tmp/nvim-linux-x86_64.tar.gz
    sudo rm -rf /opt/nvim-linux-x86_64
    sudo tar -C /opt -xzf /tmp/nvim-linux-x86_64.tar.gz
    rm -f /tmp/nvim-linux-x86_64.tar.gz
    log_info "Neovim installed: $(nvim --version | head -1)"
fi

add_to_path /opt/nvim-linux-x86_64/bin

write_marker "05-editor"
