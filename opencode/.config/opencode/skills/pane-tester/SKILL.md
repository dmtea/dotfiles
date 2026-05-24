---
name: pane-tester
version: 0.6
description: tmux pane testing framework for CLI skills requiring sudo, interactive input, multi-step processes, and output capture. TRIGGERS: pane, pane-tester, tmux pane, sudo, interactive, TUI
tools: [Bash, Read, Write]
---

# pane-tester

**Version:** 0.6

---

## Quick Reference

| Command | Description |
|---------|-------------|
| `pane_create` | Create new tmux pane (horizontal/vertical) |
| `pane_send` | Send command to pane |
| `pane_capture` | Capture pane output |
| `pane_expect` | Send command + verify output |
| `pane_save` | Save output to file |
| `pane_cleanup` | Run cleanup script |
| `pane_reset` | Kill pane + create new one |
| `test_init` | Initialize test session |
| `test_step` | Execute step + verify marker |
| `test_report` | Generate summary report |
| `test_delegate` | Delegate test to sub-agent |

---

## Purpose

Skill for testing CLI-based skills and scripts that require:
- `sudo` access (password input)
- Multi-step processes with verification
- Output capture for analysis
- Cleanup between test iterations
- Isolated test environments (tmux panes)



## Namespace

```
pane-tester-{AGENT_ID}-{TASK_NAME}
```

## ⚡ Initialization

### MANDATORY: tmux Availability Check

**BEFORE any pane operation**, the agent MUST verify that OpenCode is actually running inside tmux:

```bash
echo "TMUX=$TMUX"
```

- If `$TMUX` is **empty** → OpenCode is NOT in tmux → **pane-tester CANNOT be used**
- If `$TMUX` is **set** (e.g. `/tmp/tmux-1000/default,12345,0`) → OpenCode IS in tmux → proceed

**NEVER assume tmux is available just because `tmux list-sessions` shows sessions.**
Stale sessions from previous runs do NOT mean the current OpenCode instance is in tmux.

**If tmux is NOT available:**

1. **STOP immediately** — do not attempt any pane operations
2. **Ask the user what they prefer:**
   - Restart OpenCode inside tmux: `tmux new-session -s opencode`
   - Run the commands manually themselves
   - Other approach the user suggests
3. **Do this BEFORE starting work** — as soon as you realize pane-tester will be needed, check tmux and resolve the blocker upfront. Don't wait until the middle of work to discover tmux is missing.
4. **NEVER ask for passwords.** VM passwords are a documented exception for test environments only. Host passwords are never requested, stored, or piped into commands.

**Goal: handle it once at the start, then work without interruptions.**

### Alert Sound

When agent needs user attention (password prompt, decision, checkpoint), play a sound:

```bash
paplay /usr/share/sounds/freedesktop/stereo/message-new-instant.oga
```

Use this whenever the agent outputs `ACTION_REQUIRED` or waits for human input.
This helps if the user is on another workspace (browser, etc.).

### Agent ID Generation

On skill load (after tmux check passes), agent immediately runs:

```bash
AGENT_ID=$(openssl rand -hex 2)   # e.g.: a3f9
```

Agent remembers `AGENT_ID` as a critical session fact.

## Variables

```bash
PANE_ID=""                    # Set by pane_create, e.g.: %17
ITERATION=0                   # Incremented each reset
OUTPUT_DIR="/tmp/pane-tester-${AGENT_ID}"
CLEANUP_SCRIPT=""             # Optional, set by test_cleanup_set
CURRENT_TEST=""               # Test name for output files
```

## Commands

### pane_create

Create new tmux pane for testing.

**Parameters:**
- `direction` — `auto` (default), `horizontal`, or `vertical`
- `mode` — `pane` (default) or `window`

