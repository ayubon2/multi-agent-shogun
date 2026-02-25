# 009 discover デザインリニューアル 参考サイト調査

## 殿の指定参考サイト
- **レイアウト**: https://syo-ei.com/ （カード配置、余白、セクション分割、モダンで清潔感）
- **色味**: https://gcs-tc-school.com/ （明るく親しみやすい、丸ゴシック + Quicksand）

## 参考サイト10選

### Tier 1: 最も参考にすべき

| サイト | URL | 参考ポイント |
|--------|-----|-------------|
| **AniList** | https://anilist.co/search/manga | グリッド整列、余白、セクション分割、ダーク/ライト切替 |
| **BookWalker** | https://bookwalker.jp/ | バッジシステム(NEW/SALE)、統一カード、出版社フィルター |
| **少年ジャンプ+** | https://shonenjumpplus.com/ | シンプルナビ、大型表紙、毎日更新ランキング |

### Tier 2: 部分的に参考

| サイト | URL | 参考ポイント |
|--------|-----|-------------|
| **MAL** | https://myanimelist.net/topmanga.php | スコアランキング表、ホバー詳細表示 |
| **MangaDex** | https://mangadex.org/ | 多軸タグフィルター(AND/OR)、多言語対応 |
| **ピッコマ** | https://piccoma.com/web/ | モジュール積み重ね、同作品を複数文脈で表示 |
| **コミックシーモア** | https://www.cmoa.jp/ | ジャンル色分けタブ、ブランドカラー(オレンジ)一貫使用 |
| **まんが王国** | https://comic.k-manga.jp/ | カテゴリ別背景色変化、コンパクトカード |
| **Kitsu** | https://kitsu.io/ | ソーシャル+ディスカバリー融合、プロフェッショナルブランディング |
| **Open Library** | https://openlibrary.org/subjects/manga | API設計、ほぼ見えないナビゲーション |

## 推奨デザイン方針

1. **レイアウト**: AniListのグリッド整列 + syo-ei.comの余白感
2. **色使い**: 白背景ベース + 明るいアクセントカラー（オレンジ系/コーラル系）
3. **フォント**: 丸ゴシック系(Noto Sans JP / M PLUS Rounded 1c) + Quicksand/Inter(英字)
4. **カード**: BookWalker式の統一サイズ表紙 + バッジ重畳、ホバーで詳細プレビュー
5. **セクション**: ピッコマ式モジュール積み重ね、同カードを複数文脈で再利用
6. **フィルター**: MangaDex式多軸タグ + コミックシーモア式ジャンル色分けタブ

## 現コンポーネントとの対応

| 現コンポーネント | 参考元 |
|-----------------|--------|
| work-card/work-grid | AniList(均一グリッド) + BookWalker(バッジ重畳) |
| search-bar/tag-filter | MangaDex(多軸フィルター) + コミックシーモア(色分けタブ) |
| hero-section/carousel | ジャンプ+(大型バナー) + ピッコマ(モジュール式) |
| nav-header | ジャンプ+(シンプル固定) + syo-ei.com(清潔な固定ナビ) |
