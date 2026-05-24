#!/usr/bin/env bash
set -euo pipefail

MODULES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$MODULES_DIR/lib.sh"

log_info "Setting up git identity..."

GITCONFIG="$HOME/.gitconfig"

if [ -f "$GITCONFIG" ] && grep -qE '^\s+name\s*=' "$GITCONFIG" 2>/dev/null; then
    log_info "gitconfig already configured with user identity"
    exit 0
fi

if [ "${GIT_NAME:-}" = "" ] || [ "${GIT_EMAIL:-}" = "" ]; then
    echo ""
    echo "  Git identity configuration:"
    GIT_NAME="$(ask_value "Your name" "${GIT_NAME:-}")"
    GIT_EMAIL="$(ask_value "Your email" "${GIT_EMAIL:-}")"
fi

cat > "$GITCONFIG" <<EOF
[user]
	name = ${GIT_NAME}
	email = ${GIT_EMAIL}
[init]
	defaultBranch = main
EOF

log_info "gitconfig written: ${GIT_NAME} <${GIT_EMAIL}>"
