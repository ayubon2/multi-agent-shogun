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
8. 各ペインのコンテキスト残量を取得:
   ```bash
   for pane_id in $(tmux list-panes -a -F '#{pane_id} #{@agent_id}' | awk '$2 != "" {print $1}'); do
     agent=$(tmux display-message -t "$pane_id" -p '#{@agent_id}')
     ctx=$(tmux capture-pane -t "$pane_id" -p | grep -o 'Context left[^:]*: [0-9]*%' | tail -1)
     echo "$agent: ${ctx:-N/A}"
   done
   ```

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
| B4 | コンテキスト残量 | 各ペインの末尾から `Context left` を抽出。20%以下 → ⚠️、10%以下 → 🔴 | 家老9%で枯渇寸前なのに誰も気づかず放置 |

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
| A1 家老inbox未読 | idle復帰手順（下記）を実行 | 未読あり |
| A3 dashboard古い | 家老にdashboard更新を指示 | 1時間以上 |
| B1 プロセス停止 | 報告のみ（手動再起動が必要） | DEAD検知 |
| B2 大量待機 | TODO.md/campaigns.md から次のcmd候補を起案し、shogun_to_karo.yaml に書いて家老にinbox_write | 50%以上待機 + 未処理cmdなし |
| B4 コンテキスト枯渇 | 対象エージェントに `/compact` を送信（idle時）。処理中なら次のidle時まで待機。10%以下かつidle → 即送信 | 20%以下 |
| D1-D4 殿待ち | /decide を呼んで殿に確認 | 項目あり |
| その他 | 報告のみ（自動対応しない） | — |

### Phase 4.5: idle復帰手順（A1/B2で使用）

idleエージェントにnudgeが届かないケースが頻発する。以下の手順で段階的に復帰を試みる。

**対象**: inbox未読があるのにidleのエージェント（❯プロンプトが見える）

```
Step 1: 状態確認
  tmux capture-pane -t <pane> -p | grep -v '^$' | tail -10
  → thinking/Working/Reading 等が見えたら「処理中」→ 何もしない

Step 2: 通常nudge
  未読件数を確認: bash scripts/get_unread_inbox.sh <agent_id>
  tmux send-keys -t <pane> "inbox{N}" ; sleep 0.3 ; tmux send-keys -t <pane> Enter

Step 3: 5秒待って確認
  tmux capture-pane -t <pane> -p | grep -v '^$' | tail -5
  → thinking/Working が見えたら成功。終了

Step 4: Escape×2 + リトライ（Step 3で変化なしの場合）
  tmux send-keys -t <pane> Escape ; sleep 0.3
  tmux send-keys -t <pane> Escape ; sleep 0.5
  tmux send-keys -t <pane> "inbox{N}" ; sleep 0.3
  tmux send-keys -t <pane> Enter

Step 5: 5秒待って最終確認
  → 動いたら成功
  → まだ動かない → 「{agent}が応答なし。/clear検討」としてdashboard.md 🚨要対応に記載
```

**pane探索**: `@agent_id` から動的に探す（ハードコードしない）
```bash
tmux list-panes -a -F '#{pane_id} #{@agent_id}' | awk -v id="<agent_id>" '$2 == id { print $1 }'
```

### Phase 5: ストック補充（B2: 全員idle + 未処理cmdなし の場合のみ）

**発動条件**: Phase 2 で B2 が ⚠️WARNING **かつ** `queue/shogun_to_karo.yaml` に pending/in_progress の cmd がゼロ

**頻度制御**: 前回の起案から3時間以内なら Phase 5 をスキップする。
判定方法: dashboard.md の「📋 cmd候補」セクション内の最終起案日時を確認。

```
Step 1: TODO.md を読む（~/projects/TODO.md）
Step 2: campaigns.md を読む（projects/campaigns.md）
Step 3: dashboard.md の直近完了戦果と 📌観察事項 を確認
Step 4: 上記から次の cmd 候補を 5-10 件起案する
  各候補のフォーマット:
    - id: cmd_NNN（連番。queue/shogun_to_karo.yaml の最大cmd番号 + 1 から開始）
    - purpose: 1行で「何が完了すればdoneか」
    - acceptance_criteria: テスト可能な条件リスト
    - project: 対象プロジェクト（sakusen_NNN or プロジェクト名）
    - priority: high / medium / low
    - tier: T1 / T2 / T3（Autonomy Tiers準拠）

  起案ルール:
    a. ソース: TODO.md未完了 + campaigns.md進行中作戦 + dashboard観察事項 + 過去の改善提案
    b. T1(自動)/T2(将軍即決) は承認不要マークをつける
    c. T3(殿確認)/T4(殿手動) は承認待ちとして積む
    d. 予算影響・外部サービス契約・新規ドメイン取得を含むcmdは起案のみ（即実行禁止）

Step 5: dashboard.md の「📋 cmd候補（殿の承認待ち）」セクションに書く
  - T1/T2 候補は「✅ 即実行可」マーク
  - T3/T4 候補は「🔒 殿の承認待ち」マーク

Step 6: LINE通知を送る
  bash ~/.claude/scripts/notify_lord.sh "📋 [将軍] cmd候補N件積みました。ご確認ください"

Step 7: T1/T2 の候補は即座に shogun_to_karo.yaml に投入し、家老に inbox_write で通知
  T3/T4 の候補は殿の承認を待つ（dashboardに積むだけ）
```

**殿が承認した場合の流れ**:
殿がチャットまたはdashboardで承認 → 将軍が承認分を shogun_to_karo.yaml に投入 → 家老が配分開始

## 注意事項

- ポーリングループにしない。1回実行して完了
- /clearは自動実行しない。復帰手順はnudge送信まで
- 殿に報告する際は専門用語を避け、「要するにこういう状態」を添える
- shogun_patrol.sh が10分ごとにこのスキルを自動投入する（customizations/lord_overrides.md #4参照）
- Phase 5 は3時間に1回まで。頻繁な起案は殿の承認負荷を増やすため抑制する
