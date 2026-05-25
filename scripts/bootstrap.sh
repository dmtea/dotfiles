#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$SCRIPT_DIR/modules"
STATE_DIR="$HOME/.local/state/bootstrap"

BOOTSTRAP_FORCE=0
BOOTSTRAP_ONLY=""
BOOTSTRAP_CONFIG=""

cleanup() {
    rm -f /tmp/sops_*.deb /tmp/age.tar.gz /tmp/nvim-linux-x86_64.tar.gz
    rm -f /tmp/FiraCode.zip /tmp/FiraMono.zip
    rm -rf /tmp/age/
}
trap cleanup EXIT

usage() {
    echo "Usage: bootstrap.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --only MOD1,MOD2   Run only specified modules"
    echo "  --force            Re-run modules even if .done markers exist"
    echo "  --config FILE      Path to bootstrap.conf (default: ./bootstrap.conf)"
    echo "  -h, --help         Show this help"
    echo ""
    echo "Available modules:"
    for f in "$MODULES_DIR"/[0-9]*.sh; do
        [ -f "$f" ] || continue
        name=$(basename "$f" .sh)
        printf "  %-22s\n" "$name"
    done
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --only)
            BOOTSTRAP_ONLY="$2"
            shift 2
            ;;
        --force)
            BOOTSTRAP_FORCE=1
            shift
            ;;
        --config)
            BOOTSTRAP_CONFIG="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

export BOOTSTRAP_FORCE

CONFIG_FILE="${BOOTSTRAP_CONFIG:-$SCRIPT_DIR/bootstrap.conf}"
if [ -f "$CONFIG_FILE" ]; then
    eval "$(grep -E '^[A-Z_]+=' "$CONFIG_FILE" | grep -v 'rm\|exec\|eval\|system\|source')"
    echo "Config loaded: $CONFIG_FILE"
fi

export STOP_ON_ERROR="${STOP_ON_ERROR:-0}"

LOG_FILE="/tmp/bootstrap-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== Bootstrap — Pop!_OS / Ubuntu 24.04+ (amd64) ==="
echo "Log: $LOG_FILE"

ALL_MODULES=(00-preflight 01-system-base 02-terminal-fonts 03-shell 04-multiplexer 05-editor 06-languages 07-infrastructure 08-secrets-auth 09-dotfiles 10-summary)

if [ -n "$BOOTSTRAP_ONLY" ]; then
    IFS=',' read -ra SELECTED <<< "$BOOTSTRAP_ONLY"
    MODULES_TO_RUN=()
    for sel in "${SELECTED[@]}"; do
        matched=false
        for mod in "${ALL_MODULES[@]}"; do
            if [[ "$mod" == *"$sel"* ]]; then
                MODULES_TO_RUN+=("$mod")
                matched=true
            fi
        done
        if [ "$matched" = false ]; then
            echo "WARNING: Module matching '$sel' not found"
        fi
    done
else
    MODULES_TO_RUN=()
    for mod in "${ALL_MODULES[@]}"; do
        skip=false
        for skipped in "${SKIP_MODULES[@]+"${SKIP_MODULES[@]}"}"; do
            [[ "$mod" == *"$skipped"* ]] && skip=true
        done
        [ "$skip" = true ] && continue
        MODULES_TO_RUN+=("$mod")
    done
fi

echo "Modules to run: ${MODULES_TO_RUN[*]}"
echo ""

FAILED=()
SUCCEEDED=()

run_module() {
    local module="$1"
    local module_file="$MODULES_DIR/${module}.sh"

    if [ ! -f "$module_file" ]; then
        echo "ERROR: Module file not found: $module_file"
        FAILED+=("$module")
        return 1
    fi

    if [ "$BOOTSTRAP_FORCE" != "1" ]; then
        local marker="$STATE_DIR/${module}.done"
        if [ -f "$marker" ]; then
            local marker_hash current_hash
            marker_hash=$(head -1 "$marker" 2>/dev/null | cut -d' ' -f1)
            current_hash=$(sha256sum "$module_file" 2>/dev/null | cut -d' ' -f1)
            if [ "$marker_hash" = "$current_hash" ]; then
                echo "=== Module $module: already completed, skipping ==="
                SUCCEEDED+=("$module")
                return 0
            else
                echo "=== Module $module: script changed, re-executing ==="
            fi
        fi
    fi

    echo "=== Running module: $module ==="
    (
        export SCRIPT_DIR MODULES_DIR STATE_DIR LOG_FILE BOOTSTRAP_FORCE
        [ -f "$STATE_DIR/saved-path" ] && export PATH="$(cat "$STATE_DIR/saved-path")"
        source "$module_file"
        echo "$PATH" > "$STATE_DIR/saved-path"
    )
    local rc=$?

    if [ -f "$STATE_DIR/saved-path" ]; then
        export PATH="$(cat "$STATE_DIR/saved-path")"
    fi

    [ -f "$STATE_DIR/vw-git-identity" ] && source "$STATE_DIR/vw-git-identity"

    if [ $rc -eq 0 ]; then
        SUCCEEDED+=("$module")
        echo "=== Module $module: OK ==="
    else
        FAILED+=("$module")
        echo "=== Module $module: FAILED (exit $rc) ==="
        if [ "$STOP_ON_ERROR" = "1" ]; then
            echo "STOP_ON_ERROR=1, aborting."
            exit 1
        fi
    fi
}

mkdir -p "$STATE_DIR"

for module in "${MODULES_TO_RUN[@]}"; do
    run_module "$module"
done

echo ""
echo "============================================"
echo "=== Bootstrap Complete ==="
echo "============================================"
echo "  Succeeded: ${#SUCCEEDED[@]}"
echo "  Failed:    ${#FAILED[@]}"
[ ${#FAILED[@]} -gt 0 ] && echo "  Failed modules: ${FAILED[*]}"
echo ""
