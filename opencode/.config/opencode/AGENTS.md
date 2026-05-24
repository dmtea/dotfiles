# Global Rules — OpenCode

**Location:** `~/.config/opencode/AGENTS.md`  
**Updated:** 2026-05-22 (added verify-before-write rule)

---

## Verify Before Writing

Agent MUST run verification commands before stating ANY system property (OS version, DE, kernel, package version, file contents, config state). Never assume based on context, project theme, or "it should be". If a claim cannot be verified, mark it as UNVERIFIED.

---

## Language Policy

### Code & Content Language — English

All files used for prompts, context, code comments, documentation, plans, drafts, commit messages, and any other project artifacts MUST be written in **English**.

This applies to:
- Code comments
- Documentation files (`*.md`)
- Plans and drafts (`.sisyphus/plans/`, `.sisyphus/drafts/`)
- Commit messages
- Variable names, function names, and identifiers
- Configuration files with human-readable content
- Knowledge base files

### Dialog Language — Russian

Dialog with the user must be in **Russian** unless the user explicitly switches to another language. Follow the user's language: if they write in Russian — respond in Russian; if they write in English — respond in English.

---

## Active Rules

Rules are stored in `~/.config/opencode/rules/` and referenced below.

| Rule ID                | Description                                    | File                                          |
| ---------------------- | ---------------------------------------------- | --------------------------------------------- |
| `doc-freshness-sync`   | Documentation freshness checking & git sync    | [rules/doc-freshness-sync.md](./rules/doc-freshness-sync.md) |
| `interactive-commands` | SSH, sudo, TUI — use pane-tester               | [rules/interactive-commands.md](./rules/interactive-commands.md) |
| `action-logging`       | Log all significant actions and decisions      | [rules/action-logging.md](./rules/action-logging.md) |

### Attention Sound

When the agent needs user input (password, decision, checkpoint, confirmation) and the user hasn't responded after 3 messages/prompts, play an alert sound to get their attention:

```bash
paplay ~/.config/opencode/sounds/attention.wav
```

This covers situations where the user is on another workspace (browser, etc.) and may not see the prompt.

**Rule:** Ask normally first 3 times. On the 4th attempt, play the sound alongside the prompt.

**Sound file:** `~/.config/opencode/sounds/attention.wav` (klavichord-4)

---

## Active Skills

Skills are stored in `~/.config/opencode/skills/` and provide specialized workflows.

| Skill ID      | Description                                      | Location                                    |
| ------------- | ------------------------------------------------ | ------------------------------------------- |
| `docs-sync`   | Local docs management with freshness checking    | [skills/docs-sync/SKILL.md](./skills/docs-sync/SKILL.md) |
| `vpsemu`      | Incus containers for VPS emulation (Ansible/IaC) | [skills/vpsemu/SKILL.md](./skills/vpsemu/SKILL.md)       |
| `pane-tester` | tmux pane testing framework                      | [skills/pane-tester/SKILL.md](./skills/pane-tester/SKILL.md) |
| `external-analysis` | External AI analysis collection, synthesis, integration (5-step protocol). TRIGGERS: external analysis, AI analysis, convergence matrix, digest, review with external models | [skills/external-analysis/SKILL.md](./skills/external-analysis/SKILL.md) |

---

## oh-my-openagent Tmux Integration

### How it Works

oh-my-openagent has **built-in** tmux integration for sub-agents.

**When `tmux.enabled = true` in `oh-my-openagent.json`:**
- Background agents (`run_in_background=true`) automatically open in separate tmux panes
- Each pane shows live agent output
- Does NOT require pane-tester skill

### Configuration

```json
{
  "tmux": {
    "enabled": true,
    "layout": "main-vertical",
    "main_pane_size": 60,
    "main_pane_min_width": 120,
    "agent_pane_min_width": 40
  }
}
```

| Option                  | Default         | Description                            |
| ----------------------- | --------------- | -------------------------------------- |
| `enabled`               | `false`         | Enable automatic panes for agents      |
| `layout`                | `main-vertical` | `main-vertical` / `main-horizontal` / `tiled` |
| `main_pane_size`        | `60`            | Main pane % (20–80)                    |
| `main_pane_min_width`   | `120`           | Min columns for main pane              |
| `agent_pane_min_width`  | `40`            | Min columns for agent pane             |

### Requirements

1. Run OpenCode inside tmux:
   ```bash
   tmux new-session -s opencode "opencode --port 3000"
   ```

2. Or start OpenCode, then attach to session

### pane-tester vs oh-my-openagent tmux

| Aspect       | oh-my-openagent tmux           | pane-tester skill               |
| ------------ | ----------------------------- | ------------------------------- |
| Purpose      | Auto panes for agents         | Manual panes for testing        |
| Trigger      | `run_in_background=true`      | Explicit `pane_create` etc.     |
| Model        | Built into oh-my-openagent    | Separate skill                  |
| Usage        | All background agents         | sudo, TUI, interactive CLI      |