**Auto-detection (default):**
```bash
# Determine split direction based on current pane position
CURRENT_PANE=$(tmux display-message -p "#{pane_id}")
MAIN_PANE=$(tmux list-panes -F "#{pane_id}" | head -1)

if [ "$CURRENT_PANE" = "$MAIN_PANE" ]; then
    PANE_ID=$(tmux split-window -h -P -F "#{pane_id}")   # main → right column
else
    PANE_ID=$(tmux split-window -v -P -F "#{pane_id}")   # right column → stack below
fi
```

**Explicit direction:**
```bash
# Force horizontal (right)
PANE_ID=$(tmux split-window -h -P -F "#{pane_id}")

# Force vertical (below)
PANE_ID=$(tmux split-window -v -P -F "#{pane_id}")
```

**Agent action:**
1. Execute split-window with chosen direction
2. Store returned pane_id in PANE_ID
3. Increment ITERATION

### window_create

Create new tmux window for isolated testing.

```bash
# Create new window and get pane_id directly
PANE_ID=$(tmux new-window -P -F "#{pane_id}")
```

**Alternative (get window_id first):**
```bash
WINDOW_ID=$(tmux new-window -P -F "#{window_id}")
PANE_ID=$(tmux display-message -p "#{pane_id}" -t ${WINDOW_ID})
```

**Parameters:**
- `name` — Optional window name (e.g., "pane-tester-bootstrap")
- `attach` — Attach to window after creation (default: true)


### test_environment_choose

Interactive or automatic selection of test environment.

**Rule: ALWAYS ask the user. No automatic decisions.**

```bash
choose_test_environment() {
  # NO automatic rules — always ask user
  echo "ASK_USER"
}
```

**Interactive mode (ALWAYS, no auto):**

```
How should I run the test?

  1. Pane (right column, stacked) - Default
  2. New window (isolated)

Select [1-2] or press Enter for default (pane):
```

**Parameters:**
- `interactive` — ALWAYS true (default: true, cannot be disabled)


### Window vs Pane Decision Matrix

```
┌─────────────────────────────────────────────────────────────┐
│              ENVIRONMENT DECISION                             │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ALWAYS ASK USER. No automatic decisions.                    │
│                                                              │
│  Options:                                                    │
│  1. PANE in right column (split-window -h) — DEFAULT         │
│  2. NEW WINDOW (isolated) — user explicitly chooses          │
│                                                              │
│  Pane direction:                                             │
│      Current pane is MAIN (left)?                            │
│      └── YES ──► split-window -h (create right column)      │
│                                                              │
│      Current pane is in RIGHT column?                        │
│      └── YES ──► split-window -v (stack below)              │
│                                                              │
│  DEFAULT: pane, -h from main, -v from right column           │
│  OVERRIDE: user choice takes precedence                      │
└─────────────────────────────────────────────────────────────┘
```

### Implementation: Auto + Interactive

```typescript
interface TestEnvironment {
  type: 'pane' | 'window';
  paneId?: string;
  windowId?: string;
}

async function setupTestEnvironment(options: {
  stepsCount: number;
  parallelTests: number;
  longRunning: boolean;
  direction?: 'horizontal' | 'vertical';  // explicit override
}): Promise<TestEnvironment> {
  
  // Window for complex cases
  if (options.stepsCount > 15 || options.parallelTests > 1 || options.longRunning) {
    const windowId = await tmux_new_window({ name: 'pane-tester' });
    return { type: 'window', windowId };
  }

  // Pane — determine split direction
  let splitDir: string;
  
  if (options.direction) {
    // Explicit override
    splitDir = options.direction === 'vertical' ? '-v' : '-h';
  } else {
    // Auto-detect: main pane → -h, right column → -v
    const currentPane = tmux_display_message('#{pane_id}');
    const mainPane = tmux_list_panes('-F #{pane_id}')[0];
    splitDir = currentPane === mainPane ? '-h' : '-v';
  }

  const paneId = await tmux_split_window(splitDir);
  return { type: 'pane', paneId };
}
```



Create new tmux pane for testing.

```bash
# Returns pane_id like %17
tmux split-window -h -P -F "#{pane_id}"
```

