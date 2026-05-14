---
id: "01KRK33W3E7KKQZRSTB22G5KB0"
title: "orchestration-engine Step 4-2 成果物パース + 状態管理 Plan"
date: 2026-05-14
type: plan
status: draft
related:
  - type: derived_from
    ref: "projects/orchestration-engine/docs/plans/2026-05-14-kickoff-step-4-2-parse-and-state-management.md"
    reason: "変換元 KickOff。kickoff-to-plan SKILL に従い本 Plan を生成"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/19"
    reason: "Epic #19 Phase 4 MVP 実装の Step 4-2（観測層・親 Epic）"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/87"
    reason: "Step 4-2 観測層サブ Issue"
  - type: source_material
    ref: "projects/orchestration-engine/docs/discussions/2026-05-14-discussion-parse-and-state-management.md"
    reason: "Step 4-2 Discussion（Q1〜Q7 質問駆動設計の合意記録、KickOff の入力）"
  - type: source_material
    ref: "projects/orchestration-engine/docs/plans/2026-05-13-kickoff-step-4-1-envelope-and-dispatcher.md"
    reason: "Step 4-1 KickOff（15 DI、エンベロープ + ディスパッチャ骨格。本 Step の前提）"
  - type: source_material
    ref: "https://github.com/stlwolf/ai-development-hub/pull/85"
    reason: "Step 4-1 成果物 PR（schemas 5件、ADR 3件、episodes 13件、validate-envelope.sh）"
  - type: source_material
    ref: "projects/orchestration-engine/docs/discussions/2026-05-13-discussion-engine-scope-and-goals.md"
    reason: "Step 4-0 Discussion（15 論点・3 UC・arena 反映済み、全体スコープの正本）"
tags: [orchestration, mvp, step-4-2, plan, parse, state-management, marker, monitor-loop, audit-log]
---

# Step 4-2: 成果物パース + 状態管理 — Plan

> 本 Plan は [KickOff](2026-05-14-kickoff-step-4-2-parse-and-state-management.md) を `kickoff-to-plan` SKILL に従い変換したもの。KickOff の 7 Decision Items（DI-1〜DI-7）を 5 Phase に配置し、各 DI を実装 TODO として展開する。Phase 構造は KickOff §DI 依存関係の推奨実装順に準拠。

## 変換上の判断メモ

> KickOff は Discussion Q1〜Q7 合意をもとに DI-1〜DI-7 を定義した構造。Step 4-1（設計主軸）と異なり、全 DI が実装コーディングを伴う。以下の判断で変換した。

1. **DI → Phase 変換**: KickOff §DI 依存関係の推奨実装順 Phase A〜E をそのまま Plan の Phase 構造に採用。各 Phase 内で該当 DI を実装 TODO として展開
2. **cleanup.sh の Phase 配置**: cleanup.sh は KickOff 上で独立 DI を持たないが、DI-2（一時ファイル削除）、DI-5（cleanup イベント）、DI-7（ファイルレイアウト）、完了条件 7 に跨る要素。Phase D（出力）に配置した理由: `oe_audit_emit()`（DI-5）を利用するため、DI-5 実装後でなければ cleanup イベント記録が完成しない
3. **Open Questions の配置**: KickOff §Open Questions の「実装中に判断する事項」4 項目を、関連する Phase の冒頭に「確定タスク」として配置。「スコープ外だが次ステップに影響する事項」3 項目は §スコープ外 に転記
4. **per-Phase 検証サイクル**: KickOff §次アクション の「実装 → shellcheck → 単体動作確認 → Episode 記録」サイクルを各 Phase に配置
5. **GATE/STOP 配置**: ユーザー指示により Phase A/B/D に GATE、Phase C/E に STOP（HG）を配置。KickOff には明示的な STOP/GATE 指示がないため、これはユーザー指定の追加構造
6. **DI-3 と capture.sh の Phase 分割**: DI-3 の定数定義・`oe_capture_scan()`・`oe_capture_classify()` は Phase B（Step 3）で実装。DI-4 の `monitor.sh` は Phase C（Step 5）で実装し、capture.sh の関数を呼び出す。KickOff 原文では `capture.sh` が DI-3 と DI-6 の両方に関連するが、依存グラフの `DI-3 → DI-4` パスに従い Phase B で基本関数を実装し、DI-6 の `oe_capture_write_kvs()` は Phase D で追加する
7. **完了条件の展開**: 8 項目それぞれにサブ条件（箇条書き）があるため、サブ条件を検証 TODO の説明に含めて展開

## Context

### 前提（KickOff で確定済み）

