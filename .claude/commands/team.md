# /team — 三国志マルチエージェント起動

Claude Code の TeamCreate/Task 機能を使い、複数エージェントをチームとして起動する汎用スキル。
将軍（tmux+YAML）システムとは独立。どのプロジェクトでも使える。

## 役職（三国志）

| 役職 | 読み | 役割 | Claude Code agent type |
|------|------|------|----------------------|
| 丞相 | じょうしょう | 総指揮・戦略決定（自分自身） | — (current session) |
| 都督 | ととく | 作戦調整・タスク配分 | general-purpose |
| 祭酒 | さいしゅ | 品質検証・レビュー | general-purpose |
| 兵 | へい | 実装・実行 | general-purpose |
| 細作 | さいさく | 調査・偵察 | Explore |

## 手順

### 1. チーム編成を決定

殿に `AskUserQuestion` で聞く:

**question**: どんなチームを編成しますか？
**options**:
- **小隊（3名）**: 都督1 + 兵2。小〜中規模タスク向き
- **中隊（5名）**: 都督1 + 祭酒1 + 兵2 + 細作1。QC付きの標準編成
- **大隊（7名）**: 都督1 + 祭酒1 + 兵4 + 細作1。大規模実装向き

### 2. チーム作成

```
TeamCreate: team_name="{task}-team", description="三国志チーム: {task概要}"
```

### 3. タスク作成

TaskCreate で全タスクを作成し、依存関係を設定。

### 4. エージェント起動

Task ツールで各エージェントを起動:

```
# 都督（調整役）
Task: name="totoku", team_name="{team}", subagent_type="general-purpose"
  prompt: "あなたは都督（ととく）。チームの作戦調整役。タスクリストを確認し、兵にタスクを割り振り、進捗を管理せよ。..."

# 兵（実行役）
Task: name="hei1", team_name="{team}", subagent_type="general-purpose"
  prompt: "あなたは兵（へい）1号。TaskListを確認し、未割り当てタスクを取得して実行せよ。..."

# 祭酒（QC）
Task: name="saishu", team_name="{team}", subagent_type="general-purpose"
  prompt: "あなたは祭酒（さいしゅ）。兵の成果物をレビューし、品質を検証せよ。..."

# 細作（調査）
Task: name="saisaku", team_name="{team}", subagent_type="Explore"
  prompt: "あなたは細作（さいさく）。コードベースを調査し、実装に必要な情報を収集せよ。..."
```

### 5. 監視

- `TaskList` で進捗確認
- 都督からのメッセージで状況把握
- 完了したら `TeamDelete` でクリーンアップ

## 注意事項

- 丞相（自分）は直接実装しない。都督に委任する
- 兵は `isolation: "worktree"` で起動すると安全（並行編集の競合防止）
- 大隊編成はトークン消費が大きい。必要な規模だけ起動する
- 将軍システム（tmux+YAML）とは完全に別。混同しない
