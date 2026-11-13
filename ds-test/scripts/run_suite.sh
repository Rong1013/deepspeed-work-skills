#!/usr/bin/env bash
# Run tests/run_test.sh with a completion marker and resume-on-interrupt.
# Usage: run_suite.sh [--log-dir DIR] [--retries N] [--script tests/run_test.sh]
#
# The log ends with "=== DS_TEST_DONE exit=<code> ===" only when the whole script finished.
# If a run dies without the marker, the next attempt resumes from the command that was running.
set -uo pipefail

LOG_DIR="${DS_WORK_DIR:-/workspace/deepspeed-work}/test"
RETRIES=2
SCRIPT=tests/run_test.sh
while [ $# -gt 0 ]; do
  case "$1" in
    --log-dir) LOG_DIR="$2"; shift 2;;
    --retries) RETRIES="$2"; shift 2;;
    --script) SCRIPT="$2"; shift 2;;
    *) echo "unknown arg $1" >&2; exit 2;;
  esac
done

test -f "$SCRIPT" || { echo "ERROR: $SCRIPT not found (run from repo root)" >&2; exit 2; }
VERSION=$(python3 -c "import deepspeed;print(deepspeed.__version__)" 2>/dev/null || cat version.txt)
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/test_ds_${VERSION}_$(date +%Y%m%d-%H%M).log"
TESTS_DIR=$(cd "$(dirname "$SCRIPT")" && pwd)
SCRIPT_ABS="$TESTS_DIR/$(basename "$SCRIPT")"

# Each non-empty, non-comment line of run_test.sh is one step; we wrap it with a step marker
# so an interrupted run can resume. `cd` lines are kept so relative paths still work.
run_from() {
  local start=$1 n=0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|\#*) continue;; esac
    n=$((n+1))
    if [ $n -lt "$start" ]; then
      case "$line" in cd\ *) eval "$line";; esac   # replay directory changes only
      continue
    fi
    echo "=== DS_TEST_STEP $n: $line"
    eval "$line"
    LAST_RC=$?
  done < "$SCRIPT_ABS"
}

attempt=0; start=1; LAST_RC=0
echo "=== DS_TEST_START $(date '+%F %T') deepspeed=$VERSION head=$(git rev-parse --short HEAD) ===" | tee "$LOG"
while :; do
  ( cd "$TESTS_DIR" && LAST_RC=0 && run_from "$start" && echo "=== DS_TEST_DONE exit=$LAST_RC $(date '+%F %T') ===" ) >>"$LOG" 2>&1
  if tail -1 "$LOG" | grep -q DS_TEST_DONE; then break; fi
  attempt=$((attempt+1))
  last=$(grep -o 'DS_TEST_STEP [0-9]*' "$LOG" | tail -1 | awk '{print $2}')
  echo "=== DS_TEST_INTERRUPTED at step ${last:-?} (attempt $attempt/$RETRIES) ===" | tee -a "$LOG"
  [ "$attempt" -gt "$RETRIES" ] && { echo "giving up; log: $LOG"; exit 1; }
  start=$(( ${last:-0} + 1 ))   # skip the step that died (it is recorded as interrupted)
done

echo "log: $LOG"
echo "next: python3 $(dirname "$0")/extract_failed_cases.py $LOG"
