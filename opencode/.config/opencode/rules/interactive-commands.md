# Rule: Interactive Commands

**ID:** `interactive-commands`
**Version:** 1.1
**Updated:** 2026-03-25

---

## Purpose

Defines when and how to use pane-tester for interactive commands instead of bash tool.

---

## Problem

Bash tool has no TTY. Commands requiring interactive input fail:

```
sudo: a terminal is required to read the password
ssh: Are you sure you want to continue connecting?
```

---

## Decision Matrix

| Command                        | Bash tool | pane-tester     |
| ------------------------------ | --------- | --------------- |
| `sudo ...` local               | ❌        | ✅              |
| `sudo ...` over SSH            | ❌        | ✅              |
| `ssh user@host` (first time)   | ❌        | ✅              |
| `ssh user@host` (known host)   | ✅        | ✅ (for session)|
| `scp`                          | ✅        | ❌ (not needed) |
| `ssh-keygen`                   | ❌        | ✅              |
| `gpg --gen-key`                | ❌        | ✅              |
| TUI (vim, htop, mc)            | ❌        | ✅              |
| Regular commands               | ✅        | ❌ (overkill)   |

---

## Workflow Patterns

### A. Single sudo command (remote host)

```bash
# 1. Create pane (if no SSH session yet)
tmux split-window -h -P -F "#{pane_id}"
# → %15

# 2. Establish SSH session
tmux send-keys -t %15 "ssh orangebot" Enter
sleep 3

# 3. Execute sudo command
tmux send-keys -t %15 "sudo rm -rf /something" Enter

# 4. Check for password prompt
tmux capture-pane -p -t %15 -S -5
# If "[sudo] password" visible → report ACTION_REQUIRED

# 5. After user enters password — verify result
sleep 5 && tmux capture-pane -p -t %15 -S -10
```

### B. SSH with host verification

```bash
# 1. SSH command
tmux send-keys -t %15 "ssh user@newhost" Enter
sleep 2

# 2. Check for "Are you sure"
OUTPUT=$(tmux capture-pane -p -t %15 -S -5)
if echo "$OUTPUT" | grep -q "Are you sure"; then
    tmux send-keys -t %15 "yes" Enter
    sleep 2
fi
```

### C. Heredoc via pane

```bash
# Heredoc does NOT work directly in send-keys
# Solution: write to /tmp file, then cat

# On remote host — line by line
tmux send-keys -t %15 "cat > ~/config.yml << 'EOF'" Enter
tmux send-keys -t %15 "content: here" Enter
tmux send-keys -t %15 "EOF" Enter
```

### D. Copying files with root permissions

```bash
# Problem: scp cannot overwrite root-owned files

# Solution: two-step process
# 1. Locally: sudo cp + chown
# 2. scp to target directory
# 3. Remotely: sudo chown if needed

# Example:
tmux send-keys -t %LOCAL_PANE "sudo cp -r ~/data /tmp/backup" Enter
# ... wait for password input ...
tmux send-keys -t %LOCAL_PANE "sudo chown -R \$USER:\$USER /tmp/backup" Enter
# ... wait for password input ...
tmux send-keys -t %LOCAL_PANE "scp -r /tmp/backup/* remote:~/target/" Enter
```

---

## ACTION_REQUIRED Pattern

When user input is required:

```
**ACTION_REQUIRED:** Enter sudo password in pane %15
```

After reporting:
1. DO NOT continue automatically
2. Wait for confirmation or sleep + capture
3. Verify command completed

---

## Common Mistakes

| Mistake                              | Correct                      |
| ------------------------------------ | ---------------------------- |
| `ssh host "sudo cmd"`                | pane + interactive           |
| `echo password \| sudo -S`           | pane + interactive (insecure)|
| `sudo cmd` in bash tool              | pane-tester                  |
| Forgot `sleep` after command         | Always `sleep N` before capture |
| Heredoc in send-keys as single line  | Write line by line or via /tmp |

---

## Integration with pane-tester Skill

pane-tester skill provides:
- `pane_create` — create pane
- `pane_send` — send command
- `pane_capture` — capture output
- `pane_wait_sudo` — wait for sudo password input

**This rule describes WHEN to use the skill, the skill describes HOW.**

---

## See Also

- [skills/pane-tester/SKILL.md](../skills/pane-tester/SKILL.md)
- [AGENTS.md - Active Rules](../AGENTS.md#active-rules)