**⚠️ Known Issue:** [GitHub #2729](https://github.com/code-yeongyu/oh-my-openagent/issues/2729) — tmux panes not working in `serve + attach` mode

**Workaround:** Run OpenCode locally (`opencode` without `serve`)

### pane-tester: sudo and Interactive Input

**⚠️ CRITICAL: Always verify tmux availability BEFORE using pane-tester.**

```bash
# Check if OpenCode is running inside tmux
echo "TMUX=$TMUX"
# Empty → NOT in tmux → pane-tester CANNOT be used
# Set (e.g. /tmp/tmux-1000/default,12345,0) → in tmux → proceed
```

**NEVER rely on `tmux list-sessions` — stale sessions from previous runs are NOT the current session.**

**If `$TMUX` is empty:**
1. STOP before starting work
2. Ask the user what they prefer: restart in tmux, or run commands manually
3. Resolve this upfront — before diving into work. Don't discover the blocker halfway through.

**Key use case:** Commands requiring interactive input (sudo password, confirmations, etc.)

```bash
# Problem: sudo in regular bash doesn't work
sudo apt-get install sqlite3  # → "a terminal is required to read the password"

# Solution: pane-tester creates interactive pane
pane_create
pane_send --command "sudo apt-get install sqlite3"
# User sees password prompt in pane and enters password
pane_wait_sudo  # Agent waits for user to enter password
pane_capture    # Continue after input
```

**Workflow for sudo commands:**

1. `pane_create` — creates interactive pane
2. `pane_send "sudo ..."` — sends command
3. Agent reports: "ACTION_REQUIRED: Enter sudo password in pane %X"
4. User enters password manually in pane
5. `pane_capture` — captures result after input

**Why it doesn't work via regular bash:**
- `sudo` requires TTY for password input
- `bash` tool has no interactive terminal
- `pane-tester` creates real tmux pane with TTY

**Commands requiring pane-tester:**
- `sudo ...` — needs password
- `ssh-keygen` — interactive questions
- `gpg --gen-key` — passphrase input
- TUI apps: `vim`, `htop`, `pudb`, `mc`

---

## Quick Reference

### Documentation Freshness (`doc-freshness-sync`)

**When to apply:** User asks about libraries, configs, time-sensitive info.

**Key locations:**
- Manifest: `~/.cache/ai_docs_sync/.manifest.json`
- Docs: `~/.cache/ai_docs_sync/docs/`
- CLI: `docs-sync`

**TTL summary:**
| Type             | TTL       |
| ---------------- | --------- |
| Versioned        | 7 days    |
| Latest           | 24 hours  |
| Beta/canary      | 4 hours   |
| Package versions | 1 hour    |

**Decision:** Check manifest → fresh? use local → stale? update → not found? offer to clone.

**Parallel:** Run docs-sync check IN PARALLEL with librarian MCP tools (context7, websearch, grep_app).

---

### Interactive Commands (`interactive-commands`)

**When to apply:** Commands requiring TTY (sudo, SSH first-time, ssh-keygen, TUI).

**Rule:** Interactive commands → **pane-tester**, NOT bash tool.

**Triggers:**
- `sudo ...` on local or remote host
- SSH first-time host verification
- `ssh-keygen`, `gpg --gen-key`
- TUI: vim, htop, mc, pudb

**Workflow:**
1. `pane_create` — create pane
2. `pane_send "command"` — send command
3. Report: `ACTION_REQUIRED: Enter password in pane %X`
4. `sleep N && capture-pane` — check result

**Decision Matrix:**

| Command            | Bash | pane-tester |
| ------------------ | ---- | ----------- |
| `sudo`             | ❌   | ✅          |
| `ssh` (first time) | ❌   | ✅          |
| `ssh` (known host) | ✅   | optional    |
| `scp`              | ✅   | ❌          |
| TUI apps           | ❌   | ✅          |

**Details:** [rules/interactive-commands.md](./rules/interactive-commands.md)

---

### Action Logging (`action-logging`)

**When to apply:** After completing significant actions, setups, or decisions.

**Rule:** Document WHAT was done, WHY, and HOW in project `docs/` folder.

**Triggers:**
- Service setup/deployment
- Configuration changes
- Infrastructure changes (DNS, tunnels, networking)
- Backup/restore procedures
- Architecture decisions

**Log format:**
```markdown
# [Service] Setup
**Date:** YYYY-MM-DD
## What / Why / How
## Files / Commands / Verification
```

**Location:**
- Project actions → `project/docs/{topic}.md`
- Personal setup → `~/docs/{topic}.md`

**Details:** [rules/action-logging.md](./rules/action-logging.md)

---

## Adding New Rules

1. Create `~/.config/opencode/rules/{rule-id}.md`
2. Add entry to the Active Rules table above
3. Include quick reference in Quick Reference section

---

## Adding New Skills

1. Create `~/.config/opencode/skills/{skill-id}/SKILL.md`
2. Add entry to the Active Skills table above
3. Include description with trigger phrases

---

## Notes

- Rules are loaded at session start
- Skills are loaded via `load_skills=["skill-name"]` in task()
- Project-level `AGENTS.md` overrides global rules
- User-installed skills take priority over built-in skills
