# /team — 全軍起動スキル

全エージェント（家老→足軽・軍師）を起動し、未完了cmdを再開させる。

## 手順

1. **状態確認**（並行で実行）:
   - `tmux list-panes -t multiagent -F 'pane:#{pane_index} agent:#{@agent_id} cmd:#{pane_current_command}'` でペイン一覧取得
   - 各ペインのプロセス稼働確認（Claude Codeが起動しているか）
   - `queue/shogun_to_karo.yaml` で未完了cmd一覧を確認
   - `dashboard.md` で最終状態を確認

2. **家老起動**:
   - 家老ペインにClaude Codeが未起動なら `tmux send-keys -t multiagent:2.2 'claude' Enter`
   - 起動確認（5秒待ってからcapture-paneで確認）

3. **全軍再始動cmd発行**:
   - `queue/shogun_to_karo.yaml` に新cmdを追記:
     - purpose: 全エージェント再起動と未完了タスク再開
     - 未完了cmdの一覧を command に含める
     - dashboard.md 即時更新を指示
   - `bash scripts/inbox_write.sh karo "cmd_XXXを発令した。全軍再始動せよ。" cmd_new shogun`

4. **殿への報告**:
   - 起動したエージェント数
   - 再開されるcmd一覧
   - 推定所要時間（あれば）

## 注意事項

- 家老が既に稼働中なら起動をスキップ（二重起動防止）
- 足軽・軍師の起動は家老に委任（F002: 将軍が足軽に直接指示しない）
- tmuxセッション名・ウィンドウ番号は `tmux list-windows` で都度確認
