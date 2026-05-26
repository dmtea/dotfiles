#!/usr/bin/env bash
set -euo pipefail

MODULES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$MODULES_DIR/lib.sh"
source "$MODULES_DIR/versions.sh"

log_step "03" "Shell Environment"

# --- zsh ---
if check_cmd zsh; then
    log_info "zsh already installed: $(get_version zsh)"
else
    log_info "Installing zsh..."
    install_apt_packages zsh
    log_info "zsh installed: $(get_version zsh)"
fi

if [ "$SHELL" != "$(which zsh)" ]; then
    log_info "Setting zsh as default shell..."
    sudo chsh -s "$(which zsh)" "$USER"
else
    log_info "zsh is already the default shell"
fi

# --- oh-my-zsh ---
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [ -d "$HOME/.oh-my-zsh" ]; then
    log_info "oh-my-zsh already installed"
else
    log_info "Installing oh-my-zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
    log_info "oh-my-zsh installed"
fi

# --- zsh plugins ---
ZSH_PLUGINS=(
    "zsh-users/zsh-syntax-highlighting"
    "zsh-users/zsh-autosuggestions"
    "marlonrichert/zsh-autocomplete"
)

for plugin in "${ZSH_PLUGINS[@]}"; do
    name=$(basename "$plugin")
    target="$ZSH_CUSTOM/plugins/$name"
    if [ -d "$target" ]; then
        log_info "plugin $name already installed"
    else
        git clone --depth 1 "https://github.com/$plugin" "$target"
        log_info "plugin $name installed"
    fi
done

# --- starship ---
if check_cmd starship; then
    log_info "starship already installed: $(get_version starship)"
else
    log_info "Installing starship..."
    curl -sS https://starship.rs/install.sh | sh -s -- -y
    log_info "starship installed: $(get_version starship)"
fi

# --- fzf ---
if [ -d "$HOME/.fzf" ]; then
    log_info "fzf already installed"
else
    log_info "Installing fzf..."
    git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
    ~/.fzf/install --key-bindings --completion --no-update-rc
    log_info "fzf installed"
fi

# --- zoxide ---
if check_cmd zoxide; then
    log_info "zoxide already installed: $(get_version zoxide)"
else
    log_info "Installing zoxide..."
    curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
    log_info "zoxide installed: $(get_version zoxide)"
fi

write_marker "03-shell"
