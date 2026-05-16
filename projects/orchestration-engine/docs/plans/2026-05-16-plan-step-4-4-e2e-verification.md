---
id: "01KRRMPMXJEFJM6FYNZAW7X1F5"
title: "orchestration-engine Step 4-4 E2E 検証 (実 agent で 1 サイクル完走) Plan"
date: 2026-05-16
type: plan
status: draft
related:
  - type: derived_from
    ref: "projects/orchestration-engine/docs/plans/2026-05-16-kickoff-step-4-4-e2e-verification.md"
    reason: "変換元 KickOff (status: confirmed)。kickoff-to-plan SKILL に従い本 Plan を生成"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/19"
    reason: "Epic #19 Phase 4 MVP 実装の Step 4-4 (観測層・親 Epic)"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/95"
    reason: "Step 4-4 観測層サブ Issue"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/91"
    reason: "Step 4-4 着手前必須 → 本 Plan Phase A に組み込み"
  - type: source_material
    ref: "projects/orchestration-engine/docs/discussions/2026-05-16-discussion-step-4-4-e2e-verification.md"
    reason: "Step 4-4 Discussion (QDD Q1〜Q8 closed、本 Plan の入力)"
  - type: source_material
    ref: "projects/orchestration-engine/docs/decisions/2026-05-16-decision-verification-gate-design.md"
    reason: "Step 4-3 ADR (検証ゲート v1 アーキテクチャ確定形、本 Step の基盤)"
  - type: source_material
    ref: "projects/orchestration-engine/docs/episodes/2026-05-16-episode-step-4-3-implementation.md"
    reason: "Step 4-3 Episode (so-compare 2 段階レビュー結果、mock 限界の認識)"
  - type: source_material
    ref: "https://github.com/stlwolf/ai-development-hub/pull/94"
    reason: "Step 4-3 全成果物 PR (マージ済み、本 Step の基盤)"
  - type: design_context
    ref: "canonical/skills/adversarial-review/SKILL.md"
    reason: "Compliance Review プロンプト規約 (検証 agent が use_skills 経由で参照)"
  - type: design_context
    ref: "projects/orchestration-engine/lib/spawn.sh"
    reason: "Phase A で CLI ディスパッチャを追加する対象ファイル"
  - type: design_context
    ref: "projects/orchestration-engine/lib/verify.sh"
    reason: "Phase A で OE_VERIFY_AI_MODEL を追加 + spawn dispatcher 経由化"
tags: [orchestration, mvp, step-4-4, plan, e2e-verification, real-agent, cli-dispatcher]
---

# Step 4-4: E2E 検証 (実 agent で 1 サイクル完走) — Plan

> 本 Plan は [KickOff](2026-05-16-kickoff-step-4-4-e2e-verification.md) (status: confirmed) を `kickoff-to-plan` SKILL に従い変換した。KickOff の 8 Decision Items (DI-1〜DI-8) を 5 Phase に配置し、各 DI を実装 TODO として展開する。

## 変換上の判断メモ

> KickOff は Discussion Q1〜Q8 合意をもとに DI-1〜DI-8 を定義した構造。Step 4-3 で構築した `lib/verify.sh` 等の検証ゲート v1 を **実 agent (cursor-agent + claude -p) で動かす**ことが本 Step の核心。以下の判断で変換した。

1. **DI → Phase 変換**: KickOff §「想定 Plan 構成」の 5 Phase をそのまま Plan の Phase 構造に採用:
   - Phase A: DI-3 (CLI ディスパッチャ) + DI-4 (env var 拡張) + 物理前提実機確認
   - Phase B: DI-2 (実 agent spawn 経路の通電確認、最小プロンプト)
   - Phase C: DI-1 (target タスク完遂)
   - Phase D: DI-2 + DI-7 (検証フェーズ E2E + 構造的判定)
   - Phase E: DI-5 + DI-6 + DI-8 (`tests/e2e_real_agent/` 整備 + Episode 記録)
