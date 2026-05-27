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
3. **Version Pinning**: Pin tool versions where possible (tmux 3.6b, kitty 0.47.0, nvim v0.12.2, SOPS 3.13.1, age 1.3.1, BW CLI 2026.3.0, Nerd Fonts 3.4.0)
4. **Version-Specific**: Each script targets exactly one OS version
5. **Git**: Never commit secrets or .env files
6. **PATH**: `add_to_path` writes to `.bashrc`, `.profile`, `.zprofile` — NOT `.zshrc` (stow-managed). Exception: removing the oh-my-zsh template `.zshrc` after `--unattended` install is required for stow to symlink the managed version.
7. **Step Order**: System Base → Early Dotfiles Stow → Terminal & Fonts → Shell → Multiplexer → Editor → Languages → Infrastructure → Secrets & Auth → AI Agents → Dotfiles

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
| Secrets backend   | Vaultwarden (collections + folders)       | Org items per collection, folders as type labels. BW CLI pinned 2026.3.0 |
| TPM location      | ~/.config/tmux/plugins/tpm (XDG path)        | Matches tmux.conf XDG location; TPM auto-detects XDG      |
| fzf install       | git clone + --no-update-rc                   | Dotfiles .zshrc already sources .fzf.zsh                   |
| Dotfiles packages | kitty/, nvim/, opencode/, tmux/, zsh/ | Managed via GNU stow in ~/dotfiles             |
| Keyboard layout   | System XKB replacement (unipunct)           | Custom layout requires sudo cp to /usr/share/X11/xkb/symbols/ru, not possible via stow |
| Dotfiles paths    | No hardcoded $HOME paths — all use $HOME     | Portable across usernames                                   |
| .gitconfig        | Generated by setup-git.sh (not a stow package) | No git/ directory in repo                                 |
| archive/          | Present in repo but not in STOW_PACKAGES      | Archived configs, intentionally excluded from bootstrap     |
| Fonts             | Nerd Fonts v3.4.0 via curl                   | Pinned version, more complete than apt fonts-firacode      |

---

## Research

- **Vaultwarden integration** — full guide: `docs/vaultwarden-guide.md`. Organization collections for per-machine access, folders for type labels. BW CLI pinned to 2026.3.0.
- **XKB unipunct layout** — DEFERRED: CapsLock toggle has unresolved issues (SPICE double-press in VMs, COSMIC comp bug). Layout itself deploys fine; toggle set to Alt+Shift until CapsLock is fixed. Research: `docs/research/xkb-unipunct-layout/`.

---

## Vaultwarden Quick Reference

### Structure: org → collections (per machine) + folders (per type)

- **Collection** = machine access (dmbot=laptop, atmanam=server). One item per collection — NEVER multi-collection items.
- **Folder** = type label (`.ssh` for keys, `.env` for vars).
- **organizationId** MANDATORY on all items (or they won't show in UI).
- SSH keys: type 5 (native), folder `.ssh`. Env vars: type 2 (Secure Note), folder `.env`.

### BW CLI Rules

- Version pinned: `2026.3.0` (in `versions.sh`). NEVER install latest — 2026.4.0 was supply-chain attacked.
- Login: `BW_PASSWORD="$PASS" bw login --passwordenv BW_PASSWORD` — NEVER `--raw` or stdin pipe.
- Create items: `bw get template item | jq ... | bw encode | bw create item` — NEVER raw JSON to bw create.
- Explore safely: `vw-safe list items collection <id>` — NEVER raw bw output (leaks secrets).

### VW Triggers

| Trigger | Action |
|---------|--------|
| "add SSH key to VW" | Run `ssh-backup --org ID --collection ID <key-path>` |
| "add env var to VW" | Run `env-backup --org ID --collection ID <VAR_NAME>` |
| "rotate key/token" | See `docs/vaultwarden-guide.md` → Key Rotation |
| "check VW items" | Run `vw-safe list items collection <id>` |
| "VW login" | Run `source vw-connect` |

---

## Open Questions

1. Secrets recovery flow — Z_AI_API_KEY + SSH keys + git identity now in VW. Remaining: age key → SOPS → GitHub PAT → WireGuard config.
2. `.local/share/opencode/` in dotfiles — should `auth.json` and app data be stow-managed at all? Consider removing `.local/` from the opencode stow package.
3. `.gitignore` stow conflict at `~/.config/opencode/.gitignore` — pre-existing file from opencode prevents stow from deploying dotfiles version.
4. SSH key rotation automation — `ssh-backup` + `env-backup` utilities available, but no cron/systemd timer yet.

---

## VM Bootstrap Testing

### Test Credentials (NEVER ask user, NEVER commit)

All test credentials are in `tmp/test.env` (project-relative). Source it before testing:

```bash
source ~/dotfiles/tmp/test.env
```

Contains: VM sudo password, VW URL, VW email, VW master password, VM IPs.
If file missing → create it. Values are in the agent's session context.

### Test VMs

| VM | OS | DE | IP | Snapshot |
|----|-----|-----|-----|----------|
| freshubuntu26 | Ubuntu 26.04 LTS | GNOME 50, Wayland | `192.168.122.204` (DHCP) | `freshready` |
| freshpop24 | Pop!_OS 24.04 | COSMIC DE, Wayland | `192.168.122.22` (DHCP) | `freshready` |

### MANDATORY Test Procedure

**CRITICAL RULES:**
- **NEVER create bootstrap.conf.** ALL values come from Vaultwarden or are typed interactively. Zero pre-configuration.
- **ALL input is typed interactively through tmux pane** — exactly like a real user would.
- **NEVER skip interactive steps. NEVER press N on prompts without reason.**
- **Imitate a human.** Everything the bootstrap asks for — type it via `tmux send-keys` into the pane.

**Step-by-step:**

1. **Revert VM**: `virsh destroy <vm> && sleep 5 && virsh snapshot-revert <vm> freshready && virsh start <vm> && sleep 25`
2. **Create pane**: `tmux split-window -h` → SSH into VM
3. **Clone**: `git clone https://github.com/dmtea/dotfiles.git ~/dotfiles && cd ~/dotfiles/scripts`
4. **Run bootstrap**: `STOP_ON_ERROR=1 ./bootstrap.sh`
5. **Handle ALL prompts via pane** (type each value, just like a human):
   - sudo password → type from test.env
   - GIT_USER_NAME → type `Test User`
   - GIT_USER_EMAIL → type `test@example.com`
   - "Configure Vaultwarden now?" → type `y`
   - VW URL → type from test.env
   - VW email → type from test.env
   - Master password → type from test.env
   - Collection selection → type `1` (dmbot)
   - "Apply these values?" → type `y`
   - "Deploy SSH keys?" → type `y`
   - BT MAC → type Enter (skip)
7. **Verify**:
   - 13/13 modules pass
   - `test -f ~/.env.local && grep Z_AI_API_KEY ~/.env.local` — secrets pulled
   - opencode API verified in module 10 summary

### Skills Required

- `pane-tester` — ALL VM testing goes through tmux panes (sudo, VW master password, interactive prompts)
- Agent MUST check `$TMUX` before starting. Not in tmux → stop and tell user.

### COSMIC vs GNOME

| Feature | GNOME (freshubuntu26) | COSMIC (freshpop24) |
|---------|----------------------|---------------------|
| gsettings input-sources | ✅ Works | ❌ COSMIC ignores gsettings |
| evdev.xml patch | ✅ Required | ❌ Not needed |
| **Primary test target** | ✅ **ALWAYS use this** | Layout verification only |
