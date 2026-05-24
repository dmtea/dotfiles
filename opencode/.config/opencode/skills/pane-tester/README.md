# pane-tester

A skill for testing CLI-based skills and scripts using tmux panes.

## Purpose

Test CLI skills that require:
- `sudo` access (password input)
- Multi-step processes with verification
- Output capture for analysis
- Cleanup between test iterations
- Isolated test environments (tmux panes)

## Version

Current: **0.6**

## Files

| File | Description |
|------|-------------|
| `SKILL.md` | Main skill definition |
| `TODO.md` | Tasks for next versions |

## Quick Start

```
1. Load skill: pane-tester
2. Create pane: pane_create
3. Run commands: pane_send, pane_expect
4. Capture output: pane_capture, pane_save
5. Cleanup: pane_cleanup, pane_reset
```

## Core Commands

| Command | Description |
|---------|-------------|
| `pane_create` | Create new tmux pane |
| `pane_send` | Send command to pane |
| `pane_capture` | Capture pane output |
| `pane_expect` | Send + verify output |
| `pane_save` | Save output to file |
| `pane_cleanup` | Run cleanup script |
| `pane_reset` | Kill pane + create new |
| `test_init` | Initialize test session |
| `test_step` | Execute + verify step |
| `test_report` | Generate report |

## Experimental Features

- **block_run** — Execute multi-command blocks
- **debug_mode** — Structured debugging workflow
- **delegated_testing** — Sub-agent execution with watchdog

## License

Part of OpenCode skills ecosystem.
