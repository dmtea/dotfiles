#!/usr/bin/env bash
set -euo pipefail

MODULES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$MODULES_DIR/lib.sh"
source "$MODULES_DIR/versions.sh"

log_step "08" "Secrets & Auth"

# --- SOPS ---
if check_cmd sops; then
    log_info "SOPS already installed: $(get_version sops)"
else
    log_info "Installing SOPS ${SOPS_VERSION}..."
    SOPS_DEB="sops_${SOPS_VERSION}_amd64.deb"
    curl -Lo "/tmp/${SOPS_DEB}" "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/${SOPS_DEB}"
    sudo dpkg -i "/tmp/${SOPS_DEB}" || sudo apt-get install -f -y
    rm -f "/tmp/${SOPS_DEB}"
    log_info "SOPS installed: $(get_version sops)"
fi

# --- age ---
if check_cmd age; then
    log_info "age already installed: $(get_version age)"
else
    log_info "Installing age v${AGE_VERSION}..."
    curl -fsSL "https://dl.filippo.io/age/v${AGE_VERSION}?for=linux/amd64" -o /tmp/age.tar.gz
    tar -xzf /tmp/age.tar.gz -C /tmp
    sudo install -m 755 /tmp/age/age /usr/local/bin/age
    sudo install -m 755 /tmp/age/age-keygen /usr/local/bin/age-keygen
    rm -rf /tmp/age /tmp/age.tar.gz
    log_info "age installed: $(get_version age)"
fi

# --- Bitwarden CLI ---
if check_cmd bw; then
    log_info "Bitwarden CLI already installed: $(get_version bw)"
else
    log_info "Installing Bitwarden CLI via npm..."
    sudo npm install -g @bitwarden/cli
    log_info "Bitwarden CLI installed: $(get_version bw)"
fi

# --- gh CLI ---
if check_cmd gh; then
    log_info "gh CLI already installed: $(get_version gh)"
else
    log_info "Installing gh CLI..."
    (type -p wget >/dev/null || sudo apt-get install wget -y) \
        && sudo mkdir -p -m 755 /etc/apt/keyrings \
        && out=$(mktemp) && wget -nv -O"$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        && cat "$out" | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
        && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
        && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
        && sudo apt update \
        && sudo apt install gh -y \
        && rm -f "$out"
    log_info "gh CLI installed: $(get_version gh)"
fi

# --- opencode CLI ---
if [ -x "$HOME/.opencode/bin/opencode" ]; then
    log_info "opencode already installed: $($HOME/.opencode/bin/opencode --version 2>/dev/null || echo 'installed')"
else
    log_info "Installing opencode CLI..."
    curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path
    log_info "opencode installed: $($HOME/.opencode/bin/opencode --version 2>/dev/null || echo 'installed')"
fi

# --- Vaultwarden login (optional) ---
if check_cmd bw; then
    BW_STATUS="$(bw status 2>/dev/null | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4 || echo 'unknown')"

    if [ "$BW_STATUS" = "unauthenticated" ] && [ -z "${VW_URL:-}" ]; then
        echo ""
        echo "  Vaultwarden can store your git identity, SSH keys, and secrets."
        if ask_yesno "Configure Vaultwarden now?" "n"; then
            VW_URL="$(ask_value "Vaultwarden URL (e.g. https://vault.example.com)")"
        fi
    fi

    if [ -n "${VW_URL:-}" ] && [ "$BW_STATUS" != "authenticated" ]; then
        log_info "Configuring Bitwarden for: $VW_URL"
        bw config server "$VW_URL" 2>&1 || log_warn "bw config server failed"

        BW_EMAIL="$(ask_value "Vaultwarden email")"
        if [ -n "$BW_EMAIL" ]; then
            log_info "Logging in to Vaultwarden..."
            BW_SESSION="$(bw login "$BW_EMAIL" --raw 2>&1)" || true
            if [ -n "$BW_SESSION" ] && ! echo "$BW_SESSION" | jq -e '.statusCode' >/dev/null 2>&1; then
                export BW_SESSION
                log_info "Logged in to Vaultwarden"

                for VW_ITEM in GIT_USER_NAME GIT_USER_EMAIL BT_HEADPHONES_MAC BT_MOUSE_MAC; do
                    VW_NOTES="$(bw get item "$VW_ITEM" 2>/dev/null | jq -r '.notes // empty' 2>/dev/null || true)"
                    if [ -n "$VW_NOTES" ]; then
                        case "$VW_ITEM" in
                            GIT_USER_NAME) export GIT_NAME="$VW_NOTES"; log_info "Git name from VW: $GIT_NAME" ;;
                            GIT_USER_EMAIL) export GIT_EMAIL="$VW_NOTES"; log_info "Git email from VW: $GIT_EMAIL" ;;
                            BT_HEADPHONES_MAC) export BT_HEADPHONES="$VW_NOTES"; log_info "BT headphones from VW: $BT_HEADPHONES" ;;
                            BT_MOUSE_MAC) export BT_MOUSE="$VW_NOTES"; log_info "BT mouse from VW: $BT_MOUSE" ;;
                        esac
                    fi
                done

                echo "$BW_SESSION" > "$STATE_DIR/bw-session"

                cat > "$STATE_DIR/vw-data" <<VWEOF
GIT_NAME="${GIT_NAME:-}"
GIT_EMAIL="${GIT_EMAIL:-}"
BT_HEADPHONES="${BT_HEADPHONES:-}"
BT_MOUSE="${BT_MOUSE:-}"
VWEOF
            else
                log_warn "Vaultwarden login failed — check email and password"
            fi
        fi
    elif [ "$BW_STATUS" = "authenticated" ]; then
        log_info "Bitwarden already authenticated"
    fi
fi

write_marker "08-secrets-auth"
