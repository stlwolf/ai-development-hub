---
id: "01KRJKWFCRYGYN9XDRT9G105DD"
title: "G6 Initializer Envelope スキーマ定義"
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
    ref: "https://github.com/stlwolf/ai-development-hub/issues/37"
    reason: "Harness ギャップ G6 Initializer Envelope"
tags: [orchestration, mvp, step-4-1, episode, schema, envelope, g6]
---

# G6 Initializer Envelope スキーマ定義

## 経緯・背景

Step 4-0 Discussion 論点 6 および Harness ギャップ [#37](https://github.com/stlwolf/ai-development-hub/issues/37) G6 で、サブエージェント起動時に「読む docs / 使う skill / 出力先 / 終了条件」をどう渡すかが論点となった。KickOff DI-5 として「表現形式（JSON / YAML / Markdown frontmatter）とディスパッチャの注入方法」が Decision Item に設定された。

Step 4-1 Plan フェーズ 1 で以下が確定:

- 表現形式: JSON 単一ファイル（`jq` で検証可能、ディスパッチャがプロンプト先頭に展開して注入）
- フィールド構成: `session_id`, `pane_id`, `task`, `context`, `constraints`, `exit_state`

## 検討した選択肢

### 表現形式

| 候補 | 利点 | 欠点 | 評価 |
|---|---|---|---|
| 案 A: JSON 単一ファイル | jq で検証可・Schema 標準あり・プログラム処理容易 | 人間可読性がやや低い | **採用** |
| 案 B: Markdown frontmatter | spec-card 形式踏襲・人間可読性高い | YAML パーサー依存・jq 検証不可 | 見送り |
| 案 C: ハイブリッド | 構造化+可読性の両立 | 二重管理・パース複雑化 | 見送り |

→ JSON 単一ファイルを採用。理由: architecture-sketch §2「薄いシェル: Bash + jq」制約との整合、DI-15 の Schema-driven 検証（jq ベース）との直接的な接続。

### 注入方法

ディスパッチャが envelope.json を読み、**プロンプト先頭に展開して注入**する方式を採用。

- CLI 引数: 長すぎる場合に OS の引数長制限に抵触
- 環境変数: 同上 + エスケープ処理が煩雑
- プロンプト先頭展開: 長さ制限なし + サブエージェントが構造化コンテキストとして解釈可能

## 確定内容

- JSON Schema ファイル: `schemas/envelope.schema.json`（draft-07 準拠）
- 必須フィールド: `session_id`（ULID）, `pane_id`（integer）, `task`（object）, `context`（object）, `constraints`（object）
- `exit_state` は起動時は未設定、完了時にディスパッチャまたはサブエージェントが書き込む
- `task.output_dir` が outputs 宣言の正本（DI-6 との接続点）
- `task.exit_conditions.marker` が最小解析ラッパーのスキャン対象（DI-8 との接続点）
- `constraints.state_vocabulary` は 5 値の閉集合（DI-3 確定済み）

### フィールド設計の意図

- `session_id`: セッション単位の一意識別。ULID により時系列ソート可能
- `pane_id`: WezTerm ペインとの紐付け。中間層 API（capture/send/kill）の操作対象
- `task.read_docs` / `task.use_skills`: サブエージェントに初期コンテキストを供給。既存 canonical/skills との接続点
- `task.exit_conditions`: オープンループ制御の終了判定条件。`marker`（出力スキャン）+ `timeout_seconds`（時間制限）+ `max_turns`（ターン制限）の 3 軸
- `context.parent_session_id`: 親子セッション関係の追跡。null の場合はトップレベルセッション
- `context.shared_kvs_path`: UC-2 並列協調で子セッション間が共有 KVS を参照するためのパス

## 根拠

- JSON 単一ファイル形式は `jq` で直接検証可能（DI-15 の検証ツール選定 = `jq --exit-status`）
- `session_id` の ULID 形式は既存プロジェクトの spec-card / episode での ULID 採用と一致
- `state_vocabulary` 5 値（spawn/ready/progress/done/blocked）は DI-3 で確定済みの中間層プロトコル最小サブセットに由来
- `exit_state` の failure-taxonomy enum 6 値は DI-4 で定義済み

## 影響・制約

- ディスパッチャ実装（Step 4-1 後半）はこの Schema に準拠した envelope 生成・注入・検証を行う
- DI-15（Schema-driven 検証）の `validate-envelope.sh` がこの Schema を検証対象とする
- DI-6（session-state KVS）は `session_id` / `pane_id` / `state` フィールドをエンベロープと共有
- envelope ファイルパスの命名規約（例: `{session_id}.envelope.json`）は Step 4-1 後半のディスパッチャ実装で確定

## 将来の拡張ポイント

- `task.dependencies`: 他セッション完了待ちの依存宣言（UC-2 DAG 実行向け）
- `task.cost_budget`: トークンコスト上限（G5 Time Budgeting の拡張）
- `constraints.allowed_tools`: サブエージェントの利用可能ツール制限（権限分離 DI-13 向け）
- `$ref` による failure-taxonomy.schema.json の参照（enum 定義の一元化）
