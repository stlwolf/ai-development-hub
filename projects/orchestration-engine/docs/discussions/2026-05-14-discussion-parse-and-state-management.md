---
id: "01KRJZKS2EJ2A4MMXA32JRM4R4"
title: "Step 4-2 成果物パース・状態管理の設計判断（質問駆動設計）"
date: 2026-05-14
type: discussion
status: closed
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/19"
    reason: "Epic #19 Phase 4 MVP 実装の Step 4-2 設計判断"
  - type: source_material
    ref: "projects/orchestration-engine/docs/discussions/2026-05-13-discussion-engine-scope-and-goals.md"
    reason: "Step 4-0 Discussion（15 論点・3 UC・arena 反映済み、全体スコープの正本）"
  - type: source_material
    ref: "projects/orchestration-engine/docs/plans/2026-05-13-kickoff-step-4-1-envelope-and-dispatcher.md"
    reason: "Step 4-1 KickOff（15 DI、エンベロープ + ディスパッチャ骨格）"
  - type: source_material
    ref: "https://github.com/stlwolf/ai-development-hub/pull/85"
    reason: "Step 4-1 成果物 PR（schemas 5件、ADR 3件、episodes 13件、validate-envelope.sh）"
  - type: design_context
    ref: "projects/orchestration-engine/schemas/envelope.schema.json"
    reason: "4-1 で確定した Initializer Envelope スキーマ（Q2 一時ファイル注入の基盤）"
  - type: design_context
    ref: "projects/orchestration-engine/schemas/audit-log.schema.json"
    reason: "4-1 で確定した監査ログスキーマ（Q5 イベント種別の基盤）"
  - type: design_context
    ref: "projects/orchestration-engine/schemas/session-state.schema.json"
    reason: "4-1 で確定したセッション状態 KVS スキーマ（Q6 書き込み責務の基盤）"
tags: [orchestration, mvp, step-4-2, question-driven-design, parse, state-management, marker, monitor-loop]
---

# Step 4-2 成果物パース・状態管理の設計判断（質問駆動設計）

