# Issue: Window vs Pane Decision

**Date:** 2025-02-25
**Status:** Open
**Priority:** High

## Problem

Agent incorrectly created a **new tmux session** (`tmux new-session -d -s vpsemu`) for interactive testing mode.

This is wrong because:
1. New session/window is **hidden** from user
2. User cannot see sudo password prompt
3. Breaks the interactive workflow

## Correct Behavior

### Interactive Mode (Parent Agent)
```
┌────────────────────────────────────────────────────────────┐
│  CURRENT WINDOW (where agent runs)                         │
│  ┌──────────────────────┬─────────────────────────────────┐│
│  │  AGENT PANE          │  TEST PANE (horizontal split)   ││
│  │  (orchestration)     │  (sudo prompts visible)         ││
│  └──────────────────────┴─────────────────────────────────┘│
└────────────────────────────────────────────────────────────┘

Command: tmux split-window -h -P -F "#{pane_id}"
```

### Delegated Mode (Sub-Agent)
```
┌────────────────────────────────────────────────────────────┐
│  NEW WINDOW (isolated)                                     │
│  ┌────────────────────────────────────────────────────────┐│
│  │  SUB-AGENT TEST PANE                                   ││
│  │  (autonomous execution, no sudo interaction needed)    ││
│  └────────────────────────────────────────────────────────┘│
└────────────────────────────────────────────────────────────┘

Command: tmux new-window -P -F "#{pane_id}"
```

## Rule

| Mode | Command | Visibility |
|------|---------|------------|
| Interactive (parent) | `tmux split-window -h` | User sees pane |
| Delegated (sub-agent) | `tmux new-window` | Isolated |

## Files to Update

- [ ] `SKILL.md` — Add explicit rule in "test_environment_choose" section
- [ ] `examples/delegated-testing-details.md` — Clarify window usage

## Action Items

1. Update SKILL.md with clear distinction
2. Add warning in docs about not using new-session/new-window for interactive
3. Consider adding `pane_create_interactive` vs `pane_create_delegated` helpers

---

*Created during vpsemu bootstrap testing session*
