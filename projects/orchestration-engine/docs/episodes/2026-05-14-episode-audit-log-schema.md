---
id: "01KRJME485MH814XFZWHS2NQTP"
title: "DI-11 監査ログ JSON Lines スキーマ定義"
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
    ref: "projects/orchestration-engine/schemas/failure-taxonomy.schema.json"
    reason: "state フィールドの値定義元"
  - type: design_context
    ref: "projects/orchestration-engine/schemas/exit-code-mapping.schema.json"
    reason: "session_end 時の state 値決定ロジック"
tags: [orchestration, mvp, step-4-1, episode, audit-log, jsonl, observability, di-11]
---

# DI-11 監査ログ JSON Lines スキーマ定義

## 経緯・背景

Step 4-0 Discussion §11 で「監査ログは JSON Lines 形式で `audit/` 配下に追記」の方針が合意された。Discussion §14 では「クリーンアップ実行も監査ログに記録」が追加要件として明記されている。

MVP の監査ログに求められる粒度は「1 サイクル再構成可能」であり、コマンド単位の完全再現は MVP 外とされた（Discussion §11 明記）。この粒度基準に基づき、記録対象のイベント種別と各フィールドの構成を確定する。

## 検討した選択肢

### ログ形式

| 候補 | 評価 |
|---|---|
| 構造化ログ（JSON Lines） | `jq` で即時検索・フィルタ可能。1 行 1 イベントで追記が容易。Bash + `jq -c` で生成可能 |
| プレーンテキスト | パース困難。構造化クエリ不可 |
| SQLite | 単体で高機能だが、Bash からの書き込みに追加ツールが必要 |
| 1 ファイル / 全セッション共有 | ファイルロック競合のリスク。並列セッション時に問題 |

→ JSON Lines を採用。1 セッション = 1 ファイル（`audit/${session_id}.jsonl`）でファイルロック不要。

### event_type の粒度

| 候補 | 評価 |
|---|---|
| 最小限（start / end のみ） | サイクル再構成不可 |
| 中間（9 種別） | 状態遷移・割り込み・サーキットブレーカー・クリーンアップを網羅。MVP の「1 サイクル再構成可能」基準を満たす |
| 最大限（コマンド単位記録を含む） | Discussion §11 で MVP 外と明記 |

→ 9 種別の中間粒度を採用。

### payload の型制約

| 候補 | 評価 |
|---|---|
| event_type ごとに厳格な payload スキーマ | 型安全だが、MVP の反復速度を下げる |
| 自由形式（`additionalProperties: true`） | 柔軟。MVP ではイベント種別ごとの推奨フィールドをドキュメントで示す |
| payload なし（トップレベルに全フィールド展開） | event_type ごとに異なるフィールドが混在し、スキーマが肥大化 |

→ 自由形式を採用。Schema の `allOf` + `if/then` でイベントごとの推奨構造をドキュメント的に記述。

### state フィールドの nullable 設計

| 候補 | 評価 |
|---|---|
| 全イベントで state 必須 | `polling_snapshot` 等に無意味な値を強制 |
| state は nullable、特定 event_type でのみ必須 | `state_change` と `session_end` で必須、それ以外は null 許容 |
| state フィールドなし（payload 内に格納） | トップレベルでのフィルタリングが不便 |

→ nullable 設計を採用。`state_change` と `session_end` では `required` で強制。

## 確定内容

### スキーマ構造

| フィールド | 型 | 必須 | 説明 |
|---|---|---|---|
| `ts` | string (ISO 8601) | Yes | イベント発生時刻（タイムゾーン付き） |
| `session_id` | string (ULID) | Yes | セッション識別子 |
| `pane_id` | integer | Yes | WezTerm ペイン ID |
| `event_type` | string (enum) | Yes | イベント種別（9 値） |
| `state` | string / null | No | failure-taxonomy enum 値（該当イベントのみ） |
| `payload` | object | No | イベント種別ごとの付加情報（自由形式） |

### event_type 一覧（9 種別）

| event_type | 説明 | state | payload（推奨） |
|---|---|---|---|
| `session_start` | セッション開始（envelope 注入完了時） | null | envelope サマリ |
| `state_change` | 状態遷移 | 遷移先 state | `from`, `to` |
| `polling_snapshot` | ポーリング取得（状態変化時のみ記録） | null | スナップショット要約 |
| `interrupt` | 割り込み実行 | null | `method` (SIGINT / tty_inject) |
| `human_input` | 人間の直接入力（UC-3 監査要件） | null | `target_pane_id`, `input_content` |
| `circuit_breaker_triggered` | サーキットブレーカー発動 | null | `limit_type`, `reached_value` |
| `validation_failure` | Schema 検証失敗 | null | `schema_path`, `error_detail` |
| `cleanup` | クリーンアップ実行（§14 準拠） | null | `killed_pane_ids` |
| `session_end` | セッション終了 | 最終 exit_state | — |

### 記録粒度（MVP 基準）

| 対象 | 粒度 | 根拠 |
|---|---|---|
| 状態遷移 | 全遷移を記録 | 1 サイクル再構成に必須 |
| ポーリング | 状態変化時のみ | 毎ポーリング記録は MVP 外 |
| 人間割り込み | 全入力を記録 | UC-3 監査要件 |
| コマンド単位 | 記録しない | Discussion §11 で MVP 外と明記 |

### ファイル配置

- パス: `audit/${session_id}.jsonl`
- 書き込み: ディスパッチャが `jq -c` で整形して追記
- 1 ファイル = 1 セッション（並列セッション時のロック不要）

### Schema ファイル

- `schemas/audit-log.schema.json` — JSON Lines の 1 行分のスキーマ

## 根拠

- JSON Lines は `jq` エコシステムと親和性が高く、Bash ベースのディスパッチャに適合
- 9 種別の event_type は「1 サイクル再構成可能」の MVP 基準から逆算
- `session_start` → `state_change*` → `session_end` の時系列が揃えば、セッションの流れを再構成できる
- payload を自由形式にすることで、event_type 追加時にスキーマ変更を最小化
- `cleanup` イベントの記録は Discussion §14 の明示的要件

## 影響・制約

- DI-4（failure-taxonomy enum）: `state` フィールドの値定義に依存
- DI-9（exit code マッピング）: `session_end` イベントの `state` 値はマッピング結果を使用
- DI-15（Schema-driven 検証）: 監査ログ行の `jq` バリデーション対象
- ポーリング頻度の変更（毎回記録への切り替え等）は event_type の追加ではなく記録ポリシーの変更で対応
- `payload` の厳格なスキーマ定義は将来課題（MVP 後のフェーズで event_type ごとの sub-schema を導入可能）

## 将来の拡張ポイント

- event_type の追加（例: `retry_start`, `dependency_resolved`）は enum 拡張で対応
- payload の sub-schema 導入（event_type ごとに `$ref` で厳格な型定義）
- ログローテーション・圧縮（長時間セッション対応）
- 監査ログの集約ビューア（複数セッション横断検索）
- リプレイ機能（監査ログから操作を再現するデバッグツール）
