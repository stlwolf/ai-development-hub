---
id: "01KRMYHMET73WDE32JXD1TZ0A4"
title: "orchestration-engine Step 4-3 検証ゲート v1 Plan"
date: 2026-05-15
type: plan
status: draft
related:
  - type: derived_from
    ref: "projects/orchestration-engine/docs/plans/2026-05-15-kickoff-step-4-3-verification-gate.md"
    reason: "変換元 KickOff（status: confirmed）。kickoff-to-plan SKILL に従い本 Plan を生成"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/19"
    reason: "Epic #19 Phase 4 MVP 実装の Step 4-3（観測層・親 Epic）"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/89"
    reason: "Step 4-3 観測層サブ Issue"
  - type: source_material
    ref: "projects/orchestration-engine/docs/discussions/2026-05-15-discussion-step-4-3-verification-gate.md"
    reason: "Step 4-3 Discussion（Q1〜Q7 QDD 合意記録、status: closed、本 Plan の入力）"
  - type: source_material
    ref: "https://github.com/stlwolf/ai-development-hub/pull/88"
    reason: "Step 4-2 成果物 PR（bin/oe, lib/*.sh, tests/*、本 Step が拡張する基盤）"
  - type: source_material
    ref: "projects/orchestration-engine/docs/episodes/2026-05-15-episode-step-4-2-phase-e-integration-validation.md"
    reason: "Step 4-2 Phase E 統合検証（完了条件 8 項目の検証結果）"
  - type: design_context
    ref: "canonical/skills/adversarial-review/SKILL.md"
    reason: "Compliance Review プロンプト規約。本 Plan の検証 agent は本 SKILL に従って動作する"
  - type: design_context
    ref: "projects/orchestration-engine/schemas/session-state.schema.json"
    reason: "Phase A で verification / verification_summary フィールドを追加する対象"
  - type: design_context
    ref: "projects/orchestration-engine/schemas/audit-log.schema.json"
    reason: "Phase A で verification_started / verification_completed イベントを追加する対象"
tags: [orchestration, mvp, step-4-3, plan, verification-gate, adversarial-review, kvs-extension]
---

# Step 4-3: 検証ゲート v1 — Plan

> 本 Plan は [KickOff](2026-05-15-kickoff-step-4-3-verification-gate.md)（status: confirmed）を `kickoff-to-plan` SKILL に従い変換した。KickOff の 7 Decision Items（DI-1〜DI-7）を 5 Phase に配置し、各 DI を実装 TODO として展開する。

## 変換上の判断メモ

> KickOff は Discussion Q1〜Q7 合意をもとに DI-1〜DI-7 を定義した構造。Step 4-2 の `bin/oe` + `lib/*.sh` を拡張する形で実装する。以下の判断で変換した。

1. **DI → Phase 変換**: DI 依存関係を解析し、5 Phase に配置:
   - Phase A: DI-5（スキーマ拡張）— 他全 DI の前提
   - Phase B: DI-3 + DI-7(a)（検証 envelope 生成 + 新ペイン spawn + マーカー要求）
   - Phase C: DI-4（プロンプト 3 ソース統合構築）
   - Phase D: DI-7(b) + DI-5(書き込み)（マーカーパース + KVS 書き込み + 集計）
   - Phase E: DI-2 + DI-6（end-of-session 発火統合 + 通知 + 統合検証）
2. **DI-1（Compliance Review only）の扱い**: 実装コーディングを伴わない「スコープ確定」DI のため、Context に明記しすべての Phase の前提として記載。独立 Step は作らない
3. **`bin/oe` への統合**: 既存 `lib/monitor.sh` の `oe_monitor_loop` 末尾に「全ペイン完了後の検証フェーズ遷移」を追加。新規 `lib/verify.sh` を作成し、検証フェーズ専用関数群を集約
4. **テストの粒度**: Step 4-2 と同様の粒度（関数単位 + E2E スモーク）。`tests/test_verify.sh` を新設、`tests/test_capture.sh` に `@@OE_VERIFY:` ケース追加、`tests/test_e2e_smoke.sh` に検証フェーズを含む 1 サイクルを追加
5. **GATE 配置**: Phase A 完了時（スキーマ検証）、Phase D 完了時（書き込み確認）、Phase E 完了時（E2E）に GATE を配置。各 GATE は user の合図で次 Phase へ進む
6. **STOP 配置**: Phase E 完了 + ADR/Episode 記録後に STOP を 1 件配置（user 報告 → PR 作成判断）
7. **派生課題（adversarial-review skill 改修、per-pane 昇格、自動リトライ）**: 本 Plan のスコープ外として Context §「スコープ外」に明記、実装 TODO 化しない

## Context

### 前提（Discussion / KickOff で確定済み）

