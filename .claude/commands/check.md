# /check — 全軍異常検知スキル

全エージェント系の停滞・異常・ブロッカーを一斉チェックし、問題があれば即対応する。
「止まっていないか？」を1コマンドで確認するためのスキル。

## 手順

### Phase 1: 情報収集（すべて並行で実行）

以下を **すべて同時に** 読み取る:

1. `dashboard.md` 全文
2. `tmux list-panes -t multiagent -F '#{pane_index} #{@agent_id} #{pane_current_command}'`
3. 全エージェントペインの末尾を取得:
   ```bash
   for i in 0 1 2 3 4 5 6 7 8 9; do
     agent=$(tmux display-message -t multiagent:0.$i -p '#{@agent_id}' 2>/dev/null)
     cmd=$(tmux display-message -t multiagent:0.$i -p '#{pane_current_command}' 2>/dev/null)
     echo "=== $agent (pane $i): $cmd ==="
   done
   ```
4. `queue/inbox/karo.yaml` — 未読メッセージ数 (`read: false` の件数)
5. `queue/inbox/shogun.yaml` — 将軍宛て未読
6. `queue/shogun_to_karo.yaml` — pending/in_progress の cmd を grep
7. `date +%s` と dashboard.md の最終更新時刻の差分

### Phase 2: 異常検知チェックリスト

以下の全項目をチェックし、結果を OK / ⚠️WARNING / 🔴CRITICAL で表示する。

#### A. 将軍 ↔ 家老 通信チェック

| # | チェック項目 | 判定基準 | 過去事例 |
|---|------------|---------|---------|
| A1 | 家老inbox未読 | `karo.yaml` に `read: false` が1件以上 → ⚠️ | 将軍が指示送信後に家老が読まず全軍停止 |
| A2 | 将軍inbox未読 | `shogun.yaml` に `read: false` が1件以上 → ⚠️ | 家老の確認事項に将軍が気づかず停滞 |
| A3 | dashboard更新鮮度 | 最終更新から30分以上 → ⚠️、1時間以上 → 🔴 | 家老がdashboard更新せず殿に情報が届かない |
| A4 | pending cmd放置 | pending状態で30分以上 → ⚠️ | cmd書いたが家老に通知せず |
| A5 | 🚨要対応セクション | dashboard.mdに🚨があり殿未回答 → ⚠️ | 殿の判断待ちでブロック |

#### B. 全エージェント稼働チェック

| # | チェック項目 | 判定基準 | 過去事例 |
|---|------------|---------|---------|
| B1 | プロセス生存 | `pane_current_command` が空 or tmuxエラー → 🔴 | エージェントプロセスがクラッシュ |
| B2 | 待機エージェント数 | dashboard「待機中」が全エージェントの50%超 → ⚠️ | タスク不足で遊んでいる |
| B3 | エージェント自己識別 | `#{@agent_id}` が正しくセットされているか → 確認 | /clear後に誤認（家老が足軽2と誤認した事例） |

#### C. リソース・インフラチェック

| # | チェック項目 | 判定方法 | 過去事例 |
|---|------------|---------|---------|
| C1 | DBロック | `fuser data/db/manga_v2.db 2>/dev/null` or `lsof` でロック確認 | collect_google_books.pyが5時間ロック |
| C2 | 長時間プロセス | `ps aux` で2時間以上動いている python/node を検出 | バッチ処理がハング |
| C3 | ディスク容量 | `df -h /Volumes/Manga02` 90%超 → ⚠️ | — |
| C4 | inbox_watcher | `pgrep -f inbox_watcher` で生存確認 → 死んでたら 🔴 | watcher停止でinbox配送不能 |
| C5 | chrome-ai-bridge | `pgrep -f chrome-ai-bridge` + 最新ログ確認 | EXT_READY_TIMEOUT連続 |
| C6 | Dockerコンテナ | `docker ps --format '{{.Names}} {{.Status}}'` で期待コンテナ(komga等)の生存確認 → 停止/不在なら 🔴 | Komga停止に気づかず漫画閲覧不能 |

#### D. 殿のアクション待ちチェック

| # | チェック項目 | 判定方法 | 過去事例 |
|---|------------|---------|---------|
| D1 | 承認待ち | dashboard.md「🚦承認待ち」セクション | cmd_046設計承認で将軍が気づかず停滞 |
| D2 | kill承認待ち | D006対象プロセスの停止承認 | PID 81085, PID 35598 |
| D3 | credentials待ち | TODO.md「殿の手作業」で未完了 | Google OAuth, LINE Token |
| D4 | 手動操作待ち | Chrome reload等の物理操作 | chrome-ai-bridge復旧 |

#### E. タスクフローチェック

| # | チェック項目 | 判定基準 | 過去事例 |
|---|------------|---------|---------|
| E1 | 完了cmd未反映 | YAML status:done だが dashboard/TODO未更新 → ⚠️ | 成果が記録されない |
| E2 | report未読 | `queue/reports/` に新しいレポートがあるが処理されていない → ⚠️ | 足軽の成果を家老が拾わない |
| E3 | 作業中だが進捗なし | in_progress が1時間以上 + dashboardに更新なし → ⚠️ | 足軽がスタック |

### Phase 3: 結果表示

```
## /check 結果 — YYYY-MM-DD HH:MM

### サマリー
🔴 CRITICAL: N件  ⚠️ WARNING: N件  ✅ OK: N件

### 🔴 CRITICAL（即対応）
- [B1] ashigaru3 プロセス停止 → 家老に/clear指示
- ...

### ⚠️ WARNING（要注意）
- [A1] 家老inbox未読 2件（15分経過）→ 家老にnudge送信済み
- [B2] 待機中 5/7名 → タスク追加を検討
- ...

### ✅ 正常項目
A1-A5, B1-B3, C1-C5, D1-D4, E1-E3 — 全XX項目チェック済み
```

### Phase 4: 自動対応（WARNING以上がある場合）

| 異常 | 自動対応 | 条件 |
|------|---------|------|
| A1 家老inbox未読 | `inbox_write.sh karo` でnudge送信 | 15分以上未読 |
| A3 dashboard古い | 家老にdashboard更新を指示 | 1時間以上 |
| B2 大量待機 | 殿に追加タスク提案（/decide連携） | 50%以上待機 |
| D1-D4 殿待ち | /decide を呼んで殿に確認 | 項目あり |
| その他 | 報告のみ（自動対応しない） | — |

## 注意事項

- ポーリングループにしない。1回実行して完了
- 自動対応は軽微なもの（nudge送信）のみ。/clearやkillは絶対に自動実行しない
- 殿に報告する際は専門用語を避け、「要するにこういう状態」を添える
- このスキル自体がトークンを消費するので、必要時のみ実行（定期実行しない）
