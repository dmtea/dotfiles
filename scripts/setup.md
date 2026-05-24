# Bootstrap Guide — Ubuntu 24.04+ (including Pop!_OS)

Modular, idempotent bootstrap for fresh Ubuntu 24.04+ (including Pop!_OS) installations.

## Prerequisites

- **OS**: Ubuntu 24.04+ (including Pop!_OS)
- **Architecture**: amd64 (x86_64)
- **Internet**: Required
- **Sudo access**: Required

Preflight module (`00-preflight.sh`) verifies these automatically.

## Quick Start

```bash
cd ~/dotfiles/scripts/
cp bootstrap.conf.example bootstrap.conf
# Edit bootstrap.conf with your name, email, BT devices
./bootstrap.sh
```

All output is logged to `/tmp/bootstrap-<timestamp>.log`.

## Options

```
./bootstrap.sh                  # Run all modules (prompt for missing values)
./bootstrap.sh --only shell,editor  # Run specific modules only
./bootstrap.sh --force          # Re-run even if .done markers exist
./bootstrap.sh --config FILE    # Use custom config file
./bootstrap.sh --help           # Show available modules
```

## Modules (11 steps)

| # | Module | Contents |
|---|--------|----------|
| 00 | **Preflight** | Architecture, OS version, sudo checks |
| 01 | **System Base** | apt packages + build-essential + user scripts → `~/.local/bin` |
| 02 | **Terminal & Fonts** | kitty + COSMIC default terminal + Nerd Fonts (FiraCode + FiraMono) |
| 03 | **Shell Environment** | zsh → oh-my-zsh → plugins → starship → fzf → zoxide |
| 04 | **Multiplexer** | tmux + TPM |
| 05 | **Editor** | Neovim |
| 06 | **Languages & Runtimes** | Python 3 → uv → Node.js LTS → Bun |
| 07 | **Infrastructure** | Docker Engine + Compose → Ansible |
| 08 | **Secrets & Auth** | SOPS → age → Bitwarden CLI → gh CLI → opencode |
| 09 | **Dotfiles** | Stow packages + generate .gitconfig + BT keybindings |
| 10 | **Summary** | Version report + post-bootstrap instructions |

Pinned versions are in `modules/versions.sh`.

## Configuration (`bootstrap.conf`)

Copy `bootstrap.conf.example` and edit:

```bash
GIT_NAME="Your Name"
GIT_EMAIL="you@example.com"
BT_HEADPHONES=""               # MAC or empty = auto-detect
BT_MOUSE=""                    # MAC or empty = auto-detect
# SKIP_MODULES=(xkb)           # Uncomment to skip modules
# STOP_ON_ERROR=1              # Abort on first failure
```

Empty values are prompted at runtime.

## Why No pip?

Ubuntu 24.04 ships Python 3.12 with **PEP 668** enforcement: `pip install` is blocked. `uv tool install` handles all Python tools instead.

## Post-Bootstrap

1. **Generate age key**:
   ```bash
   mkdir -p ~/.config/sops/age
   age-keygen -o ~/.config/sops/age/keys.txt
   ```

2. **Save the public key** to `.sops.yaml`. Save the private key in Vaultwarden!

3. **Configure Bitwarden CLI**:
   ```bash
   bw config server https://your-server.example.com
   bw login
   ```

4. **Log out and back in** — required for zsh default shell + Docker group.

5. **Install tmux plugins** — inside tmux, press `Ctrl-a` then `I`.

## Troubleshooting

### "command not found" after bootstrap

Log out and log back in. The script changed the default shell to zsh.

### Docker permission denied

Run `newgrp docker` for the current session, or log out and back in.

### uv not found

Add to `~/.zprofile`: `export PATH="$HOME/.local/bin:$PATH"`

### Bun not found

Add to `~/.zprofile`: `export PATH="$HOME/.bun/bin:$PATH"`

### Re-run a single module

```bash
./bootstrap.sh --force --only shell
```

### npm install fails with compilation errors

```bash
sudo apt install -y build-essential
sudo npm install -g @bitwarden/cli
```

## Verification

```bash
echo "=== Terminal ===" && kitty --version && \
echo "=== Shell ===" && zsh --version && starship --version && ~/.fzf/bin/fzf --version && zoxide --version && \
echo "=== Multiplexer ===" && tmux -V && \
echo "=== Editor ===" && nvim --version | head -1 && \
echo "=== Languages ===" && python3 --version && uv --version && node --version && npm --version && bun --version && \
echo "=== Infrastructure ===" && docker --version && docker compose version && ansible --version | head -1 && \
echo "=== Secrets ===" && sops --version && age --version && bw --version && gh --version && \
echo "=== Dev tools ===" && rg --version && jq --version && fd --version && bat --version
```

All output is logged to `/tmp/bootstrap-<timestamp>.log`.

## Running Modes

```bash
./bootstrap.sh                          # run all modules, prompt for missing values
./bootstrap.sh --only shell,editor      # run specific modules
./bootstrap.sh --force                  # re-run even if .done markers exist
./bootstrap.sh --config ~/my.conf       # use custom config file
./bootstrap.sh --help                   # list available modules
```

