# Delegated Testing Details

Detailed examples and helpers for delegated testing. See SKILL.md for overview.

---

## Parent Agent: Environment Decision Helper

```typescript
interface EnvironmentDecision {
  type: 'pane_vertical' | 'window';
  reason: string;
  askUser: boolean;
}

function decideSubagentEnvironment(options: {
  stepsCount: number;
  parallelTests: number;
  expectedOutputLines: number;
}): EnvironmentDecision {
  
  // Auto-decide
  if (options.stepsCount > 15) {
    return {
      type: 'window',
      reason: `${options.stepsCount} steps → need more space`,
      askUser: false
    };
  }
  
  if (options.parallelTests > 1) {
    return {
      type: 'window',
      reason: 'Parallel tests → isolated windows',
      askUser: false
    };
  }
  
  if (options.expectedOutputLines > 500) {
    return {
      type: 'window',
      reason: 'Large output expected → window for scrollback',
      askUser: false
    };
  }
  
  // Borderline case - ask user
  if (options.stepsCount > 10 && options.stepsCount <= 15) {
    return {
      type: 'pane_vertical',
      reason: 'Default, but borderline',
      askUser: true  // Let user decide
    };
  }
  
  // Default
  return {
    type: 'pane_vertical',
    reason: 'Default for sub-agents',
    askUser: false
  };
}

// Usage
const decision = decideSubagentEnvironment({
  stepsCount: 12,
  parallelTests: 1,
  expectedOutputLines: 200
});

if (decision.askUser) {
  const choice = await ask_user(
    `Test has ${stepsCount} steps. Environment?`,
    [
      `1. Vertical pane (below) - ${decision.reason}`,
      '2. New window (isolated)'
    ],
    { default: '1' }
  );
  decision.type = choice === '2' ? 'window' : 'pane_vertical';
}

// Include in test plan
testPlan += `\n## ENVIRONMENT\n- TYPE: ${decision.type}\n- REASON: ${decision.reason}\n`;
```

---

## Test Plan Format (Strict)

For complex scenarios requiring precise control:

```markdown
## TEST PLAN

### Prerequisites
- Files needed: /tmp/config.yaml
- Cleanup script: /tmp/cleanup.sh
- Output dir: /tmp/pane-tester-XXXX

### Steps

#### Step 1: Create Pane
- ACTION: tmux split-window -h -P -F "#{pane_id}"
- EXPECT: pane_id like %XX
- SAVE: pane_id for subsequent steps

#### Step 2: Initialize Environment
- ACTION: echo "INIT_START" && sleep 2 && echo "INIT_OK"
- WAIT: 5 seconds
- EXPECT: "INIT_OK"
- ON_FAIL: Save output, report FAILURE, abort

#### Step 3: Run Check
- ACTION: test -f /etc/hosts && echo "CHECK_OK"
- WAIT: 2 seconds
- EXPECT: "CHECK_OK"

#### Step 4: Cleanup
- ACTION: sudo /tmp/cleanup.sh
- WAIT: 10 seconds
- EXPECT: "Cleanup complete"

#### Step 5: Kill Pane
- ACTION: tmux kill-pane -t ${PANE_ID}
- EXPECT: pane closed

### Result
After all steps:
- Generate summary: /tmp/pane-tester-XXXX/summary.md
- Report SUCCESS or FAILURE
```

---

## Result Report Structure

### Directory Structure

```
/tmp/pane-tester-{AGENT_ID}/
├── summary.md           # Human-readable summary
├── steps/
│   ├── 01_create_pane.txt
│   ├── 02_init_env.txt
│   ├── 03_run_check.txt
│   └── ...
├── error.txt            # Only if failure
├── result.json          # Machine-readable result
└── final_output.txt     # Full pane capture
```

### result.json

```json
{
  "status": "SUCCESS|FAILURE",
  "iteration": 1,
  "steps_total": 10,
  "steps_completed": 7,
  "steps_failed_at": "03_run_check",
  "error_message": "File not found: /etc/myconfig",
  "duration_seconds": 45,
  "logs_dir": "/tmp/pane-tester-a3f9",
  "timestamp": "2026-02-25T14:30:00Z"
}
```

### summary.md

```markdown
# Test Run Summary

**Status:** FAILURE
**Duration:** 45s
**Steps:** 7/10 completed

## Failure

**Step:** 03_run_check
**Error:** File not found: /etc/myconfig

## Output

Error: File not found: /etc/myconfig

## Completed Steps

1. ✅ create_pane
2. ✅ init_env

## Logs

