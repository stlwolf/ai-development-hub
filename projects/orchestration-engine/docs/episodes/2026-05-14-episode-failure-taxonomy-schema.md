---
id: "01KRJKWEC3FFHRMMP85220XBPT"
title: "G4 Failure Taxonomy 6 値スキーマ定義"
date: 2026-05-14
type: episode
status: draft
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
    ref: "https://github.com/stlwolf/ai-development-hub/issues/37"
    reason: "Harness ギャップ G4 Failure Taxonomy"
tags: [orchestration, mvp, step-4-1, episode, schema, failure-taxonomy, g4]
---

# G4 Failure Taxonomy 6 値スキーマ定義

## 経緯・背景

Step 4-0 Discussion 論点 6 および Harness ギャップ [#37](https://github.com/stlwolf/ai-development-hub/issues/37) G4 で、サブエージェント実行結果を分類する Failure Taxonomy の必要性が識別された。KickOff DI-4 として「6 値 enum のスキーマ表現と格納場所」が Decision Item に設定された。

Step 4-1 Plan フェーズ 1 で以下が確定:

- 6 値 enum: `success / partial / retryable_failure / blocked / protocol_error / timeout`
- フィールド名: `state`
- 格納場所: 監査ログの `state` フィールド + エンベロープの `exit_state` フィールド

## 検討した選択肢

### フィールド名

| 候補 | 評価 |
|---|---|
| `status` | HTTP ステータスコードとの混同リスク |
| `state` | 状態機械（state machine）の語彙と整合。state_vocabulary との対称性あり |
| `result` | 「結果」は曖昧（成果物なのか状態なのか） |

→ `state` を採用。`constraints.state_vocabulary`（spawn/ready/progress/done/blocked）は「実行中の状態」、`state`（failure-taxonomy）は「完了後の分類」として意味的に分離される。

### 格納場所

| 候補 | 評価 |
|---|---|
| エンベロープの `exit_state` のみ | 監査ログから独立して確認不可 |
| 監査ログの `state` のみ | エンベロープ単体で完結性がない |
| 両方 | 冗長だが、両方のコンテキストで独立参照可能 |

→ 両方に配置。エンベロープは「セッション単位の完結した記録」、監査ログは「時系列イベントの記録」として、それぞれの文脈で独立参照できるようにする。

## 確定内容

- JSON Schema ファイル: `schemas/failure-taxonomy.schema.json`
- 型: `string` with `enum`
- 6 値: `success`, `partial`, `retryable_failure`, `blocked`, `protocol_error`, `timeout`
- フィールド名: `state`（監査ログ）/ `exit_state`（エンベロープ）
- エンベロープ Schema（`envelope.schema.json`）の `exit_state` が `$ref` 的にこの enum を参照（MVP では inline 定義、将来 `$ref` 化可能）

## 根拠

- 6 値は Step 4-0 Discussion で確定済み（DI-9 exit code マッピングとの一体検討結果）
- `state` フィールド名は `constraints.state_vocabulary`（5 値: spawn/ready/progress/done/blocked）との対称性を意識しつつ、意味的に「実行中 vs 完了後」で区別される
- JSON Schema `enum` は `jq` で検証可能（DI-15 の検証ツール選定と整合）

## 影響・制約

- DI-9（exit code → 6 値マッピング）はこの enum 定義に依存。exit code 単独では判別不能な値（`timeout`, `blocked`）は補助シグナル（タイマー、出力マーカー）で分岐
- DI-11（監査ログ JSON Lines）の `state` フィールドがこの enum を使用
- DI-15（Schema-driven 検証）で `jq` による enum 値チェックの対象

## 将来の拡張ポイント

- 6 値の追加・細分化（例: `partial` を `partial_success` / `partial_failure` に分岐）は JSON Schema の `enum` 配列を拡張するだけで対応可能
- `$ref` による Schema 間参照の導入（envelope / session-state / audit-log が同一定義を参照）
- 各値の「重大度（severity）」属性付与（リトライ判断の自動化向け）
