---
id: "01KRJKWGD7G2HFAX5RTS7YY80S"
title: "G3 outputs 宣言フォーマット + KVS 契約定義"
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
    ref: "https://github.com/stlwolf/ai-development-hub/issues/47"
    reason: "並列セッション運用要件（UC-2 / DI-6 の補助入力）"
tags: [orchestration, mvp, step-4-1, episode, schema, outputs, kvs, g3, session-state]
---

# G3 outputs 宣言フォーマット + KVS 契約定義

## 経緯・背景

Step 4-0 Discussion 論点 6 および Harness ギャップ [#37](https://github.com/stlwolf/ai-development-hub/issues/37) G3 で、サブエージェントの「何を生成し、どこに置くか」の宣言方法と、UC-2 並列協調のためのファイルベース KVS の設計が論点となった。KickOff DI-6 として Decision Item に設定された。

Step 4-1 Plan フェーズ 1 で以下が確定:

- outputs 宣言の正本: envelope 内の `task.output_dir`
- KVS 形式: 単一 JSON ファイル（`{session_id}.state.json`）
- ロック戦略: atomic rename（`mv`）

## 検討した選択肢

### outputs 宣言の場所

| 候補 | 利点 | 欠点 | 評価 |
|---|---|---|---|
| SKILL.md frontmatter に `outputs:` 追加 | スキル定義と一体管理 | 既存パターンなし（Step 0 調査で確認）、SKILL.md は汎用定義でセッション固有情報を持たない | 見送り |
| 独立宣言ファイル | 柔軟 | 管理対象ファイル増加 | 見送り |
| envelope 内 `task.output_dir` | ディスパッチャとの整合性高い、セッション固有の出力先を指定可能 | スキル定義との分離 | **採用** |

→ envelope 経由での宣言を採用。`canonical/skills` に `outputs:` フィールドがない（Step 0 調査結果）ため、新規パターンを skill 側に導入するよりも、dispatcher が制御する envelope 側に寄せる方が設計の一貫性が高い。

### KVS 形式

| 候補 | 利点 | 欠点 | 評価 |
|---|---|---|---|
| 単一 JSON ファイル（`{session_id}.state.json`） | jq で読み書き可能・セッション単位で分離 | ファイル数がセッション数に比例 | **採用** |
| JSON Lines 追記 | 1 ファイルで全セッション管理 | 並列書き込みで破損リスク | 見送り |
| ディレクトリ + 個別 JSON | 構造化度高い | 過剰な階層 | 見送り |

### ロック戦略

| 候補 | 利点 | 欠点 | 評価 |
|---|---|---|---|
| `flock` | 標準的なファイルロック | macOS で挙動が異なる（BSD flock） | 見送り |
| atomic rename（`mv`） | POSIX で atomic 保証・クロスプラットフォーム | 一時ファイル管理が必要 | **採用** |
| lockfile なし（単一ライター前提） | シンプル | 並列書き込み時に破損リスク | 見送り |

→ atomic rename を採用。書き込みパターン: 一時ファイルに書き出し → `mv` で本番パスに移動。`mv` は同一ファイルシステム内で POSIX atomic が保証される。

## 確定内容

### outputs 宣言

- 正本: envelope 内の `task.output_dir`（相対パス）
- サブエージェントはこのディレクトリに成果物を配置
- 実際に生成されたファイル一覧は session-state KVS の `outputs` 配列に記録

### Session State KVS スキーマ

- JSON Schema ファイル: `schemas/session-state.schema.json`（draft-07 準拠）
- ファイル命名: `{session_id}.state.json`
- 必須フィールド: `session_id`（ULID）, `pane_id`（integer）, `state`（failure-taxonomy enum）, `last_updated`（ISO 8601）
- オプションフィールド: `outputs`（生成ファイルパス配列）, `blockers`（ブロッカー記述配列）

### 読み書きフロー

1. サブエージェント（または dispatcher の監視ループ）が状態変化を検知
2. 一時ファイル `{session_id}.state.json.tmp` に新しい状態を書き出し
3. `mv {session_id}.state.json.tmp {session_id}.state.json` で atomic に更新
4. 親エージェントは `{session_id}.state.json` を `jq` で読み取り

## 根拠

- `task.output_dir` を正本とすることで、envelope → dispatcher → サブエージェントの情報フローが一方向になり、設計の見通しが良い
- `{session_id}.state.json` のセッション単位分離により、並列セッション（UC-2）間の干渉を構造的に排除
- atomic rename は macOS / Linux 両対応で、`flock` の BSD/GNU 差異問題を回避
- `outputs` フィールドにより「宣言された出力先（envelope）」と「実際の成果物（KVS）」を突合可能

## 影響・制約

- KVS ファイルの配置ディレクトリは dispatcher 起動時に決定（envelope の `context.shared_kvs_path` または dispatcher のデフォルトパス）
- `state` フィールドは DI-4 の failure-taxonomy enum を使用（6 値に限定）
- 同一セッション内での並列書き込みは想定しない（1 セッション = 1 ライター）
- KVS ファイルのクリーンアップは DI-14（クリーンアップ戦略）の管轄

## 将来の拡張ポイント

- `outputs` 配列の各要素に型情報（例: `{"path": "...", "type": "episode"}`) を付与して成果物の自動分類に対応
- `blockers` 配列の構造化（自由記述 → 型付きブロッカーオブジェクト）
- `progress` フィールドの追加（0.0〜1.0 の進捗率、粗い粒度）
- 複数ライター対応（CAS: Compare-And-Swap パターン + version フィールド）