- Step outputs: /tmp/pane-tester-a3f9/steps/
- Error log: /tmp/pane-tester-a3f9/error.txt
```

---

## Helper: Generate Test Plan from Skill

```bash
generate_test_plan() {
  local skill_file="$1"
  local output_file="$2"
  
  cat > ${output_file} << 'HEADER'
## TEST PLAN (Auto-generated)

### Prerequisites
- Cleanup script: /tmp/cleanup.sh
- Output dir: /tmp/pane-tester-${AGENT_ID}

### Steps

HEADER

  # Extract bash code blocks
  local step_num=0
  while IFS= read -r line; do
    if [[ "$line" =~ ^\`\`\`bash ]]; then
      in_block=true
      step_num=$((step_num + 1))
      echo "#### Step ${step_num}: Execute Command Block" >> ${output_file}
      echo "- ACTION:" >> ${output_file}
    elif [[ "$line" =~ ^\`\`\`$ ]] && [ "$in_block" = true ]; then
      in_block=false
      echo "" >> ${output_file}
      echo "- WAIT: 10 seconds" >> ${output_file}
      echo "- EXPECT: success marker or no error" >> ${output_file}
      echo "- ON_FAIL: Save output, report FAILURE, abort" >> ${output_file}
      echo "" >> ${output_file}
    elif [ "$in_block" = true ]; then
      echo "  ${line}" >> ${output_file}
    fi
  done < ${skill_file}
  
  # Add cleanup step
  cat >> ${output_file} << 'FOOTER'

#### Final Step: Cleanup
- ACTION: sudo /tmp/cleanup.sh
- WAIT: 10 seconds
- EXPECT: "Cleanup complete"

### Result
Generate summary and report.
FOOTER
}
```

---

## Example: Full Delegation Flow

```typescript
// 1. Prepare artifacts
await write_file("/tmp/cleanup.sh", cleanup_script);

// 2. Delegate to sub-agent
const taskId = task(
  category="quick",
  load_skills=["pane-tester"],
  run_in_background=true,
  description="Test bootstrap",
  prompt=testPlan
);

// 3. Monitor with watchdog
const statusFile = `/tmp/pane-tester-${taskId}/status.json`;
for (let waited = 0; waited < 300; waited += 30) {
  await sleep(30);
  const status = JSON.parse(await read_file(statusFile));
  if (status.status === 'complete' || status.status === 'failed') break;
}

// 4. Get result
const result = await background_output(taskId);

// 5. Handle result
if (result.includes("RESULT: SUCCESS")) {
  console.log("✅ Test passed");
} else {
  console.log("❌ Test failed");
  // Read logs, make decision
}
```

---

## Watchdog: Periodic Progress Checks

### Status File Pattern

Sub-agent writes progress to a status file that parent can poll:

```bash
STATUS_FILE="/tmp/pane-tester-${TASK_ID}/status.json"

# Sub-agent updates after each step:
echo '{
  "step": 3,
  "step_name": "create_network",
  "status": "in_progress",
  "timestamp": "2026-02-25T14:30:15Z",
  "steps_total": 10,
  "steps_completed": 2
}' > ${STATUS_FILE}
```

### Watchdog Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `check_interval` | 30s | Time between checks |
| `max_wait` | 600s | Maximum total wait time |
| `stuck_threshold` | 180s | Alert if same step for this long |
| `on_stuck` | "alert" | Action: `alert`, `cancel`, `continue` |

### Watchdog Decision Matrix

```
PROGRESS CHECK RESULT
│
├── status = "complete" ──────────► DONE, get result
├── status = "failed" ────────────► ERROR, get logs
├── status = "in_progress" ──────► Check for stuck:
│   ├── step changed ──► OK, continue
│   └── step same for > threshold
│       ├── on_stuck = "alert" ───► NOTIFY user
│       ├── on_stuck = "cancel" ──► CANCEL sub-agent
│       └── on_stuck = "continue" ► KEEP waiting
├── status file missing ──────────► WAIT (not started)
└── max_wait exceeded ─────────────► TIMEOUT, cancel
```

### Sub-Agent: Writing Status

```bash
update_status() {
  local step_num="$1"
  local step_name="$2"
  local status="$3"
  
  cat > ${STATUS_FILE} << EOF
{
  "task_id": "${TASK_ID}",
  "step": ${step_num},
  "step_name": "${step_name}",
  "status": "${status}",
  "timestamp": "$(date -Iseconds)",
  "steps_total": ${STEPS_TOTAL},
  "steps_completed": $((step_num - 1))
}
EOF
}
```

### Combined: Delegate + Watchdog

```typescript
// 1. Delegate test
const taskId = task(
  category="quick",
  load_skills=["pane-tester"],
  run_in_background=true,
  description="Test vpsemu bootstrap",
  prompt=testPlan
);

// 2. Start watchdog
const statusFile = `/tmp/pane-tester-${taskId}/status.json`;
let lastStep = '';
let lastStepTime = Date.now();

for (let waited = 0; waited < 600; waited += 30) {
  await sleep(30);
  
  try {
    const status = JSON.parse(await read_file(statusFile));
    console.log(`[${status.timestamp}] ${status.steps_completed}/${status.steps_total} - ${status.step_name}`);
    
    if (status.status === 'complete') {
      console.log("Test passed");
      break;
    }
    if (status.status === 'failed') {
      console.log("Test failed at:", status.step_name);
      break;
    }
    
    // Check for stuck (same step > 3 min)
    if (status.step_name !== lastStep) {
      lastStep = status.step_name;
      lastStepTime = Date.now();
    } else if ((Date.now() - lastStepTime) / 1000 > 180) {
      console.log("WARNING: Stuck on", status.step_name);
    }
  } catch (e) {
    console.log("Waiting for sub-agent...");
  }
}

// 3. Get full result
const result = await background_output(taskId);
```

---

## Parallel Testing

Run multiple tests in parallel with different sub-agents:

```typescript
// Launch multiple test agents
const task1 = task(
  category="quick",
  load_skills=["pane-tester"],
  run_in_background=true,
  description="Test bootstrap variant A",
  prompt="..." // Plan A
);

const task2 = task(
  category="quick",
  load_skills=["pane-tester"],
  run_in_background=true,
  description="Test bootstrap variant B",
  prompt="..." // Plan B
);

// Continue other work...

// Collect results when needed
const result1 = await background_output(task1);
const result2 = await background_output(task2);

// Compare results
```

---

*See SKILL.md for command reference and basic examples.*