**Agent action:**
1. Execute split-window
2. Store returned pane_id in PANE_ID
3. Increment ITERATION

### pane_send

Send command to pane.

```bash
# Single command
tmux send-keys -t ${PANE_ID} "command" Enter

# Multi-line (heredoc alternative - write to file first)
echo "content" > /tmp/pane-tester-config.yaml
tmux send-keys -t ${PANE_ID} "cat /tmp/pane-tester-config.yaml | command" Enter
```

**Parameters:**
- `command` — Command string to send
- `wait` — Seconds to wait after sending (default: 2)

### pane_capture

Capture pane output.

```bash
tmux capture-pane -p -t ${PANE_ID} -S -${LINES}
```

**Parameters:**
- `lines` — Number of lines to capture (default: 20, use 3000 for full)
- `save` — Optional filename to save output

**Returns:** Output text

### pane_expect

Send command and verify expected output.

```bash
# 1. Send command
tmux send-keys -t ${PANE_ID} "${COMMAND}" Enter

# 2. Wait
sleep ${TIMEOUT}

# 3. Capture and check
OUTPUT=$(tmux capture-pane -p -t ${PANE_ID} -S -50)
echo "${OUTPUT}" | grep -q "${EXPECTED}" && echo "PASS" || echo "FAIL"
```

**Parameters:**
- `command` — Command to execute
- `expect` — String or regex to match in output
- `timeout` — Seconds to wait (default: 10)
- `marker` — Optional: append `&& echo 'MARKER_OK'` to command

**Returns:** `PASS` or `FAIL` with captured output

### pane_wait_sudo

Wait for user to enter sudo password.

```bash
# Check if password prompt visible
OUTPUT=$(tmux capture-pane -p -t ${PANE_ID} -S -10)
if echo "${OUTPUT}" | grep -q "password"; then
  echo "ACTION_REQUIRED: Enter sudo password in pane ${PANE_ID}"
  # Wait for user confirmation
fi
```

**Agent action:**
1. After first sudo command, check for password prompt
2. Notify user to enter password
3. Wait for user confirmation ("y")
4. Verify sudo worked

### pane_save

Save current pane output to file.

```bash
mkdir -p ${OUTPUT_DIR}
tmux capture-pane -p -t ${PANE_ID} -S -3000 > "${OUTPUT_DIR}/${FILENAME}"
```

**Parameters:**
- `filename` — Output filename (will be prefixed with iteration)

### pane_cleanup

Run cleanup script/command.

```bash
tmux send-keys -t ${PANE_ID} "${CLEANUP_SCRIPT}" Enter
sleep 8
tmux capture-pane -p -t ${PANE_ID} -S -20
# Verify cleanup markers
```

**Parameters:**
- `script` — Path to cleanup script or inline command
- `verify` — Optional string to verify cleanup succeeded

### pane_reset

Kill current pane and create new one.

```bash
tmux kill-pane -t ${PANE_ID}
# New pane: auto-detect direction (will be -v since we're in right column)
CURRENT_PANE=$(tmux display-message -p "#{pane_id}")
MAIN_PANE=$(tmux list-panes -F "#{pane_id}" | head -1)
if [ "$CURRENT_PANE" = "$MAIN_PANE" ]; then
    PANE_ID=$(tmux split-window -h -P -F "#{pane_id}")
else
    PANE_ID=$(tmux split-window -v -P -F "#{pane_id}")
fi
ITERATION=$((ITERATION + 1))
```

**Agent action:**
1. Save output if unsaved
2. Kill pane
3. Create new pane
4. Store new PANE_ID
5. Increment ITERATION

### test_init

Initialize test session.

```bash
mkdir -p ${OUTPUT_DIR}
ITERATION=0
echo "Test session initialized: ${OUTPUT_DIR}"
```

**Parameters:**
- `name` — Test name (used for output files)
- `cleanup_script` — Optional path to cleanup script

### test_step

Execute and verify a test step.

