# Dotfiles

GNU Stow packages for Ubuntu 24.04+ (including Pop!_OS) laptop + bootstrap script.

## Structure

```
~/dotfiles/               ← clone here, stow root
├── scripts/
│   ├── bootstrap.sh      ← full machine provisioning (9 steps)
│   ├── setup.md          ← walkthrough and troubleshooting
│   └── bin/              ← user scripts (installed to ~/.local/bin)
│       └── bt-toggle.sh
├── docs/
│   └── research/         ← investigations and solutions
├── xkb/                  ← stow package
├── zsh/                  ← stow packages
├── kitty/
├── nvim/
├── tmux/
├── git/
├── opencode/
└── archive/              ← archived configs (not used in bootstrap)
```

## Bootstrap

```bash
cd ~/dotfiles/scripts/
chmod +x bootstrap.sh
./bootstrap.sh
```

All output is logged to `/tmp/bootstrap-<timestamp>.log`.

## What Gets Installed

### System Base (Step 1)

| Tool | Purpose |
|------|---------|
| curl, wget, git, ca-certificates, gnupg | Core CLI utilities |
| software-properties-common | apt repository management |
| stow | Dotfiles symlink manager |
| unzip, zip | Archive tools |
| ripgrep (`rg`) | Fast text search |
| jq | JSON processing |
| fd-find (`fd`) | Fast file finder |
| bat | Better cat |
| tree | Directory visualization |
| xclip + wl-clipboard | Clipboard for X11 + Wayland |
| build-essential | Compiler tools (gcc, make) |

Also installs custom keyboard layout `ruu` (via stow package, not system files) and GNOME keybindings.

### Terminal & Fonts (Step 2)

| Tool | Version | Purpose |
|------|---------|---------|
| kitty | 0.46.2 | GPU-accelerated terminal emulator |
| FiraCode Nerd Font | v3.4.0 | Programming font with ligatures + icons |
| FiraMono Nerd Font | v3.4.0 | Monospace variant |

Includes COSMIC DE integration: Super+T → kitty, xdg-mime defaults.

### Shell Environment (Step 3)

| Tool | Purpose |
|------|---------|
| zsh | Default shell (set via chsh) |
| oh-my-zsh | Zsh framework (unattended install) |
| zsh-syntax-highlighting | Real-time syntax highlighting |
| zsh-autosuggestions | Fish-like autosuggestions |
| zsh-autocomplete | Real-time completions |
| starship | Cross-shell prompt |
| fzf | Fuzzy finder (key bindings + completion) |
| zoxide | Smarter cd command |

### Multiplexer (Step 4)

| Tool | Version | Purpose |
|------|---------|---------|
| tmux | 3.6a | Terminal multiplexer (static binary) |
| TPM | latest | Tmux Plugin Manager |

### Editor (Step 5)

| Tool | Version | Purpose |
|------|---------|---------|
| Neovim | v0.12.1 | Text editor (official tarball to /opt) |

### Languages & Runtimes (Step 6)

| Tool | Purpose |
|------|---------|
| Python 3 | System Python (venv + full, PEP 668 blocks pip) |
| uv | Fast Python package manager (astral.sh) |
| Node.js + npm | JavaScript runtime (NodeSource LTS) |
| Bun | Fast JS runtime |

### Infrastructure (Step 7)

| Tool | Purpose |
|------|---------|
| Docker Engine + Compose | Container runtime (official repo, DEB822 format) |
| Ansible | Infrastructure as Code (uv tool) |

### Secrets & Auth (Step 8)

| Tool | Version | Purpose |
|------|---------|---------|
| SOPS | 3.12.2 | Secrets encryption (dpkg) |
| age | 1.3.1 | File encryption (pinned binary) |
| Bitwarden CLI | latest | Password manager CLI (npm) |
| gh CLI | latest | GitHub CLI (official apt repo) |
| opencode | latest | AI coding CLI (official installer, --no-modify-path) |

### Dotfiles (Step 9)

Auto-applies stow packages if repo is at `~/dotfiles`.

## Stow Packages

```sh
stow zsh       # .zshrc, .fzf.zsh, starship.toml
stow kitty     # kitty terminal config
stow opencode  # opencode CLI config + oh-my-openagent + skills + PATH
stow nvim      # Neovim config
stow tmux      # tmux config + TPM
stow git       # .gitconfig
stow xkb       # custom Russian+Ukrainian keyboard layout (~/.config/xkb/)
stow archive   # archived configs (not used in bootstrap)
```

## Post-Bootstrap

After the script finishes:

1. **Generate age key**: `mkdir -p ~/.config/sops/age && age-keygen -o ~/.config/sops/age/keys.txt`
2. **Save the public key** to `.sops.yaml` in your project. Save the private key in Vaultwarden!
3. **Configure Bitwarden CLI**: `bw config server <url>` then `bw login`
4. **Log out and back in** — required for zsh default shell + Docker group

## Requirements

- **OS**: Ubuntu 24.04+ (including Pop!_OS)
- **Architecture**: amd64 (x86_64)
- **Internet**: Required
- **Sudo**: Required (script calls sudo internally — do NOT run as root)