> Step 4-1（エンベロープ + ディスパッチャ骨格、[PR #85](https://github.com/stlwolf/ai-development-hub/pull/85)）完了後、Step 4-2 の実装に先立ち `question-driven-design` スキルで 7 つの設計論点を探索・合意した記録。

## 進め方の前提

- `question-driven-design` スキルを適用。実装前に設計ツリーを質問で網羅的に掘り下げ、暗黙の前提を明示化した
- 全 7 問について選択肢を提示し、議論の上で合意を得た（status: closed）
- 合意結果は後続の KickOff（[`2026-05-14-kickoff-step-4-2-parse-and-state-management.md`](../plans/2026-05-14-kickoff-step-4-2-parse-and-state-management.md)）で DI に変換する
- 未解決事項（マーカーフォーマット詳細、`--verbose` 実装時期）は実装フェーズで判断する

## Step 4-1 からの入力

Step 4-2 の設計判断に直接影響する 4-1 成果物:

- `schemas/envelope.schema.json` — Initializer Envelope の構造（`session_id`, `pane_id`, `task`, `context`, `constraints`）
- `schemas/session-state.schema.json` — ファイルベース KVS の最小契約（atomic rename、セッション完了時のみ書き込み）
- `schemas/failure-taxonomy.schema.json` — G4 6 値分類（`success / partial / retryable_failure / blocked / protocol_error / timeout`）
- `schemas/audit-log.schema.json` — 監査ログ 9 イベント種別（MVP 7 種 + verbose 2 種）
- `schemas/exit-code-mapping.schema.json` — exit code → 6 値マッピングルール
- `scripts/validate-envelope.sh` — jq ベースの envelope バリデーション

## 設計質問と合意

### Q1: スクリプト構成

**質問**: `bin/oe` のコード構成をどうするか?

| 案 | 内容 | トレードオフ |
|----|------|-------------|
| A. モノリシック | 全機能を `bin/oe` 1 ファイルに集約 | 単純だが、膨張すると可読性低下 |
| **B. 関数ライブラリ + エントリ** | `lib/` に機能別ファイル、`bin/oe` は `source` して呼び出し | 分割統治、テスタブル、C 昇格パスと整合 |
| C. サブコマンド CLI | `oe spawn`, `oe monitor` 等のサブコマンド体系 | 将来形としては理想だが MVP には過剰 |

**決定**: **B. 関数ライブラリ + エントリ**

**根拠**:

- `lib/` 分割により各関数の単体テスト・shellcheck が容易
- `bin/oe` はエントリポイントとして薄く保ち、将来 C（サブコマンド CLI）へ昇格する際の移行コストを最小化
- 4-1 の `scripts/validate-envelope.sh` がスタンドアロンスクリプトとして存在しており、`lib/` からの呼び出しパターンと整合

### Q2: エンベロープ注入

**質問**: envelope をサブエージェントにどう渡すか?

| 案 | 内容 | トレードオフ |
|----|------|-------------|
| **A. 一時ファイル** | `/tmp/oe-{session_id}-envelope.json` に書き出し、パスを環境変数で渡す | シンプル、`validate-envelope.sh` と整合、サイズ制限なし |
| B. 環境変数 | `OE_ENVELOPE='{...}'` として展開 | サイズ制限（`getconf ARG_MAX`）、エスケープ問題 |
| C. stdin パイプ | `echo "$envelope" \| oe spawn` | TTY 占有と競合するリスク |

**決定**: **A. 一時ファイル**（`/tmp/oe-{session_id}-envelope.json`）

**根拠**:

- 4-1 の `validate-envelope.sh` がファイルパスを引数に取る設計であり、直接接続可能
- `/tmp/` 配下で session_id 名前空間を使うことでセッション間の衝突を回避
- cleanup（Q7 / DI-7）で一時ファイル削除を一括管理
- サブエージェントへの注入は `wez pane send` でプロンプト先頭に展開する形式（envelope.schema.json の description に記載済み）

### Q3: マーカー規約

**質問**: サブエージェントの終了・状態を検出するマーカー文字列の設計は?

| 案 | 内容 | トレードオフ |
|----|------|-------------|
| A. 終了マーカーのみ | `@@OE_EXIT:{code}` で exit code を通知 | 最小。出力パス通知は別手段が必要 |
| B. 出力マーカー追加 | `@@OE_OUTPUT:{path}` で成果物パスも通知 | サブ側の出力契約が必要 |
| **A+B ハイブリッド** | MVP は A のみ、将来 B を追加 | 拡張性確保しつつ MVP を軽量に保つ |

**決定**: **A+B ハイブリッド**（MVP は `@@OE_EXIT:{code}` のみ、将来 `@@OE_OUTPUT:path` 追加）

**根拠**:

- プレフィックス `@@OE_` で名前空間を確保。通常の出力テキストとの衝突を回避
- MVP ではサブエージェントに `@@OE_EXIT:{code}` の出力のみを要求。サブ側の実装負荷を最小化
- exit code から G4 6 値への分類はディスパッチャ（`capture.sh`）が行う（Q6 と連動）
- `@@OE_OUTPUT:path` は KVS 書き込みとの二重経路になるため、必要性が明確になってから追加

### Q4: 監視ループ

**質問**: サブエージェントペインのポーリング方式は?

| 案 | 内容 | トレードオフ |
|----|------|-------------|
| **A. 単一ループ全ペイン巡回** | 1 つの `while` ループで全管理ペインを順次 capture | シンプル、リソース消費小、SLO 5s に余裕 |
| B. ペインごとに独立ループ | 各ペインに対し `&` でバックグラウンドループ | 並列性高いが、プロセス管理が複雑化 |
| C. inotifywait イベント駆動 | KVS ファイル変更を `inotifywait` で検知 | macOS 非対応（`fswatch` 要）、依存追加 |

**決定**: **A. 単一ループ全ペイン巡回**（2s poll）

**根拠**:

- `wez pane capture` の実測値（4-1 SLO episode 参照）: 1 ペインあたり約 50〜80ms
- 5 ペイン巡回でも約 380ms。2s ポーリング間隔で SLO 5s に十分な余裕
- 単一プロセスのため `trap` によるクリーンアップが確実に動作
- CB（サーキットブレーカー）の監視も同一ループ内で統合可能

### Q5: Audit log

**質問**: MVP で記録する監査ログイベントの範囲は?

4-1 の `audit-log.schema.json` で 9 イベント種別が定義済み。MVP での記録範囲を決定する。

| 案 | 内容 | イベント数 |
|----|------|-----------|
| A. 全イベント | 9 種すべて記録 | 9 |
| B. コアイベント | 状態遷移系 5 種（start/change/interrupt/CB/end） | 5 |
| **C. 7 種（verbose 2 種を先送り）** | `polling_snapshot` / `envelope_validated` を `--verbose` 拡張へ先送り | 7 |

**決定**: **C. 7 種**（`polling_snapshot` / `envelope_validated` は `--verbose` 拡張へ先送り）

MVP で記録する 7 イベント:

1. `session_start` — セッション開始（envelope 注入完了時）
2. `state_change` — 状態遷移検出（マーカースキャンで検知）
3. `interrupt` — 割り込み実行（SIGINT / TTY inject）
4. `human_input` — 人間の直接入力（UC-3 監査要件）
5. `circuit_breaker_triggered` — CB 発動（timeout / max_turns / max_panes）
6. `cleanup` — クリーンアップ実行（trap ハンドラ / ゾンビペイン kill）
7. `session_end` — セッション終了（最終 exit_state 記録）

先送り（`--verbose` 拡張）:

- `polling_snapshot` — 各ポーリング結果（デフォルトではノイズが多い）
- `validation_failure`（= `envelope_validated`）— schema 検証結果

**根拠**:

- 7 種で「1 サイクルの流れを事後再構成」という audit-log.schema.json の設計意図を満たす
- `polling_snapshot` はポーリング間隔（2s）ごとに発生し、ログ量が大きくなるためデフォルトでは抑制
- 検証失敗は `protocol_error` 状態として `state_change` / `session_end` に記録されるため、独立イベントは冗長

### Q6: KVS 書き込み

**質問**: `{session_id}.state.json`（ファイルベース KVS）を誰が書くか?

| 案 | 内容 | トレードオフ |
|----|------|-------------|
| **A. ディスパッチャが書く** | exit code + マーカーから判定し、ディスパッチャ（`capture.sh`）が KVS を更新 | サブ側の実装負荷ゼロ、一元管理 |
| B. サブエージェントが書く | サブが自身の state.json を直接更新 | サブ側に KVS 書き込み契約を強制 |
| C. 両者が書く | サブが中間状態を書き、ディスパッチャが最終状態を書く | 複雑、競合リスク |

**決定**: **A. ディスパッチャが書く**

**根拠**:

- 4-1 の `session-state.schema.json` の description に「セッション完了時にのみ書き込む」と明記済み
- ディスパッチャが `@@OE_EXIT:{code}` マーカーを検出し、exit code → G4 6 値分類 → KVS 書き込みの一連の処理を一元的に行う
- サブエージェント側に OE 固有の書き込みロジックを要求しないことで、既存の AI CLI（claude / codex / cursor）をそのまま利用可能
- 実行中の状態（`spawn / ready / progress` 等）は `wez pane capture` のマーカースキャンで取得する設計（so-compare レビュー episode で確認済み）

### Q7: ファイルレイアウト

**質問**: Step 4-2 で実装するファイルの配置は?

| 案 | 内容 | ファイル数 |
|----|------|-----------|
| A. 最小構成 | `bin/oe` + `lib/core.sh` の 2 ファイル | 2 |
| **B. 機能別分割** | `bin/oe` + `lib/` 7 ファイル（capture + state 統合） | 8 |
| C. 粒度細分化 | `lib/` 10+ ファイル（capture と state を分離） | 11+ |

**決定**: **B. 機能別分割**（`bin/oe` + `lib/` 7 ファイル）

```
projects/orchestration-engine/
├── bin/
│   └── oe                    # エントリポイント（将来 C 昇格時のサブコマンドルーター）
├── lib/
│   ├── envelope.sh           # envelope 生成・一時ファイル書き出し・検証呼び出し
│   ├── spawn.sh              # wez pane split + pane send でサブ起動
│   ├── capture.sh            # wez pane capture + マーカーパース + 6値判定（capture+state統合）
│   ├── monitor.sh            # ポーリングループ本体（capture→audit→CB判定）
│   ├── audit.sh              # audit log emit（7 event types）
│   ├── cleanup.sh            # trap handler + pane kill + 一時ファイル削除
│   └── constants.sh          # マーカープレフィックス、SLO値、CB閾値等の定数
├── scripts/
│   └── validate-envelope.sh  # 既存（4-1 成果物）
└── schemas/                  # 既存（4-1 成果物）
```

**根拠**:

- Q1（関数ライブラリ + エントリ）の決定を具現化
- `capture.sh` に state 判定を統合することで、マーカースキャン → 6 値分類 → KVS 書き込み準備が 1 ファイルで完結（Q3, Q6 と連動）
- `constants.sh` にマーカープレフィックス `@@OE_`、SLO 値（5s）、CB 閾値（1800s / 10 turns / 5 panes）を集約
- 既存の `scripts/validate-envelope.sh` と `schemas/` は変更せず参照のみ

## 未解決事項（実装中に判断）

| 項目 | 現状 | 判断時期 |
|------|------|---------|
| `@@OE_EXIT:{code}` の具体フォーマット（改行位置、前後の区切り文字） | プレフィックス `@@OE_` のみ確定 | `capture.sh` 実装時 |
| `@@OE_OUTPUT:path` の導入基準 | MVP スコープ外、KVS の `outputs[]` で代替可能か要評価 | 4-4 E2E 検証時 |
| `--verbose` フラグの実装時期 | 4-2 スコープ外の可能性 | KickOff の scope 判断で確定 |
| `constants.sh` の CB 閾値の最終値 | 例示値（1800s / 10 / 5）のみ | 4-4 E2E 検証のフィードバックで調整 |

## 次のステップ

1. 本 Discussion の Q1〜Q7 を DI に変換し、[KickOff](../plans/2026-05-14-kickoff-step-4-2-parse-and-state-management.md) を作成
2. KickOff から `kickoff-to-plan` で Plan に展開
3. 4-2 用の観測層 Issue を作成（KickOff 完了後）

## 関連

- Parent Epic: [#19](https://github.com/stlwolf/ai-development-hub/issues/19)
- Step 4-1 成果物: [PR #85](https://github.com/stlwolf/ai-development-hub/pull/85)（[#84](https://github.com/stlwolf/ai-development-hub/issues/84) closed）
- Step 4-0 Discussion: [`2026-05-13-discussion-engine-scope-and-goals.md`](./2026-05-13-discussion-engine-scope-and-goals.md)
- Step 4-1 KickOff: [`2026-05-13-kickoff-step-4-1-envelope-and-dispatcher.md`](../plans/2026-05-13-kickoff-step-4-1-envelope-and-dispatcher.md)
- Envelope Schema: [`schemas/envelope.schema.json`](../../schemas/envelope.schema.json)
- Audit Log Schema: [`schemas/audit-log.schema.json`](../../schemas/audit-log.schema.json)
- Session State Schema: [`schemas/session-state.schema.json`](../../schemas/session-state.schema.json)
