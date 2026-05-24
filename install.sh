#!/usr/bin/env bash
# Usage: curl -fsSL <raw-url>/install.sh | bash
set -euo pipefail

REPO_URL="https://github.com/dmtea/dotfiles.git"
CLONE_DIR="$HOME/dotfiles"
BRANCH="main"

echo "=== dmtea/dotfiles installer ==="
echo ""

if [ "$(id -u)" -eq 0 ]; then
    echo "ERROR: Do not run as root. This script calls sudo internally." >&2
    exit 1
fi

if ! command -v git >/dev/null 2>&1; then
    echo "git not found. Installing..."
    sudo apt update -qq && sudo apt install -y git
fi

if ! grep -qE "^ID=(ubuntu|pop)" /etc/os-release 2>/dev/null; then
    echo "ERROR: Only Pop!_OS and Ubuntu are supported." >&2
    exit 1
fi

VERSION_ID=$(grep "^VERSION_ID=" /etc/os-release | cut -d'"' -f2)
VERSION_MAJOR="${VERSION_ID%%.*}"
if [[ "$VERSION_MAJOR" -lt 24 ]]; then
    echo "ERROR: Ubuntu/Pop!_OS 24.04+ is required. Detected: ${VERSION_ID}" >&2
    exit 1
fi

ARCH=$(dpkg --print-architecture 2>/dev/null || echo "unknown")
if [[ "$ARCH" != "amd64" ]]; then
    echo "ERROR: Only amd64 is supported. Detected: ${ARCH}" >&2
    exit 1
fi

if [ -d "$CLONE_DIR/.git" ]; then
    echo "Repository already exists at ${CLONE_DIR}, pulling latest..."
    git -C "$CLONE_DIR" pull --ff-only || {
        echo "WARNING: Could not pull updates. Continuing with existing version."
    }
else
    if [ -d "$CLONE_DIR" ]; then
        echo "ERROR: ${CLONE_DIR} exists but is not a git repo. Move it aside and retry." >&2
        exit 1
    fi
    echo "Cloning dotfiles to ${CLONE_DIR}..."
    git clone -b "$BRANCH" "$REPO_URL" "$CLONE_DIR"
fi

cd "$CLONE_DIR/scripts"

if [ ! -f bootstrap.conf ]; then
    echo "Creating bootstrap.conf from example..."
    cp bootstrap.conf.example bootstrap.conf
    echo ""
    echo "NOTE: GIT_NAME and GIT_EMAIL are empty."
    echo "      You will be prompted during bootstrap, or edit:"
    echo "      ${CLONE_DIR}/scripts/bootstrap.conf"
    echo ""
fi

echo "Starting bootstrap..."
chmod +x bootstrap.sh
exec ./bootstrap.sh "$@"