2. **物理前提の実機確認 Step**: Phase A の Step 1 として配置。「`cursor-agent` / `claude -p ... --model` の正しい invocation 仕様確認」と「composer-2 の Bash + Markdown 実力確認」を Phase A の冒頭 obligation 化 (Discussion §「未解決の細部」)
3. **DI-1 具体タスクの選定**: Plan §Phase C Step 6 で 1 つに絞る。KickOff §DI-1 の候補 3 つから推奨デフォルトを **`OE_VERIFY_REVIEWER_SESSION_IDS` 追跡** (派生 [#93](https://github.com/stlwolf/ai-development-hub/issues/93) 前半の取り込み) に設定。理由は (a) #93 の半分を消化、(b) 検証 agent が「kill 動作」を assertion 経由で判定しやすい、(c) Step 4-5 で残り半分 (nonce マーカー) の判断材料になる、の 3 点
4. **GATE 配置**: 各 Phase 末尾に GATE を配置 (Step 4-3 と同じパターン)。Phase E 完了後に STOP を 1 件配置 (user 報告 + PR 作成判断)
5. **物理前提が揃わない開発者環境への配慮**: Phase A〜Phase D の Step は mock テストで完走確認できるように設計。Phase E (実 agent E2E) のみ「物理前提が揃わない環境ではスキップ可」と Plan で明示
6. **so-compare 2 段階体制の踏襲**: Plan 段階 (本ドキュメント完成後) と実装段階 (Phase E 完了後) でそれぞれ so-compare を実行する想定。Plan 段階の指摘は本 Plan 内に F-* として、実装段階の指摘は別途 Phase A〜E 修正コミットに F-SO-* として反映する

## Context

### 前提 (KickOff + Discussion で確定済み)

- Step 4-3 [PR #94](https://github.com/stlwolf/ai-development-hub/pull/94) で検証ゲート v1 (mock 経由 299 assertions PASS) が動作する状態
- Step 4-4 [Discussion](../discussions/2026-05-16-discussion-step-4-4-e2e-verification.md) で 8 Q (Q1〜Q8) を user との 1 問ずつの対話で合意済み
- **DI-2: CLI + モデル明示指定**: target = `cursor-agent` / `composer-2` (サブスク内)、検証 = `claude -p` / `claude-sonnet-4-6` (~$0.045/サイクル)
- **DI-7: 構造的判定**: `verify_result` の値 (pass/fail/warn) は assertion 対象外、engine の動作 4 点 (marker emit / KVS / audit / notify) のみを判定

### 物理前提

| CLI | 認証 | 利用モデル |
|------|------|----------|
| `cursor-agent` | Cursor Pro/Business サブスク + login | `composer-2` |
| `claude -p` | `ANTHROPIC_API_KEY` 環境変数 or `claude login` | `claude-sonnet-4-6` |

Phase E は両方の物理前提が揃った開発者環境でのみ実施可。揃わない場合は Phase A〜D の mock テストまで進められる。

### 設計入力

- KickOff: [`docs/plans/2026-05-16-kickoff-step-4-4-e2e-verification.md`](2026-05-16-kickoff-step-4-4-e2e-verification.md)
- Discussion: [`docs/discussions/2026-05-16-discussion-step-4-4-e2e-verification.md`](../discussions/2026-05-16-discussion-step-4-4-e2e-verification.md)
- Step 4-3 ADR: [`docs/decisions/2026-05-16-decision-verification-gate-design.md`](../decisions/2026-05-16-decision-verification-gate-design.md)
- skill: [`canonical/skills/adversarial-review/SKILL.md`](../../../../canonical/skills/adversarial-review/SKILL.md)

### 駆動層入力 (Step 4-3 成果物)

| 成果物 | パス | 本 Step での利用 |
|--------|------|----------------|
| `lib/spawn.sh` | `oe_spawn_prepare_pane` / `oe_spawn_send` | **Phase A で CLI ディスパッチャを追加** (`_oe_spawn_build_cli_command`) + `oe_spawn_send` がディスパッチャ経由で送信するように改修 |
| `lib/verify.sh` | `oe_verify_run_phase` / `oe_verify_spawn` | **Phase A で `OE_VERIFY_AI_MODEL` env var 対応** + `oe_verify_spawn` がディスパッチャ経由で送信するように改修 |
| `bin/oe` | `oe_main` | **Phase A で `OE_TARGET_AI_CLI` / `OE_TARGET_AI_MODEL` env var を読む** ように改修 |
| `lib/constants.sh` | (`OE_VERIFY_AI_CLI` 既実装) | **Phase A で `OE_VERIFY_AI_MODEL` 追加 + デフォルト値設定** |
| `tests/test_*.sh` | 8 スイート 299 assertions | **Phase A 〜 D で回帰なしを維持** |
| `schemas/envelope.schema.json` | envelope の形 | **変更なし** (envelope への `task.ai_cli` / `task.ai_model` 追加は Step 4-5 候補) |
| `canonical/skills/adversarial-review/SKILL.md` | Compliance Review 規約 | **検証 agent が `use_skills` 経由で参照、本 Step では skill 側に変更なし** |

### 観測層 Issue (Read-only)

- [#19](https://github.com/stlwolf/ai-development-hub/issues/19) — Epic 親、Phase 4 ステップ管理
- [#89](https://github.com/stlwolf/ai-development-hub/issues/89) — Step 4-3 サブ Issue (closed、[PR #94](https://github.com/stlwolf/ai-development-hub/pull/94))
- [#91](https://github.com/stlwolf/ai-development-hub/issues/91) — AI CLI 起動オプション修正 (本 Plan Phase A に組み込み、本 PR で同時 closed 予定)
- [#92](https://github.com/stlwolf/ai-development-hub/issues/92) — 変更ファイル検出 per-pane / 完了報告充実 (Step 4-5 候補、本 Step スコープ外)
- [#93](https://github.com/stlwolf/ai-development-hub/issues/93) — 一時ファイル掃除 / nonce マーカー (前半を Phase C で取り込み予定、後半は MVP 後拡張)
- [#95](https://github.com/stlwolf/ai-development-hub/issues/95) — Step 4-4 サブ Issue (本 Plan の観測層)

### スコープ外 (本 Plan では扱わない)

KickOff §スコープ外 + Discussion §派生課題:

- envelope schema への `task.ai_cli` / `task.ai_model` フィールド追加 (Step 4-5 候補)
- 完全 CI 自動化 (Step 4-5 以降)
- 統計判定 (Q7 案 C、必要性が見えてから)
- 3 CLI 全対応 (現状 `codex -p` は CLI ディスパッチャにスタブとして残すが動作確認は cursor + claude のみ)
- 検証 agent 自体の品質評価 (Step 4-5 候補)
- 派生 Issue [#92](https://github.com/stlwolf/ai-development-hub/issues/92) (per-pane 変更ファイル検出 / 完了報告充実) の本格実装
- 派生 Issue [#93](https://github.com/stlwolf/ai-development-hub/issues/93) 後半 (nonce 付きマーカー偽陽性対策、MVP 後)

---

## Phase A: CLI ディスパッチャ + env var 拡張 + 物理前提実機確認 (DI-3 + DI-4)

> 全 Phase の前提となる CLI ディスパッチャを `lib/spawn.sh` に追加し、target / 検証双方の AI CLI / モデル選択を env var で制御可能にする。物理前提 (cursor-agent / claude CLI 認証) の実機確認を Phase 冒頭で obligation 化。

### Step 1: 物理前提の実機確認 (Phase A 冒頭、Plan obligation)

- [ ] `cursor-agent --version` (または `cursor --version`) が実行可能であることを確認
- [ ] `claude --version` (or `claude-safe --version`) が実行可能であることを確認
- [ ] `cursor-agent` の **正しい invocation 仕様**を実機で確認:
  - 候補形: `cursor-agent --prompt '<text>'` / `cursor-agent agent <text>` / `cursor agent <text>` 等
  - 実際の引数 / オプション / モデル指定方法を確認
  - 確認結果を Plan の §「物理前提の実機確認結果」に追記
- [ ] `claude -p` の **正しい invocation 仕様**を実機で確認:
  - 候補形: `claude -p "<text>" --model claude-sonnet-4-6 -w "$(pwd)"` (adversarial-review SKILL のツール別起動例参照)
  - `--model claude-sonnet-4-6` の指定方法 (CLI 引数 or env var) を確定
  - 確認結果を Plan の §「物理前提の実機確認結果」に追記
- [ ] `composer-2` の Bash + Markdown 実力確認:
  - cursor-agent で簡単な依頼を実行 (例: 「`projects/orchestration-engine/lib/test_dummy.sh` を作成して shebang と set -euo pipefail だけ書いて」)
  - 動作不安定な場合は本 Plan を **gpt-4.1 退避案** に書き換え (Plan 修正コミット)
- [ ] **物理前提が揃わない開発者環境**で本 Plan を進める場合、Phase E スキップ条件を `tests/e2e_real_agent/README.md` に明示

### Step 2: `lib/spawn.sh` に CLI ディスパッチャ `_oe_spawn_build_cli_command` を追加

- [ ] 新規関数 `_oe_spawn_build_cli_command(ai_cli, ai_model, envelope_path, [workspace])` を `lib/spawn.sh` に追加
- [ ] ディスパッチ対象: 3 CLI (`cursor-agent` / `claude` / `codex`)
  - `cursor-agent`: Step 1 で確定した正しい invocation 形式に置き換え + `composer-2` (or 退避先) モデル指定
  - `claude`: `claude -p "Read <envelope_path> and execute the task" --model <ai_model> -w <workspace>` 形式
  - `codex`: スタブ実装 (本 Step では動作確認なし、`claude` と同じパターンで仮置き)
  - 未対応 CLI はエラーとする (`echo "unsupported ai_cli '${ai_cli}'" >&2 ; return 1`)
- [ ] 戻り値: 組み立てた CLI コマンド文字列 (stdout に出力)
- [ ] shellcheck クリーン

### Step 3: env var 4 つの追加 + デフォルト値設定

- [ ] `lib/constants.sh` に追加:
  - `OE_TARGET_AI_CLI="${OE_TARGET_AI_CLI:-cursor-agent}"`
  - `OE_TARGET_AI_MODEL="${OE_TARGET_AI_MODEL:-composer-2}"`
  - `OE_VERIFY_AI_MODEL="${OE_VERIFY_AI_MODEL:-claude-sonnet-4-6}"`
- [ ] 既存 `OE_VERIFY_AI_CLI` (Step 4-3 F-SO-6 で `lib/verify.sh` 内に hardcode default `cursor`) のデフォルトを `claude` に変更 + `lib/constants.sh` に移動
- [ ] env var の docstring を `lib/constants.sh` のコメントに記載

### Step 4: `oe_spawn_send` / `oe_verify_spawn` をディスパッチャ経由に改修

- [ ] `oe_spawn_send` を改修:
  - 旧: `cli_command="${ai_cli} --prompt 'Read ${envelope_path} and execute the task' ; printf '\\n@@OE_EXIT:%d\\n' \$?"`
  - 新: `cli_command="$(_oe_spawn_build_cli_command "$ai_cli" "$ai_model" "$envelope_path") ; printf '\\n@@OE_EXIT:%d\\n' \$?"`
  - 関数シグネチャに `ai_model` 引数を追加 (デフォルト: env var 由来)
- [ ] `oe_verify_spawn` も同様に改修 (ai_model 引数追加 + ディスパッチャ経由)
- [ ] `bin/oe` の `oe_main` で `OE_TARGET_AI_CLI` / `OE_TARGET_AI_MODEL` を読んで `oe_spawn_send` に伝播
- [ ] `oe_verify_run_phase` で `OE_VERIFY_AI_MODEL` を読んで `oe_verify_spawn` に伝播

### Step 5: 既存 mock テストに回帰なし確認

- [ ] `tests/test_e2e_smoke.sh` の wez モックは「ai_cli の値」を意識していないため、ディスパッチャ経由でも既存 assertion がすべて通る想定
  - 必要に応じて mock を拡張 (例: send.log に展開後の cli_command を記録、ディスパッチャ動作を assertion)
- [ ] `tests/test_verify.sh` の wez モックも同様に確認
- [ ] **完了基準**: 全 8 スイート PASS、299 assertions 維持 (回帰なし)

### GATE: Phase A 完了確認

- [ ] Step 1〜5 完了
- [ ] `shellcheck ./bin/oe ./lib/*.sh ./tests/*.sh ./scripts/*.sh` クリーン
- [ ] `for f in ./tests/test_*.sh; do bash "$f" || exit 1; done` 全 PASS (299 assertions)
- [ ] 物理前提 (cursor-agent + claude CLI) が揃った環境で `_oe_spawn_build_cli_command cursor-agent composer-2 /tmp/dummy-envelope.json` を実行し、出力されたコマンドが実 CLI に解釈可能であることを確認 (構文 OK レベルで、実行はしない)
- [ ] user に Phase A 完了報告、Phase B 進行可否の合図を待つ

---

## Phase B: 実 agent spawn 経路の通電確認 (DI-2)

> 最小プロンプト (echo 系) で cursor-agent / claude -p をそれぞれ単独起動し、`@@OE_EXIT` emit までを確認する。target タスク完遂 (Phase C) や検証 E2E (Phase D) に進む前の通電確認。

### Step 6: target (cursor-agent / composer-2) の通電確認スクリプト

- [ ] `tests/e2e_real_agent/probe_target.sh` を新規作成 (ディレクトリも本 Step で作成):
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  # cursor-agent (composer-2) を最小プロンプトで起動し @@OE_EXIT を待つ
  # 期待: "@@OE_EXIT:0" が出力に含まれる
  ```
- [ ] 実 agent が起動できることだけを確認 (タスク内容は「@@OE_EXIT:0 を 1 行で出力して」程度の最小プロンプト)
- [ ] 出力ログを `tests/e2e_real_agent/.tmp_probe_target.log` に保存
- [ ] **完了基準**: スクリプトが 0 終了、ログに `@@OE_EXIT:0` を含む

### Step 7: 検証 (claude -p / claude-sonnet-4-6) の通電確認スクリプト

- [ ] `tests/e2e_real_agent/probe_verify.sh` を新規作成
- [ ] claude -p (sonnet-4-6) を最小プロンプトで起動し `@@OE_VERIFY` emit を確認
  - プロンプト: 「`adversarial-review` skill を読まずに、`@@OE_VERIFY:pass` を 1 行で出力して」(skill load は Phase D で確認、本 Step では emit プロトコルだけ確認)
- [ ] 出力ログを `tests/e2e_real_agent/.tmp_probe_verify.log` に保存
- [ ] **完了基準**: スクリプトが 0 終了、ログに `@@OE_VERIFY:pass` を含む

### GATE: Phase B 完了確認

- [ ] Step 6, 7 完了
- [ ] `probe_target.sh` と `probe_verify.sh` がそれぞれ 0 終了
- [ ] 出力ログに期待するマーカーが含まれる
- [ ] user に Phase B 完了報告

---

## Phase C: target タスク完遂 (DI-1)

> DI-1 で確定した「orchestration-engine 自体の小機能追加」を target (cursor-agent / composer-2) に依頼し、`@@OE_EXIT:0` まで完走させる。

### Step 8: DI-1 具体タスクの最終確定

- [ ] KickOff §DI-1 の候補 3 つから 1 つを選択 (本 Plan の推奨デフォルト: **`OE_VERIFY_REVIEWER_SESSION_IDS` 追跡** = 派生 [#93](https://github.com/stlwolf/ai-development-hub/issues/93) 前半の取り込み)
- [ ] 採用根拠: (a) 既存派生 [#93](https://github.com/stlwolf/ai-development-hub/issues/93) の半分を本 Step で消化、(b) 検証 agent が「kill 動作」を test 経由で判定しやすい、(c) Step 4-5 で残り半分 (nonce 付きマーカー) を判断する材料になる
- [ ] envelope の `task.description` を作成 (target に渡される指示):
  - 要件: `lib/constants.sh` に `OE_VERIFY_REVIEWER_SESSION_IDS=()` を追加、`lib/verify.sh` の `oe_verify_run_phase` で reviewer ULID 生成時に当該配列に append、`lib/cleanup.sh` で当該配列をループして `/tmp/oe-{rsid}-verify-*` を削除
  - 完了条件: shellcheck クリーン、既存 mock テスト 299 assertions に回帰なし、新 test 追加 (test_cleanup.sh で OE_VERIFY_REVIEWER_SESSION_IDS 経由の reviewer 一時ファイル削除を assertion)
- [ ] `task.description` をテストファイル `tests/e2e_real_agent/task_description_dogfood_cleanup.md` に保存 (再現性のため)

### Step 9: target 起動 + タスク完遂確認

- [ ] `tests/e2e_real_agent/smoke_cursor_composer_claude_sonnet.sh` を新規作成 (Phase C / D 共通の E2E スクリプト):
  - 環境変数 `OE_TARGET_AI_CLI=cursor-agent`, `OE_TARGET_AI_MODEL=composer-2`, `OE_VERIFY_AI_CLI=claude`, `OE_VERIFY_AI_MODEL=claude-sonnet-4-6` を明示セット
  - `bin/oe "$(cat tests/e2e_real_agent/task_description_dogfood_cleanup.md)"` で起動
  - target session_id をログに記録
- [ ] **本 Step (Phase C) の完了基準**: target が `@@OE_EXIT:0` を emit、`state/{session_id}.state.json` に `state: success` が記録される
- [ ] 完了基準を満たすか `tests/e2e_real_agent/check_phase_c.sh` で確認 (補助スクリプト):
  - `state.session_id` と `state.state == "success"` を `jq` で検査
  - audit log に `state_change` (state=success) と `session_end` が記録されているか確認
- [ ] Phase D に進む前に target の変更内容 (実際の constants.sh / verify.sh / cleanup.sh 編集差分) を `git diff` で確認

### GATE: Phase C 完了確認

- [ ] Step 8, 9 完了
- [ ] target がタスクを完遂、`state: success` が KVS に記録
- [ ] target が実装した変更内容 (Step 8 で指定した OE_VERIFY_REVIEWER_SESSION_IDS 追跡) が機能している (`git diff` で確認、必要なら shellcheck も target が走らせている前提だが、人間が再走させて確認)
- [ ] user に Phase C 完了報告 + 変更差分を提示

---

## Phase D: 検証フェーズ E2E + 構造的判定 (DI-2 + DI-7)

> Phase C 完走後、engine が `oe_verify_run_phase` を呼んで claude -p (claude-sonnet-4-6) を起動する。検証 agent が adversarial-review skill の Compliance Review を実行し `@@OE_VERIFY:{result}` を emit、engine が二値検出 + write_kvs + verification_completed audit emit を行う。構造的判定の 4 点を assertion。

### Step 10: 検証 agent の動作観察

- [ ] Phase C で起動した `bin/oe` プロセスがそのまま続行し、`oe_verify_run_phase` 経由で claude -p (sonnet-4-6) が起動することを確認
  - reviewer pane が wez split で作成される
  - verify-envelope.json + verify-inputs.md が `/tmp` に生成される
  - claude -p が起動し、skill (adversarial-review) と read_docs を読んで Compliance Review を実行
  - 末尾で `@@OE_VERIFY:{pass|fail|warn}` + shell 後置 `@@OE_EXIT:0` が emit される
- [ ] engine が両 marker を二値保持で検出 (Step 4-3 F3) し:
  - `oe_verify_write_kvs` で `verification[$target_pane_id]` を書き込み
  - `oe_verify_emit_completed` で `verification_completed` audit イベント emit
  - `oe_verify_summary_update` で `verification_summary` を集計
  - `cleanup.sh` で reviewer pane + 一時ファイル削除 + `wez notify` 呼び出し

### Step 11: 構造的判定 4 点の assertion (`check_cycle_complete.sh`)

- [ ] `tests/e2e_real_agent/check_cycle_complete.sh` を新規作成
- [ ] 引数: `target_session_id` (Phase C 起動時のログから渡す)
- [ ] 構造的判定 (Q7 / DI-7) の 4 点を assertion:
  1. `@@OE_EXIT:0` (target) と `@@OE_VERIFY:{pass|fail|warn}` (reviewer) が両方 emit (audit log + KVS で確認)
  2. `state/{session_id}.state.json` に `state: success` と `verification[].result` が記録 (`validate-session-state.sh` で validation)
  3. `audit/{session_id}.jsonl` に主要 7 イベントが記録 (`jq` でイベント件数確認)
  4. `wez notify` が呼ばれ、本文に `pass={} fail={} warn={} fail_rate={} protocol_errors={} timeouts={}` が展開 (notify ログまたは `wez` mock log 経由、実環境は wez notify の実呼び出し)
- [ ] `verify_result` の値 (pass/fail/warn) は assertion 対象外、Episode 記録用に出力に含める

### GATE: Phase D 完了確認

- [ ] Step 10, 11 完了
- [ ] `check_cycle_complete.sh` の 4 点 assertion が全 PASS
- [ ] `verify_result` の値 (pass/fail/warn) を Episode 記録用に保存
- [ ] user に Phase D 完了報告 + 検証結果の観察を提示

---

## Phase E: tests/e2e_real_agent/ 整備 + Episode 記録 (DI-5 + DI-6 + DI-8)

> Phase A〜D で作成したスクリプト群を `tests/e2e_real_agent/` 配下に整理し、README で環境前提 + 実行手順を明示。実 agent で 1 サイクル完走を実証 + Episode に観察記録を残す。

### Step 12: `tests/e2e_real_agent/` 構成整備

- [ ] ディレクトリ構成:
  ```
  tests/e2e_real_agent/
  ├── README.md                                    # 環境前提 + 実行手順 + Phase E スキップ条件
  ├── probe_target.sh                              # Phase B Step 6 で作成
  ├── probe_verify.sh                              # Phase B Step 7 で作成
  ├── smoke_cursor_composer_claude_sonnet.sh       # Phase C Step 9 で作成
  ├── task_description_dogfood_cleanup.md          # Phase C Step 8 で保存
  ├── check_phase_c.sh                             # Phase C Step 9 補助
  └── check_cycle_complete.sh                      # Phase D Step 11 で作成
  ```
- [ ] `README.md` の内容:
  - 環境前提: cursor-agent + claude CLI 両方 + 認証
  - 実行手順: `OE_TARGET_AI_CLI=... bash tests/e2e_real_agent/smoke_cursor_composer_claude_sonnet.sh`
  - Phase E スキップ条件: 物理前提が揃わない開発者環境では本 README の手順を skip 可
  - 期待コスト: ~$0.045/サイクル (claude-sonnet-4-6 検証側のみ、cursor はサブスク内)
  - 想定実行頻度: MVP では 1 回完走を実証すれば十分、Step 4-5 以降で定期実行を検討
- [ ] shellcheck クリーン (e2e_real_agent/ 配下の全 .sh が対象)

### Step 13: 1 回の完走実証

- [ ] 開発者環境で `bash tests/e2e_real_agent/smoke_cursor_composer_claude_sonnet.sh` を実行
- [ ] 完走 (Phase A〜D の Step 9〜11 を全通過) を確認
- [ ] 出力ログを保存 (`tests/e2e_real_agent/.tmp_smoke_<timestamp>.log`)
- [ ] 完走しなかった場合は Plan に F-* 修正項目を追記して再実行 (Plan iter1)

### Step 14: Episode 起草

- [ ] `docs/episodes/<YYYY-MM-DD>-episode-step-4-4-implementation.md` を新規作成
- [ ] Step 4-3 Episode のフォーマット (元実装 / so-compare 結果 / 修正後 の 3 セクション分離) を踏襲
- [ ] Episode に記録する内容:
  - **(A) 元実装フェーズ**: Phase A〜E の commit 履歴 + 各 Phase の設計判断 + DI-1〜DI-8 の反映証跡
  - **(B) so-compare 実装段階レビュー (iter2)**: 実装後の so-compare で発見された指摘 + Critical / Concern 分類
  - **(C) F-SO 修正反映**: so-compare iter2 の対応
  - **(D) 実 agent 動作観察**: 完走実証ログ + cost (target / 検証それぞれ何 token / $) + verify_result の傾向 (pass/fail/warn の比率、reproducibility)
  - **教訓 / 学び**: mock vs 実 agent の挙動差、composer-2 vs gpt-4.1 退避案の判断結果 等

### Step 15: ADR 起草

- [ ] `docs/decisions/<YYYY-MM-DD>-decision-e2e-verification.md` を新規作成
- [ ] Step 4-3 ADR (`2026-05-16-decision-verification-gate-design.md`) のフォーマットを踏襲
- [ ] 蒸留対象:
  - **コンテキスト**: Step 4-3 mock 段階の限界 + 実 agent E2E の必要性
  - **検討した代替案**: Q1〜Q8 の各案
  - **決定**: DI-1〜DI-8 の確定形
  - **根拠**: 設計判断の主軸 (engine の対外境界の検証 / cross-CLI 独立性 / 半自動の妥当性 / 構造的判定の必然性)
  - **結果 / トレードオフ**: 得たもの / トレードオフ / 観測したリスク (Episode と相互参照)

### GATE: Phase E 完了確認

- [ ] Step 12, 13, 14, 15 完了
- [ ] `tests/e2e_real_agent/` が整備済み、README に従って再現可能
- [ ] 完走実証ログが保存されている
- [ ] Episode + ADR が起草済み、相互参照リンク張り済み
- [ ] user に Phase E 完了報告

---

## ADR / Episode 記録 (Phase E Step 14, 15 と重複だが kickoff-to-plan SKILL の TODO として独立配置)

- [ ] **Episode** (Phase E Step 14): `docs/episodes/<YYYY-MM-DD>-episode-step-4-4-implementation.md`
- [ ] **ADR** (Phase E Step 15): `docs/decisions/<YYYY-MM-DD>-decision-e2e-verification.md`

## STOP: Step 4-4 実装完了 — user 報告 + PR 作成判断

- [ ] Phase A〜E 全 GATE クリア + Episode / ADR 記録完了を user に報告
- [ ] user の判断: PR 作成に進む / 追加レビュー (so-compare iter2) を挟む

---

## 最終検証 (KickOff §完了条件 8 項目に対応)

KickOff §完了条件のチェックボックス 8 項目を、Phase 実装後の最終検証 TODO として展開する。

- [ ] **(1)** `@@OE_EXIT:0` (target) と `@@OE_VERIFY:{pass|fail|warn}` (reviewer) が両方 emit される
  - 検証方法: `check_cycle_complete.sh` 内で audit log + KVS から確認 (Phase D Step 11)
- [ ] **(2)** `state/{session_id}.state.json` に `state: success` と `verification[].result` が記録される
  - 検証方法: `check_cycle_complete.sh` 内で `validate-session-state.sh` を呼ぶ (Phase D Step 11)
- [ ] **(3)** `audit/{session_id}.jsonl` に主要 7 イベント (`session_start`, `state_change`, `session_end`, `verification_started`, `verification_completed`, `cleanup`, [optional `verification_protocol_error`]) が記録される
  - 検証方法: `check_cycle_complete.sh` 内で `jq` でイベント件数確認 (Phase D Step 11)
- [ ] **(4)** `wez notify` が呼ばれ、本文に `pass={} fail={} warn={} fail_rate={} protocol_errors={} timeouts={}` が展開される
  - 検証方法: `check_cycle_complete.sh` 内で notify ログまたは `wez` 実行記録から確認 (Phase D Step 11)
- [ ] **(5)** shellcheck クリーン + 既存 299 mock assertions 回帰なし
  - 検証方法: `shellcheck` 全対象 + `bash tests/test_*.sh` (Phase A GATE Step 5)
- [ ] **(6)** [#91](https://github.com/stlwolf/ai-development-hub/issues/91) の CLI ディスパッチャが少なくとも 2 CLI (`cursor-agent` + `claude -p`) で動作
  - 検証方法: `_oe_spawn_build_cli_command` 動作確認 (Phase A Step 2) + 通電確認スクリプト (Phase B Step 6, 7) + E2E 完走 (Phase D)
- [ ] **(7)** 実 agent E2E スクリプトが `tests/e2e_real_agent/` に存在し、再現可能 (cursor-agent + claude CLI 環境で 1 回完走実証)
  - 検証方法: Phase E Step 12 (整備) + Step 13 (実証) + README に手順
- [ ] **(8)** Step 4-5 (architecture-sketch 更新) のフィードバック材料として、実 agent E2E の Episode が記録される
  - 検証方法: Episode に observed cost + verify_result の傾向 + 教訓を記録 (Phase E Step 14)

## 関連

- 変換元 KickOff: [`2026-05-16-kickoff-step-4-4-e2e-verification.md`](2026-05-16-kickoff-step-4-4-e2e-verification.md)
- Parent Epic: [#19](https://github.com/stlwolf/ai-development-hub/issues/19)
- 観測層サブ Issue: [#95](https://github.com/stlwolf/ai-development-hub/issues/95)
- Step 4-4 Discussion: [`2026-05-16-discussion-step-4-4-e2e-verification.md`](../discussions/2026-05-16-discussion-step-4-4-e2e-verification.md)
- Step 4-3 ADR (本 Step の基盤): [`2026-05-16-decision-verification-gate-design.md`](../decisions/2026-05-16-decision-verification-gate-design.md)
- Step 4-3 Episode (so-compare 経験の参照): [`2026-05-16-episode-step-4-3-implementation.md`](../episodes/2026-05-16-episode-step-4-3-implementation.md)
- Step 4-3 全成果物 PR: [#94](https://github.com/stlwolf/ai-development-hub/pull/94)
- 派生 Issue: [#91](https://github.com/stlwolf/ai-development-hub/issues/91) (本 Plan Phase A に組み込み) / [#92](https://github.com/stlwolf/ai-development-hub/issues/92) (Step 4-5 候補) / [#93](https://github.com/stlwolf/ai-development-hub/issues/93) (前半 Phase C に取り込み予定、後半 MVP 後)
- adversarial-review SKILL: [`canonical/skills/adversarial-review/SKILL.md`](../../../../canonical/skills/adversarial-review/SKILL.md)

## 完全性チェック

`kickoff-to-plan` SKILL の Step 4 に従い、KickOff からの変換完全性を確認する。

### 必須 (全合格)

| 突合項目 | KickOff | Plan | 結果 |
|---------|---------|------|------|
| 完了条件チェックボックス数 → 最終検証 TODO 数 | 8 件 | 8 件 | ✅ |
| DI 数 → 実装 Step 配置数 (DI 対応分) | 8 件 | 8 件 (DI-1=Phase C Step 8、DI-2=Phase A+B+D、DI-3=Phase A、DI-4=Phase A Step 3, 4、DI-5=Phase E Step 12, 13、DI-6=Phase A Step 5 + Phase E、DI-7=Phase D Step 11、DI-8=最終検証) | ✅ |
| STOP 指示数 → STOP TODO 数 | 0 (KickOff 明示なし) | 1 (Phase E 完了後、ユーザー指定の補強) | ✅ (判断メモ §4) |
| 全ての GATE が独立 TODO 項目 (Step 子 TODO に埋没していない) | — | 5 件全て独立 (Phase A/B/C/D/E 各末尾) | ✅ |
| 「〜等」「〜など」で省略された項目がない | — | 0 件 | ✅ |

### 推奨

| 突合項目 | KickOff | Plan | 結果 |
|---------|---------|------|------|
| 着手前タスク項目数 → Plan 内反映数 | 6 件 (housekeeping + 物理前提) | 6 件 (Plan §Context + Phase A Step 1) | ✅ |
| スコープ外項目数 → スコープ外記載数 | 6 件 (KickOff §スコープ外) | 6 件 Context §スコープ外 | ✅ |
| 概算時間が Step 名に含まれている | — | KickOff 原文に概算時間なし、Plan も含めず | ✅ (KickOff 準拠) |

### 内容の検証

| 突合項目 | 結果 |
|---------|------|
| KickOff の表現がそのまま使われている | ✅ DI-1〜DI-8 の名称・決定内容、`@@OE_VERIFY:`、`OE_TARGET_AI_CLI` 等の用語を原文保持 |
| コード例・コマンド例 | ✅ Phase A Step 2 の CLI ディスパッチャ署名、Phase A Step 4 の旧/新 cli_command 形式、Phase E Step 12 のディレクトリ構成を Plan 内で具体化 |
| frontmatter の related 参照が Context または Phase に含まれている | ✅ 全 9 件が「設計入力」「駆動層入力」「観測層 Issue」「スコープ外」に分配 |
| 引き継ぎの「解決済み」が Context に含まれている | ✅ Step 4-3 PR #94 完了、Discussion 全 Q closed を Context に明記 |

## 物理前提の実機確認結果 (Phase A Step 1 で追記する)

> Phase A Step 1 実施時に、本セクションを追記する。Plan が変更されるため commit が必要。
>
> - `cursor-agent` 実 invocation 仕様: (TBD)
> - `claude -p` 実 invocation 仕様 + `--model claude-sonnet-4-6` 指定方法: (TBD)
> - `composer-2` の Bash + Markdown 実力確認結果: (TBD、必要なら gpt-4.1 退避案を Plan に書き換え)
