# 設計書群（Design Notes）

> 将軍と殿のセッションで決定した方針・コンセプト・設計を「付箋」として蓄積する。
> 1ファイル = 1テーマ。短く、明確に。
> 作戦（sakusen_NNN）が「何をやるか」なら、設計書は「どうあるべきか」。
> **Memory MCP の代替**: 殿の方針はここに書く。エージェントは必要時にこのディレクトリを読む。

最終更新: 2026-03-01

## インデックス

### ビジョン・コンセプト

| ファイル | テーマ | 決定日 |
|---------|--------|--------|
| [site_vision.md](site_vision.md) | ビジョン・差別化・成功指標 | 2026-02-27 |
| [target_user.md](target_user.md) | ターゲットユーザー・流入戦略 | 2026-02-27 |
| [competitive_position.md](competitive_position.md) | 競合ポジショニング | 2026-02-27 |
| [content_scope.md](content_scope.md) | コンテンツ範囲（何を含め何を除くか） | 2026-02-27 |

### UX・機能設計

| ファイル | テーマ | 決定日 |
|---------|--------|--------|
| [ux_principles.md](ux_principles.md) | UX 方針・操作原則 | 2026-02-27 |
| [recommendation_design.md](recommendation_design.md) | レコメンドアルゴリズム方針 | 2026-02-27 |
| [auth_strategy.md](auth_strategy.md) | 認証戦略（MVP は認証なし） | 2026-02-27 |
| [zoning_policy.md](zoning_policy.md) | 成人コンテンツのゾーニング | 2026-02-27 |

### データ・インフラ

| ファイル | テーマ | 決定日 |
|---------|--------|--------|
| [tag_system.md](tag_system.md) | タグ体系設計（10層・メイン/サブ分離） | 2026-03-01 |
| [cover_pipeline.md](cover_pipeline.md) | カバー画像パイプライン | 2026-03-01 |
| [ranking_sources.md](ranking_sources.md) | 多角的ランキングデータソース | 2026-03-01 |
| [data_policy.md](data_policy.md) | データソース方針（何を使い、何を使わないか） | 2026-03-01 |
| [quality_standards.md](quality_standards.md) | 品質基準（画像・データ） | 2026-03-01 |

### 収益化・ローンチ

| ファイル | テーマ | 決定日 |
|---------|--------|--------|
| [affiliate_strategy.md](affiliate_strategy.md) | アフィリエイト・収益化戦略 | 2026-03-01 |
| [launch_strategy.md](launch_strategy.md) | ローンチ戦略・チャネル | 2026-02-27 |

### 運用ルール

| ファイル | テーマ | 決定日 |
|---------|--------|--------|
| [manga_file_policy.md](manga_file_policy.md) | 漫画ファイル管理方針（自動格納禁止） | 2026-02-28 |

## 運用ルール

- 新しい方針が決まったら、該当ファイルを更新 or 新規作成
- 1ファイルが長くなりすぎたら分割
- 古い方針が変わったら上書き（履歴は git で追跡）
- **全エージェント**: タスク実行前に関連する設計書を読むこと
- **Memory MCP**: 設計書にある内容は Memory MCP に入れない（二重管理防止）
