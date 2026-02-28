#!/bin/bash
# kill_approved.sh - 殿が承認済みのプロセスをkillする (D006 approved script)
#
# Usage: bash scripts/kill_approved.sh <PID> [reason]
#
# D006 exception: 殿の承認を得たPIDのみ対象。
# Raw kill/killall/pkill remain banned under D006.
#
# Safety:
# - PIDが存在しなければ何もしない
# - プロセス情報をログに記録してからkill
# - Claude Code / tmux / launchd プロセスはkill禁止（ガードあり）

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="$SCRIPT_DIR/logs/kill_approved.log"

mkdir -p "$(dirname "$LOG_FILE")"

PID="$1"
REASON="${2:-no reason provided}"

if [ -z "$PID" ]; then
    echo "Usage: bash scripts/kill_approved.sh <PID> [reason]"
    exit 1
fi

# PID must be numeric
if ! [[ "$PID" =~ ^[0-9]+$ ]]; then
    echo "ERROR: PID must be numeric, got: $PID"
    exit 1
fi

# Check if process exists
if ! ps -p "$PID" > /dev/null 2>&1; then
    echo "PID $PID is not running. Nothing to do."
    exit 0
fi

# Get process info before kill
PROC_INFO=$(ps -p "$PID" -o pid,user,etime,command 2>/dev/null | tail -1)
PROC_CMD=$(ps -p "$PID" -o command= 2>/dev/null)

# Safety guard: refuse to kill protected processes
PROTECTED_PATTERNS="claude|tmux|launchd|launchctl|sshd|WindowServer|loginwindow|kernel_task|inbox_watcher"
if echo "$PROC_CMD" | grep -qiE "$PROTECTED_PATTERNS"; then
    echo "REFUSED: PID $PID matches protected pattern. Cannot kill."
    echo "$(date -Iseconds) REFUSED PID=$PID CMD=$PROC_CMD REASON=$REASON" >> "$LOG_FILE"
    exit 1
fi

# Log and kill
echo "$(date -Iseconds) KILL PID=$PID CMD=$PROC_CMD REASON=$REASON" >> "$LOG_FILE"
echo "Killing PID $PID: $PROC_CMD"
echo "Reason: $REASON"

kill "$PID"

# Verify
sleep 1
if ps -p "$PID" > /dev/null 2>&1; then
    echo "WARNING: PID $PID still alive after SIGTERM. Sending SIGKILL..."
    kill -9 "$PID" 2>/dev/null || true
    echo "$(date -Iseconds) SIGKILL PID=$PID" >> "$LOG_FILE"
fi

if ! ps -p "$PID" > /dev/null 2>&1; then
    echo "OK: PID $PID terminated."
else
    echo "ERROR: PID $PID could not be killed."
    exit 1
fi
