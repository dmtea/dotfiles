#!/usr/bin/env bash
set -euo pipefail

MODULES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$MODULES_DIR/lib.sh"
source "$MODULES_DIR/versions.sh"

log_step "04" "Multiplexer"

# --- tmux ---
if check_cmd tmux && [[ "$(tmux -V 2>/dev/null)" == "tmux ${TMUX_VERSION}" ]]; then
    log_info "tmux already installed: $(tmux -V)"
else
    log_info "Installing tmux ${TMUX_VERSION}..."
    curl -fsSL "https://github.com/tmux/tmux-builds/releases/download/v${TMUX_VERSION}/tmux-${TMUX_VERSION}-linux-x86_64.tar.gz" \
        | tar xzf - -C /tmp
    sudo mv /tmp/tmux /usr/local/bin/tmux
    sudo chmod 755 /usr/local/bin/tmux
    rm -f /tmp/tmux
    log_info "tmux installed: $(tmux -V)"
fi

# --- TPM ---
if [ -d "$HOME/.config/tmux/plugins/tpm" ]; then
    log_info "tpm already installed"
else
    log_info "Installing tpm..."
    mkdir -p "$HOME/.config/tmux/plugins"
    git clone https://github.com/tmux-plugins/tpm "$HOME/.config/tmux/plugins/tpm"
    log_info "tpm installed."
fi

write_marker "04-multiplexer"
