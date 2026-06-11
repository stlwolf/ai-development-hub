---
id: "01KRJKWHDY04T8RZ95J35YNEK1"
title: "Schema-driven Boundaries 検証ツール + 差し戻し動作定義"
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
    ref: "projects/orchestration-research/synthesis/architecture-sketch.md"
    reason: "architecture-sketch §2「薄いシェル: Bash + jq」制約"
tags: [orchestration, mvp, step-4-1, episode, schema, validation, jq, schema-driven-boundaries]
---

# Schema-driven Boundaries 検証ツール + 差し戻し動作定義

## 経緯・背景

Step 4-0 Discussion 論点 15 で Schema-driven Boundaries の検証方法が議論され、KickOff DI-15 として「検証ツール選定と差し戻しフロー」が Decision Item に設定された。DI-4（failure-taxonomy）/ DI-5（envelope）/ DI-6（session-state）の各 Schema が定義された後、それらを検証するツールと検証失敗時の動作を確定する必要があった。

## 検討した選択肢

### 検証ツール

| 候補 | 利点 | 欠点 | 評価 |
|---|---|---|---|
| `ajv-cli` | JSON Schema 完全準拠・厳密な検証 | Node.js 依存。architecture-sketch §2 の「Bash + jq」制約に抵触 | 見送り（将来の移行先候補） |
| `python3 -m jsonschema` | JSON Schema 完全準拠 | Python 依存。同上 | 見送り |
| `jq --exit-status` | Bash + jq で完結・外部依存なし | JSON Schema の完全検証は困難（`$ref`, `patternProperties` 等は非対応） | **採用** |

→ `jq --exit-status` を採用。MVP では「必須フィールド存在チェック + enum 値チェック + 型チェック」で十分。JSON Schema ファイル自体は draft-07 標準準拠で作成済みのため、将来 `ajv-cli` への移行パスは確保されている。

### 検証失敗時の差し戻しフロー

| 候補 | 利点 | 欠点 | 評価 |
|---|---|---|---|
| 同サブエージェントへ即座に再投入 | 自動回復・人間介入不要 | 制御ループ複雑化・無限リトライリスク | 見送り（MVP 外） |
| 親エージェントに通知 → 新規 spawn | 親が判断可能 | 通知 → spawn の自動化が必要 | 見送り（MVP 外） |
| 監査ログ記録 + 親エージェント通知 → 人間判断 | シンプル・安全 | 自動回復なし | **採用** |

→ 人間判断フローを採用。検証失敗は `protocol_error`（DI-4）として記録し、親エージェントに通知。リトライ判断は人間が行う。

## 確定内容

### 検証スクリプト

- ファイル: `scripts/validate-envelope.sh`
- 技術: `jq` による必須フィールド存在チェック + enum 値チェック + 型チェック
- exit code 体系:
  - `0`: valid（検証成功）
  - `1`: invalid（検証エラー）
  - `2`: file not found / jq not found
- `--verbose` オプションで検証過程を stderr に出力

### 検証対象

| Schema | 検証スクリプト | 検証タイミング |
|---|---|---|
| `envelope.schema.json` | `validate-envelope.sh` | ディスパッチャが envelope 読み込み時 |
| `session-state.schema.json` | （将来実装） | 親エージェントが KVS 読み取り時 |
| `failure-taxonomy.schema.json` | envelope / session-state の enum チェックに内包 | 上記に含まれる |

### 差し戻しフロー

1. ディスパッチャが envelope を読み込み → `validate-envelope.sh` で検証
2. 検証失敗 → exit code `1`
3. ディスパッチャは `protocol_error` を監査ログに記録
4. 親エージェントに通知（stderr 出力 + KVS の `state` を `protocol_error` に設定）
5. 人間が判断（修正して再実行 / 別のサブエージェントに差し替え / 中止）

### 検証項目一覧（MVP）

- 必須トップレベルフィールド: `session_id`, `pane_id`, `task`, `context`, `constraints`
- 型チェック: `session_id`（string）, `pane_id`（number）, `task`（object）, `context`（object）, `constraints`（object）
- `task` 内必須フィールド: `description`, `output_dir`, `exit_conditions`
- `exit_conditions` 内必須フィールド: `marker`, `timeout_seconds`
- `constraints` 内必須フィールド: `max_panes`, `state_vocabulary`
- `state_vocabulary` の enum チェック: 5 値完全一致（spawn/ready/progress/done/blocked）
- `exit_state`（存在する場合）の enum チェック: failure-taxonomy 6 値

## 根拠

- `jq` ベースの検証は architecture-sketch §2「薄いシェル: Bash + jq」制約に最も整合
- MVP で JSON Schema 完全検証が不要な理由: envelope の生成元はディスパッチャ自身（自動生成）であり、手動編集による構造破壊リスクは低い。主な検証目的は「ディスパッチャの生成ロジックのバグ検知」と「外部入力のサニティチェック」
- 差し戻しを人間判断としたのは、制御ループの複雑化を回避するため。自動リトライは Step 4-3 以降で検討

## 影響・制約

- `validate-envelope.sh` は DI-5 の envelope.schema.json と同期を維持する必要がある（Schema 変更時にスクリプトも更新）
- `jq` が未インストールの環境では exit code `2` で即時停止（検証スキップは許容しない）
- JSON Schema の高度な機能（`$ref`, `additionalProperties`, `patternProperties`）は `jq` では検証不可。将来の Schema 拡張時に `ajv-cli` 移行を検討

## 将来の拡張ポイント

- `validate-session-state.sh` の追加（session-state.schema.json の検証）
- `ajv-cli` への移行（Node.js 環境が許容される場合）
- 検証失敗時の自動リトライ（リトライ回数上限 + バックオフ付き）
- pre-commit hook / CI への検証スクリプト統合
- 検証結果の構造化出力（JSON 形式のエラーレポート）
