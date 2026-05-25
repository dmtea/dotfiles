#!/usr/bin/env bash
# lib.sh — shared functions for bootstrap modules
# Sourced by modules via: source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
#
# Expects the following to be set by the orchestrator or preflight:
#   SCRIPT_DIR   — path to scripts/ directory
#   MODULES_DIR  — path to scripts/modules/ directory
#   STATE_DIR    — path to ~/.local/state/bootstrap/
#   LOG_FILE     — path to log file

# ============================================
# State markers
# ============================================

write_marker() {
    local module="$1"
    mkdir -p "$STATE_DIR"
    local module_hash
    module_hash=$(sha256sum "${MODULES_DIR}/${module}.sh" 2>/dev/null | cut -d' ' -f1)
    echo "$module_hash $(date -Iseconds)" > "${STATE_DIR}/${module}.done"
    echo "  [marker] ${module}.done written"
}

check_marker() {
    local module="$1"
    local marker="${STATE_DIR}/${module}.done"
    [ ! -f "$marker" ] && return 1

    # If --force, ignore markers
    [ "${BOOTSTRAP_FORCE:-0}" = "1" ] && return 1

    # Check if module script changed since last run
    local marker_hash current_hash
    marker_hash=$(head -1 "$marker" 2>/dev/null | cut -d' ' -f1)
    current_hash=$(sha256sum "${MODULES_DIR}/${module}.sh" 2>/dev/null | cut -d' ' -f1)

    if [ "$marker_hash" = "$current_hash" ]; then
        return 0
    else
        echo "  [marker] ${module} script changed since last run, will re-execute"
        return 1
    fi
}

# ============================================
# Command helpers
# ============================================

check_cmd() {
    command -v "$1" >/dev/null 2>&1
}

get_version() {
    local cmd="$1"
    if command -v "$cmd" >/dev/null 2>&1; then
        "$cmd" --version 2>&1 | grep -Em1 '[0-9]+\.[0-9]+' || "$cmd" --version 2>&1 | tail -1
    else
        echo "N/A"
    fi
}

get_path() {
    local cmd="$1"
    if command -v "$cmd" >/dev/null 2>&1; then
        command -v "$cmd"
    else
        echo "N/A"
    fi
}

# ============================================
# Package management
# ============================================

install_apt_packages() {
    local packages=("$@")
    local to_install=()

    for pkg in "${packages[@]}"; do
        if ! dpkg -l "$pkg" >/dev/null 2>&1; then
            to_install+=("$pkg")
        fi
    done

    if [ ${#to_install[@]} -gt 0 ]; then
        echo "  Installing: ${to_install[*]}"
        sudo apt update -qq 2>&1 || log_warn "apt update failed"
        sudo apt install -y "${to_install[@]}" 2>&1 || {
            log_error "Failed to install: ${to_install[*]}"
            return 1
        }
    else
        echo "  All apt packages already installed"
    fi
}

# ============================================
# PATH management
# ============================================

add_to_path() {
    local dir="$1"
    local entry="export PATH=\"${dir}:\$PATH\""

    for rc in ~/.bashrc ~/.profile ~/.zprofile; do
        touch "$rc"
        if ! grep -qF "$dir" "$rc" 2>/dev/null; then
            echo "$entry" >> "$rc"
        fi
    done
}

# ============================================
# Interactive prompts
# ============================================

ask_value() {
    local prompt="$1"
    local default="${2:-}"
    local result

    if [ -n "$default" ]; then
        echo -n "  ${prompt} [${default}]: " >&2
    else
        echo -n "  ${prompt}: " >&2
    fi

    read -r result
    echo "${result:-$default}"
}

ask_secret() {
    local prompt="$1"
    local result

    echo -n "  ${prompt}: " >&2
    read -rs result
    echo "" >&2
    echo "$result"
}

ask_yesno() {
    local prompt="$1"
    local default="${2:-n}"
    local answer

    if [ "$default" = "y" ]; then
        echo -n "  ${prompt} [Y/n]: " >&2
    else
        echo -n "  ${prompt} [y/N]: " >&2
    fi

    read -r answer
    answer="${answer:-$default}"
    [[ "$answer" =~ ^[Yy] ]]
}

# ============================================
# Config file
# ============================================

read_config() {
    local config_file="$1"
    if [ -f "$config_file" ]; then
        # Source only known variable assignments (safe parsing)
        eval "$(grep -E '^[A-Z_]+=' "$config_file" | grep -v 'rm\|exec\|eval\|system\|source')"
        echo "  Config loaded: $config_file"
    fi
}

# ============================================
# Logging
# ============================================

log_step() {
    local step_num="$1"
    local step_name="$2"
    echo ""
    echo "=== Step ${step_num}: ${step_name} ==="
    echo ""
}

log_info() {
    echo "  $*"
}

log_warn() {
    echo "  WARNING: $*" >&2
}

log_error() {
    echo "  ERROR: $*" >&2
}
