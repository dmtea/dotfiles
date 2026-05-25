#!/usr/bin/env bash
set -euo pipefail

MODULES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$MODULES_DIR/lib.sh"

log_step "08" "AI Agents"

if [ -x "$HOME/.opencode/bin/opencode" ]; then
    log_info "opencode already installed: $($HOME/.opencode/bin/opencode --version 2>/dev/null || echo 'installed')"
else
    log_info "Installing opencode CLI..."
    curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path
    log_info "opencode installed: $($HOME/.opencode/bin/opencode --version 2>/dev/null || echo 'installed')"
fi

write_marker "08-ai-agents"
