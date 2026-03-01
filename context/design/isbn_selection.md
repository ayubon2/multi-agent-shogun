# ISBN選択優先度ルール

決定日: 2026-03-01
ステータス: 殿承認済み（仕組みとして全スクリプト・クエリに組み込むこと）

## 問題

`MIN(isbn13)` で1作品1ISBNを選ぶと、数字の小さい remix/文庫版ISBNが優先され、
通常単行本（コミックス）1巻のカバーではなく、別版のカバーが表示される。

## 集英社 ISBN プレフィックス → 版マッピング

| プレフィックス | 版 | 優先度 | 件数 |
|---|---|---|---|
| `9784088` | 通常単行本（ジャンプ・コミックス等） | 1（最優先） | 10,908 |
| `9784089` | 新単行本（JUMP COMICS+） | 2 | 19 |
| `9784086` | 混在（文庫 + 一部通常） | 3 | 1,111 |
| `9784087` | 愛蔵版 | 4 | 577 |
| `9784081` | remix/総集編（最低優先） | 5 | 502 |

## 標準SQLスニペット（全スクリプト・クエリで使用すること）

### Python（収集スクリプト用）

```python
# --- ISBN選択優先度 (context/design/isbn_selection.md 参照) ---
ISBN_PRIORITY_SQL = """
    SELECT e.external_id as isbn
    FROM external_ids e
    WHERE e.work_id = {work_id_column}
      AND e.source = 'isbn'
      AND e.external_id LIKE '978%'
      AND LENGTH(e.external_id) = 13
    ORDER BY
      CASE
        WHEN e.external_id LIKE '9784088%' THEN 1
        WHEN e.external_id LIKE '9784089%' THEN 2
        WHEN e.external_id LIKE '9784086%' THEN 3
        WHEN e.external_id LIKE '9784087%' THEN 4
        WHEN e.external_id LIKE '9784081%' THEN 5
        ELSE 3
      END,
      e.external_id ASC
    LIMIT 1
"""
```

### TypeScript（queries.ts用）

```sql
(SELECT external_id FROM external_ids
 WHERE work_id = w.id AND source='isbn'
   AND external_id LIKE '978%' AND LENGTH(external_id) = 13
 ORDER BY
   CASE
     WHEN external_id LIKE '9784088%' THEN 1
     WHEN external_id LIKE '9784089%' THEN 2
     WHEN external_id LIKE '9784086%' THEN 3
     WHEN external_id LIKE '9784087%' THEN 4
     WHEN external_id LIKE '9784081%' THEN 5
     ELSE 3
   END,
   external_id ASC
 LIMIT 1) as first_isbn
```

## 適用対象

### Pythonスクリプト（MIN(isbn)を上記CASE ORDER BYに置換）
| ファイル | 場所 | 現状 |
|---|---|---|
| `012_manga-workspace/scripts/collect_kinokuniya_covers.py` | L151 | `MIN(e.external_id) as isbn` |
| `002_manga-system/collect_openbd.py` | L104 | `MIN(ei.external_id) as isbn` |
| `002_manga-system/collect_google_books.py` | L95 | `MIN(ei.external_id) as isbn` |
| `002_manga-system/collect_bookwalker_covers.py` | — | DESC順で正しい（変更不要） |

### TypeScript（LIMIT 1 → CASE ORDER BY + LIMIT 1に置換）
| ファイル | 箇所数 |
|---|---|
| `012_manga-workspace/apps/public/src/lib/queries.ts` | 18箇所 |

全箇所で `(SELECT external_id FROM external_ids WHERE work_id = w.id AND source='isbn' LIMIT 1)` を上記の標準SQLスニペットに置換すること。

## 修正後の再収集

修正適用後、既に間違ったカバーで登録された作品（約28件、紀伊國屋）のcover_urlをNULLにリセットし、再収集すること。

## 将来の拡張

- 他出版社でも同様のプレフィックス→版マッピングが判明したら、CASEに追加する
- `external_ids` テーブルに `edition_type` カラムを追加し、ISBNを分類する方式も将来検討可
