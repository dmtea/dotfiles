#!/usr/bin/env bash
set -euo pipefail

MODULES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(dirname "$MODULES_DIR")"
STATE_DIR="$HOME/.local/state/bootstrap"

source "$MODULES_DIR/lib.sh"

ARCH=$(dpkg --print-architecture)
if [[ "$ARCH" != "amd64" ]]; then
    log_error "Only amd64 is supported. Detected: $ARCH"
    exit 1
fi

if ! grep -qE "^ID=(ubuntu|pop)" /etc/os-release 2>/dev/null; then
    log_error "Only Pop!_OS and Ubuntu are supported."
    exit 1
fi

VERSION_ID=$(grep "^VERSION_ID=" /etc/os-release | cut -d'"' -f2)
if [[ "$VERSION_ID" != "24.04" ]]; then
    log_error "This script is for 24.04 only. Detected: ${VERSION_ID}"
    exit 1
fi

if [ "$(id -u)" -eq 0 ]; then
    log_error "Do not run as root. This script calls sudo internally."
    exit 1
fi

sudo -v || { log_error "sudo access required."; exit 1; }

mkdir -p "$STATE_DIR"

export PATH="/opt/nvim-linux-x86_64/bin:$HOME/.local/kitty.app/bin:$HOME/.local/bin:$HOME/.bun/bin:$PATH"

echo "Preflight checks passed: amd64, ${VERSION_ID}, sudo OK"