```bash
# 1. Send command with marker
COMMAND="${CMD} && echo '${MARKER}_OK'"
tmux send-keys -t ${PANE_ID} "${COMMAND}" Enter

# 2. Wait
sleep ${TIMEOUT}

# 3. Capture
OUTPUT=$(tmux capture-pane -p -t ${PANE_ID} -S -${LINES})

# 4. Check for marker
if echo "${OUTPUT}" | grep -q "${MARKER}_OK"; then
  STATUS="PASS"
elif echo "${OUTPUT}" | grep -qi "error\|failed"; then
  STATUS="FAIL"
else
  STATUS="UNKNOWN"
fi

# 5. Save output
echo "${OUTPUT}" > "${OUTPUT_DIR}/${TEST_NAME}_iter${ITERATION}_${MARKER}.txt"
```

**Parameters:**
- `command` — Command to execute
- `marker` — Success marker (will check for `{MARKER}_OK`)
- `timeout` — Wait time in seconds
- `lines` — Lines to capture (default: 30)
- `on_fail` — Action: `abort`, `continue`, `cleanup` (default: `abort`)

**Returns:** 
- `PASS` — Marker found
- `FAIL` — Error detected
- `UNKNOWN` — Neither found

### test_report

Generate report from all outputs.

```bash
# Combine all outputs
cat ${OUTPUT_DIR}/*.txt > ${OUTPUT_DIR}/full_report.txt

# Generate summary
echo "# Test Report" > ${OUTPUT_DIR}/summary.md
echo "" >> ${OUTPUT_DIR}/summary.md
echo "Iterations: ${ITERATION}" >> ${OUTPUT_DIR}/summary.md
echo "Files: $(ls ${OUTPUT_DIR}/*.txt | wc -l)" >> ${OUTPUT_DIR}/summary.md
```

**Parameters:**
- `combine` — Combine all outputs into single file
- `summary` — Generate summary markdown

## Workflow Template

```
1. test_init --name "my_test" --cleanup "/path/to/cleanup.sh"

2. pane_create → PANE_ID=%17

3. test_step --command "echo 'Step 1' && sleep 2" --marker "STEP1" --timeout 10
   → If sudo password needed: pane_wait_sudo

4. test_step --command "test -f /etc/hosts" --marker "CHECK" --timeout 5

5. test_step --command "cat /etc/hostname" --marker "HOSTNAME" --timeout 3

6. pane_save --filename "final_state.txt"

7. pane_cleanup --verify "Cleanup complete"

8. pane_reset

9. test_report --combine --summary
```
```


## Output File Naming

```
{OUTPUT_DIR}/{test_name}_iter{N}_{step}.txt

Examples:
  /tmp/pane-tester-a3f9/bootstrap_iter0_INIT.txt
  /tmp/pane-tester-a3f9/bootstrap_iter0_NETWORK.txt
  /tmp/pane-tester-a3f9/bootstrap_iter1_INIT.txt
  /tmp/pane-tester-a3f9/full_report.txt
```

## Error Handling

### On FAIL:
1. Save output immediately
2. Ask user: `continue`, `fix`, `abort`, `cleanup`
3. If `cleanup` → pane_cleanup → pane_reset
4. If `abort` → test_report → exit

### On pane stuck:
1. Try `Ctrl+C`: `tmux send-keys -t ${PANE_ID} C-c`
2. If still stuck: pane_reset

## Heredoc Pattern

For multi-line configs, use file redirect:

```bash
# Create config via bash
cat > /tmp/pane-tester-config.yaml << 'EOF'
config:
  key: value
devices:
  eth0:
    type: nic
EOF

# Reference in pane
pane_send --command "cat /tmp/pane-tester-config.yaml | my_command"
```


## Integration with vpsemu

This skill can be used to test vpsemu:

```
1. Load both skills: pane-tester, vpsemu
2. test_init --name "vpsemu_bootstrap" --cleanup "/path/to/vpsemu-cleanup.sh"
3. pane_create
4. Execute vpsemu bootstrap commands via test_step
5. Verify each step
6. pane_cleanup
7. pane_reset
8. test_report
```

---

## Example: SSH + sudo Workflow

Full example for remote host with sudo:

```bash
# 1. Create pane
PANE_ID=$(tmux split-window -h -P -F "#{pane_id}")
echo "Created pane: $PANE_ID"

