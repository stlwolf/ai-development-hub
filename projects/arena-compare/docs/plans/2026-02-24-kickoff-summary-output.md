---
title: "キックオフ: arena-compare.sh に回答サマリ出力機能を追加する"
date: 2026-02-24
type: plan
related:
  - type: derived_from
    ref: ../episodes/2026-02-24-command-and-model-defaults.md
    reason: "コマンド化・モデル選定完了後の次ステップとして、比較体験の改善が必要"
  - type: derived_from
    ref: ../episodes/2026-02-22-prototype-verification.md
    reason: "次のステップに「回答品質を比較する自動サマリ機能」が残っている"
  - type: depends_on
    ref: ../../arena-compare.sh
    reason: "改修対象"
tags: [arena-compare, summary, diff, comparison, ux]
---

# キックオフ: arena-compare.sh に回答サマリ出力機能を追加する

## 背景

arena-compare.sh は複数モデルの回答を個別ファイル（`{model}-stdout.txt`）に保存するが、比較は `cat` を並べて目視するしかない。ツールのコア目的が「多角的な意見の比較」である以上、回答内容の比較を容易にする出力が必要。

3モデルの arena 評価（2026-02-24）でも全員一致で「サマリ機能が最優先」と判断。

## 成功基準

1. 実行完了後に `{out_dir}/summary.md` が自動生成される
2. summary.md は各モデルの回答を見出し付きで並べた Markdown
3. メタデータテーブル（モデル名、実行時間、出力サイズ、exit code）が冒頭にある

## 設計

### summary.md の構造

```markdown
# Arena Compare Summary

- **プロンプト**: (先頭100文字...)
- **日時**: 2026-02-24 01:54:40
- **モデル**: gpt-5.2, gemini-3.1-pro, composer-1.5

## メタデータ

| モデル | 時間 | 行数 | バイト数 | exit |
|--------|------|------|----------|------|
| gpt-5.2 | 64秒 | 66行 | 5776B | 0 |
| gemini-3.1-pro | 45秒 | 37行 | 3740B | 0 |
| composer-1.5 | 29秒 | 115行 | 6216B | 0 |

## gpt-5.2

(stdout の全文)

## gemini-3.1-pro

(stdout の全文)

## composer-1.5

(stdout の全文)
```

### 生成タイミング

完了待ち（`wait`）の後、サマリ表示の前に `generate_summary()` を呼ぶ。

### コマンド（arena-perspectives）への反映

Step 3 の結果表示で、個別 `cat` の代わりに `summary.md` を読むだけで済むように更新。

## 実装ステップ

### Step 0: 前提確認（5分）

- 既存の出力構造（`{model}-meta.txt`, `{model}-stdout.txt`, `prompt.txt`）で summary 生成に必要な情報が揃っているか確認
- `set -euo pipefail` 環境で summary 生成が失敗しても本体の exit code に影響しないようにする方針決定

### Step 1: `generate_summary()` 関数の実装（20分）

- prompt.txt からプロンプト先頭を取得
- 各モデルの meta.txt を source してメタデータテーブルを生成
- 各モデルの stdout.txt を見出し付きで結合
- `{out_dir}/summary.md` に書き出し

### Step 2: 本体への組み込み（10分）

- 完了待ちの後、サマリ表示の前に `generate_summary` を呼ぶ
- 生成成功時に `cat $OUT_DIR/summary.md` のヒントを表示
- dry-run 時はスキップ

### Step 3: コマンド更新（5分）

- `arena-perspectives.md` の Step 3 を `summary.md` ベースに更新

### Step 4: 検証（10分）

- デフォルトモデルで実行し、summary.md が正しく生成されることを確認
- タイムアウトしたモデル（exit≠0）がある場合の表示を確認
- shellcheck パス

### Step 5: エピソード記録（10分）

- 検証結果をエピソードに記録

## 完了条件

- [x] `arena-compare.sh` 実行後に `summary.md` が自動生成される
- [x] summary.md にメタデータテーブル + 各モデルの回答全文が含まれる
- [x] タイムアウトしたモデルは「(タイムアウト)」等で表示される
- [x] `arena-perspectives.md` の Step 3 が更新されている
- [x] shellcheck パス
- [x] 検証エピソードが記録されている

## 実行フロー

Stage 1〜3 を本スレッドで連続実行する想定（小規模改修のため Stage 分離は不要）。