- Step 4-2 [PR #88](https://github.com/stlwolf/ai-development-hub/pull/88) で `bin/oe` + `lib/*.sh` 7 ファイル + tests 7 本（145+ assertions）が動作する状態（shellcheck PASS、全テスト PASS、Episode で 8 完了条件確認済み）
- Step 4-3 [Discussion](../discussions/2026-05-15-discussion-step-4-3-verification-gate.md) で 7 Q（Q1〜Q7）を user との 1 問ずつの対話で合意済み
- **DI-1: 検証モード = Compliance Review のみ**。Plan Review は engine 統合せず、必要時は人間が `adversarial-review` skill を単独起動
- `adversarial-review` skill の Compliance Review プロンプトに従って動作する検証 agent を envelope の `use_skills: [adversarial-review]` で指定する（疎結合）
- engine 側はプロトコルとして `@@OE_VERIFY:{pass|fail|warn}` マーカーを要求し、`capture.sh` の正規表現を拡張してパースする

### 設計入力

- KickOff: [`docs/plans/2026-05-15-kickoff-step-4-3-verification-gate.md`](2026-05-15-kickoff-step-4-3-verification-gate.md)
- Discussion: [`docs/discussions/2026-05-15-discussion-step-4-3-verification-gate.md`](../discussions/2026-05-15-discussion-step-4-3-verification-gate.md)
- skill: [`canonical/skills/adversarial-review/SKILL.md`](../../../../canonical/skills/adversarial-review/SKILL.md) — Compliance Review プロンプトテンプレート + ツール別起動例

### 駆動層入力（Step 4-2 成果物）

| 成果物 | パス | 本 Step での利用 |
|--------|------|----------------|
| Envelope Schema | `schemas/envelope.schema.json` | 検証用 envelope 生成時に再利用（`use_skills` / `exit_conditions.marker` フィールド活用） |
| Session State KVS Schema | `schemas/session-state.schema.json` | **Phase A で `verification` / `verification_summary` フィールド追加** |
| Audit Log Schema | `schemas/audit-log.schema.json` | **Phase A で `verification_started` / `verification_completed` イベント追加** |
| `lib/envelope.sh` | `oe_envelope_create` | 検証用 envelope 生成で再利用、必要なら検証専用ヘルパー追加 |
| `lib/spawn.sh` | `oe_spawn_prepare_pane` / `oe_spawn_send` | 検証 agent ペインの spawn にそのまま再利用 |
| `lib/capture.sh` | `_oe_capture_scan_parse` / `oe_capture_classify` | **Phase D で `@@OE_VERIFY:` 検出を正規表現に追加** |
| `lib/monitor.sh` | `oe_monitor_loop` | **Phase E で end-of-session 後に検証フェーズへ遷移する処理を追加** |
| `lib/audit.sh` | `oe_audit_emit` | 検証イベントの追加に対応（スキーマ拡張のみで関数はそのまま利用） |
| `lib/cleanup.sh` | `oe_cleanup` | **Phase E で `wez notify` 呼び出しを追加** |
| `scripts/validate-envelope.sh` | — | 既存（変更なし）。検証用 envelope も同じ validator で検査 |

### 観測層 Issue（Read-only）

- [#19](https://github.com/stlwolf/ai-development-hub/issues/19) — Epic 親、Phase 4 ステップ管理
- [#87](https://github.com/stlwolf/ai-development-hub/issues/87) — Step 4-2 サブ Issue（closed、[PR #88](https://github.com/stlwolf/ai-development-hub/pull/88)）
- [#89](https://github.com/stlwolf/ai-development-hub/issues/89) — Step 4-3 サブ Issue（本 Plan の観測層）

### スコープ外（本 Plan では扱わない）

KickOff §スコープ外:

- `human_input` audit イベントの実装（必要時に追加、本 Step 必須ではない）
- wez CLI Phase 3 の設計（#20 側で実施）
- adversarial-review skill 側の改修（派生課題、Step 4-4 以降で判断）
- per-pane 発火への昇格（DI-2 案 A、Step 4-4 以降）
- 自動リトライ / 人間エスカレーション（DI-6 案 B/C、Step 4-4 以降）

Discussion §「未解決の細部（Plan で詰める）」:

- 検証 agent 自体の選択 — envelope の `task.description` で指定可能にする（後述 Phase B Step 3 で確定）
- 検証プロンプトの送信手段 — 一時ファイル経由（`OE_VERIFY_PROMPT_PATH`、`OE_ENVELOPE_PATH` パターン踏襲）。Phase C で確定
- 変更対象ファイルリスト構築 — KVS `outputs[]` を主、`git diff --name-only` をフォールバック。Phase C で確定
- 検証 agent の CB タイムアウト値 — 既存 1800s を踏襲（Phase B で確定）

---

## Phase A: スキーマ拡張（DI-5）

> 全 Phase の前提となる KVS / audit log スキーマを最小拡張する。Step 4-2 の `validate-envelope.sh` パターンに従い、新規 validator も並走で追加する。

### Step 1: `session-state.schema.json` 拡張

- [ ] `verification` フィールドを追加（**pane-keyed map**、複数 target pane の per-pane 結果を保持）:
  ```json
  "verification": {
    "<target_pane_id>": {
      "result": "pass" | "fail" | "warn",
      "reviewer_session_id": "<ULID>",
      "reviewer_pane_id": "<pane_id>",
      "issues_count": 0,
      "marker_raw": "@@OE_VERIFY:pass",
      "completed_at": "<ISO 8601>"
    },
    ...
  }
  ```
- [ ] `verification_summary` フィールドを追加（セッション全体集計、`verification` map から導出）:
  - `total`: integer >= 0（検証実行件数 = `verification` map のキー数）
  - `passed`: integer >= 0
  - `failed`: integer >= 0
  - `warned`: integer >= 0
  - `fail_rate`: number, 0.0〜1.0（小数 3 桁、`failed / total` を engine が `awk` で計算）
- [ ] 既存フィールド (`session_id`, `state`, `outputs`, `blockers`, `last_updated`) との `required` 整合性確認（`verification`/`verification_summary` は optional、検証フェーズ実行後にのみ存在）
- [ ] スキーマ `$id` / `description` の更新（Step 4-3 拡張を明記、pane-keyed map 構造の意図を `description` で明文化）

> **so-compare レビュー反映 (F5)**: `verification` を単一オブジェクトではなく **pane-keyed map** に変更。Discussion §「Q5 KVS 拡張仕様」では単一オブジェクト表記だったが、Q2 で確定した「セッション内 fail 率を実運用データとして記録」要件には複数 target pane の per-pane 結果を保持する必要があるため、pane-keyed map が正しい構造。本 Plan が確定形とする。

### Step 2: `audit-log.schema.json` 拡張

- [ ] `event_type` enum に追加: `verification_started`, `verification_completed`
- [ ] `verification_started` の payload schema:
  - `target_pane_id`: string（被検証ペイン ID）
  - `target_session_id`: string（被検証セッション ID = bin/oe メインの session_id）
  - `reviewer_pane_id`: string（検証 agent のペイン ID）
  - `reviewer_session_id`: string（検証 agent のセッション ID）
- [ ] `verification_completed` の payload schema:
  - `target_pane_id`: string
  - `result`: enum [`pass`, `fail`, `warn`]
  - `issues_count`: integer >= 0
  - `marker_raw`: string（捕捉した `@@OE_VERIFY:{value}` の原文）

### Step 3: 新規 validator（`scripts/validate-session-state.sh`）

- [ ] `scripts/validate-envelope.sh` をひな型に `validate-session-state.sh` を作成
- [ ] jq ベースで `session-state.schema.json` の構造検証（`verification` / `verification_summary` 含む）
- [ ] 既存テスト `tests/test_kvs.sh` を拡張し、`verification` 書き込み後の出力が validator で PASS することを検証
- [ ] `shellcheck ./scripts/validate-session-state.sh` クリーン

### GATE: Phase A 完了確認

- [ ] スキーマ JSON 自体の構文検査（`jq -e . < schemas/*.json`）
- [ ] `validate-session-state.sh` が既存 `state/*.state.json`（Step 4-2 のテスト出力）に対して **後方互換**（既存出力は `verification` フィールドなしでも PASS）
- [ ] user に Phase A 完了報告、Phase B 進行可否の合図を待つ

---

## Phase B: 検証 envelope 生成 + spawn（DI-3 + DI-7(a)）

> 既存 `lib/envelope.sh` / `lib/spawn.sh` を再利用しつつ、検証専用の関数を追加。検証 agent への envelope は `use_skills: [adversarial-review]` と `@@OE_VERIFY:` マーカー要求を含む。

### Step 4: `lib/verify.sh` 新規ファイル

- [ ] `lib/verify.sh` 作成、`shellcheck` 対象に追加
- [ ] `oe_verify_envelope_create()` 関数:
  - 入力: 被検証ペインの `target_pane_id`, `target_session_id`, `target_envelope_path`
  - 出力: 検証用 envelope ファイル（`/tmp/oe-{reviewer_session_id}-verify-envelope.json`）と環境変数 `OE_VERIFY_ENVELOPE_PATH`
  - envelope 内容（**疎結合: engine は構造化入力のみ注入、プロンプト本文は skill 側で組み立てる**）:
    - `task.description`: 「Compliance Review を実行せよ。3 入力は `read_docs` の各ファイルから読み取れ」程度の **検証指示の概要のみ**。skill の Compliance Review プロンプト本文は engine に持たない
    - `task.use_skills`: `["adversarial-review"]`
    - `task.read_docs`: skill ファイル (`canonical/skills/adversarial-review/SKILL.md`) + 被検証 envelope パス + audit JSONL パス + KVS パス + （後述 Phase C で生成する）`OE_VERIFY_PROMPT_PATH` のプロンプトファイル
    - `task.exit_conditions.marker`: `@@OE_VERIFY:` を新マーカーとして指定（既存の `@@OE_EXIT:` は従来通り正常終了通知に使う）
    - `task.exit_conditions.timeout_seconds`: 1800（既存 CB と同値、Discussion §「未解決の細部」で確定）
    - `context.parent_session_id`: 被検証セッション ID
- [ ] `oe_verify_envelope_create` が `scripts/validate-envelope.sh` で PASS する envelope を生成すること

> **so-compare レビュー反映 (F4)**: DI-7 の `use_skills` 疎結合方針と整合させるため、Compliance Review プロンプト本文の static copy を envelope に含めない設計に変更。検証 agent は `read_docs` で skill を読み、自分でプロンプトを組み立てる。engine 側は「何を読むべきか」のリストと 3 入力（後述 Phase C で生成）の所在を構造化注入するだけに責務を限定する。

### Step 5: 検証ペイン spawn

- [ ] `oe_verify_spawn()` 関数（`lib/verify.sh` 内）:
  - `lib/spawn.sh` の `oe_spawn_prepare_pane` / `oe_spawn_send` を呼び出す
  - 検証用 envelope を引数に取り、検証 agent ペインを起動
  - audit イベント `verification_started` を emit（Phase A Step 2 で拡張済みの schema 準拠）
  - 戻り値: 検証ペイン ID（`reviewer_pane_id`）
- [ ] 既存 CB（`OE_CB_MAX_PANES=5`）に検証ペインも含めることを `constants.sh` で確認
- [ ] テスト: `tests/test_verify.sh` 新規、`oe_verify_envelope_create` / `oe_verify_spawn` の wez モック経由動作確認

### GATE: Phase B 完了確認

- [ ] `shellcheck ./lib/verify.sh` クリーン
- [ ] `tests/test_verify.sh` PASS
- [ ] 検証用 envelope JSON が `validate-envelope.sh` で PASS
- [ ] user に Phase B 完了報告

---

## Phase C: プロンプト構築（DI-4）

> Compliance Review プロンプトの 3 入力（要件 / 完了報告 / 変更ファイル）を engine の出力（envelope / audit JSONL / KVS）から動的構築する。

### Step 6: プロンプト構築関数

- [ ] `oe_verify_prompt_build()` 関数（`lib/verify.sh` 内、**engine は 3 入力の構造化抽出のみ。Compliance Review プロンプト本文は組み立てない**）:
  - 入力: 被検証ペインの `target_pane_id`, `target_session_id`, `target_envelope_path`
  - 構築要素（3 入力ファイル化のみ）:
    - 要件: `target_envelope_path` の `task.description` を `jq -r` で抽出
    - 完了報告: `audit/{target_session_id}.jsonl` から最後の `state_change` イベントを抽出（`jq -s 'map(select(.event_type=="state_change")) | last'`）
    - 変更ファイル: `state/{target_session_id}.state.json` の `outputs[]` を抽出。**MVP では `capture.sh:104` で `outputs[]` は常に空配列で書き出される**ため、実運用ではフォールバックの `git diff --name-only` が常に選択される。`outputs[]` 自体への書き込み拡張は本 Step スコープ外（F7）
  - 出力: 一時ファイル `/tmp/oe-{reviewer_session_id}-verify-inputs.md` に **3 入力のみを構造化してダンプ**（YAML ブロックや見出し付きセクションで「## 要件」「## 完了報告」「## 変更ファイル」を区切る）、パスを `OE_VERIFY_PROMPT_PATH` でエクスポート
- [ ] **engine は skill の Compliance Review プロンプト本文を内蔵しない**。検証 agent は envelope の `task.use_skills: [adversarial-review]` と `task.read_docs` で skill を読み、3 入力ファイル (`OE_VERIFY_PROMPT_PATH`) を参照して自分でプロンプトを組み立てる
- [ ] `oe_verify_prompt_build` の出力ファイル仕様は `tests/test_verify.sh` でアサーション（3 セクション存在 + 各セクション内容の jq 抽出結果と一致）

> **so-compare レビュー反映 (F4 + F7)**: skill の Compliance Review テンプレートを engine 側に static copy する設計を撤回。engine は 3 入力の構造化抽出だけに責務を限定し、プロンプト組み立ては skill 側 + 検証 agent 側に委譲する。これにより skill 改訂時の追従が自動化される（DI-7 の `use_skills` 疎結合方針と整合）。`outputs[]` フォールバックは MVP では常に `git diff` パスを選択し、`outputs[]` 書き込みの拡張は本 Step スコープ外と明示。

### Step 7: envelope への注入

- [ ] `oe_verify_envelope_create()` を更新し、生成プロンプトパス (`OE_VERIFY_PROMPT_PATH`) を `task.read_docs` 配列に追加する（task.description にプロンプト本文を含めない、F4 と整合）
- [ ] テスト: `tests/test_verify.sh` に「プロンプト構築 → ファイル出力 → 内容アサーション」ケース追加
- [ ] テスト: 3 入力のうち audit JSONL / KVS が空の場合のフォールバック動作確認（`outputs[]` 空 → `git diff` パスが選択されること）

### GATE: Phase C 完了確認

- [ ] `tests/test_verify.sh` PASS（プロンプト構築ケース含む）
- [ ] サンプル envelope + サンプル audit + サンプル KVS から構築したプロンプトファイルが skill のフォーマットに準拠
- [ ] user に Phase C 完了報告

---

## Phase D: パース + KVS 書き込み + 集計（DI-7(b) + DI-5(書き込み)）

> 検証 agent の出力末尾 `@@OE_VERIFY:{result}` を `capture.sh` の正規表現で検出し、KVS の `verification` フィールドへの書き込み、`verification_summary` の集計、audit イベント emit を行う。

### Step 8: `capture.sh` 拡張（`@@OE_VERIFY:` 検出、**戻り値を二値保持に変更**）

- [ ] `_oe_capture_scan_parse()` の正規表現を拡張: 既存 `@@OE_EXIT:{1-3 桁 code}` に加え `@@OE_VERIFY:{pass|fail|warn}` を検出
- [ ] **戻り値構造を二値保持に変更**: 既存 `marker_type` + `value` の単一構造は、検証 agent の出力に `@@OE_VERIFY:fail` と `@@OE_EXIT:0` の両方が並ぶケースで一方が上書きされる問題がある（`spawn.sh:24-25` が必ず `@@OE_EXIT:{code}` を後置するため）。新構造は以下:
  - `OE_SCAN_EXIT_CODE`: integer or empty（`@@OE_EXIT:` の値、検出時のみセット）
  - `OE_SCAN_VERIFY_RESULT`: string ["pass" | "fail" | "warn"] or empty（`@@OE_VERIFY:` の値、検出時のみセット）
  - `OE_SCAN_BLOCKED_FLAG`: 既存維持（`@@OE_BLOCKED` 検出）
  - 既存 `OE_SCAN_MARKER_TYPE` / `OE_SCAN_VALUE` は後方互換のため残し、`OE_SCAN_EXIT_CODE` が空でないなら `MARKER_TYPE=exit` 同等、`OE_SCAN_VERIFY_RESULT` が空でないなら `MARKER_TYPE=verify` 同等とする（既存テストへの影響最小化）
- [ ] `monitor.sh` の `case "$OE_SCAN_MARKER_TYPE"` 分岐は通常ペインでは現状維持（EXIT のみ）。検証ペインの監視は `verify.sh` 側の独立ループに集約（後述 F1 / Phase E Step 11）
- [ ] テスト: `tests/test_capture.sh` に `@@OE_VERIFY:` 各値ケース追加（pass / fail / warn / 不正値 / CR 付き / ANSI 付き / 行頭アンカー）+ **「VERIFY + EXIT 両方検出」**ケース（両変数が同時にセットされ、`OE_SCAN_EXIT_CODE=0` と `OE_SCAN_VERIFY_RESULT=fail` 等の組み合わせ）

> **so-compare レビュー反映 (F3)**: VERIFY と EXIT の同時検出時の優先順位未定義問題を、`OE_SCAN_EXIT_CODE` と `OE_SCAN_VERIFY_RESULT` の **二値保持**で根本解決。既存の単一 `OE_SCAN_MARKER_TYPE` / `OE_SCAN_VALUE` は後方互換のため残すが、検証ペインの処理側 (`verify.sh`) は二値変数を直接参照する。

### Step 9: KVS 書き込み（`oe_verify_write_kvs`、**pane-keyed map 構造**）

- [ ] `oe_verify_write_kvs()` 関数（`lib/verify.sh` 内）:
  - 入力: `target_session_id`, `target_pane_id`, `reviewer_session_id`, `reviewer_pane_id`, `result`, `issues_count`, `marker_raw`
  - 既存 `state/{target_session_id}.state.json` を読み、`verification.{target_pane_id}` キーに per-pane オブジェクトを書き込み（atomic rename、`jq '.verification[$pid] = {...}'` パターン）
  - `completed_at` は `date -u +%Y-%m-%dT%H:%M:%SZ` で生成
  - 既存 `verification` map に他 pane の結果がある場合は維持（破壊しない）
- [ ] `oe_verify_summary_update()` 関数:
  - `state/{target_session_id}.state.json` の `verification` map を `jq` で集計（`verification | to_entries | map(.value.result)` → group → count）
  - `verification_summary.{total, passed, failed, warned, fail_rate}` を KVS に書き込み
  - `fail_rate` は `failed / total` を `awk` で計算（Bash 3.2 整数演算回避）、小数 3 桁に丸め
- [ ] テスト: `tests/test_verify.sh` に KVS 書き込みケース追加（**複数 pane の連続書き込み + summary 集計**を確認）、`validate-session-state.sh` で出力検証

### Step 10: audit イベント `verification_completed` emit

- [ ] **`verification_started` の emit は Phase B Step 5 で `oe_verify_spawn()` 内に配置済み**。本 Step では追加しない（F6: 二重宣言の削除）
- [ ] `@@OE_VERIFY:` 検出後（`oe_verify_write_kvs` の直後）に `verification_completed` を emit
- [ ] テスト: audit JSONL に `verification_started`（Phase B 由来）+ `verification_completed`（本 Step 由来）の 2 イベントが正しいフォーマットで 1 検証あたり 1 件ずつ記録されることを確認

> **so-compare レビュー反映 (F6)**: `verification_started` emit を Phase B Step 5 のみに配置することで二重宣言を解消。本 Step は `verification_completed` の新規 emit に責務を限定。テストは Phase B 側で `verification_started`、Phase D 側で `verification_completed` を独立にアサーション。

### GATE: Phase D 完了確認

- [ ] `shellcheck` 全スクリプト PASS
- [ ] `tests/test_capture.sh` + `tests/test_verify.sh` 全 PASS
- [ ] `validate-session-state.sh` がサンプル KVS（`verification` / `verification_summary` 含む）に対して PASS
- [ ] audit JSONL のサンプルが `validate` 系で PASS（手動 `jq` 検証で可）
- [ ] user に Phase D 完了報告

---

## Phase E: 発火統合 + 通知 + 統合検証（DI-2 + DI-6）

> `monitor.sh` の end-of-session 後に検証フェーズへ遷移する処理を追加。`cleanup.sh` 末尾で `wez notify` を呼び出し。最後に E2E スモークで 1 サイクル完走を確認する。

### Step 11: 検証フェーズ統合 — `monitor.sh` から `verify.sh` の独立ループへ遷移

- [ ] `oe_monitor_loop()` の終了条件（全 `OE_DONE_PANES` 完了 or CB 発動）の後に **`verify.sh` 内の独立関数 `oe_verify_run_phase()` を呼び出す**（monitor.sh の責務範囲を膨らませない、`OE_DONE_PANES` の意味を「通常ペイン完了集合」のまま保持）:
  - CB 発動時は検証スキップ（既存 `circuit_breaker_triggered` イベントで終了、`oe_verify_run_phase` を呼ばない）
  - 全完了時のみ `oe_verify_run_phase()` を呼ぶ
- [ ] `oe_verify_run_phase()` 関数（`lib/verify.sh` 内、独立ポーリングループ）:
  1. `OE_MANAGED_PANES` （通常ペイン集合）の各被検証ペインに対して順次:
     a. `oe_verify_envelope_create`
     b. `oe_verify_prompt_build`
     c. `oe_verify_spawn` → 検証ペイン ID を `OE_VERIFY_MANAGED_PANES` 配列に追加（**通常ペインの `OE_MANAGED_PANES` / `OE_DONE_PANES` とは別配列**、F2）
     d. 内部ポーリングループ: `OE_POLL_INTERVAL` 間隔で `oe_capture_scan` → `OE_SCAN_VERIFY_RESULT` が非空になるまで待機（F3 の二値保持を利用）
     e. 検出時: `oe_verify_write_kvs` → `oe_audit_emit verification_completed` → `OE_VERIFY_DONE_PANES` に追加
     f. CB タイムアウト（`OE_CB_MAX_TURNS_PER_SESSION`、既存 1800s 同値）超過時は当該検証をスキップして次へ
  2. 全検証完了後 `oe_verify_summary_update` でセッション集計
- [ ] **並列性**: MVP は逐次（per-target-pane）で起動。並列化は Step 4-4 以降
- [ ] `lib/constants.sh` に追加: `OE_VERIFY_MANAGED_PANES=()` / `OE_VERIFY_DONE_PANES=()` の配列宣言（Bash 3.2 互換、`declare -a` で空配列初期化）

> **so-compare レビュー反映 (F1 + F2)**: 検証ペイン監視を `verify.sh` 内の独立関数 `oe_verify_run_phase()` + 独立ループに確定。`monitor.sh` の責務範囲を「通常ペイン監視」に限定し、検証フェーズへの遷移は単純な関数呼び出し 1 行に縮約する。`OE_DONE_PANES`（既存「完了済み通常ペイン」集合）と `OE_VERIFY_DONE_PANES`（新規「完了済み検証ペイン」集合）を別配列にすることで、意味の衝突を回避（実装者が解釈で割れる余地を消す）。

### Step 12: `cleanup.sh` 末尾に `wez notify` 統合

- [ ] `oe_cleanup()` 内で、検証フェーズが完走した場合（CB 発動以外）に `wez notify` を呼ぶ
- [ ] 通知タイトル: `orchestration-engine session complete`
- [ ] 通知本文: `session_id={session_id}, verification: pass={N}, fail={N}, fail_rate={X.XXX}`（`verification_summary` から構築）
- [ ] `wez notify` 失敗時も engine 終了は継続（best-effort）
- [ ] テスト: `tests/test_cleanup.sh` に通知呼び出しケース追加（wez モックで `notify` サブコマンドを記録）

### Step 13: E2E スモーク拡張

- [ ] `tests/test_e2e_smoke.sh` を拡張し、検証フェーズを含む 1 サイクル完走を確認:
  - 既存: spawn → marker 検出 → 6 値分類 → KVS / audit / cleanup
  - 追加: 検証 envelope 生成 → 検証 spawn → `@@OE_VERIFY:pass` 検出 → KVS verification 書き込み → summary 更新 → `wez notify` 呼び出し
- [ ] アサーション: KVS に `verification` と `verification_summary` 両フィールドが存在、`audit/*.jsonl` に `verification_started` と `verification_completed` が記録、`wez notify` が呼ばれた

### GATE: Phase E 完了確認

- [ ] `shellcheck ./bin/oe ./lib/*.sh ./tests/*.sh ./scripts/*.sh` 全 PASS
- [ ] `for f in ./tests/test_*.sh; do bash "$f" || exit 1; done` 全 PASS
- [ ] E2E スモークで検証フェーズを含む 1 サイクル完走
- [ ] user に Phase E 完了報告

---

## ADR / Episode 記録

- [ ] **ADR: `docs/decisions/2026-05-15-decision-verification-gate-design.md`** — 検証ゲート v1 の設計判断（DI-1〜DI-7 の決定と派生課題）を Discussion からの蒸留として記録
- [ ] **Episode: `docs/episodes/2026-05-15-episode-step-4-3-implementation.md`** — 各 Phase の実装結果・遭遇した問題・解決方法を記録

## STOP: Step 4-3 実装完了 — user 報告 + PR 作成判断

- [ ] Phase A〜E 全 GATE クリア + ADR / Episode 記録完了を user に報告
- [ ] user の判断: PR 作成に進む / 追加レビュー（so-compare）を挟む

---

## 最終検証（KickOff §完了条件 8 項目に対応）

KickOff §完了条件のチェックボックス 8 項目を、Phase 実装後の最終検証 TODO として展開する。

- [ ] **検証ゲートが Compliance Review モードで動作する**（end-of-session 発火、新ペイン spawn、envelope の `use_skills: [adversarial-review]` で skill 指定）
  - `oe_monitor_loop` 末尾の検証フェーズ遷移が動作（Phase E Step 11）
  - 検証用 envelope に `use_skills: [adversarial-review]` が含まれる（Phase B Step 4）
  - 検証 agent が新ペインで起動される（Phase B Step 5）
- [ ] **検証 agent が出力末尾に `@@OE_VERIFY:{pass|fail|warn}` マーカーを出し、engine がパースする**
  - envelope の `exit_conditions.marker` で `@@OE_VERIFY:` を要求（Phase B Step 4）
  - `capture.sh` の正規表現が `@@OE_VERIFY:` を検出（Phase D Step 8）
  - `tests/test_capture.sh` で各値ケースが PASS（Phase D Step 8）
- [ ] **検証結果が KVS の `verification` フィールドに、セッション集計が `verification_summary` フィールドに記録される**（fail 率含む）
  - `oe_verify_write_kvs` が `verification` を書き込む（Phase D Step 9）
  - `oe_verify_summary_update` が集計（fail_rate 含む）を書き込む（Phase D Step 9）
  - `validate-session-state.sh` で出力が PASS（Phase A Step 3）
- [ ] **audit ログに `verification_started` / `verification_completed` の 2 イベントが追加される**
  - スキーマ拡張で 2 イベント定義（Phase A Step 2）
  - `oe_verify_spawn` / `@@OE_VERIFY:` 検出時に emit（Phase D Step 10）
- [ ] **不合格時も engine は停止せず、`wez notify` で完了通知のみ出す**
  - `oe_cleanup` 末尾で `wez notify` 呼び出し（Phase E Step 12）
  - 不合格時も engine 終了処理は通常通り進む（Phase E Step 11 で fail 時の特別停止処理なし）
- [ ] **shellcheck で全スクリプトが pass**
  - `shellcheck ./bin/oe ./lib/*.sh ./tests/*.sh ./scripts/*.sh` クリーン（Phase E GATE）
- [ ] **テストスイート: 検証プロンプト構築 / 結果パース / KVS 拡張のユニットテスト + E2E スモークが PASS**
  - `tests/test_verify.sh` 新規（プロンプト構築、KVS 書き込み、spawn）
  - `tests/test_capture.sh` 拡張（`@@OE_VERIFY:` ケース）
  - `tests/test_e2e_smoke.sh` 拡張（検証フェーズ含む 1 サイクル）
- [ ] **`schemas/session-state.schema.json` / `schemas/audit-log.schema.json` の拡張が validator と整合**
  - スキーマ拡張（Phase A Step 1, 2）
  - 新規 `scripts/validate-session-state.sh`（Phase A Step 3）が拡張出力に対して PASS

## 関連

- 変換元 KickOff: [`2026-05-15-kickoff-step-4-3-verification-gate.md`](2026-05-15-kickoff-step-4-3-verification-gate.md)
- Parent Epic: [#19](https://github.com/stlwolf/ai-development-hub/issues/19)
- 観測層サブ Issue: [#89](https://github.com/stlwolf/ai-development-hub/issues/89)
- Step 4-3 Discussion: [`2026-05-15-discussion-step-4-3-verification-gate.md`](../discussions/2026-05-15-discussion-step-4-3-verification-gate.md)
- Step 4-2 成果物: [PR #88](https://github.com/stlwolf/ai-development-hub/pull/88)（[#87](https://github.com/stlwolf/ai-development-hub/issues/87) closed）
- Step 4-2 Plan: [`2026-05-14-plan-step-4-2-parse-and-state-management.md`](2026-05-14-plan-step-4-2-parse-and-state-management.md)
- adversarial-review SKILL: [`canonical/skills/adversarial-review/SKILL.md`](../../../../canonical/skills/adversarial-review/SKILL.md)

## 完全性チェック

`kickoff-to-plan` SKILL の Step 4 に従い、KickOff からの変換完全性を確認する。

### 必須（全合格）

| 突合項目 | KickOff | Plan | 結果 |
|---------|---------|------|------|
| 完了条件チェックボックス数 → 最終検証 TODO 数 | 8 件 | 8 件 | ✅ |
| DI 数 → 実装 Step 配置数（DI 対応分） | 7 件 | 7 件（DI-1=Context、DI-2/6=Phase E、DI-3=Phase B、DI-4=Phase C、DI-5=Phase A+D、DI-7=Phase B+D） | ✅ |
| STOP 指示数 → STOP TODO 数 | 0（KickOff 明示なし） | 1（Phase E 完了後、ユーザー指定の補強） | ✅（判断メモ §6） |
| 全ての GATE が独立 TODO 項目（Step 子 TODO に埋没していない） | — | 5 件全て独立（Phase A/B/C/D/E 各末尾） | ✅ |
| 「〜等」「〜など」で省略された項目がない | — | 0 件（so-compare 初回レビューで `plan:318` に「so-compare 等」を検出 → F8 で修正済み） | ✅ |

### 推奨

| 突合項目 | KickOff | Plan | 結果 |
|---------|---------|------|------|
| Pre-Implementation 項目数 → Pre-Implementation TODO 数 | 6 件（うち 3 件は確認済み済み・着手前タスク） | 着手前タスクは KickOff §進め方 #1 で完了済み、Plan には reconfirm として配置せず | ✅（判断メモ §1） |
| スコープ外項目数 → スコープ外記載数 | 5 件（KickOff §スコープ外）+ 4 件（Discussion §未解決の細部） | 5 + 4 = 9 件 Context に転記 | ✅ |
| 概算時間が Step 名に含まれている | — | KickOff 原文に概算時間なし、Plan も含めず | ✅（KickOff 準拠） |

### 内容の検証

| 突合項目 | 結果 |
|---------|------|
| Kickoff の表現がそのまま使われている | ✅ DI-1〜DI-7 の名称・決定内容、`@@OE_VERIFY:`、`verification` / `verification_summary` 等の用語を原文保持 |
| コード例・スキーマ定義例 | ✅ Phase A の JSON 構造例は Discussion §Q5 から保持 |
| frontmatter の related 参照が Context または Phase に含まれている | ✅ 全 9 件が「設計入力」「駆動層入力」「観測層 Issue」「スコープ外」に分配 |
| 引き継ぎの「解決済み」が Context に含まれている | ✅ Step 4-2 PR #88 完了、Discussion 全 Q closed、DI-1 確定を Context に明記 |

## Review 履歴

### so-compare 初回レビュー (2026-05-15、`tmp/so-20260515-163925/`)

**Reviewer:** Codex (126s) + Claude (197s) の 2 者並列

**結果:** **Issues Found** — 実装ブロックなしだが、Plan 文書の修正で解消可能な指摘 8 件。同一コミット (F1〜F8) で反映済み。

#### 反映済み修正一覧

| ID | 区分 | 指摘 | 反映箇所 |
|----|------|------|----------|
| **F1** | Critical (Clarity, 両者一致) | Phase E Step 11 の検証ペイン監視所在が 3 通り解釈可能 | Phase E Step 11: `verify.sh` 内 `oe_verify_run_phase()` 独立ループに確定 |
| **F2** | Critical (Clarity, Claude) | `OE_DONE_PANES` を検証ペイン用に再利用すると現状の「完了済み通常ペイン」意味と衝突 | Phase E Step 11: `OE_VERIFY_MANAGED_PANES` / `OE_VERIFY_DONE_PANES` を別配列として導入 |
| **F3** | Critical (Clarity, 両者一致) | `@@OE_VERIFY:` と `@@OE_EXIT:` 同時検出時の優先順位未定義 (`spawn.sh:24-25` が必ず後置するため) | Phase D Step 8: scan 結果を `OE_SCAN_EXIT_CODE` + `OE_SCAN_VERIFY_RESULT` の二値保持に変更 |
| **F4** | Strong (Consistency + YAGNI, Codex) | DI-7 の `use_skills` 疎結合方針と矛盾する skill prompt の static copy | Phase B Step 4 + Phase C Step 6: engine は 3 入力の構造化抽出のみ、プロンプト組み立ては検証 agent が `read_docs` で skill を読んで実施 |
| **F5** | Strong (Consistency, Codex) | `verification` が単一オブジェクトのため複数 target pane の per-pane 結果を保持できない | Phase A Step 1: `verification` を **pane-keyed map** に変更 (`verification.{target_pane_id}.{result, ...}`) |
| **F6** | Strong (Consistency, Claude) | `verification_started` emit が Phase B Step 5 と Phase D Step 10 で二重宣言 | Phase D Step 10: `verification_started` 削除、`verification_completed` の新規 emit のみに責務限定 |
| **F7** | Strong (Clarity, Claude) | `outputs[]` フォールバック「`git diff` の試行」が具体性低い、`capture.sh:104` で常に空配列のため挙動不明 | Phase C Step 6: 「MVP では `outputs[]` は常に空配列、`git diff` パスが常時選択、`outputs[]` 拡張は本 Step スコープ外」と明示 |
| **F8** | Trivial (Codex) | 完全性チェック表「〜等」省略 0 件と主張だが `plan:318` に「so-compare 等」を検出 | STOP セクション「so-compare 等」→ 「so-compare」に修正、完全性チェック表に補足注記 |

#### 観点別判定（修正反映後の見込み）

| 観点 | 初回 (Codex / Claude) | 修正後の見込み |
|------|---------------------|---------------|
| Completeness | Issues Found / Approved | Approved（F4 解消で曖昧記述なし） |
| Consistency | Issues Found / Issues Found | Approved（F4 F5 F6 解消） |
| Clarity | Issues Found / Issues Found | Approved（F1 F2 F3 F7 解消） |
| Scope | Approved / Approved | Approved（変更なし） |
| YAGNI | Issues Found / Approved | Approved（F4 解消） |
| 完了条件 ↔ 最終検証 1:1 | ✅ 8↔8 / ✅ 8↔8 | ✅ 維持 |
| DI ↔ Step | ✅ 7↔7 / ✅ 7↔7 | ✅ 維持 |

修正後の再レビューは user の判断に委ねる（必須ではない、追加 so-compare 1 イテレーションで判定可能）。