# 2. Establish SSH session
tmux send-keys -t $PANE_ID "ssh user@hostname" Enter
sleep 3

# 3. Check host verification (first time)
OUTPUT=$(tmux capture-pane -p -t $PANE_ID -S -5)
if echo "$OUTPUT" | grep -q "Are you sure"; then
    tmux send-keys -t $PANE_ID "yes" Enter
    sleep 2
fi

# 4. Execute sudo command
tmux send-keys -t $PANE_ID "sudo systemctl status docker" Enter
sleep 2

# 5. Check for password prompt
OUTPUT=$(tmux capture-pane -p -t $PANE_ID -S -5)
if echo "$OUTPUT" | grep -q "password"; then
    echo "**ACTION_REQUIRED:** Enter sudo password in pane $PANE_ID"
    # Wait for user input (sleep or user confirmation)
    sleep 10
fi

# 6. Verify result
sleep 5
OUTPUT=$(tmux capture-pane -p -t $PANE_ID -S -20)
echo "$OUTPUT"

# 7. (Optional) Close pane
tmux kill-pane -t $PANE_ID
```

**Key points:**
- Always `sleep` after send-keys before capture
- Check output for "password" / "Are you sure"
- Report ACTION_REQUIRED for user input

## Security Notes

1. `AGENT_ID` generated once, never written to disk
2. Output files in `/tmp/` — cleared on reboot
3. Sudo password never logged
4. Cleanup script should validate before destructive operations


---

## 🧪 Experimental Features

These features are experimental and may change based on testing feedback.

---

### block_run (Experimental)

Execute a block of commands from a skill (like bootstrap section) in one go.

#### Mode A: As-Is Execution

Run block exactly as written in the source skill.

```bash
# Parse block from skill file
BLOCK=$(sed -n '/```bash/,/```/p' skill.md | head -n -1 | tail -n +2)

# Write to temp script
echo "#!/bin/bash" > /tmp/pane-tester-block.sh
echo "${BLOCK}" >> /tmp/pane-tester-block.sh
chmod +x /tmp/pane-tester-block.sh

# Execute in pane
tmux send-keys -t ${PANE_ID} "/tmp/pane-tester-block.sh" Enter
```

**Parameters:**
- `source` — Path to skill file or inline block
- `block_name` — Name of block to extract (e.g., "bootstrap", "cleanup")
- `timeout` — Total timeout for block execution (default: 120)

#### Mode B: Chained Execution

Convert block to single chained command with `&&`.

```bash
# Parse and chain commands
COMMANDS=$(echo "$BLOCK" | grep -v '^#' | grep -v '^$' | tr '\n' ' && ')
COMMANDS="${COMMANDS% && *}"  # Remove trailing ' &&'

# Execute chained command
tmux send-keys -t ${PANE_ID} "${COMMANDS}" Enter
```

**Improved Chaining:**

```bash
# Smart chain with error markers
chain_commands() {
  local block="$1"
  local marker="$2"
  local cmd_num=0
  local chained=""
  
  while IFS= read -r line; do
    # Skip comments and empty lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue
    
    cmd_num=$((cmd_num + 1))
    
    # Add step marker between commands
    if [ -n "$chained" ]; then
      chained="${chained} && echo 'STEP_${marker}_${cmd_num}_OK' && "
    fi
    chained="${chained}${line}"
  done <<< "$block"
  
  # Add final marker
  echo "${chained} && echo 'BLOCK_${marker}_COMPLETE'"
}
```

**Parameters:**
- `mode` — `asis` or `chained`
- `step_markers` — Add markers between commands (default: true for chained)
- `fail_fast` — Stop on first error (default: true)

#### Block Verification

```bash
# After block execution, capture and verify
tmux capture-pane -p -t ${PANE_ID} -S -100 > ${OUTPUT_DIR}/block_output.txt

