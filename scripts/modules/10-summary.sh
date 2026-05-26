#!/usr/bin/env bash
set -euo pipefail

MODULES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$MODULES_DIR/lib.sh"
source "$MODULES_DIR/versions.sh"

log_step "10" "Summary"

echo "  zsh:        $(get_version zsh)          [$(get_path zsh)]"
echo "  tmux:       $(tmux -V 2>/dev/null || echo N/A)           [$(get_path tmux)]"
echo "  kitty:      $(kitty --version 2>/dev/null | head -1 | awk '{print $2}' || echo N/A)           [$(get_path kitty)]"
echo "  Neovim:     $(nvim --version 2>/dev/null | head -1 || echo N/A)  [$(get_path nvim)]"
echo "  Python:     $(get_version python3)     [$(get_path python3)]"
echo "  uv:         $(get_version uv)           [$(get_path uv)]"
echo "  Node.js:    $(get_version node)         [$(get_path node)]"
echo "  npm:        $(get_version npm)          [$(get_path npm)]"
echo "  Bun:        $(get_version bun)          [$(get_path bun)]"
echo "  Docker:     $(get_version docker)       [$(get_path docker)]"
echo "  Ansible:    $(get_version ansible)      [$(get_path ansible)]"
echo "  SOPS:       $(get_version sops)         [$(get_path sops)]"
echo "  age:        $(get_version age)          [$(get_path age)]"
echo "  Bitwarden:  $(get_version bw)           [$(get_path bw)]"
echo "  gh CLI:     $(get_version gh)           [$(get_path gh)]"
echo "  opencode:   $([ -x "$HOME/.opencode/bin/opencode" ] && $HOME/.opencode/bin/opencode --version 2>/dev/null || echo N/A)"
echo "  starship:   $(get_version starship)     [$(get_path starship)]"
echo "  fzf:        $(~/.fzf/bin/fzf --version 2>/dev/null || echo N/A)       [$(get_path fzf)]"
echo "  zoxide:     $(get_version zoxide)       [$(get_path zoxide)]"
echo "  oh-my-zsh:  $( [ -d "$HOME/.oh-my-zsh" ] && echo 'installed' || echo 'N/A' )"
echo "  tpm:        $( [ -d "$HOME/.config/tmux/plugins/tpm" ] && echo 'installed' || echo 'N/A' )"
echo "  dotfiles:   $( [ -L "$HOME/.zshrc" ] && echo 'stowed' || echo 'not applied' )"
echo "  apt extras: ripgrep, jq, fd-find, bat, tree, zip, xclip, wl-clipboard"
echo ""

if [ -x "$HOME/.opencode/bin/opencode" ] && [ -f "$HOME/.env.local" ]; then
    OPENCODE_TEST="$(source "$HOME/.env.local" && cd "$HOME/dotfiles" && timeout 30 "$HOME/.opencode/bin/opencode" run "Reply with exactly: OK" 2>&1 || true)"
    if echo "$OPENCODE_TEST" | grep -q "OK"; then
        log_info "opencode API verified: model responded"
    else
        log_warn "opencode API test: no response (check Z_AI_API_KEY and network)"
    fi
fi

echo ""

echo "============================================"
echo "=== Next Steps ==="
echo "============================================"
echo ""

if [ ! -f "$STATE_DIR/vw-data" ] && [ ! -f "$HOME/.env.local" ]; then
    echo "1. Configure Vaultwarden CLI:"
    echo "   bw config server 'https://your-vaultwarden.example.com'"
    echo "   bw login"
    echo ""
    NEXT_NUM=2
else
    NEXT_NUM=1
fi

echo "${NEXT_NUM}. Generate age key:"
echo "   mkdir -p ~/.config/sops/age"
echo "   age-keygen -o ~/.config/sops/age/keys.txt"
NEXT_NUM=$((NEXT_NUM + 1))
echo ""

echo "${NEXT_NUM}. Save the public key to .sops.yaml in your project"
echo "   Save the private key in Vaultwarden!"
NEXT_NUM=$((NEXT_NUM + 1))
echo ""

echo "${NEXT_NUM}. Log out and back in (required for shell/docker group changes)"
echo ""

write_marker "10-summary"
