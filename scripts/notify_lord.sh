#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# notify_lord.sh — LINE push notification to Lord
# ═══════════════════════════════════════════════════════════════
# Sends a push message to the Lord's LINE account via LINE Messaging API.
# Reuses credentials from ~/.gip-monitor/config (LINE_CHANNEL_TOKEN, LINE_USER_ID).
#
# Usage:
#   bash scripts/notify_lord.sh "メッセージ内容"
#   bash scripts/notify_lord.sh "🚨 要対応: 設計承認が必要です"
#
# Exit codes:
#   0 — sent successfully
#   1 — config not found or missing credentials
#   2 — LINE API returned error
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

CONFIG_FILE="${HOME}/.gip-monitor/config"
LINE_API="https://api.line.me/v2/bot/message/push"

# ─── Argument check ───
if [ -z "${1:-}" ]; then
    echo "Usage: bash scripts/notify_lord.sh \"message\"" >&2
    exit 1
fi

MESSAGE="$1"

# ─── Load credentials ───
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: $CONFIG_FILE not found" >&2
    exit 1
fi

source "$CONFIG_FILE"

if [ -z "${LINE_CHANNEL_TOKEN:-}" ] || [ -z "${LINE_USER_ID:-}" ]; then
    echo "Error: LINE_CHANNEL_TOKEN or LINE_USER_ID not set in $CONFIG_FILE" >&2
    exit 1
fi

# ─── Send push message ───
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$LINE_API" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $LINE_CHANNEL_TOKEN" \
    -d "{
        \"to\": \"$LINE_USER_ID\",
        \"messages\": [
            {
                \"type\": \"text\",
                \"text\": \"$MESSAGE\"
            }
        ]
    }")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ]; then
    exit 0
else
    echo "LINE API error (HTTP $HTTP_CODE): $BODY" >&2
    exit 2
fi
