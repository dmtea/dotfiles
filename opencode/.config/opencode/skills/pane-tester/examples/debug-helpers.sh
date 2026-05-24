#!/bin/bash
# pane-tester Debug Helper Functions
# Source this file or copy functions into your test script
#
# Usage:
#   source /path/to/debug-helpers.sh
#   debug_capture "Error description"
#   debug_propose "Error message"

# Variables (set these before using functions)
OUTPUT_DIR="/tmp/pane-tester-debug"
DEBUG_LOG="${OUTPUT_DIR}/debug_session.md"
SOLUTION_DB="${OUTPUT_DIR}/solutions_db.md"
PANE_ID=""
ITERATION=0

# Initialize debug environment
debug_init() {
  mkdir -p "${OUTPUT_DIR}"
  echo "# Debug Session - $(date)" > ${DEBUG_LOG}
}

# Capture failure state for analysis
debug_capture() {
  local description="$1"
  local timestamp=$(date +%Y%m%d_%H%M%S)
  
  # Capture pane output
  tmux capture-pane -p -t ${PANE_ID} -S -3000 > "${OUTPUT_DIR}/debug_${timestamp}_output.txt"
  
  # Record in debug log
  echo "" >> ${DEBUG_LOG}
  echo "### Failure: ${description}" >> ${DEBUG_LOG}
  echo "**Time:** ${timestamp}" >> ${DEBUG_LOG}
  echo "**Iteration:** ${ITERATION}" >> ${DEBUG_LOG}
  echo "" >> ${DEBUG_LOG}
  echo '```' >> ${DEBUG_LOG}
  tail -50 "${OUTPUT_DIR}/debug_${timestamp}_output.txt" >> ${DEBUG_LOG}
  echo '```' >> ${DEBUG_LOG}
  
  echo "Failure captured: ${OUTPUT_DIR}/debug_${timestamp}_output.txt"
}

# Propose investigation options to user
debug_propose() {
  local error="$1"
  
  echo ""
  echo "=== DEBUG MODE ==="
  echo "Error detected: ${error}"
  echo ""
  echo "Investigation options:"
  echo "  1. Auto-investigate (search logs, check docs)"
  echo "  2. Manual investigation (I'll check myself)"
  echo "  3. Skip this error and continue"
  echo "  4. Abort testing"
  echo "  5. Try known fix from database"
  echo ""
  echo "Select option [1-5]:"
}

# Run investigation steps
debug_investigate() {
  local problem="$1"
  local timestamp=$(date +%Y%m%d_%H%M%S)
  local findings="${OUTPUT_DIR}/debug_${timestamp}_findings.md"
  
  echo "# Investigation: ${problem}" > ${findings}
  echo "" >> ${findings}
  
  # Step 1: Check system state
  echo "## System State" >> ${findings}
  tmux send-keys -t ${PANE_ID} "echo '=== ENV ===' && env | head -20" Enter
  sleep 2
  tmux capture-pane -p -t ${PANE_ID} -S -30 >> ${findings}
  
  # Step 2: Check logs
  echo "" >> ${findings}
  echo "## Recent Logs" >> ${findings}
  tmux send-keys -t ${PANE_ID} "dmesg | tail -20 2>/dev/null || journalctl -n 20 2>/dev/null || echo 'No logs'" Enter
  sleep 2
  tmux capture-pane -p -t ${PANE_ID} -S -30 >> ${findings}
  
  echo "Investigation complete. Findings: ${findings}"
}

# Add solution to database
debug_solution_add() {
  local error_pattern="$1"
  local solution="$2"
  local confidence="$3"  # high, medium, low
  
  echo "" >> ${SOLUTION_DB}
  echo "### Solution: ${error_pattern}" >> ${SOLUTION_DB}
  echo "**Confidence:** ${confidence}" >> ${SOLUTION_DB}
  echo "**Solution:** ${solution}" >> ${SOLUTION_DB}
  echo "**Added:** $(date)" >> ${SOLUTION_DB}
}

# Search solutions in database
debug_solution_search() {
  local error="$1"
  
  if [ -f ${SOLUTION_DB} ]; then
    grep -A5 "${error}" ${SOLUTION_DB} || echo "No solutions found"
  else
    echo "Solution database not initialized"
  fi
}

# Attempt a fix and record result
debug_try_fix() {
  local fix_description="$1"
  local fix_command="$2"
  local timestamp=$(date +%Y%m%d_%H%M%S)
  
  echo "" >> ${DEBUG_LOG}
  echo "### Trying Fix: ${fix_description}" >> ${DEBUG_LOG}
  echo "**Time:** ${timestamp}" >> ${DEBUG_LOG}
  echo "**Command:** ${fix_command}" >> ${DEBUG_LOG}
  
  # Execute fix
  tmux send-keys -t ${PANE_ID} "${fix_command}" Enter
  sleep 5
  
  # Capture result
  RESULT=$(tmux capture-pane -p -t ${PANE_ID} -S -30)
  echo "" >> ${DEBUG_LOG}
  echo "**Result:**" >> ${DEBUG_LOG}
  echo '```' >> ${DEBUG_LOG}
  echo "${RESULT}" >> ${DEBUG_LOG}
  echo '```' >> ${DEBUG_LOG}
  
  # Check if fix worked
  if echo "${RESULT}" | grep -qi "error\|fail"; then
    echo "FIX_FAILED" >> ${DEBUG_LOG}
    return 1
  else
    echo "FIX_SUCCESS" >> ${DEBUG_LOG}
    return 0
  fi
}

# Generate debug session summary
debug_summary() {
  echo "" >> ${DEBUG_LOG}
  echo "---" >> ${DEBUG_LOG}
  echo "" >> ${DEBUG_LOG}
  echo "## Debug Session Summary" >> ${DEBUG_LOG}
  echo "" >> ${DEBUG_LOG}
  echo "**Duration:** $(date)" >> ${DEBUG_LOG}
  echo "**Fixes Attempted:** $(grep -c 'Trying Fix' ${DEBUG_LOG} 2>/dev/null || echo 0)" >> ${DEBUG_LOG}
  echo "**Fixes Successful:** $(grep -c 'FIX_SUCCESS' ${DEBUG_LOG} 2>/dev/null || echo 0)" >> ${DEBUG_LOG}
  echo "**Solutions Added:** $(grep -c 'Solution:' ${SOLUTION_DB} 2>/dev/null || echo 0)" >> ${DEBUG_LOG}
  
  echo "Debug summary: ${DEBUG_LOG}"
}
