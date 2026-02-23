#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# shogun_layout.sh — 戦場レイアウト構築スクリプト
# 将軍+家老+軍師+忍び2名+足軽5人を指定レイアウトに配置
#
# 目標レイアウト:
# ┌──────────────┬─────────┬─────────┐
# │   将軍(大)   │  軍師   │  足軽2  │
# │              ├─────────┼─────────┤
# │              │  忍c    │  足軽3  │
# │              ├─────────┼─────────┤
# │              │  忍g    │  足軽4  │
# ├──────────────┼─────────┼─────────┤
# │   家老       │  足軽1  │  足軽5  │
# └──────────────┴─────────┴─────────┘
# ═══════════════════════════════════════════════════════════════
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SESSION="multiagent"
WIN_NAME="battlefield"

# ─── Step 1: 各エージェントのユニークペインID（%N形式）を収集 ───
# bash 3.2対応: 個別変数に格納
find_pane() {
    local agent="$1"
    local result=""
    # multiagent セッションを検索
    result=$(tmux list-panes -s -t "$SESSION" -F "#{pane_id} #{@agent_id}" 2>/dev/null | while read -r pid aid; do
        if [ "$aid" = "$agent" ]; then echo "$pid"; break; fi
    done)
    # 見つからなければ shogun セッションを検索
    if [ -z "$result" ]; then
        result=$(tmux list-panes -s -t shogun -F "#{pane_id} #{@agent_id}" 2>/dev/null | while read -r pid aid; do
            if [ "$aid" = "$agent" ]; then echo "$pid"; break; fi
        done)
    fi
    echo "$result"
}

P_shogun=$(find_pane shogun)
P_karo=$(find_pane karo)
P_gunshi=$(find_pane gunshi)
P_shinobi_c=$(find_pane shinobi_c)
P_shinobi_g=$(find_pane shinobi_g)
P_ashigaru1=$(find_pane ashigaru1)
P_ashigaru2=$(find_pane ashigaru2)
P_ashigaru3=$(find_pane ashigaru3)
P_ashigaru4=$(find_pane ashigaru4)
P_ashigaru5=$(find_pane ashigaru5)

# ─── Step 2: 全エージェント存在確認 ───
MISSING=""
for var in P_shogun P_karo P_gunshi P_shinobi_c P_shinobi_g P_ashigaru1 P_ashigaru2 P_ashigaru3 P_ashigaru4 P_ashigaru5; do
    eval val=\$$var
    if [ -z "$val" ]; then
        name=$(echo "$var" | sed 's/^P_//')
        MISSING="$MISSING $name"
    fi
done

if [ -n "$MISSING" ]; then
    echo "ERROR: 以下のエージェントが見つかりません:$MISSING" >&2
    echo "レイアウト構築をスキップします" >&2
    exit 1
fi

echo "全10エージェント確認。レイアウト構築開始..."

# ─── Step 3: 新ウィンドウを作成し、将軍ペインを配置 ───
tmux new-window -d -t "$SESSION" -n "$WIN_NAME"
EMPTY=$(tmux list-panes -t "$SESSION:$WIN_NAME" -F "#{pane_id}")

# 将軍を空ペインの左側に配置（40%幅）
tmux join-pane -d -b -h -s "$P_shogun" -t "$EMPTY" -l 40%
# 空ペインを削除
tmux kill-pane -t "$EMPTY"

# ─── Step 4: 3列レイアウト構築 ───
# 将軍(40%) | 軍師(30%) | 足軽2(30%)
tmux join-pane -d -h -s "$P_gunshi" -t "$P_shogun" -l 60%
tmux join-pane -d -h -s "$P_ashigaru2" -t "$P_gunshi" -l 50%

# ─── Step 5: 左列 — 将軍(75%) + 家老(25%) ───
tmux join-pane -d -v -s "$P_karo" -t "$P_shogun" -l 25%

# ─── Step 6: 中列 — 軍師 / 忍c / 忍g / 足軽1（各25%） ───
tmux join-pane -d -v -s "$P_shinobi_c" -t "$P_gunshi" -l 75%
tmux join-pane -d -v -s "$P_shinobi_g" -t "$P_shinobi_c" -l 67%
tmux join-pane -d -v -s "$P_ashigaru1" -t "$P_shinobi_g" -l 50%

# ─── Step 7: 右列 — 足軽2 / 足軽3 / 足軽4 / 足軽5（各25%） ───
tmux join-pane -d -v -s "$P_ashigaru3" -t "$P_ashigaru2" -l 75%
tmux join-pane -d -v -s "$P_ashigaru4" -t "$P_ashigaru3" -l 67%
tmux join-pane -d -v -s "$P_ashigaru5" -t "$P_ashigaru4" -l 50%

# ─── Step 8: battlefieldウィンドウをアクティブに ───
tmux select-window -t "$SESSION:$WIN_NAME"

# pane-border-format を再設定（新ウィンドウにも適用）
tmux set-option -t "$SESSION" -w pane-border-status top
tmux set-option -t "$SESSION" -w pane-border-format '#{?pane_active,#[reverse],}#[bold]#{@agent_id}#[default] (#{@model_name}) #{@current_task}'

# ─── Step 9: inbox_watcher をユニークペインID（%N）で再起動 ───
echo "inbox_watcher 再起動中..."
pkill -f "inbox_watcher.sh" 2>/dev/null || true
pkill -f 'fswatch.*queue/inbox' 2>/dev/null || true
sleep 0.5

tmux list-panes -t "$SESSION:$WIN_NAME" -F "#{pane_id} #{@agent_id} #{@agent_cli}" 2>/dev/null | while read -r pid aid cli; do
    cli="${cli:-claude}"
    if [ -n "$aid" ]; then
        nohup bash "$SCRIPT_DIR/scripts/inbox_watcher.sh" "$aid" "$pid" "$cli" \
            >> "$SCRIPT_DIR/logs/inbox_watcher_${aid}.log" 2>&1 &
    fi
done

echo "レイアウト構築完了！"