# Check for completion marker
if grep -q "BLOCK_${MARKER}_COMPLETE" ${OUTPUT_DIR}/block_output.txt; then
  echo "BLOCK PASS"
  
  # Verify each step
  STEPS=$(grep -c "STEP_${MARKER}_[0-9]*_OK" ${OUTPUT_DIR}/block_output.txt)
  echo "Steps completed: ${STEPS}"
else
  echo "BLOCK FAIL"
  
  # Find which step failed
  LAST_OK=$(grep "STEP_${MARKER}_[0-9]*_OK" ${OUTPUT_DIR}/block_output.txt | tail -1)
  echo "Last successful step: ${LAST_OK}"
fi
```

---

### debug_mode (Experimental)

Structured debugging and solution-finding mode.

#### Activation

```bash
# Enable debug mode
debug_mode=true
DEBUG_LOG="${OUTPUT_DIR}/debug_session.md"

echo "# Debug Session - $(date)" > ${DEBUG_LOG}
echo "" >> ${DEBUG_LOG}
echo "## Problem" >> ${DEBUG_LOG}
```

#### Debug Workflow

1. **CAPTURE** — Save current state, record error
2. **PROPOSE** — Ask user: auto-investigate or manual?
3. **INVESTIGATE** — Check logs, verify prerequisites, try known fixes
4. **RECORD** — Document findings and hypotheses
5. **SOLUTION** — List possible fixes with confidence levels
6. **APPLY** — Execute fix, verify, record outcome
7. **ITERATE** — If not fixed, back to step 3


#### Debug Functions

Full implementations available in `examples/debug-helpers.sh`

| Function | Purpose |
|----------|---------|
| `debug_init` | Initialize debug environment |
| `debug_capture` | Capture failure state |
| `debug_propose` | Show investigation options |
| `debug_investigate` | Run investigation steps |
| `debug_solution_add` | Add solution to database |
| `debug_solution_search` | Search solutions |
| `debug_try_fix` | Attempt fix + record result |
| `debug_summary` | Generate session summary |

**Quick usage:**
```bash
source examples/debug-helpers.sh
debug_init
debug_capture "Bootstrap failed"
debug_propose "Network error"
# User selects option...
debug_summary
```


---

### Usage Example: Block Run + Debug

See `examples/debug-helpers.sh` for full implementation.

```bash
pane_create
block_run --source "skill.md" --block_name "bootstrap" --mode "chained"
if [ $? -ne 0 ]; then
  debug_capture "Failed"
  debug_propose "Error"
  debug_summary
fi
```

---

## Experimental Feature Flags

```bash
# Enable/disable experimental features
PANE_TESTER_EXPERIMENTAL_BLOCK_RUN=true
PANE_TESTER_EXPERIMENTAL_DEBUG_MODE=true
PANE_TESTER_BLOCK_STEP_MARKERS=true
PANE_TESTER_AUTO_DEBUG=false  # Auto-enter debug on failure
```

---

*Experimental features added: $(date)*

---

## 🚀 Delegated Testing (Sub-Agent Mode)

Run testing in a sub-agent with a fast model. Parent agent only receives final results or errors.

---

### Why Sub-Agent Testing?

| Aspect | Parent Agent | Sub-Agent |
|--------|--------------|-----------|
| Model | Powerful, slow | Fast, cheap |
| Role | Orchestration, decisions | Execution, monitoring |
| Attention | Full context | Focused task |
| Cost | High | Low |
| Parallelization | Sequential | Can run multiple |

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    PARENT AGENT                              │
│  (Powerful model - orchestration & decisions)                │
├─────────────────────────────────────────────────────────────┤
│  1. Define test plan (strict algorithm)                     │
│  2. Choose environment (pane vs window)                      │
│  3. Delegate to sub-agent                                    │
│  4. Watchdog: periodic progress checks                       │
│  5. Receive result: SUCCESS / ERROR + logs                   │
│  6. Make decisions based on result                           │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        │ task(category="quick", ...)
                        ▼
┌─────────────────────────────────────────────────────────────┐
│                    SUB-AGENT                                  │
│  (Fast model - strict execution only)                        │
├─────────────────────────────────────────────────────────────┤
│  1. Receive test plan + environment choice                   │
│  2. Create pane/window as specified                          │
│  3. Execute each step EXACTLY as specified                   │
│  4. Write progress to status file                            │
│  5. DO NOT deviate, improvise, or optimize                   │
│  6. Capture outputs to files                                 │
│  7. Return structured result                                 │
│  8. On error: capture + abort (no debugging)                 │
└─────────────────────────────────────────────────────────────┘
```

