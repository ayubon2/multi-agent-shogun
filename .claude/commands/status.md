# /status — 戦況確認スキル

現在の全軍の状態・cmd進捗・殿への要対応事項を一覧表示する。

## 手順

1. **情報収集**（すべて並行で読む）:
   - `dashboard.md` 全文を読む
   - `tmux list-panes -t multiagent -F '#{pane_index} #{@agent_id} #{pane_current_command}'` で全エージェント状態
   - 各エージェントペインの末尾5行を `tmux capture-pane` で取得
   - `queue/shogun_to_karo.yaml` で pending/in_progress の cmd を抽出

2. **整形して表示**:

   ```
   ## 全軍状態
   | エージェント | 状態 | 担当タスク |
   |---|---|---|

   ## cmd進捗
   | cmd | 内容 | 状態 |
   |---|---|---|

   ## 🚨 殿への要対応（あれば）
   - ...

   ## 直近の完了
   - ...
   ```

3. **異常検知**:
   - エージェントが10分以上応答なし → 報告
   - cmdがpendingのまま30分以上 → 報告
   - dashboard.md が1時間以上更新なし → 報告

## 注意事項

- 読み取りのみ。何も変更しない
- ポーリングループにしない（1回実行して終了）
- 情報量が多い場合は要約して表示
