# Dotfiles — AI Agent Configuration

**Project**: Laptop Dotfiles + Bootstrap
**Date**: 2026-05-21

---

## Project Overview

Dotfiles repo for Ubuntu 24.04+ (including Pop!_OS) laptop — stow-managed configs + bootstrap provisioning script.
- Stow packages at repo root, bootstrap in `scripts/`
- Version-locked to 24.04 (Noble)
- Self-contained, idempotent bootstrap script
- amd64 only (no ARM support)
- Tested on clean VM (Pop!_OS 24.04 via libvirt)

For tool versions and step-by-step breakdown, see `README.md` and `scripts/setup.md`.

---

## AI Agent Rules

### Triggers

| Trigger                          | Action                                  |
| -------------------------------- | --------------------------------------- |
| "bootstrap", "setup laptop"      | Run or review `scripts/bootstrap.sh`    |
| "fresh install"                  | Execute bootstrap for 24.04             |
| "secrets"                        | Remind about SOPS, never plaintext      |
| "syntax check"                   | Run `bash -n scripts/bootstrap.sh`      |

### ⚠️ CRITICAL: Interactive Terminal Rule

**ANY time you need to run a command that requires user input (passwords, confirmations, prompts, TUI) — you MUST open a tmux pane.**

This is NON-NEGOTIABLE. There are NO exceptions. Follow this procedure EXACTLY:

#### When This Applies

- `sudo` commands (need password)
- `bw login`, `bw unlock` (need master password)
- SSH first-time host verification (`Are you sure?`)
- `ssh-keygen`, `gpg --gen-key` (interactive prompts)
- TUI applications (`htop`, `vim`, `mc`)
- ANY command where the agent cannot provide all input non-interactively

#### How to Open a Pane (ALWAYS Follow These Steps)

1. **Detect current pane position:**
   ```bash
   CURRENT_PANE=$(tmux display-message -p "#{pane_id}")
   MAIN_PANE=$(tmux list-panes -F "#{pane_id}" | head -1)
   ```

2. **Choose split direction:**
   - Current pane is MAIN (left) → **`split-window -h`** (open RIGHT column)
   - Current pane is in RIGHT column → **`split-window -v`** (stack BELOW)

3. **Open the pane via `interactive_bash`:**
   ```
   tmux_command: "split-window -h -P -F '#{pane_id}'"
   ```
   Save the returned pane ID (e.g. `%4`).

4. **Send commands to that pane:**
   ```
   tmux_command: "send-keys -t %4 'bw unlock' Enter"
   ```

5. **Tell the user to act:**
   Report `ACTION_REQUIRED: Enter <what> in pane <ID>` and wait.

#### FORBIDDEN (Will Break Things)

- ❌ `new-window` — wastes space, user loses context
- ❌ `split-window -v` from main pane — shrinks opencode vertically
- ❌ Using `bash` tool for interactive commands — no TTY, password prompts fail
- ❌ Guessing split direction without checking — always detect first

### Conventions

1. **Secrets**: Always via SOPS + age, never in plaintext
2. **Idempotent**: Every install step must be safe to re-run
3. **Version Pinning**: Pin tool versions where possible (tmux 3.6a, kitty 0.46.2, nvim v0.12.1, SOPS 3.12.2, age 1.3.1, Nerd Fonts 3.4.0)
4. **Version-Specific**: Each script targets exactly one OS version
5. **Git**: Never commit secrets or .env files
6. **PATH**: `add_to_path` writes to `.bashrc`, `.profile`, `.zprofile` — NOT `.zshrc` (stow-managed). Exception: removing the oh-my-zsh template `.zshrc` after `--unattended` install is required for stow to symlink the managed version.
7. **Step Order**: System Base → Terminal & Fonts → Shell → Multiplexer → Editor → Languages → Infrastructure → Secrets & Auth → Dotfiles

### Forbidden Actions

- ❌ No ARM support (amd64 only)
- ❌ No Ansible playbooks (this is bootstrap only)
- ❌ No hardcoded secrets or API keys
- ❌ No VPS/server-specific configurations
- ❌ No modifications to `.zshrc` from bootstrap (stow will manage it)

### Action Logging

After significant actions — document in `scripts/setup.md`:

Format: **What / Why / How** + commands + verification.

---

## Key Decisions

| Decision          | Choice                                       | Why                                                        |
| ----------------- | -------------------------------------------- | ---------------------------------------------------------- |
| Structure         | Stow packages at repo root, scripts in `scripts/` | Dotfiles repo = stow root; bootstrap in dedicated dir |
| Package manager   | apt (system), uv (Python), npm (Node)        | System packages via apt, Python tools via uv, Node global via npm |
| Terminal          | kitty via official installer                 | COSMIC DE integration, GPU-accelerated, not in apt         |
| Shell setup       | oh-my-zsh --unattended + git clone plugins   | No interactive prompts, reproducible                       |
| tmux              | Static binary from tmux-builds (not apt)     | Apt version outdated on 24.04                              |
| Neovim            | Official tarball to /opt                     | Latest version, not available in apt                       |
| Node.js source    | NodeSource official repository               | Current LTS, not outdated apt version                      |
| Docker install    | Docker official apt repo (DEB822 format)     | Modern Ubuntu prefers DEB822 (.sources)                    |
| gh CLI install    | GitHub CLI official apt repo (legacy .list)  | Upstream docs use .list format; .list still works on 24.04 |
| opencode CLI      | Official installer via curl (--no-modify-path) | Binary to ~/.opencode/bin; PATH managed by dotfiles stow |
| Python manager    | uv (astral.sh)                               | Replaces pip + pipx + virtualenv                           |
| 24.04 Python      | pip excluded (PEP 668 blocks it), venv+full  | Workaround: uv tool for global packages                    |
| Bun runtime       | Included                                     | Fast JS runtime, available on 24.04+                       |
| Secrets backend   | SOPS + age + Bitwarden CLI                   | Encrypt-in-repo + CLI access to Vaultwarden                |
| TPM location      | ~/.config/tmux/plugins/tpm (XDG path)        | Matches tmux.conf XDG location; TPM auto-detects XDG      |
| fzf install       | git clone + --no-update-rc                   | Dotfiles .zshrc already sources .fzf.zsh                   |
| Dotfiles packages | git/, archive/, kitty/, nvim/, opencode/, tmux/, zsh/ | Managed via GNU stow in ~/dotfiles             |
| Dotfiles paths    | No hardcoded $HOME paths — all use $HOME     | Portable across usernames                                   |
| Fonts             | Nerd Fonts v3.4.0 via curl                   | Pinned version, more complete than apt fonts-firacode      |

---

## Research

- **XKB unipunct layout** — custom Russian layout (US punctuation + Ukrainian AltGr): `docs/research/xkb-unipunct-layout/`. Contains: deployment research (AGENTS.md), system `symbols/ru`, kitty `ru-shortcuts.conf`, legacy user xkb files. Tested on Pop!_OS 24.04 (COSMIC) and Ubuntu 26.04 (GNOME) VMs.

---

## Open Questions

1. Secrets recovery flow — Z_AI_API_KEY now in VW. Remaining: age key → SOPS → SSH keys → GitHub PAT → WireGuard config.
2. `.local/share/opencode/` in dotfiles — should `auth.json` and app data be stow-managed at all? Consider removing `.local/` from the opencode stow package.
3. `.gitignore` stow conflict at `~/.config/opencode/.gitignore` — pre-existing file from opencode prevents stow from deploying dotfiles version.
