# Generic Test Example

Complete example of testing a CLI script using pane-tester.

## Test Target

```bash
# /tmp/my_script.sh
#!/bin/bash
echo "Starting deployment..."
sleep 2
echo "Checking prerequisites..."
test -f /etc/hosts && echo "PREREQ_OK"
sleep 1
echo "Deployment complete"
```

## Test Session

### 1. Initialize

```bash
# Agent generates AGENT_ID
AGENT_ID=$(openssl rand -hex 2)

# Set variables
OUTPUT_DIR="/tmp/pane-tester-${AGENT_ID}"
mkdir -p ${OUTPUT_DIR}
ITERATION=0
CURRENT_TEST="generic_test"
```

### 2. Create Pane

```bash
PANE_ID=$(tmux split-window -h -P -F "#{pane_id}")
ITERATION=$((ITERATION + 1))
echo "Created pane: ${PANE_ID}"
```

### 3. Execute Steps

```bash
# Step 1: Make script executable
tmux send-keys -t ${PANE_ID} "chmod +x /tmp/my_script.sh && echo 'STEP1_OK'" Enter
sleep 3
OUTPUT=$(tmux capture-pane -p -t ${PANE_ID} -S -20)
echo "${OUTPUT}" > "${OUTPUT_DIR}/iter${ITERATION}_step1.txt"
echo "${OUTPUT}" | grep -q "STEP1_OK" && echo "PASS: Step 1" || echo "FAIL: Step 1"

# Step 2: Run script
tmux send-keys -t ${PANE_ID} "/tmp/my_script.sh" Enter
sleep 5
OUTPUT=$(tmux capture-pane -p -t ${PANE_ID} -S -30)
echo "${OUTPUT}" > "${OUTPUT_DIR}/iter${ITERATION}_step2.txt"
echo "${OUTPUT}" | grep -q "PREREQ_OK" && echo "PASS: Step 2" || echo "FAIL: Step 2"

# Step 3: Verify output
tmux send-keys -t ${PANE_ID} "echo 'Verification complete' && echo 'VERIFY_OK'" Enter
sleep 2
OUTPUT=$(tmux capture-pane -p -t ${PANE_ID} -S -10)
echo "${OUTPUT}" > "${OUTPUT_DIR}/iter${ITERATION}_verify.txt"
echo "${OUTPUT}" | grep -q "VERIFY_OK" && echo "PASS: Verify" || echo "FAIL: Verify"
```

### 4. Save Final State

```bash
tmux capture-pane -p -t ${PANE_ID} -S -3000 > "${OUTPUT_DIR}/final_state.txt"
```

### 5. Cleanup

```bash
tmux kill-pane -t ${PANE_ID}
```

### 6. Generate Report

```bash
cat > "${OUTPUT_DIR}/summary.md" << EOF
# Test Report: ${CURRENT_TEST}

**Date:** $(date)
**Iteration:** ${ITERATION}

## Files
$(ls -la ${OUTPUT_DIR})

## Steps
1. chmod +x script — $(grep -q "STEP1_OK" ${OUTPUT_DIR}/iter${ITERATION}_step1.txt && echo "PASS" || echo "FAIL")
2. run script — $(grep -q "PREREQ_OK" ${OUTPUT_DIR}/iter${ITERATION}_step2.txt && echo "PASS" || echo "FAIL")
3. verify — $(grep -q "VERIFY_OK" ${OUTPUT_DIR}/iter${ITERATION}_verify.txt && echo "PASS" || echo "FAIL")
EOF

echo "Report: ${OUTPUT_DIR}/summary.md"
```

## Using test_step Helper

```bash
# Simplified version using test_step pattern

test_step() {
  local cmd="$1"
  local marker="$2"
  local timeout="${3:-10}"
  
  tmux send-keys -t ${PANE_ID} "${cmd} && echo '${marker}_OK'" Enter
  sleep ${timeout}
  
  OUTPUT=$(tmux capture-pane -p -t ${PANE_ID} -S -30)
  echo "${OUTPUT}" > "${OUTPUT_DIR}/iter${ITERATION}_${marker}.txt"
  
  if echo "${OUTPUT}" | grep -q "${marker}_OK"; then
    echo "PASS: ${marker}"
    return 0
  else
    echo "FAIL: ${marker}"
    return 1
  fi
}

# Usage
test_step "chmod +x /tmp/my_script.sh" "CHMOD" 3
test_step "/tmp/my_script.sh" "RUN" 6
test_step "echo done" "DONE" 2
```
