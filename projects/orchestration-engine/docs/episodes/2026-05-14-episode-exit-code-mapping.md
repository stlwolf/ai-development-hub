---
id: "01KRJME2ZDVW26VWGQWDVQTGAC"
title: "DI-9 Exit Code ↔ G4 6 値マッピング確定"
date: 2026-05-14
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/19"
    reason: "Epic #19 Phase 4 MVP"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/84"
    reason: "Step 4-1 観測層サブ Issue"
  - type: source_material
    ref: "projects/orchestration-engine/docs/plans/2026-05-13-plan-step-4-1-envelope-and-dispatcher.md"
    reason: "Step 4-1 Plan"
  - type: design_context
    ref: "https://github.com/stlwolf/ai-development-hub/issues/36"
    reason: "#36 多周制御仕様文書（exit code 0/1/2 基本分類の出典）"
  - type: design_context
    ref: "https://github.com/stlwolf/ai-development-hub/issues/22"
    reason: "#22 so-compare.sh（exit code 体系 0/1/2 の由来）"
tags: [orchestration, mvp, step-4-1, episode, exit-code, failure-taxonomy, g4, di-9]
---

# DI-9 Exit Code ↔ G4 6 値マッピング確定

## 経緯・背景

Step 4-0 Discussion §8 で、サブエージェントの exit code 体系を `0 / 1 / 2` の 3 値に定めた（#22 so-compare.sh 由来）。一方、DI-4 で確定した G4 Failure Taxonomy は 6 値 enum（`success / partial / retryable_failure / blocked / protocol_error / timeout`）であり、exit code 3 値と 6 値 enum の間にマッピングルールが必要になった。

DI-7+DI-12 でサーキットブレーカー設計が確定し、`timeout` コマンドによるタイムアウト検出（exit code 124）が加わったことで、マッピング対象は 5 パターンに拡大した。

## 検討した選択肢

### exit code の拡張方針

| 候補 | 評価 |
|---|---|
| exit code を 6 値に 1:1 対応させる | サブエージェント側に 6 値の exit code 規約を強制。既存ツール（so-compare.sh 等）との互換性を損なう |
| exit code は最小限（0/1/2）+ 補助シグナルで 6 値に分岐 | 既存の exit code 体系を維持しつつ、終了マーカースキャン等で不足分を補完 |
| exit code を無視し、出力のみで判定 | exit code の即時判定メリットを失う |

→ 2 番目を採用。exit code は「一次分類」、補助シグナル（終了マーカースキャン）は「二次分類」として 2 段階判定を行う。

### exit code 124 の扱い

| 候補 | 評価 |
|---|---|
| 124 を `protocol_error` に含める | timeout 固有のリカバリ戦略を区別できない |
| 124 を専用の `timeout` にマッピング | Bash `timeout` コマンドの標準 exit code（POSIX 非標準だが de facto）と一致。DI-7+DI-12 サーキットブレーカー設計と整合 |

→ exit code 124 は `timeout` に直接マッピング。

### `blocked` の判定方法

| 候補 | 評価 |
|---|---|
| 専用 exit code（例: 3）を割り当て | サブエージェントに `blocked` 専用の exit code を返す実装が必要。Claude Code CLI の exit code 仕様に制約される |
| exit code 2 + 終了マーカースキャン | DI-8 の終了マーカー仕様（`===STATE: blocked===`）を活用。exit code を変更せずに判定可能 |

→ exit code 2 + 終了マーカースキャンの組み合わせを採用。exit code 単独では `retryable_failure`、マーカーに `BLOCKED` を含む場合のみ `blocked` に上書き。

## 確定内容

### マッピングテーブル

| exit code | 一次マッピング | 補助シグナル | 最終 state |
|---|---|---|---|
| 0 | `success` | — | `success` |
| 1 | `partial` | — | `partial` |
| 2 | `retryable_failure` | 終了マーカーに `BLOCKED` 含む → `blocked` | `retryable_failure` or `blocked` |
| 124 | `timeout` | — | `timeout` |
| その他 (≥3, ≠124) | `protocol_error` | — | `protocol_error` |

### 判定フロー

1. サブエージェントプロセスの exit code を取得
2. exit code 124 → `timeout`（即確定）
3. exit code 0 → `success`（即確定）
4. exit code 1 → `partial`（即確定）
5. exit code 2 → 終了マーカーをスキャン
   - `===STATE: blocked===` を検出 → `blocked`
   - 検出なし → `retryable_failure`
6. exit code ≥3 (≠124) → `protocol_error`

### Schema ファイル

- `schemas/exit-code-mapping.schema.json` — マッピングルールを JSON Schema 形式で構造化

## 根拠

- exit code 0/1/2 の基本分類は #22 so-compare.sh に由来し、#36 多周制御仕様文書で追認済み
- exit code 124 は Bash `timeout` コマンドの戻り値（GNU coreutils 由来の de facto 標準）
- `blocked` は exit code だけでは判別不能 → DI-8 終了マーカースキャンとの組み合わせが必要（2 段階判定）
- 「一次マッピング → 補助シグナルで上書き」の設計は、既存 exit code 体系を壊さずに 6 値 enum の表現力を確保する

## 影響・制約

- DI-8（終了マーカー仕様）に依存: `blocked` 判定は終了マーカースキャンがなければ `retryable_failure` にフォールバック
- DI-4（failure-taxonomy enum）のすべての値がこのマッピングでカバーされている
- DI-5（envelope の `exit_state`）にマッピング結果を書き込む
- DI-11（監査ログ）の `session_end` イベントの `state` フィールドにも同じ値を記録
- サブエージェント側は exit code 0/1/2 のみを意識すればよい（124 はディスパッチャの `timeout` コマンドが返す）

## 128+N（signal-killed）の扱い

> 2026-06-11 追記（#149 監査 L6 の back-propagation）。本節は [so-compare 設計レビュー episode](2026-05-14-episode-so-compare-step-4-1-design-review.md) の「修正 2」が本 episode への追記を指示したまま未反映だった欠陥（監査 L6 の実例）の解消。

- **問題**: SIGINT (130) / SIGKILL (137) など 128+N（signal-killed）は素朴には `protocol_error` に落ちるが、UC-1 の意図的 interrupt（`wez pane send` による SIGINT 注入）と区別できない
- **MVP の契約**: ディスパッチャは `wez pane send` の実行主体であり「直前に interrupt を送信した」情報を保持できる。**直前に interrupt を送った場合は exit 130 を `blocked` に再分類**する補助判定ルールを契約として明示する
- それ以外の 128+N は `protocol_error` のまま扱う

## 将来の拡張ポイント

- exit code の追加（例: Claude Code CLI が新しい exit code を導入した場合）はマッピングテーブルに行を追加するだけで対応
- 補助シグナルの追加（例: stderr パターンマッチ、ファイル存在チェック）で判定精度を向上可能
- 多周制御（#36）でリトライ判断に `retryable_failure` / `partial` の区別を活用予定
