#!/usr/bin/env bash
set -euo pipefail

MODULES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$MODULES_DIR/lib.sh"
source "$MODULES_DIR/versions.sh"

log_step "07" "Infrastructure"

# --- Docker Engine + Docker Compose ---
if check_cmd docker; then
    log_info "Docker already installed: $(get_version docker)"
else
    log_info "Installing Docker..."

    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    sudo usermod -aG docker "$USER"

    log_info "Docker installed: $(get_version docker)"
    log_warn "Docker group change requires logout/login to take effect."
    log_warn "Run 'newgrp docker' to activate in the current session."
fi

# --- Ansible ---
if check_cmd ansible; then
    log_info "Ansible already installed: $(get_version ansible)"
else
    log_info "Installing Ansible via uv tool..."

    export PATH="$HOME/.local/bin:$PATH"
    uv tool install ansible-core

    log_info "Ansible installed: $(get_version ansible)"
fi

write_marker "07-infrastructure"
