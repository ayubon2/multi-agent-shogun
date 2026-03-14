# /bugyou — 奉行（自動監視+自動再投入）

idle足軽を検知して自動でタスクを再投入するスキル。
launchdで5分おきに自動実行される。手動でも `/bugyou` で即時実行可能。

## 使い方

- `/bugyou` — 即時実行（全足軽チェック+idle再投入）
- `/bugyou status` — bugyou launchdサービスの状態確認
- `/bugyou install` — launchdサービスの再インストール

## 手順

### Step 1: 全足軽の稼働状態チェック

```bash
bash scripts/bugyou.sh
```

### Step 2: 結果確認

```bash
tail -10 /tmp/bugyou.log
```

### Step 3: 結果を報告

- 全員稼働中 → 「✅ 全軍稼働中」
- idle検知あり → 「⚠️ {agent}がidleだったので再投入した」+ 何のタスクを送ったか

### Step 4: タスクYAMLが古い場合

idleの足軽に送るタスクが古い（完了済み）場合:

1. `queue/shogun_to_karo.yaml` から pending の cmd を探す
2. なければ新しい cmd を起案（/check の Phase 5 手順に従う）
3. `queue/tasks/ashigaru{N}.yaml` を更新
4. 再度 `bash scripts/bugyou.sh` を実行

## 引数が `status` の場合

```bash
launchctl list | grep bugyou
cat /tmp/bugyou.log | tail -20
```

稼働状態とログ直近20行を表示。

## 引数が `install` の場合

```bash
launchctl unload ~/Library/LaunchAgents/com.shogun.bugyou.plist 2>/dev/null
launchctl load ~/Library/LaunchAgents/com.shogun.bugyou.plist
launchctl list | grep bugyou
```

## 自動実行について

- launchd: `com.shogun.bugyou` が5分おきに `scripts/bugyou.sh` を実行
- idle検知 → タスクYAMLのcmdを自動送信
- ログ: `/tmp/bugyou.log`

## 注意事項

- このスキルは将軍セッションから手動実行もできるが、主な用途はlaunchdによる自動実行
- bugyou.shは足軽のtmux paneに直接 send-keys するため、将軍のコンテキストを消費しない
- 殿の「止まってんじゃん」を二度と聞かないための仕組み