### Environment Decision

**Layout principle: all panes live in the right column, stacked vertically.**

```
┌──────────────────────┬──────────────────────┐
│                      │  pane 1 (from main)  │
│                      ├──────────────────────┤
│   MAIN PANE          │  pane 2 (stacked)    │
│   (parent agent)     ├──────────────────────┤
│                      │  sub-agent pane      │
│                      │  ┌─ sub-sub-pane ──┐ │
│                      │  │ (below sub-agent)│ │
│                      │  └─────────────────┘ │
└──────────────────────┴──────────────────────┘
```

**Split rule:**

| Who opens pane             | Split direction | Why                                    |
|----------------------------|-----------------|----------------------------------------|
| Parent agent (main pane)   | `-h` (right)    | Creates the right column               |
| Any agent in right column  | `-v` (below)    | Stacks below in the right column       |

```bash
# From main pane → creates right column
tmux split-window -h -P -F "#{pane_id}"

# From any right-column pane → stacks below
tmux split-window -v -P -F "#{pane_id}"
```

**Auto-detection:**

```bash
# Determine if current pane is in main column or right column
CURRENT_PANE=$(tmux display-message -p "#{pane_id}")
MAIN_PANE=$(tmux list-panes -F "#{pane_id}" | head -1)

if [ "$CURRENT_PANE" = "$MAIN_PANE" ]; then
    SPLIT_DIR="-h"   # main pane → open right column
else
    SPLIT_DIR="-v"   # right column → stack below
fi

PANE_ID=$(tmux split-window $SPLIT_DIR -P -F "#{pane_id}")
```

**Override:** explicit `direction=horizontal` or `direction=vertical` parameter
takes precedence over auto-detection.


### test_delegate

Delegate testing to sub-agent.

**Parent Agent Usage:**

```typescript

task(
  category="quick",  // FAST model
  load_skills=["pane-tester"],
  run_in_background=true,  // Or false to wait
  description="Test vpsemu bootstrap",
  prompt=`
## TASK
Execute the following test plan EXACTLY. Do NOT deviate.

## TEST PLAN (TODOS)
- [ ] Create tmux pane
- [ ] Run: echo "Step 1: Initialize" && sleep 2 && echo "STEP1_OK"
- [ ] Verify: expect "STEP1_OK"
- [ ] Run: test -f /etc/hosts && echo "HOSTS_OK"
- [ ] Verify: expect "HOSTS_OK"
- [ ] Run: cat /etc/hostname
- [ ] Verify: output is not empty
- [ ] Run: echo "Test complete"
- [ ] Verify: expect "Test complete"
- [ ] Run cleanup script: /tmp/cleanup.sh
- [ ] Kill pane

## OUTPUT REQUIREMENTS
- Save each step output to: /tmp/pane-tester-{AGENT_ID}/step_N.txt
- On ANY error: immediately save output and report FAILURE
- On success: report SUCCESS with summary

## RESULT FORMAT
End your response with exactly:

