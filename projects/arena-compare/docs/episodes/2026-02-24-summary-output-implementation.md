---
title: "arena-compare.sh に回答サマリ出力機能（summary.md）を追加"
date: 2026-02-24
type: episode
related:
  - type: derived_from
    ref: ../plans/2026-02-24-kickoff-summary-output.md
    reason: "キックオフプランに基づく実装"
  - type: derived_from
    ref: ./2026-02-24-command-and-model-defaults.md
    reason: "コマンド化完了後の次ステップ"
tags: [arena-compare, summary, markdown, ux]
---

# arena-compare.sh に回答サマリ出力機能（summary.md）を追加

## 背景

arena-compare.sh は複数モデルの回答を個別ファイル（`{model}-stdout.txt`）に保存するが、比較には `cat` を並べて目視するしかなかった。回答内容の比較を容易にする統合出力が必要。

## 実施内容

### 1. `generate_summary()` 関数の追加

`arena-compare.sh` に `generate_summary()` 関数を追加。既存の meta.txt / stdout.txt / prompt.txt から `summary.md` を自動生成する。

summary.md の構造:
- プロンプト先頭100文字、実行日時、モデル一覧
- メタデータテーブル（モデル名、実行時間、行数、バイト数、exit code）
- 各モデルの回答全文（見出し付き）

異常系の処理:
- exit code 124 → `(タイムアウト)` サフィックス + `(タイムアウトにより出力なし)`
- exit code ≠ 0 → `(異常終了)` サフィックス
- meta.txt なし → フォールバック表示

### 2. 本体への組み込み

- `wait` 完了後、結果サマリ表示前に `generate_summary` を呼び出し
- `2>/dev/null || true` で生成失敗時も本体の exit code に影響しない
- dry-run 時はスキップ
- 結果確認コマンドが `cat summary.md` に統合

### 3. arena-perspectives コマンドの更新

`cursor/command/verification/arena-perspectives.md` の Step 3 を `summary.md` ベースに簡素化。個別 `cat` の羅列 → `cat summary.md` の1行に。

## 検証結果

### 実行検証（3モデル並列、resume-support 計画の評価タスク）

| モデル | 時間 | 出力 | exit |
|--------|------|------|------|
| composer-1.5 | 27秒 | 4,196B | 0 |
| gemini-3.1-pro | 98秒 | 3,996B | 0 |
| gpt-5.2 | 119秒 | 7,934B | 0 |

- `summary.md` 自動生成: 16,668B、メタデータテーブル + 全回答含む
- shellcheck パス（exit 0）

### 検証で発見・修正した問題

1. **UTF-8 文字化け**: `head -c 100`（バイト単位）が日本語の3バイト文字途中で切断し、不正な UTF-8 を生成。`file` コマンドが `Non-ISO extended-ASCII text` と誤判定 → エディタ・ターミナルで文字化け。`${prompt_full:0:100}`（文字単位）に修正

2. **部分 resume 時の `--mode` 欠落**（arena 評価で3モデルから指摘）: `--resume-from` 指定時、新規追加モデル（chat-id なし）でも `--mode` が付かなかった。`get_chat_id()` が `new:UUID` / `resumed:UUID` プレフィックスを返す方式に変更し、チャット単位で `--mode` 付与を判定するように修正

3. **`usage()` の ARENA_TIMEOUT デフォルト不一致**: 表記 300 → 実際の 180 に修正

## 成果物

- `projects/arena-compare/arena-compare.sh`: `generate_summary()` 追加、UTF-8 修正、`--mode` 判定改善、usage 修正
- `cursor/command/verification/arena-perspectives.md`: Step 3 更新
- `projects/arena-compare/README.md`: 出力構造に `summary.md` 追記

## キックオフプラン完了条件の達成状況

- [x] `arena-compare.sh` 実行後に `summary.md` が自動生成される
- [x] summary.md にメタデータテーブル + 各モデルの回答全文が含まれる
- [x] タイムアウトしたモデルは「(タイムアウト)」等で表示される（実装済み、実行時未発生）
- [x] `arena-perspectives.md` の Step 3 が更新されている
- [x] shellcheck パス
- [x] 検証エピソードが記録されている（本ドキュメント）
