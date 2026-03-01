#!/bin/zsh
# ═══════════════════════════════════════════════════════════════
# healthcheck.sh — 全エージェントのヘルスチェック
# Usage: zsh scripts/healthcheck.sh
# ═══════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
QUEUE_DIR="$SCRIPT_DIR/queue"

# Pane mapping: index=agent_id
pane_ids=(2 3 4 5 6 7 8 9 10)
expected_agents=(karo ashigaru1 ashigaru2 ashigaru3 ashigaru4 ashigaru5 ashigaru6 ashigaru7 gunshi)

echo "═══════════════════════════════════════════════════════"
echo " SHOGUN SYSTEM HEALTH CHECK"
echo " $(date '+%Y-%m-%d %H:%M:%S')"
echo "═══════════════════════════════════════════════════════"
echo ""
printf "%-6s %-12s %-15s %-5s %-6s %-6s %-8s %-8s %s\n" \
  "PANE" "AGENT" "STATE" "ID" "INBOX" "TASK" "WATCHER" "UNREAD" "CONTEXT"
printf "%-6s %-12s %-15s %-5s %-6s %-6s %-8s %-8s %s\n" \
  "----" "-----" "-----" "--" "-----" "----" "-------" "------" "-------"

total_ok=0
total_warn=0
total_error=0

for idx in {1..9}; do
  pane_idx=${pane_ids[$idx]}
  expected=${expected_agents[$idx]}

  # 1. Agent ID
  actual_id=$(tmux display-message -t "multiagent:2.${pane_idx}" -p '#{@agent_id}' 2>/dev/null || echo "")
  id_ok="OK"
  [[ "$actual_id" != "$expected" ]] && id_ok="NG"

  # 2. Session state
  pane_content=$(tmux capture-pane -t "multiagent:2.${pane_idx}" -p 2>/dev/null || echo "")
  agent_state="UNKNOWN"
  # ACTIVE takes priority: "esc to interrupt" means currently processing
  # even if old feedback prompt is in scrollback
  if echo "$pane_content" | grep -q "esc to interrupt"; then
    agent_state="ACTIVE"
  elif echo "$pane_content" | grep -q "How is Claude doing"; then
    agent_state="SESSION_ENDED"
  else
    agent_state="IDLE"
  fi

  # 3. Inbox
  inbox_file="$QUEUE_DIR/inbox/${actual_id}.yaml"
  inbox_ok="OK"
  unread=0
  if [[ -f "$inbox_file" ]]; then
    unread=$(grep -c "read: false" "$inbox_file" 2>/dev/null | head -1 | tr -d '[:space:]')
    [[ -z "$unread" ]] && unread=0
  else
    inbox_ok="MISS"
  fi

  # 4. Task YAML
  task_ok="OK"
  if [[ "$actual_id" == "karo" ]]; then
    task_ok="N/A"
  elif [[ ! -f "$QUEUE_DIR/tasks/${actual_id}.yaml" ]]; then
    task_ok="MISS"
  fi

  # 5. Watcher
  watcher_cnt=$(ps aux | grep "inbox_watcher.sh ${actual_id}" | grep -v grep | wc -l | tr -d ' ')
  watcher_ok="OK"
  [[ "$watcher_cnt" -eq 0 ]] && watcher_ok="DOWN"

  # 6. Context
  ctx=$(echo "$pane_content" | grep -o "Context left[^%]*%" | tail -1)
  [[ -z "$ctx" ]] && ctx="-"

  # Health symbol
  symbol="✅"
  if [[ "$agent_state" == "SESSION_ENDED" ]]; then
    symbol="💀"
    total_error=$((total_error + 1))
  elif [[ "$id_ok" == "NG" ]] || [[ "$inbox_ok" == "MISS" ]] || [[ "$watcher_ok" == "DOWN" ]]; then
    symbol="❌"
    total_error=$((total_error + 1))
  elif [[ "$agent_state" == "IDLE" ]] && [[ "$unread" -gt 0 ]]; then
    symbol="⚠️"
    total_warn=$((total_warn + 1))
  else
    total_ok=$((total_ok + 1))
  fi

  printf "%-4s %-12s %-15s %-5s %-6s %-6s %-8s %-8s %s\n" \
    "$symbol" "$actual_id" "$agent_state" "$id_ok" "$inbox_ok" "$task_ok" "$watcher_ok" "$unread" "$ctx"
done

echo ""
echo "═══════════════════════════════════════════════════════"
echo " OK=$total_ok  WARN=$total_warn  ERROR=$total_error"
echo "═══════════════════════════════════════════════════════"