- Step 4-1（[PR #85](https://github.com/stlwolf/ai-development-hub/pull/85)）でエンベロープスキーマ・失敗分類・監査ログスキーマ・exit code マッピング・セッション状態 KVS スキーマ・`validate-envelope.sh` が確定済み
- Step 4-0 Discussion の 15 論点のうち、4-2 に直結する実装論点を `question-driven-design` で 7 問に絞り込み、全問合意済み（[Discussion](../discussions/2026-05-14-discussion-parse-and-state-management.md) status: closed）
- Step 4-2 の主題: `@@OE_EXIT:{code}` マーカーの検出・パース、ポーリングベースの監視ループ、G4 6 値への分類、KVS / 監査ログへの書き込みを Bash 関数ライブラリとして実装
- 観測層 Issue [#87](https://github.com/stlwolf/ai-development-hub/issues/87) は作成済み（read-only、進捗トラッキング先）

### 実行モデルの前提（so-compare レビューで明確化）

- **MVP は one-shot モード**: AI CLI を `--prompt` / `-p` / `-q` フラグ付きで one-shot 実行。REPL（対話モード）は 4-2 スコープ外
- **`wez pane send` で送るのは shell コマンド 1 行**: envelope JSON を直接送るのではなく、AI CLI コマンド + マーカー emit を `;` チェインで構成した 1 行を送る（`wez pane send` は改行を拒否するため）
- **マーカー emit 主体はシェル**: AI CLI 終了後に shell の `;` で `printf '@@OE_EXIT:%d' $?` を実行。AI 本人にマーカー出力を依頼するのではない
- **envelope 参照はファイルパス**: `wez pane send` で送る 1 行コマンド内で envelope ファイルパスを AI CLI に渡す（例: `cursor --prompt 'Read /tmp/oe-XXX.json and execute the task'`）
- **画面キャプチャがプロトコル**: `wez pane capture` による画面状態の観測が、one-shot でも REPL でも共通の基盤。REPL 対応時にアーキテクチャ変更は不要（マーカー種別の分岐追加のみ）

### 設計入力

- KickOff: [`docs/plans/2026-05-14-kickoff-step-4-2-parse-and-state-management.md`](2026-05-14-kickoff-step-4-2-parse-and-state-management.md)
- Discussion: [`docs/discussions/2026-05-14-discussion-parse-and-state-management.md`](../discussions/2026-05-14-discussion-parse-and-state-management.md)
- DI 依存関係グラフ: KickOff §DI 依存関係（Mermaid `flowchart`）を参照

### 駆動層入力（4-1 成果物）

| 成果物 | パス | 本 Step での利用 |
|--------|------|----------------|
| Envelope Schema | `schemas/envelope.schema.json` | `lib/envelope.sh` が一時ファイル生成時に参照 |
| Failure Taxonomy | `schemas/failure-taxonomy.schema.json` | `lib/capture.sh` の 6 値判定の正本 |
| Exit Code Mapping | `schemas/exit-code-mapping.schema.json` | `lib/capture.sh` の exit code → 6 値変換ルール |
| Audit Log Schema | `schemas/audit-log.schema.json` | `lib/audit.sh` の emit フォーマット |
| Session State KVS | `schemas/session-state.schema.json` | `lib/capture.sh` の KVS 書き込みフォーマット |
| validate-envelope.sh | `scripts/validate-envelope.sh` | `lib/envelope.sh` から呼び出し（変更なし） |
| Exit Code Mapping（※4-2 で更新あり） | `schemas/exit-code-mapping.schema.json` | auxiliary_signals の pattern を `@@OE_BLOCKED` に統一（Phase B Step 3 で更新） |
| ADR: Cleanup Strategy | `docs/decisions/2026-05-14-decision-cleanup-strategy.md` | `lib/cleanup.sh` の設計根拠 |
| ADR: Permission Separation | `docs/decisions/2026-05-14-decision-permission-separation-mvp.md` | MVP 権限境界の前提 |
| ADR: #20 Phase Convergence | `docs/decisions/2026-05-14-decision-issue-20-phase-convergence.md` | 中間層（wez CLI）との合流方針 |

### 観測層 Issue（Read-only）

- [#19](https://github.com/stlwolf/ai-development-hub/issues/19) — Epic 親、Phase 4 ステップ管理
- [#84](https://github.com/stlwolf/ai-development-hub/issues/84) — Step 4-1 サブ Issue（closed、[PR #85](https://github.com/stlwolf/ai-development-hub/pull/85)）
- [#87](https://github.com/stlwolf/ai-development-hub/issues/87) — Step 4-2 サブ Issue（本 Plan の観測層）

### スコープ外（本 Plan では扱わない）

KickOff §スコープ外:

- `@@OE_OUTPUT:path` マーカー（将来拡張）
- `--verbose` フラグ（`polling_snapshot` / `validation_failure` 記録）
- dashboard API / TUI 表示（4-3 以降）
- UC-2 並列協調の ownership 宣言・コンフリクト検出（4-3 以降）
- UC-3 人間俯瞰の `wez notify` 統合（4-3 以降）
- UC-3 REPL モード対応（対話型 AI セッションの中間状態検出・re-inject。画面キャプチャ基盤は共通だがマーカープロトコルの拡張が必要）
- サブエージェント側への OE 固有ロジック注入（Q6 でディスパッチャ一元化を選択済み）
- ハング検出の高度化（出力増分差分による停止検知。MVP は CB タイムアウトで代替）

KickOff §Open Questions（スコープ外だが次ステップに影響する事項）:

- `--verbose` フラグ: `polling_snapshot` / `validation_failure` の記録制御。4-3 以降のスコープ
- UC-2 並列協調の ownership 宣言: `session-state.schema.json` への `ownership` フィールド追加。4-3 以降
- UC-3 `wez notify` 統合: `human_input` 検出時の自動通知。4-3 以降

---

## Phase A: 基盤（DI-7 + DI-1）

### Open Question 確定: `audit/` と `state/` のベースディレクトリ

- [ ] `audit/` と `state/` のベースディレクトリを確定: `bin/oe` の CWD 相対 vs 環境変数 `OE_DATA_DIR` 指定
- [ ] 確定結果を `lib/constants.sh` のパス定義に反映

### Step 1: DI-7 — ファイルレイアウト構築

- [ ] ディレクトリ構造を作成:

```
projects/orchestration-engine/
├── bin/
│   └── oe                    # エントリポイント（source lib/*.sh → main 呼び出し）
├── lib/
│   ├── constants.sh          # @@OE_ プレフィックス、SLO 5s、CB 閾値、KVS/audit パス
│   ├── envelope.sh           # oe_envelope_create（inject は spawn.sh に統合）
│   ├── spawn.sh              # oe_spawn（wez pane split + send + session_start emit）
│   ├── capture.sh            # oe_capture_scan / oe_capture_classify / oe_capture_write_kvs
│   ├── monitor.sh            # oe_monitor_loop（2s poll + CB + audit 統合）
│   ├── audit.sh              # oe_audit_emit（JSONL 追記）
│   └── cleanup.sh            # oe_cleanup（trap handler: pane kill + /tmp 削除）
├── state/                    # KVS 出力先（{session_id}.state.json）
├── audit/                    # 監査ログ出力先（{session_id}.jsonl）
├── scripts/
│   └── validate-envelope.sh  # 既存（4-1 成果物、変更なし）
└── schemas/                  # 既存（4-1 成果物、変更なし）
```

- [ ] 命名規約確認: 関数名は `oe_` プレフィックス（C 昇格時のネームスペース準備）
- [ ] `state/` と `audit/` は `bin/oe` 起動時に `mkdir -p` で自動作成する設計を `bin/oe` スケルトンに組み込み

### Step 2: DI-1 — `bin/oe` エントリポイント + `constants.sh` + `lib/` スケルトン

- [ ] `bin/oe` の shebang: `#!/usr/bin/env bash`
- [ ] `lib/` の各ファイルは関数定義のみ（直接実行不可、`source` 専用）— 各 `.sh` にスケルトン関数を配置
- [ ] `LIB_DIR` は `bin/oe` からの相対パス（`$(cd "$(dirname "$0")/../lib" && pwd)`）で解決
- [ ] 将来 C（サブコマンド CLI）へ昇格する際: `bin/oe spawn` → `lib/spawn.sh::oe_spawn()` のルーティング追加で対応可能な構造にする
- [ ] `lib/constants.sh` に以下を定義:
  - CB 閾値: `OE_CB_TIMEOUT=1800`（秒）/ `OE_CB_MAX_TURNS=10` / `OE_CB_MAX_PANES=5`
  - SLO: `OE_SLO_DETECT_SEC=5`
  - ポーリング間隔: `OE_POLL_INTERVAL=2`
  - KVS / audit パス（Open Question 確定結果を反映）

### Phase A 検証サイクル

- [ ] shellcheck: `bin/oe` + `lib/constants.sh` で shellcheck 実行、エラーゼロ確認
- [ ] 単体動作確認: `bin/oe` が `source lib/constants.sh` を正常に読み込み、定数が参照可能であること
- [ ] Episode 記録: Phase A の実装判断・発見事項を `docs/episodes/` に記録

## GATE: Phase A 基盤確認

- [ ] `bin/oe` が `lib/` の全スケルトンを `source` で読み込み、エラーなく実行開始できる
- [ ] `lib/constants.sh` にマーカープレフィックス・CB 閾値・SLO・パス定義が含まれている
- [ ] `audit/` と `state/` のベースディレクトリが確定し `constants.sh` に反映されている
- [ ] shellcheck エラーゼロ

---

## Phase B: 入力（DI-2 + DI-3）

### Open Question 確定: `@@OE_EXIT:{code}` の具体フォーマット

- [ ] `@@OE_EXIT:{code}` の改行位置、前後の区切り文字を確定（`capture.sh` の正規表現設計の前提）
- [ ] 確定結果を `lib/constants.sh` の `OE_EXIT_MARKER_RE` に反映

### Step 3: DI-3 — マーカー規約 + キャプチャ関数（`constants.sh` 追加 + `capture.sh`）

- [ ] `lib/constants.sh` にマーカー定義を追加:
  - `OE_MARKER_PREFIX="@@OE_"`
  - `OE_EXIT_MARKER_RE='^@@OE_EXIT:([0-9]{1,3})$'`（行頭・行末アンカー付き）
  - 将来マーカー種別の予約（コメントで意図記載、MVP では未使用）: `@@OE_STATUS:{state}` / `@@OE_READY` / `@@OE_OUTPUT:{path}` / `@@OE_BLOCKED:{reason}`
- [ ] `lib/capture.sh::oe_capture_scan()` 実装 — `wez pane capture` の出力を正規表現でスキャンし、**マーカー種別（marker_type）と値（value）の組**を返す（MVP は `EXIT` 種別のみ処理。REPL 拡張時に `STATUS` / `READY` 等の分岐を追加可能な構造）
- [ ] 検出フロー実装: capture 出力 → `grep -E '^@@OE_EXIT:[0-9]{1,3}$' | tail -n 1` → exit code 抽出 → `oe_capture_classify()` で 6 値判定（行頭・行末アンカー + 最後の一致のみ採用で偽陽性を回避）
- [ ] `oe_capture_classify()` 実装 — 6 値判定ロジック（`exit-code-mapping.schema.json` 準拠）:
  - `0` → `success`
  - `1` → `partial`
  - `2` → `retryable_failure`（auxiliary signal `@@OE_BLOCKED` 検出時は `blocked` に上書き）
  - `124` → `timeout`（Bash timeout コマンド由来）
  - タイマー超過（CB） → `timeout`
  - マーカーなし + プロセス停止 → `protocol_error`
- [ ] `exit-code-mapping.schema.json` の `auxiliary_signals.end_marker_blocked.pattern` を `===STATE: blocked===` から `@@OE_BLOCKED` に更新（`@@OE_` 体系に統一）

### Step 4: DI-2 — エンベロープ注入 + spawn（`envelope.sh` + `spawn.sh`）

- [ ] `lib/envelope.sh::oe_envelope_create()` 実装 — envelope JSON 生成 → 一時ファイル書き出し → `validate-envelope.sh` 呼び出し
- [ ] `lib/envelope.sh::oe_envelope_inject()` は不要（envelope JSON を直接送らない）。代わりに `oe_spawn()` 内で envelope ファイルパスを AI CLI コマンドに埋め込む
- [ ] 一時ファイルのライフサイクル: `oe_envelope_create()` で生成、`lib/cleanup.sh` で削除
- [ ] パス規約: `/tmp/oe-{session_id}-envelope.json`（`session_id` は ULID 26 文字）
- [ ] `lib/spawn.sh::oe_spawn()` 実装 — `wez pane split` で新ペイン作成 → AI CLI コマンド + マーカー emit を `;` チェインで 1 行構成 → `wez pane send` で送信 → `session_start` emit
  - 送信コマンド例: `cursor --prompt 'Read /tmp/oe-{session_id}-envelope.json and execute the task' ; printf '\n@@OE_EXIT:%d\n' $?`
  - AI CLI 種別（cursor / claude / codex）は envelope の `constraints` または環境変数で指定
  - 前提: ペインシェルは bash/zsh 互換（`$?` で直前の exit code を取得）。fish 等の非互換シェルは 4-3 以降で対応

### Phase B 検証サイクル

- [ ] shellcheck: `lib/capture.sh` + `lib/envelope.sh` + `lib/spawn.sh` で shellcheck 実行、エラーゼロ確認
- [ ] 単体動作確認: `oe_capture_scan()` がテスト文字列から `@@OE_EXIT:{code}` を検出し、`oe_capture_classify()` が正しい 6 値を返すこと
- [ ] Episode 記録: Phase B の実装判断・発見事項を `docs/episodes/` に記録

## GATE: Phase B 入力系確認

- [ ] `@@OE_EXIT:{code}` の具体フォーマットが確定し `constants.sh` に反映されている
- [ ] `oe_capture_scan()` + `oe_capture_classify()` がマーカー検出 → 6 値分類を正しく実行できる
- [ ] `oe_envelope_create()` が `/tmp/oe-{session_id}-envelope.json` を生成し `validate-envelope.sh` で検証 pass する
- [ ] `oe_spawn()` が `wez pane split` + `wez pane send` でサブエージェントを起動できる
- [ ] shellcheck エラーゼロ

---

## Phase C: コア（DI-4）

### Open Question 確定: `wez pane capture --lines` + `blocked` 判定

- [ ] `wez pane capture` の `--lines` オプション値を確定: 末尾何行をスキャンするか（実測して確定）
- [ ] `blocked` 状態の判定ヒューリスティクスを確定: マーカーなし + プロセス存在 + 出力停止の組み合わせ条件
- [ ] 確定結果を `lib/capture.sh` の `oe_capture_scan()` と `oe_capture_classify()` に反映

### Step 5: DI-4 — 監視ループ（`monitor.sh`）

- [ ] `lib/monitor.sh::oe_monitor_loop()` — メインループ関数を実装
- [ ] 管理ペイン追跡: Bash 配列 `OE_MANAGED_PANES` で spawn 済みペイン ID を保持（ファイル registry は作らない。ADR cleanup-strategy と整合）
- [ ] 完了済みペイン除外: Bash 配列 `OE_DONE_PANES` で完了検出済みペインを保持し、以後の監視対象から除外（マーカー再検出を防止）
- [ ] 前回 state 保持: `declare -A OE_LAST_STATE` 連想配列でペインごとの直前 state を保持。差分検出で `state_change` を emit
- [ ] ループ 1 サイクルの処理順を実装:
  1. `OE_MANAGED_PANES` から `OE_DONE_PANES` を除外した未完了リストを取得
  2. 各ペインに対し `oe_capture_scan()` 呼び出し → `marker_type` + `value` を取得
  3. `case $marker_type` で分岐（MVP は `EXIT` のみ実装、将来 `STATUS` / `READY` 等を追加可能な switch 構造）
  4. `EXIT` 検出時: `oe_capture_classify()` → 状態変化チェック（`OE_LAST_STATE` と比較）→ `state_change` emit（状態が変わった場合）→ `session_end` emit（この順序で必ず 2 イベント出力）→ KVS 書き込み → `OE_DONE_PANES` に追加
  5. CB チェック: 経過時間 / ターン数 / ペイン数を `constants.sh` の閾値と比較
  6. CB 違反時: `circuit_breaker_triggered` emit → 管理ペイン kill → ループ終了
  7. `sleep 2`
- [ ] ループ終了条件を実装: 全ペイン完了（`OE_DONE_PANES` = `OE_MANAGED_PANES`）or CB 発動 or SIGINT/SIGTERM 受信

### Phase C 検証サイクル

- [ ] shellcheck: `lib/monitor.sh` で shellcheck 実行、エラーゼロ確認
- [ ] 単体動作確認: `oe_monitor_loop()` がテストペインに対し 2s 間隔でキャプチャ → マーカー検出 → ループ終了のフローを完走すること（`oe_audit_emit()` / `oe_capture_write_kvs()` は Phase A Step 2 で配置したスケルトン関数を呼び出す状態。audit/KVS の実出力検証は Phase D 以降）
- [ ] Episode 記録: Phase C の実装判断・発見事項を `docs/episodes/` に記録

## STOP: Phase C コアロジック確認 — ユーザーにコアロジック（監視ループ + キャプチャ + 6 値分類）の動作結果を報告し、Phase D 着手の承認を待つ

---

## Phase D: 出力（DI-5 + DI-6）+ cleanup

### Step 6: DI-5 — Audit log（`audit.sh`）

- [ ] `lib/audit.sh::oe_audit_emit()` 実装 — JSONL 1 行を `audit/{session_id}.jsonl` に追記
- [ ] フォーマット: `audit-log.schema.json` 準拠（`ts / session_id / pane_id / event_type / state / payload`）
- [ ] `ts` は `date -u +"%Y-%m-%dT%H:%M:%S+00:00"` で UTC 固定
- [ ] 各 emit 呼び出し元を実装:
  - `session_start`: `lib/spawn.sh`（envelope 注入完了後）
  - `state_change`: `lib/monitor.sh`（マーカー検出時）
  - `interrupt`: `lib/monitor.sh`（SIGINT / TTY inject 実行時）
  - `human_input`: `lib/monitor.sh`（人間入力検出時、UC-3）
  - `circuit_breaker_triggered`: `lib/monitor.sh`（CB 発動時）
  - `cleanup`: `lib/cleanup.sh`（trap ハンドラ実行時）
  - `session_end`: `lib/monitor.sh`（ペイン完了・最終状態確定時）

### Step 7: DI-6 — KVS 書き込み（`capture.sh` 追加）

- [ ] `lib/capture.sh::oe_capture_write_kvs()` 実装 — `session-state.schema.json` 準拠の JSON を atomic write
- [ ] Atomic write 実装: `jq` で JSON 生成 → `{kvs_dir}/.{session_id}.state.json.$$` に書き出し → 同一ディレクトリ内で `mv -f` により rename（cross-FS 回避で POSIX rename atomicity を保証）
- [ ] 書き込みタイミング: `@@OE_EXIT:{code}` マーカー検出後、6 値分類完了時に 1 回だけ書き込み
- [ ] KVS ディレクトリ: `state/`（`bin/oe` 起動時に `mkdir -p` で確保）
- [ ] 書き込み内容: `session_id`, `pane_id`, `state`（6 値）, `last_updated`（ISO 8601）, `outputs[]`（空配列、`@@OE_OUTPUT` 未実装のため）, `blockers[]`（`blocked` 時のみ非空）

### Step 8: クリーンアップ（`cleanup.sh`）

> 前提: ADR cleanup-strategy（[`docs/decisions/2026-05-14-decision-cleanup-strategy.md`](../decisions/2026-05-14-decision-cleanup-strategy.md)）の設計に準拠

- [ ] `lib/cleanup.sh::oe_cleanup()` 実装 — trap handler 関数
- [ ] 二重実行ガード: 冒頭で `[[ -n "${OE_CLEANUP_DONE:-}" ]] && return; OE_CLEANUP_DONE=1` + trap 解除
- [ ] `bin/oe` 内で `trap oe_cleanup EXIT INT TERM` を設定（INT/TERM → EXIT の二重発火をガードで吸収）
- [ ] 管理下ペインの `wez pane kill` 処理（`|| true` で失敗を吸収、wez 無応答時にハングしない）
- [ ] `/tmp/oe-{session_id}-*` の一時ファイル削除（DI-2 envelope 一時ファイル含む）
- [ ] `cleanup` イベントを `oe_audit_emit()` で audit log に記録（emit 失敗も非致命扱い）

### Phase D 検証サイクル

- [ ] shellcheck: `lib/audit.sh` + `lib/cleanup.sh` + `lib/capture.sh`（追加分）で shellcheck 実行、エラーゼロ確認
- [ ] 単体動作確認: `oe_audit_emit()` が `audit-log.schema.json` 準拠の JSONL を出力し、`oe_capture_write_kvs()` が `session-state.schema.json` 準拠の JSON を atomic write すること
- [ ] Episode 記録: Phase D の実装判断・発見事項を `docs/episodes/` に記録

## GATE: Phase D 出力系確認

- [ ] `oe_audit_emit()` が 7 種のイベントを `audit-log.schema.json` 準拠の JSONL で出力できる
- [ ] `oe_capture_write_kvs()` が `session-state.schema.json` 準拠の JSON を atomic write できる
- [ ] `oe_cleanup()` が管理ペイン kill + 一時ファイル削除 + `cleanup` イベント emit を実行できる
- [ ] shellcheck エラーゼロ

---

## Phase E: 統合

### Step 9: `bin/oe` メインフロー結線

- [ ] `bin/oe` のメインフロー実装: `source lib/*.sh` → `trap` 設定 → `mkdir -p` → envelope 生成 → spawn → monitor loop → cleanup
- [ ] エンドツーエンドフローの結線確認: 各 `lib/` 関数がメインフローから正しく呼び出されること

### Step 10: shellcheck 全スクリプト pass

- [ ] `bin/oe` + `lib/*.sh`（7 ファイル）で `shellcheck` 実行、全ファイルエラーゼロ
- [ ] `shellcheck` 警告（warning）も可能な限り解消

### Phase E 検証サイクル

- [ ] 統合動作確認: `bin/oe` がエンドツーエンドでエンベロープ生成 → spawn → 監視 → 完了検出 → KVS 書き込み → audit log → cleanup のフローを完走すること
- [ ] Episode 記録: Phase E の実装判断・統合時の発見事項を `docs/episodes/` に記録

## STOP: Phase E 統合完了 — ユーザーに統合結果を報告し、最終検証への移行を確認

---

## 最終検証

> KickOff §完了条件 8 項目との照合。

- [ ] `bin/oe` が envelope を受け取りサブエージェントを spawn できる
  - `lib/envelope.sh` が `/tmp/oe-{session_id}-envelope.json` を生成し `validate-envelope.sh` で検証 pass
  - `lib/spawn.sh` が `wez pane split` + `wez pane send` でサブエージェントを起動
  - `lib/audit.sh` が `session_start` イベントを emit
- [ ] `@@OE_EXIT:{code}` マーカーで終了を検出し 6 値に分類できる
  - `lib/capture.sh` が `wez pane capture` 出力からマーカーを正規表現でスキャン
  - exit code → `failure-taxonomy.schema.json` の 6 値へ正しく分類
- [ ] ポーリングループが 2s 間隔で全管理ペインを巡回する
  - `lib/monitor.sh` が単一 `while` ループで管理ペインリストを順次処理
  - SLO 5s 以内に状態変化を検知（5 ペイン巡回で約 380ms + 2s sleep）
- [ ] CB（1800s / 10 turns / 5 panes）違反時に `circuit_breaker_triggered` を emit して停止する
  - `lib/monitor.sh` がループ内で経過時間 / ターン数 / ペイン数を `constants.sh` 閾値と比較
  - 違反検出時: `oe_audit_emit circuit_breaker_triggered` → 管理ペイン kill → ループ終了
- [ ] KVS（`{session_id}.state.json`）に完了状態を atomic write する
  - `lib/capture.sh` が `session-state.schema.json` 準拠の JSON を生成
  - `state/` 配下の隠しファイルへの書き出し → 同一ディレクトリ内 `mv -f` による atomic rename
- [ ] Audit log に 7 種のイベントを JSONL で出力する
  - `audit-log.schema.json` 準拠の各フィールド（`ts / session_id / pane_id / event_type / state / payload`）
  - 7 種: `session_start / state_change / interrupt / human_input / circuit_breaker_triggered / cleanup / session_end`
- [ ] trap EXIT で管理ペイン kill + 一時ファイル削除が動作する
  - `lib/cleanup.sh` が `trap oe_cleanup EXIT INT TERM` を設定
  - 管理下ペインの `wez pane kill` + `/tmp/oe-{session_id}-*` の削除
  - `cleanup` イベントを audit log に記録
- [ ] shellcheck で全スクリプトが pass する
  - `bin/oe` + `lib/*.sh`（7 ファイル）で `shellcheck` エラーゼロ

## 関連

- 変換元 KickOff: [`2026-05-14-kickoff-step-4-2-parse-and-state-management.md`](2026-05-14-kickoff-step-4-2-parse-and-state-management.md)
- Parent Epic: [#19](https://github.com/stlwolf/ai-development-hub/issues/19)
- 観測層サブ Issue: [#87](https://github.com/stlwolf/ai-development-hub/issues/87)
- Step 4-1 成果物: [PR #85](https://github.com/stlwolf/ai-development-hub/pull/85)（[#84](https://github.com/stlwolf/ai-development-hub/issues/84) closed）
- Step 4-2 Discussion: [`2026-05-14-discussion-parse-and-state-management.md`](../discussions/2026-05-14-discussion-parse-and-state-management.md)
- Step 4-0 Discussion: [`2026-05-13-discussion-engine-scope-and-goals.md`](../discussions/2026-05-13-discussion-engine-scope-and-goals.md)
- Step 4-1 KickOff: [`2026-05-13-kickoff-step-4-1-envelope-and-dispatcher.md`](2026-05-13-kickoff-step-4-1-envelope-and-dispatcher.md)
- wez CLI（Phase 1 完了）: [#20](https://github.com/stlwolf/ai-development-hub/issues/20)

## Review 履歴

### Plan Review (2026-05-14)

**Status:** Approved

**Reviewer:** adversarial-review SKILL（kickoff-to-plan 変換後の品質チェック）

**完全性チェック数値:**

| 突合項目 | KickOff | Plan | 結果 |
|---------|---------|------|------|
| 完了条件チェックボックス数 → 最終検証 TODO 数 | 8件 | 8件 | ✅ |
| DI 数 → Step 数（DI 対応分） | 7件 | 7件（Step 1〜7） | ✅ |
| STOP 指示数 → STOP TODO 数 | 0件（KickOff なし） | 2件（ユーザー指定） | ✅（判断メモ §5） |
| GATE 指示数 → GATE TODO 数 | 0件（KickOff なし） | 3件（ユーザー指定） | ✅（判断メモ §5） |
| Open Questions（実装中）数 → 確定タスク TODO 数 | 4件 | 4件（Phase A: 1, B: 1, C: 2） | ✅ |
| スコープ外項目数 → スコープ外記載数 | 9件（6+3） | 9件（6+3） | ✅ |
| 「〜等」「〜など」省略 | — | 0件 | ✅ |
| GATE が独立 TODO 項目 | — | 3件全て独立 | ✅ |

**検証結果:**

| 観点 | 結果 |
|------|------|
| Completeness | DI-1〜DI-7 が全て Step に割り当て済み。完了条件 8 項目が最終検証に完全展開。Open Questions 4 件が関連 Phase 冒頭に配置。スコープ外 9 件が Context に記載。cleanup.sh は独立 DI を持たないが Step 8 として正当に配置（判断メモ §2） |
| Consistency | Mermaid 依存グラフの全 8 矢印が Phase/Step 順序と整合。DI-7(Step1)→DI-1(Step2)→DI-4(Step5), DI-3(Step3)→DI-4(Step5), DI-2/SPAWN(Step4)→DI-4(Step5), DI-4(Step5)→DI-5(Step6)/DI-6(Step7), DI-3(Step3)→DI-6(Step7) の全依存パスが保持されている |
| Clarity | 各 Step が DI と 1:1 対応し、関数名・ファイルパス・正規表現・6 値マッピングが KickOff 原文のまま保持。Gate/Stop 基準は具体的かつ検証可能 |
| Scope | bin/oe + lib/ 7 ファイルの実装に収まっている。スコープ外項目（@@OE_OUTPUT, --verbose, dashboard, UC-2/UC-3, wez notify）は扱っていない |
| YAGNI | cleanup.sh（Step 8）は多 DI + 完了条件 7 からの正当な導出。per-Phase 検証サイクルは KickOff §次アクションからの忠実な変換。不要な追加なし |

**ユーザー指定 6 観点の照合:**

1. **DI 展開の完全性**: DI-1→Step 2, DI-2→Step 4, DI-3→Step 3, DI-4→Step 5, DI-5→Step 6, DI-6→Step 7, DI-7→Step 1。全 7 DI カバー
2. **完了条件カバレッジ**: 8 項目が最終検証にサブ条件含め完全展開。KickOff 原文と一致
3. **Gate 配置**: Phase A/B/D に GATE、Phase C/E に STOP（HG）。ユーザー指定どおり
4. **依存関係 → ステップ順序**: 全 8 依存矢印が Phase 順序で保持。直列パス DI-3→DI-4→DI-5/DI-6 が Phase B→C→D に正確にマッピング
5. **Open Questions 配置**: audit/state ディレクトリ→Phase A、@@OE_EXIT フォーマット→Phase B、--lines/blocked→Phase C。全て関連 Phase の冒頭に配置
6. **スコープ外の明示**: KickOff §スコープ外 6 件 + Open Questions §スコープ外 3 件 = 計 9 件が Context §スコープ外に転記

**Recommendations（advisory, do not block approval）:**

- Phase C Step 5 の監視ループ実装において、`oe_audit_emit()` と `oe_capture_write_kvs()` は Phase D まで stub（Phase A Step 2 で作成したスケルトン関数）のまま呼び出される。Phase C 検証サイクルの「単体動作確認」は stub 呼び出し状態でのフロー完走確認を意味し、audit/KVS の実出力検証は Phase D GATE 以降となる。この暗黙の前提は Step 2 の「各 .sh にスケルトン関数を配置」から読み取れるが、Phase C の検証サイクル説明に「audit/KVS は Phase D 実装後に実出力を検証」と付記すると実装者の混乱を防げる

### so-compare Review (2026-05-14)

**Reviewer:** Codex + Claude（`so-compare`）

**結果:** 9 件の指摘、うち議論不要 6 件を即時反映、設計議論 3 件を解決後に反映。

**即時反映（C3/C4/C6/C7/C8/C9）:**

- C3: KVS atomic write を `/tmp/` → `state/` から同一ディレクトリ内 rename に変更（cross-FS 回避）
- C4: trap ハンドラに二重実行ガード（`OE_CLEANUP_DONE` フラグ）追加
- C6: マーカー正規表現に行頭・行末アンカー追加（`^...$`）
- C7: 完了済みペイン除外フラグ（`OE_DONE_PANES`）を monitor ループに追加
- C8: 前回 state 保持（`declare -A OE_LAST_STATE`）を monitor ループに追加
- C9: 「registry から」の表現を「Bash 配列 `OE_MANAGED_PANES`」に修正（ADR と整合）

**設計議論後に反映（C1/C2/C5）:**

- C1: `wez pane send` 改行制約 → envelope JSON を直接送らず、ファイルパス参照を shell コマンド 1 行で送る方式に明確化。`oe_envelope_inject()` 不要に
- C2: `@@OE_EXIT` emit 主体 → AI CLI は one-shot（`--prompt`）実行、shell `;` チェインでマーカー emit。REPL 前提は誤解（文書の曖昧さが原因）
- C5: `===STATE: blocked===` → `@@OE_BLOCKED` に統一（`exit-code-mapping.schema.json` 更新タスクを Phase B に追加）

**追加の設計判断（REPL 拡張パス）:**

- `oe_capture_scan()` を「マーカー種別 + 値」の構造を返す設計に変更（MVP は EXIT のみ）
- monitor ループを `case $marker_type` switch 構造に変更
- `constants.sh` に将来マーカー種別（`@@OE_STATUS` / `@@OE_READY` / `@@OE_OUTPUT` / `@@OE_BLOCKED`）を予約定義
- スコープ外に UC-3 REPL 対応・ハング検出の高度化を明記
