#!/usr/bin/env bash
set -euo pipefail

# Keep inbox watchers alive in a persistent tmux-hosted shell.
# This script is designed to run forever.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

mkdir -p logs queue/inbox

ensure_inbox_file() {
    local agent="$1"
    if [ ! -f "queue/inbox/${agent}.yaml" ]; then
        printf 'messages: []\n' > "queue/inbox/${agent}.yaml"
    fi
}

# Find pane by @agent_id dynamically (no more hardcoded pane targets)
find_pane_by_agent_id() {
    local agent="$1"
    tmux list-panes -a -F '#{pane_id} #{@agent_id}' 2>/dev/null \
        | awk -v id="$agent" '$2 == id { print $1; exit }'
}

start_watcher_if_missing() {
    local agent="$1"
    local log_file="$2"
    local pane

    ensure_inbox_file "$agent"

    if pgrep -f "scripts/inbox_watcher.sh ${agent} " >/dev/null 2>&1; then
        return 0
    fi

    pane=$(find_pane_by_agent_id "$agent")
    if [ -z "$pane" ]; then
        return 0
    fi

    local cli
    cli=$(tmux show-options -p -t "$pane" -v @agent_cli 2>/dev/null || echo "claude")
    nohup bash scripts/inbox_watcher.sh "$agent" "$pane" "$cli" >> "$log_file" 2>&1 &
}

AGENTS="shogun karo ashigaru1 ashigaru2 ashigaru3 ashigaru4 ashigaru5 ashigaru6 ashigaru7 gunshi"

# Start nudger scripts if not running (secretaries that wake managers periodically)
start_nudger_if_missing() {
    local script="$1"
    local log="$2"
    if pgrep -f "scripts/${script}" >/dev/null 2>&1; then
        return 0
    fi
    nohup bash "scripts/${script}" >> "$log" 2>&1 &
}

while true; do
    for agent in $AGENTS; do
        start_watcher_if_missing "$agent" "logs/inbox_watcher_${agent}.log"
    done
    start_nudger_if_missing "karo_nudger.sh" "logs/karo_nudger.log"
    start_nudger_if_missing "shogun_nudger.sh" "logs/shogun_nudger.log"
    sleep 5
done
