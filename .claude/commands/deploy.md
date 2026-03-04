# /deploy — Blue-Green デプロイ操作

manga-discover (public app) の Blue-Green デプロイを操作する。

## 手順

1. まず現在の状態を確認して表示:
```bash
bash /Users/nobi/projects/012_manga-workspace/scripts/deploy/deploy.sh status
```

2. AskUserQuestion で操作を選ばせる:

```
question: "どの操作を実行しますか？"
header: "Deploy"
options:
  - label: "build"
    description: "git pull → ビルド → 待機スロットにデプロイ"
  - label: "swap"
    description: "トラフィックを待機スロットに切替（ゼロダウンタイム）"
  - label: "rollback"
    description: "前のスロットに戻す"
```

3. 選択された操作を実行:
   - **build**: `bash /Users/nobi/projects/012_manga-workspace/scripts/deploy/deploy.sh build` （タイムアウト300秒）
   - **swap**: `bash /Users/nobi/projects/012_manga-workspace/scripts/deploy/deploy.sh swap`
   - **rollback**: `bash /Users/nobi/projects/012_manga-workspace/scripts/deploy/deploy.sh rollback`

4. 実行後、再度 status で結果を表示する。

5. build 完了後は「swap しますか？」と追加で確認する。