## Modules (11 steps)

| #  | Module           | Contents                                                                             |
|----|------------------|--------------------------------------------------------------------------------------|
| 00 | **Preflight**    | Architecture, OS version, sudo access checks                                         |
| 01 | **System Base**  | apt packages + build-essential + user scripts → `~/.local/bin`                       |
| 02 | **Terminal**     | kitty 0.47.0 + COSMIC default terminal + Nerd Fonts v3.4.0 (FiraCode + FiraMono)     |
| 03 | **Shell**        | zsh → oh-my-zsh → zsh plugins → starship → fzf → zoxide                             |
| 04 | **Multiplexer**  | tmux 3.6b + TPM                                                                      |
| 05 | **Editor**       | Neovim v0.12.2                                                                       |
| 06 | **Languages**    | Python 3 (venv + full) → uv → Node.js LTS + npm → Bun                                |
| 07 | **Infrastructure** | Docker Engine + Compose → Ansible                                                  |
| 08 | **Secrets & Auth** | SOPS 3.13.1 → age 1.3.1 → Bitwarden CLI → gh CLI → opencode                        |
| 09 | **Dotfiles**     | stow packages + generate .gitconfig + BT keybindings + keyboard layouts              |
| 10 | **Summary**      | Version report + post-bootstrap instructions                                          |

### Configuration (bootstrap.conf)

```bash
# Personal data (empty = prompted at runtime)
GIT_NAME=""
GIT_EMAIL=""

# Bluetooth devices (empty = auto-detect or skip)
BT_HEADPHONES=""
BT_MOUSE=""

# Skip modules (uncomment to exclude)
# SKIP_MODULES=(xkb)

# Stop on first failure
# STOP_ON_ERROR=0
```

## Why No pip?

Ubuntu 24.04 ships Python 3.12 with **PEP 668** enforcement: `pip install` is blocked entirely. `uv tool install` handles all Python tools (Ansible, etc.). The script installs `python3-venv` and `python3-full` instead.

## Bluetooth Keybindings

BT device MAC addresses are stored in `~/.config/bt-devices.conf` (alias-based, not env vars). `bt-toggle.sh` accepts an alias name and reads the MAC from config:

```bash
bt-toggle.sh headphones    # connect/disconnect headphones
bt-toggle.sh mouse         # connect/disconnect mouse
```

dconf keybindings reference aliases, so no personal data is hardcoded.

## Stow Packages

```sh
stow zsh       # .zshrc, .fzf.zsh, starship.toml
stow kitty     # kitty terminal config
stow opencode  # opencode CLI config + oh-my-openagent + skills + PATH
stow nvim      # Neovim config
stow tmux      # tmux config + TPM
stow xkb       # custom keyboard layout (~/.config/xkb/)
```

`.gitconfig` is generated by `setup-git.sh` (not a stow package).

## Post-Bootstrap

1. **Generate age key**:
   ```bash
   mkdir -p ~/.config/sops/age
   age-keygen -o ~/.config/sops/age/keys.txt
   ```

2. **Save the public key** to `.sops.yaml` in your project. Save the private key in Vaultwarden!

3. **Configure Bitwarden CLI** (if using Vaultwarden):
   ```bash
   bw config server https://your-server.example.com
   bw login
   ```

4. **Log out and back in** — required for zsh default shell + Docker group.

5. **Install tmux plugins** — inside tmux, press `Ctrl-a` then `I` (TPM install).

## Troubleshooting

### "command not found" after bootstrap

Log out and log back in. The script changed the default shell to zsh.

### Docker permission denied

Run `newgrp docker` for the current session, or log out and back in.

### uv not found

Check PATH: `echo $PATH | tr ':' '\n' | grep local`. If missing, add to `~/.zprofile`:
```bash
export PATH="$HOME/.local/bin:$PATH"
```

### Bun not found

Check PATH: `echo $PATH | tr ':' '\n' | grep bun`. If missing, add to `~/.zprofile`:
```bash
export PATH="$HOME/.bun/bin:$PATH"
```

### tmux plugins not loading

Press `Ctrl-a` then `I` inside tmux to trigger TPM installation.

### Re-run a single module

```bash
./bootstrap.sh --only shell --force
```

### Clear all progress markers

```bash
rm -rf ~/.local/state/bootstrap/
```

## Verification

```bash
echo "=== Terminal ===" && kitty --version && \
echo "=== Shell ===" && zsh --version && starship --version && ~/.fzf/bin/fzf --version && zoxide --version && \
echo "=== Multiplexer ===" && tmux -V && \
echo "=== Editor ===" && nvim --version | head -1 && \
echo "=== Languages ===" && python3 --version && uv --version && node --version && npm --version && bun --version && \
echo "=== Infrastructure ===" && docker --version && docker compose version && ansible --version | head -1 && \
echo "=== Secrets ===" && sops --version && age --version && bw --version && gh --version && echo "opencode: $("$HOME/.opencode/bin/opencode" --version 2>/dev/null || echo N/A)" && \
echo "=== Dev tools ===" && rg --version && jq --version && fd --version && bat --version
```
