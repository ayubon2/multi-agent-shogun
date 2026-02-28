#!/bin/bash
# agent_activity.sh — エージェント活動モニター
#
# Usage: bash scripts/agent_activity.sh [--watch]
#   --watch: 5秒間隔で自動更新（Ctrl+C で停止）
#
# 各エージェントの稼働状態を以下の指標で判定:
#   CPU%: Claude Code (node) プロセスのCPU使用率
#   NET:  ESTABLISHED TCP接続数
#   MEM:  メモリ使用量 (MB)
#
# 判定基準:
#   🟢 ACTIVE  — CPU > 5% (APIレスポンス処理中 or ツール実行中)
#   🔵 LIGHT   — CPU 0.1-5% (API待ち or 軽い処理)
#   🟡 IDLE    — CPU 0% + NET > 0 (プロセス生存、入力待ち)
#   🔴 DEAD    — プロセスなし

set -e

TMUX_SESSION="multiagent"

run_check() {
    local now
    now=$(date '+%Y-%m-%d %H:%M:%S')

    # Header
    printf "\033[1m=== Agent Activity Monitor — %s ===\033[0m\n" "$now"
    printf "%-12s %-6s %-6s %-7s %-8s %s\n" "AGENT" "CPU%" "NET" "MEM(MB)" "STATUS" "PID"
    printf "%-12s %-6s %-6s %-7s %-8s %s\n" "───────────" "─────" "─────" "──────" "───────" "─────"

    local active=0 light=0 idle=0 dead=0

    # Get all panes
    tmux list-panes -t "$TMUX_SESSION" -F '#{pane_index} #{@agent_id} #{pane_pid}' 2>/dev/null | while read -r idx agent shell_pid; do
        # Skip shogun (pane 1) — that's the controlling terminal
        if [ "$agent" = "shogun" ]; then
            printf "%-12s %-6s %-6s %-7s %-8s %s\n" "$agent" "—" "—" "—" "👑 ME" "—"
            continue
        fi

        # Find Claude Code child process
        local cc_pid
        cc_pid=$(pgrep -P "$shell_pid" 2>/dev/null | head -1)

        if [ -z "$cc_pid" ]; then
            printf "%-12s %-6s %-6s %-7s %-8s %s\n" "$agent" "—" "—" "—" "🔴 DEAD" "—"
            dead=$((dead + 1))
            continue
        fi

        # Get CPU, memory
        local cpu mem net status
        cpu=$(ps -p "$cc_pid" -o %cpu= 2>/dev/null | tr -d ' ' || echo "0.0")
        mem=$(ps -p "$cc_pid" -o rss= 2>/dev/null | tr -d ' ' || echo "0")
        mem=$((mem / 1024))

        # Count ESTABLISHED connections
        net=$(lsof -p "$cc_pid" -i TCP 2>/dev/null | grep -c ESTABLISHED || echo "0")

        # Determine status
        local cpu_int
        cpu_int=$(echo "$cpu" | awk '{printf "%d", $1}')

        if [ "$cpu_int" -gt 5 ]; then
            status="🟢 ACTIVE"
            active=$((active + 1))
        elif [ "$cpu_int" -gt 0 ] || [ "$(echo "$cpu > 0" | bc 2>/dev/null || echo 0)" = "1" ]; then
            status="🔵 LIGHT"
            light=$((light + 1))
        elif [ "$net" -gt 0 ]; then
            status="🟡 IDLE"
            idle=$((idle + 1))
        else
            status="🔴 DEAD"
            dead=$((dead + 1))
        fi

        printf "%-12s %-6s %-6s %-7s %-8s %s\n" "$agent" "$cpu" "$net" "$mem" "$status" "$cc_pid"
    done

    echo ""
    printf "Summary: 🟢 Active | 🔵 Light | 🟡 Idle | 🔴 Dead\n"
    echo ""

    # JSONL growth check (optional, slightly slower)
    local jsonl_dir="/Users/nobi/.claude/projects/-Users-nobi-projects-010-multi-agent-shogun"
    local recent_jsonl
    recent_jsonl=$(find "$jsonl_dir" -maxdepth 1 -name "*.jsonl" -mmin -3 2>/dev/null | wc -l | tr -d ' ')
    printf "JSONL files updated in last 3 min: %s (≈ active sessions)\n" "$recent_jsonl"

    # Working directory file changes
    local workspace_changes
    workspace_changes=$(find ~/projects/manga-workspace -name '*.ts' -o -name '*.tsx' -o -name '*.json' -o -name '*.css' 2>/dev/null | xargs stat -f '%m' 2>/dev/null | sort -rn | head -1)
    if [ -n "$workspace_changes" ]; then
        local now_ts
        now_ts=$(date +%s)
        local age=$(( (now_ts - workspace_changes) / 60 ))
        printf "manga-workspace last file change: %s min ago\n" "$age"
    fi
}

# Main
if [ "$1" = "--watch" ]; then
    while true; do
        clear
        run_check
        echo ""
        echo "(--watch mode: refreshing every 5s, Ctrl+C to stop)"
        sleep 5
    done
else
    run_check
fi