\`\`\`
RESULT: SUCCESS | FAILURE
ITERATION: N
STEPS_COMPLETED: N
STEPS_TOTAL: N
LAST_STEP: step_name
ERROR_IF_ANY: error_message_or_none
LOGS_DIR: /path/to/logs
SUMMARY_FILE: /path/to/summary.md
\`\`\`

## CRITICAL RULES
1. Follow plan EXACTLY - no improvisation
2. Use exact commands provided - no modifications
3. Wait for each command to complete before next
4. Capture output after each step
5. On failure: STOP immediately, report, do NOT retry or debug
`
)
```

**Parameters for test_delegate:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `plan` | string | Step-by-step test plan (todos format) |
| `skill` | string | Skill to test (e.g., "vpsemu") |
| `cleanup` | string | Path to cleanup script |
| `background` | bool | Run in background (default: true) |
| `on_error` | string | `abort`, `report`, `ignore` (default: `abort`) |
| `timeout` | int | Max time in seconds (default: 600) |

---

### Test Plan Format (Strict)

For complex scenarios requiring precise control, see `examples/delegated-testing-details.md`


### Sub-Agent Rules (CRITICAL)

**The sub-agent MUST:**

1. **Execute EXACT commands** — No modifications, no "optimizations"
2. **Wait specified time** — Use exact sleep durations
3. **Check EXPECT strings** — Verify output contains expected text
4. **Save outputs** — Write to specified files
5. **Stop on failure** — No retry, no debug, just report
6. **Follow order** — Steps in exact sequence

**The sub-agent MUST NOT:**

1. **Improvise commands** — Use only what's specified
2. **Skip steps** — Execute all steps in order
3. **Add logic** — No conditionals beyond success/fail check
4. **Debug errors** — Just capture and report
5. **Modify expectations** — Check for exact strings
6. **Optimize** — No parallel execution unless specified

---

### Parent Agent: Handling Results

**Check result from sub-agent:**

```typescript
const result = await background_output(task_id);

if (result.includes("RESULT: SUCCESS")) {
  // All steps passed
  console.log("Test passed!");
  // Continue with confidence
} else {
  // Failure occurred
  const match = result.match(/LAST_STEP: (.+)/);
  const failedStep = match ? match[1] : "unknown";
  
  const logsMatch = result.match(/LOGS_DIR: (.+)/);
  const logsDir = logsMatch ? logsMatch[1] : null;
  
  console.log(`Test failed at: ${failedStep}`);
  console.log(`Logs available at: ${logsDir}`);
  
  // Read detailed logs
  const errorLog = await read_file(`${logsDir}/error.txt`);
  
  // Make decision: retry, fix, or abort
}
```

---

### Parallel Testing

Run multiple tests in parallel with different sub-agents. See `examples/delegated-testing-details.md`

---
---

### Result Report Structure

**Minimal result.json:**
```json
{
  "status": "SUCCESS|FAILURE",
  "steps_completed": 7,
  "steps_total": 10,
  "error_message": "..."
}
```

Full format: `examples/delegated-testing-details.md`


### Helper: Generate Test Plan from Skill

Full implementation: `examples/delegated-testing-details.md`



### Example: Full Delegation Flow

Full example: `examples/delegated-testing-details.md`

---

### Watchdog: Periodic Progress Checks

Parent agent periodically checks sub-agent progress. Full implementation: `examples/delegated-testing-details.md`

**Basic pattern:**
```typescript
const statusFile = `/tmp/pane-tester-${taskId}/status.json`;
while (totalWaited < maxWaitTime) {
  await sleep(checkInterval);
  const status = JSON.parse(await read_file(statusFile));
  if (status.status === "complete" || status.status === "failed") break;
}
```

---

## Delegation Feature Flags

```bash
PANE_TESTER_DELEGATION_ENABLED=true
PANE_TESTER_DELEGATION_MODEL="quick"  # Category for sub-agent
PANE_TESTER_DELEGATION_TIMEOUT=600    # 10 minutes max
PANE_TESTER_DELEGATION_PARALLEL=3     # Max parallel sub-agents
```

---

*Delegated testing added: $(date)*

