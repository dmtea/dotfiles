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
                echo "$BW_SESSION" > "$STATE_DIR/bw-session"

                VW_COLLECTIONS="$(bw list collections --session "$BW_SESSION" 2>/dev/null | jq -r '.[] | .name' 2>/dev/null || true)"
                if [ -n "$VW_COLLECTIONS" ]; then
                    echo ""
                    echo "  Available collections:"
                    echo "$VW_COLLECTIONS" | while read -r col; do echo "    - $col"; done
                    VW_COLLECTION="$(ask_value "Select collection for this machine")"
                fi

                VW_COLLECTION_ID=""
                if [ -n "${VW_COLLECTION:-}" ]; then
                    VW_COLLECTION_ID="$(bw list collections --session "$BW_SESSION" 2>/dev/null \
                        | jq -r ".[] | select(.name==\"$VW_COLLECTION\") | .id" 2>/dev/null || true)"
                fi

                VW_ALL_ITEMS="$(bw list items --session "$BW_SESSION" 2>/dev/null || true)"

                if [ -n "$VW_COLLECTION_ID" ]; then
                    VW_ITEMS="$(echo "$VW_ALL_ITEMS" | jq -r ".[] | select(.collectionIds[]? == \"$VW_COLLECTION_ID\")" 2>/dev/null || true)"
                else
                    VW_ITEMS="$(echo "$VW_ALL_ITEMS" | jq -r '.[] | select(.collectionIds | length == 0)' 2>/dev/null || true)"
                fi

                VW_ENV_ITEMS="$(echo "$VW_ITEMS" | jq -r '. | select(.type==2 and (.name | test("^[A-Z_]")))')"
                VW_SSH_ITEMS="$(echo "$VW_ITEMS" | jq -s -r '.[] | select(.type==5)')"

                if [ -n "$VW_ENV_ITEMS" ]; then
                    echo ""
                    echo "  Env vars from collection '${VW_COLLECTION:-shared}':"
                    echo "$VW_ENV_ITEMS" | jq -r '. | "    \(.name) = \(.notes)"'
                    echo ""
                    if ask_yesno "Apply these values?" "y"; then
                        VW_ENV_FILE="$STATE_DIR/vw-data"
                        : > "$VW_ENV_FILE"
                        echo "$VW_ENV_ITEMS" | jq -r '.name + "\t" + .notes' | while IFS=$'\t' read -r vw_name vw_value; do
                            [ -z "$vw_value" ] && continue
                            case "$vw_name" in
                                GIT_USER_NAME) export GIT_NAME="$vw_value" ;;
                                GIT_USER_EMAIL) export GIT_EMAIL="$vw_value" ;;
                                *) export "$vw_name=$vw_value" 2>/dev/null || true ;;
                            esac
                            echo "${vw_name}=\"${vw_value}\"" >> "$VW_ENV_FILE"
                            log_info "$vw_name = $vw_value"
                        done
                    fi
                fi

                if [ -n "$VW_SSH_ITEMS" ]; then
                    VW_SSH_COUNT="$(echo "$VW_SSH_ITEMS" | jq -s 'length')"
                    log_info "Found $VW_SSH_COUNT SSH key(s) in collection '${VW_COLLECTION:-shared}'"
                fi
            else
                log_warn "Vaultwarden login failed — check email and password"
            fi
        fi
    elif [ "$BW_STATUS" = "authenticated" ]; then
        log_info "Bitwarden already authenticated"
    fi
fi

write_marker "08-secrets-auth"
