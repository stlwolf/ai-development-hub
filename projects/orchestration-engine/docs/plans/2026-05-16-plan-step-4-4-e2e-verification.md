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
7. **Plan iter1 修正反映 (2026-05-17 so-compare 結果)**: Plan 段階 so-compare iter1 (`tmp/so-20260517-003036/`) で Codex (Critical 3) + Claude (Concern 13) が指摘した Critical 6 + Strong 9 + Minor 1 を本 Plan に反映済み。修正項目は F-1〜F-16 として §「Plan iter1 修正履歴」セクションに対応関係を整理。主な構造変更:
   - Phase A に新 Step 5 (`bin/oe --task-file` オプション追加) を挿入し、Phase B 以降の Step 番号を後ろに 1 つシフト (旧 Step 6→7, ...)
   - 最終検証 (1) を「target marker raw 直接検証不可」を踏まえて `session_end.state == "success"` 代理指標に変更 (F-2)
   - 最終検証 (7)(8) を `full-complete` / `limited-complete` の 2 段階判定に分割 (F-1)
   - `check_cycle_complete.sh` の `jq` クエリ / 判定式を Plan §付録「最終検証用 jq クエリ」で具体化 (F-6)
   - Phase A Step 1 の物理前提実機確認に項目を 4 つ追加 (composer-2 退避条件定量化 / claude workspace skill アクセス可否 / API key + sonnet-4-6 アクセス権 / claude-safe 経由判断、F-3, F-4, F-7)

## Context

### 前提 (KickOff + Discussion で確定済み)

- Step 4-3 [PR #94](https://github.com/stlwolf/ai-development-hub/pull/94) で検証ゲート v1 (mock 経由 299 assertions PASS) が動作する状態
- Step 4-4 [Discussion](../discussions/2026-05-16-discussion-step-4-4-e2e-verification.md) で 8 Q (Q1〜Q8) を user との 1 問ずつの対話で合意済み
- **DI-2: CLI + モデル明示指定**: target = `cursor-agent` / `composer-2` (サブスク内)、検証 = `claude -p` / `claude-sonnet-4-6` (~$0.045/サイクル)
- **DI-7: 構造的判定**: `verify_result` の値 (pass/fail/warn) は assertion 対象外、engine の動作 4 点 (marker emit / KVS / audit / notify) のみを判定

### 物理前提

| CLI | 認証 | 利用モデル | 追加の確認 (Phase A Step 1 で実施) |
|------|------|----------|------------------------------|
| `cursor-agent` | Cursor Pro/Business サブスク + login | `composer-2` | バイナリ名揺れ (`cursor-agent` / `cursor agent`) の確定、composer-2 の Bash 実力確認 + 退避基準 |
| `claude -p` (or `claude-safe -p`) | `ANTHROPIC_API_KEY` 環境変数 or `claude login` + `claude-sonnet-4-6` アクセス権 | `claude-sonnet-4-6` | `-w "$(pwd)"` workspace 制約での `canonical/skills/...` 読み取り可否、API key 最小通電確認、claude-safe 経由 vs 直接呼び出し判断 |

Phase E は両方の物理前提が揃った開発者環境でのみ実施可 (full-complete 判定)。揃わない場合は Phase A〜D の mock テストまで進められる (limited-complete 判定、最終検証 §「(7)(8) full-complete / limited-complete 2 段階判定」参照)。

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
  - **バイナリ名揺れの最終決定** (F-SO-12 反映): `cursor-agent` / `cursor` / `claude-safe` のうちどれを正式採用するか、フォールバック優先順位を Plan §「物理前提の実機確認結果」に明記
  - 確認結果を Plan の §「物理前提の実機確認結果」に追記
- [ ] `claude -p` の **正しい invocation 仕様**を実機で確認:
  - 候補形: `claude -p "<text>" --model claude-sonnet-4-6 -w "$(pwd)"` (adversarial-review SKILL のツール別起動例参照)
  - `--model claude-sonnet-4-6` の指定方法 (CLI 引数 or env var) を確定
  - 確認結果を Plan の §「物理前提の実機確認結果」に追記
- [ ] **F-4 反映**: `claude -p -w "$(pwd)"` で **workspace 外** (リポジトリルート配下) の skill ファイル (`canonical/skills/adversarial-review/SKILL.md`) を Read tool で読めるか実機確認:
  - 試行: `claude -p "Read /Users/.../canonical/skills/adversarial-review/SKILL.md and output the first line" --model claude-sonnet-4-6 -w "$PROJECT_DIR"`
  - 読めない場合の回避策: (a) `-w` をリポジトリルートに設定 (`-w "$(git rev-parse --show-toplevel)"`)、または (b) skill ファイルを envelope 生成時に PROJECT_DIR 配下にコピー、または (c) skill 内容を envelope の `task.description` に inline 注入
  - 採用案を Plan §「物理前提の実機確認結果」に記録
- [ ] **F-7 反映**: claude API 認証 + sonnet-4-6 アクセス権の **最小通電確認**:
  - 試行: `claude -p "echo ok" --model claude-sonnet-4-6` を 1 回実行 (cost ~$0.0001)
  - 認証エラー / モデルアクセス拒否 / レート制限のいずれかが出れば Plan 進行不可、user 確認後に資格情報整備
  - 確認結果を Plan §「物理前提の実機確認結果」に記録
- [ ] **F-7 反映**: claude を直接呼び出すか `claude-safe` 経由で呼び出すか (TTY 競合可能性) を実機判断:
  - 候補形: `bash projects/claude-safe/claude-safe -p "echo ok" --output-format text`
  - wez pane 環境では TTY 競合は起きにくい想定だが、実機検証で確認
  - 採用 (claude / claude-safe) を Plan §「物理前提の実機確認結果」に記録
- [ ] **F-3 反映**: `composer-2` の Bash + Markdown 実力確認 + 退避基準の機械判定化:
  - 試行: cursor-agent で簡単な依頼を実行 (例: 「`projects/orchestration-engine/lib/test_dummy.sh` を作成して shebang と set -euo pipefail だけ書いて」)
  - **退避判定基準** (F-3 機械判定可):
    - (a) 1 回目で shebang + `set -euo pipefail` が両方含まれる → 採用
    - (b) 1 回目失敗 (片方欠落 or 全くファイルを作成しない) → 1 回リトライ
    - (c) 2 回目も失敗 → **gpt-4.1 への退避を確定**、KickOff §DI-2 の表中 `composer-2` 行を `composer-2 → gpt-4.1 (実機判断、Step 1 で退避)` に更新するコミットを本 Plan 修正と同時に実施
    - (d) `task.description` を **明らかに誤解** (例: 別ファイルを作成、shellcheck エラーを残す) → 同様にリトライ + 失敗で退避
  - 判定者は人間 (本 Step 実施者) が判断、retry log を Plan §「物理前提の実機確認結果」に記録
- [ ] **物理前提が揃わない開発者環境**で本 Plan を進める場合、Phase E スキップ条件を `tests/e2e_real_agent/README.md` に明示 (limited-complete 判定経路)

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

### Step 4: `oe_spawn_send` / `oe_verify_spawn` / `oe_spawn` をディスパッチャ経由に改修

- [ ] `oe_spawn_send` を改修:
  - 旧: `cli_command="${ai_cli} --prompt 'Read ${envelope_path} and execute the task' ; printf '\\n@@OE_EXIT:%d\\n' \$?"`
  - 新: `cli_command="$(_oe_spawn_build_cli_command "$ai_cli" "$ai_model" "$envelope_path") ; printf '\\n@@OE_EXIT:%d\\n' \$?"`
  - 関数シグネチャに `ai_model` 引数を追加 (デフォルト: env var 由来)
- [ ] **F-8 反映**: `oe_spawn` (後方互換 wrapper、`lib/spawn.sh:37`) も同様にシグネチャ変更:
  - 旧: `oe_spawn(session_id, envelope_path, [ai_cli])`
  - 新: `oe_spawn(session_id, envelope_path, [ai_cli], [ai_model])`
  - `oe_spawn` 内で `oe_spawn_send` に ai_model を伝播
  - 既存テストが `oe_spawn` 経由で動作している場合の回帰を防ぐ
- [ ] `oe_verify_spawn` も同様に改修 (ai_model 引数追加 + ディスパッチャ経由)
- [ ] `bin/oe` の `oe_main` で `OE_TARGET_AI_CLI` / `OE_TARGET_AI_MODEL` を読んで `oe_spawn_send` に伝播
- [ ] `oe_verify_run_phase` で `OE_VERIFY_AI_MODEL` を読んで `oe_verify_spawn` に伝播

### Step 5: `bin/oe` に `--task-file <path>` オプションを追加 (F-5)

- [ ] `bin/oe` の `oe_main` を改修し、`--task-file <path>` オプションを受け取れるようにする:
  - 旧: `bin/oe "<task description>"` (`task_description="${*:-Run orchestration task}"` で受け取り、shell expansion で改行 / 特殊文字が破綻するリスク)
  - 新: `bin/oe --task-file <path>` または `bin/oe "<task description>"` のどちらも受け付ける
  - `--task-file <path>` が指定された場合、`task_description="$(cat "$path")"` でファイル内容を読み込む (shell expansion を経由せず安全)
- [ ] `--task-file` で読み込んだ task_description が `oe_envelope_create` の `task.description` に正しく注入されることを確認
- [ ] 後方互換性: 既存 `bin/oe "<text>"` 形式は引き続き動作 (Step 4-3 までの mock テストが回帰しないことを保証)
- [ ] **F-5 設計意図**: Phase C で `bin/oe --task-file tests/e2e_real_agent/task_description_dogfood_cleanup.md` 形式で起動できるようにし、Markdown を shell expansion 経由で渡す設計の破綻を回避

### Step 6: 既存 mock テストに回帰なし確認

- [ ] **F-9 反映**: `OE_VERIFY_AI_CLI` のデフォルトを `cursor` (Step 4-3 hardcode) → `claude` (本 Step Step 3) に変更したため、既存 `tests/test_verify.sh` / `tests/test_e2e_smoke.sh` の assertion が回帰する可能性を確認:
  - mock テスト側に `export OE_VERIFY_AI_CLI=cursor` (or `cursor-agent`) を明示追加し、Step 4-3 時点と同じ環境で assertion を維持する
  - または assertion 側を `${OE_VERIFY_AI_CLI:-claude}` 等で追従させる
  - 方針はどちらかを選択し本 Step 内で実装
- [ ] `tests/test_e2e_smoke.sh` / `tests/test_verify.sh` の wez モック (send.log) で **ディスパッチャ展開後の cli_command** を assertion 可能にする (Step 2 の動作確認に流用、F-15 mock/real 共通 lib 同期と整合)
- [ ] **完了基準**: 全 8 スイート PASS、299 assertions 維持 (回帰なし)

### GATE: Phase A 完了確認

- [ ] Step 1〜6 完了
- [ ] `shellcheck ./bin/oe ./lib/*.sh ./tests/*.sh ./scripts/*.sh` クリーン
- [ ] `for f in ./tests/test_*.sh; do bash "$f" || exit 1; done` 全 PASS (299 assertions)
- [ ] 物理前提 (cursor-agent + claude CLI) が揃った環境で `_oe_spawn_build_cli_command cursor-agent composer-2 /tmp/dummy-envelope.json` を実行し、出力されたコマンドが実 CLI に解釈可能であることを確認 (構文 OK レベルで、実行はしない)
- [ ] **F-15 反映**: `lib/spawn.sh` / `lib/verify.sh` を変更した際に mock テストと実 agent テストの両方をチェックする運用を Phase A GATE のセルフチェック項目に追加:
  - 変更コミット前に `bash tests/test_*.sh` (mock) を実行
  - Phase E 進行可能環境では `bash tests/e2e_real_agent/probe_*.sh` (real) も実行 (任意、Phase B 以降から)
- [ ] user に Phase A 完了報告、Phase B 進行可否の合図を待つ

---

## Phase B: 実 agent spawn 経路の通電確認 (DI-2)

> 最小プロンプト (echo 系) で cursor-agent / claude -p をそれぞれ単独起動し、`@@OE_EXIT` emit までを確認する。target タスク完遂 (Phase C) や検証 E2E (Phase D) に進む前の通電確認。

### Step 7: target (cursor-agent / composer-2) の通電確認スクリプト

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

### Step 8: 検証 (claude -p / claude-sonnet-4-6) の通電確認スクリプト (2 段)

- [ ] `tests/e2e_real_agent/probe_verify.sh` を新規作成
- [ ] **(a) emit プロトコルの最小確認**: claude -p (sonnet-4-6) で「`@@OE_VERIFY:pass` を 1 行で出力して」程度の最小プロンプトを実行
  - 出力ログを `tests/e2e_real_agent/.tmp_probe_verify_emit.log` に保存
  - **完了基準**: ログに `@@OE_VERIFY:pass` を含む
- [ ] **F-12 反映: (b) skill ロード通電確認**: claude -p で `adversarial-review` skill 冒頭を読ませて `@@OE_VERIFY:pass` を返すプロンプトを実行
  - プロンプト例: 「`<skill_path>` の最初の 5 行を読んで `Status:` という単語を含むかチェックし、結果に関わらず `@@OE_VERIFY:pass` を 1 行で出力して」
  - `<skill_path>` は Phase A Step 1 の F-4 で確定した workspace 外アクセス手段に応じて変える (`-w` 範囲内のパス指定 or envelope 経由 inline)
  - 出力ログを `tests/e2e_real_agent/.tmp_probe_verify_skill.log` に保存
  - **完了基準**: ログに `@@OE_VERIFY:pass` を含み、skill 内容を読めたことを示す痕跡 (例: skill の引用 / sonnet 自身の確認応答) が含まれる
- [ ] (b) が失敗した場合: F-4 (Step 1) の skill アクセス回避策を見直し、Plan §「物理前提の実機確認結果」を更新

### GATE: Phase B 完了確認

- [ ] Step 7, 8 完了
- [ ] `probe_target.sh` と `probe_verify.sh` がそれぞれ 0 終了
- [ ] 出力ログに期待するマーカーが含まれる
- [ ] (b) skill ロード通電確認が成功
- [ ] user に Phase B 完了報告

---

## Phase C: target タスク完遂 (DI-1)

> DI-1 で確定した「orchestration-engine 自体の小機能追加」を target (cursor-agent / composer-2) に依頼し、`@@OE_EXIT:0` まで完走させる。

### Step 9: DI-1 具体タスクの最終確定 (F-11 反映で具体化)

- [ ] KickOff §DI-1 の候補 3 つから 1 つを選択 (本 Plan の推奨デフォルト: **`OE_VERIFY_REVIEWER_SESSION_IDS` 追跡** = 派生 [#93](https://github.com/stlwolf/ai-development-hub/issues/93) 前半の取り込み)
- [ ] **F-11 反映: 採用根拠 + 他 2 候補の棄却根拠**:
  - 採用 (`OE_VERIFY_REVIEWER_SESSION_IDS` 追跡): (a) 既存派生 [#93](https://github.com/stlwolf/ai-development-hub/issues/93) の半分を本 Step で消化、(b) 検証 agent が「kill 動作」を test 経由で判定しやすい (要件明確)、(c) Step 4-5 で残り半分 (nonce 付きマーカー) を判断する材料になる、(d) **`lib/cleanup.sh:47-55` に no-op スタブが既に存在**、target はスタブを実装に置き換える形で完遂可能
  - 棄却候補 1 (`OE_VERIFY_AI_CLI` envelope 指定可能化): envelope schema 変更が必要 → Step 4-5 候補 (スコープ越境)
  - 棄却候補 2 (`oe_verify_summary_update` の audit 派生集計): 計算ロジックの正しさ判定が検証 agent には難しい (audit ↔ KVS の同一性確認になる) → Step 4-5 候補
- [ ] envelope の `task.description` を作成 (F-11 反映で具体化 + スコープ制約 + shellcheck 義務):
  - **要件 (具体ファイル位置 + 関数名ピンポイント)**:
    1. `lib/constants.sh` の最後尾 (`OE_VERIFY_PHASE_COMPLETED` 直後) に `OE_VERIFY_REVIEWER_SESSION_IDS=()` を追加
    2. `lib/verify.sh` の `oe_verify_run_phase` 関数内 (for ループ内、`_oe_verify_generate_session_id` 直後) で `OE_VERIFY_REVIEWER_SESSION_IDS+=("$reviewer_session_id")` を実行
    3. `lib/cleanup.sh` の既存スタブ `for reviewer_pane in "${OE_VERIFY_MANAGED_PANES[@]}"; do : "$reviewer_pane" ; done` (line 47-55) を、`OE_VERIFY_REVIEWER_SESSION_IDS` をループして `/tmp/oe-{rsid}-verify-envelope.json` と `/tmp/oe-{rsid}-verify-inputs.md` を `rm -f` する実装に置き換え
  - **完了条件 (target が完了報告に含めること)**:
    - `shellcheck ./lib/constants.sh ./lib/verify.sh ./lib/cleanup.sh` の stdout 全文 (or "no warnings") を完了報告に含めること
    - 既存 mock テスト全 8 スイート 299 assertions が PASS することを `bash tests/test_*.sh` 実行ログで示すこと
    - `tests/test_cleanup.sh` に新規 assertion を追加し、`OE_VERIFY_REVIEWER_SESSION_IDS` に 2 つのダミー ULID を append → `oe_cleanup` 実行 → 該当 `/tmp/oe-{rsid}-verify-*` が削除されることを確認 (mock fs 不要、実 /tmp で touch + rm 確認)
  - **スコープ制約**:
    - `OE_VERIFY_MARKER_RE` (`lib/constants.sh:12`) **変更禁止** (派生 [#93](https://github.com/stlwolf/ai-development-hub/issues/93) 後半 nonce マーカーは MVP 後拡張)
    - `oe_verify_run_phase` の polling 構造 (二値保持判定、CB タイムアウト) **変更禁止**
    - `bin/oe` への変更禁止 (本 Step Phase A で別途修正済み)
    - 他のファイル (`schemas/`, `bin/`, `tests/e2e_real_agent/`) **変更禁止**
  - **失敗時の退避** (F-11 + F-3 連携):
    - target が完遂できなかった (shellcheck エラー / mock テスト回帰 / スコープ越境) 場合、本 Step を 1 回リトライ
    - 2 回目も失敗した場合、別候補 (`oe_verify_summary_update` の audit 派生集計) に切り替えるか、本 Step を skip して Phase D 以降を mock task で代用するかを user に確認
- [ ] `task.description` をテストファイル `tests/e2e_real_agent/task_description_dogfood_cleanup.md` に保存 (再現性のため)

### Step 10: target 起動 + タスク完遂確認

- [ ] `tests/e2e_real_agent/smoke_cursor_composer_claude_sonnet.sh` を新規作成 (Phase C / D 共通の E2E スクリプト):
  - 環境変数 `OE_TARGET_AI_CLI=cursor-agent`, `OE_TARGET_AI_MODEL=composer-2`, `OE_VERIFY_AI_CLI=claude`, `OE_VERIFY_AI_MODEL=claude-sonnet-4-6` を明示セット
  - **F-5 連携**: `bin/oe --task-file tests/e2e_real_agent/task_description_dogfood_cleanup.md` で起動 (旧 `bin/oe "$(cat ...)"` 形式から変更、Markdown shell expansion 破綻を回避)
  - target session_id をログに記録
- [ ] **本 Step (Phase C) の完了基準**: target が `@@OE_EXIT:0` を emit、`state/{session_id}.state.json` に `state: success` が記録される
- [ ] 完了基準を満たすか `tests/e2e_real_agent/check_phase_c.sh` で確認 (補助スクリプト):
  - `state.session_id` と `state.state == "success"` を `jq` で検査
  - audit log に `state_change` (state=success) と `session_end` が記録されているか確認
  - target の完了報告に shellcheck stdout + mock テスト PASS ログが含まれているか確認 (F-11 義務化)
- [ ] Phase D に進む前に target の変更内容 (実際の constants.sh / verify.sh / cleanup.sh 編集差分) を `git diff` で確認

### GATE: Phase C 完了確認

- [ ] Step 9, 10 完了
- [ ] target がタスクを完遂、`state: success` が KVS に記録
- [ ] target が実装した変更内容 (Step 9 で指定した OE_VERIFY_REVIEWER_SESSION_IDS 追跡) が機能している (`git diff` で確認 + 完了報告の shellcheck + mock テスト PASS ログを確認)
- [ ] 人間が `shellcheck` と `bash tests/test_*.sh` を再走して回帰なしを確認 (target の自己報告だけに依存しない)
- [ ] user に Phase C 完了報告 + 変更差分を提示

---

## Phase D: 検証フェーズ E2E + 構造的判定 (DI-2 + DI-7)

> Phase C 完走後、engine が `oe_verify_run_phase` を呼んで claude -p (claude-sonnet-4-6) を起動する。検証 agent が adversarial-review skill の Compliance Review を実行し `@@OE_VERIFY:{result}` を emit、engine が二値検出 + write_kvs + verification_completed audit emit を行う。構造的判定の 4 点を assertion。

### Step 11: 検証 agent の動作観察

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

### Step 12: 構造的判定 4 点の assertion (`check_cycle_complete.sh`、F-6 + F-10 で具体化)

- [ ] `tests/e2e_real_agent/check_cycle_complete.sh` を新規作成
- [ ] 引数: `target_session_id` (Phase C 起動時のログから渡す)
- [ ] **F-6 反映: 構造的判定 4 点を `jq` クエリレベルまで具体化**:

  **(1) target の `@@OE_EXIT:0` 検出 — F-2 反映で代理指標化**:
  ```bash
  # target marker raw は capture.sh で保存しないため、session_end.state を代理指標として使う
  EXIT_OK=$(jq -s -r --arg sid "$TARGET_SESSION_ID" \
    'map(select(.event_type == "session_end")) | last | .state' \
    "audit/${TARGET_SESSION_ID}.jsonl")
  [[ "$EXIT_OK" == "success" ]] || fail "target session_end.state expected success, got: $EXIT_OK"
  ```

  **(1) reviewer の `@@OE_VERIFY:{pass|fail|warn}` 検出**:
  ```bash
  # reviewer marker raw は KVS の verification[].marker_raw で直接確認可能
  VERIFY_RAW=$(jq -r --arg pid "$TARGET_PANE_ID" \
    '.verification[$pid].marker_raw' \
    "state/${TARGET_SESSION_ID}.state.json")
  [[ "$VERIFY_RAW" =~ ^@@OE_VERIFY:(pass|fail|warn)$ ]] || fail "reviewer marker_raw expected @@OE_VERIFY:(pass|fail|warn), got: $VERIFY_RAW"
  ```

  **(2) KVS validation**:
  ```bash
  bash scripts/validate-session-state.sh "state/${TARGET_SESSION_ID}.state.json" || fail "KVS validator failed"
  jq -e --arg pid "$TARGET_PANE_ID" \
    '.state == "success" and (.verification[$pid].result // null) != null' \
    "state/${TARGET_SESSION_ID}.state.json" >/dev/null || fail "KVS state/verification missing"
  ```

  **(3) audit event_type ホワイトリスト + 件数**:
  ```bash
  # 必須イベント (各 1 件以上)
  REQUIRED_EVENTS=(session_start state_change session_end verification_started verification_completed cleanup)
  for ev in "${REQUIRED_EVENTS[@]}"; do
    COUNT=$(jq -s --arg ev "$ev" 'map(select(.event_type == $ev)) | length' \
      "audit/${TARGET_SESSION_ID}.jsonl")
    [[ "$COUNT" -ge 1 ]] || fail "audit event_type $ev missing"
  done
  # optional イベント (verification_protocol_error は 0 件以上、circuit_breaker_triggered は 0 件であることを期待)
  CB_COUNT=$(jq -s 'map(select(.event_type == "circuit_breaker_triggered")) | length' \
    "audit/${TARGET_SESSION_ID}.jsonl")
  [[ "$CB_COUNT" -eq 0 ]] || fail "circuit_breaker_triggered emitted ($CB_COUNT 件) — 本サイクルは完走失敗とみなし、Plan iter1 経路で再実行 (Phase E Step 14)"
  ```

  **(4) `wez notify` 呼び出し — F-10 反映で wez ラッパー shim 方式**:
  ```bash
  # 実 wez は notify を OS 通知に流して捕捉不能。tests/e2e_real_agent/bin/wez_notify_shim を PATH 先頭に置き、
  # `wez notify` 呼び出しを ${OE_MOCK_LOG_DIR}/notify.log に記録する shim を経由させる。
  # shim は実 wez を `exec /usr/local/bin/wez "$@"` で呼び出すが、notify サブコマンドだけ別記録する。
  # smoke_*.sh で PATH=tests/e2e_real_agent/bin:$PATH を export して起動する想定。
  NOTIFY_LOG="${OE_MOCK_LOG_DIR}/notify.log"
  [[ -f "$NOTIFY_LOG" ]] || fail "wez notify capture log not found: $NOTIFY_LOG"
  grep -qE 'pass=[0-9]+, fail=[0-9]+, warn=[0-9]+, fail_rate=[0-9.]+, protocol_errors=[0-9]+, timeouts=[0-9]+' "$NOTIFY_LOG" \
    || fail "wez notify body format mismatch"
  ```
- [ ] `verify_result` の値 (pass/fail/warn) は assertion 対象外、Episode 記録用に出力に含める

### GATE: Phase D 完了確認

- [ ] Step 11, 12 完了
- [ ] `check_cycle_complete.sh` の 4 点 assertion が全 PASS
- [ ] `verify_result` の値 (pass/fail/warn) を Episode 記録用に保存
- [ ] `circuit_breaker_triggered` が emit されていないこと (CB 走行は完走失敗扱い、F-6 反映)
- [ ] user に Phase D 完了報告 + 検証結果の観察を提示

---

## Phase E: tests/e2e_real_agent/ 整備 + Episode 記録 (DI-5 + DI-6 + DI-8)

> Phase A〜D で作成したスクリプト群を `tests/e2e_real_agent/` 配下に整理し、README で環境前提 + 実行手順を明示。実 agent で 1 サイクル完走を実証 + Episode に観察記録を残す。

### Step 13: `tests/e2e_real_agent/` 構成整備

- [ ] ディレクトリ構成:
  ```
  tests/e2e_real_agent/
  ├── README.md                                    # 環境前提 + 実行手順 + Phase E スキップ条件
  ├── .gitignore                                   # .tmp_* パターン (M2 反映)
  ├── bin/                                         # F-10 wez ラッパー shim 配置
  │   └── wez                                      # wez notify を notify.log に記録 + 他は実 wez に exec
  ├── probe_target.sh                              # Phase B Step 7 で作成
  ├── probe_verify.sh                              # Phase B Step 8 で作成 (skill ロード通電含む)
  ├── smoke_cursor_composer_claude_sonnet.sh       # Phase C Step 10 で作成
  ├── task_description_dogfood_cleanup.md          # Phase C Step 9 で保存
  ├── check_phase_c.sh                             # Phase C Step 10 補助
  └── check_cycle_complete.sh                      # Phase D Step 12 で作成
  ```
- [ ] **M2 反映**: `tests/e2e_real_agent/.gitignore` を新規作成し `.tmp_*` パターンを追加 (probe ログや smoke ログを `.tmp_*` で命名する規約)
- [ ] **F-10 反映**: `tests/e2e_real_agent/bin/wez` shim を作成:
  ```bash
  #!/usr/bin/env bash
  if [[ "${1:-}" == "notify" ]]; then
    printf '%s|%s\n' "${2:-}" "${3:-}" >> "${OE_MOCK_LOG_DIR:?}/notify.log"
    exit 0
  fi
  exec /opt/homebrew/bin/wez "$@"  # 実 wez パスは Phase A Step 1 で確認した実機環境に従う
  ```
  smoke スクリプトで `export PATH="tests/e2e_real_agent/bin:$PATH"` を実行することで shim を経由
- [ ] `README.md` の内容:
  - 環境前提: cursor-agent + claude CLI 両方 + 認証
  - 実行手順: `OE_TARGET_AI_CLI=... OE_MOCK_LOG_DIR=tmp/log bash tests/e2e_real_agent/smoke_cursor_composer_claude_sonnet.sh`
  - Phase E スキップ条件: 物理前提が揃わない開発者環境では本 README の手順を skip 可 (limited-complete 判定経路)
  - **F-14 反映: 期待コスト**: `claude-sonnet-4-6` のみ ~$0.045/サイクル。**`cursor-agent` (composer-2) はサブスク内 (Pro/Business) のため token / cost は CLI から取得不可、Episode には N/A 明記**
  - 想定実行頻度: MVP では 1 回完走を実証すれば十分、Step 4-5 以降で定期実行を検討
- [ ] shellcheck クリーン (e2e_real_agent/ 配下の全 .sh が対象、shim 含む)

### Step 14: 1 回の完走実証

- [ ] 開発者環境で `bash tests/e2e_real_agent/smoke_cursor_composer_claude_sonnet.sh` を実行
- [ ] 完走 (Phase A〜D の Step 10〜12 を全通過) を確認
- [ ] 出力ログを保存 (`tests/e2e_real_agent/.tmp_smoke_<timestamp>.log`)
- [ ] 完走しなかった場合は Plan に F-* 修正項目を追記して再実行 (Plan iter1)
- [ ] **F-13 反映**: Phase E iter1 (本 Step) で発生した F-* は本 Plan 内に随時反映する。**so-compare iter2 (実装段階レビュー) は Phase E 完了後に 1 回実行する想定** (F-SO-* として別途反映)。Phase E iter1 と so-compare iter2 は **時系列で連続させない** (iter1 で実 agent 観察 → Plan / 実装 修正 → 安定後に iter2 で全体レビュー)

### Step 15: Episode 起草

- [ ] `docs/episodes/<YYYY-MM-DD>-episode-step-4-4-implementation.md` を新規作成
- [ ] Step 4-3 Episode のフォーマット (元実装 / so-compare 結果 / 修正後 の 3 セクション分離) を踏襲
- [ ] Episode に記録する内容:
  - **(A) 元実装フェーズ**: Phase A〜E の commit 履歴 + 各 Phase の設計判断 + DI-1〜DI-8 の反映証跡
  - **(B) so-compare iter1 (Plan 段階)**: 本 Plan で F-1〜F-16 を反映済み、概要を Episode に転記
  - **(C) so-compare iter2 (実装段階)**: 実装後の so-compare で発見された指摘 + F-SO-* 分類
  - **(D) F-SO 修正反映**: so-compare iter2 の対応
  - **(E) 実 agent 動作観察**: 完走実証ログ + cost 観察 + verify_result の傾向
    - **F-14 反映: cost 計測の注意**: claude 側は session metadata の token 数から算出 (`(input_tokens * $3/M) + (output_tokens * $15/M)` で算出)、**cursor 側は「サブスク内ゆえ正確値取得不可」と明記**
    - reproducibility: 同じタスクを 2-3 回回した時の verify_result のばらつき (pass/fail/warn) を観察記録
  - **教訓 / 学び**: mock vs 実 agent の挙動差、composer-2 vs gpt-4.1 退避案の判断結果、Step 4-3 教訓 (F-SO-* 系) の活用度、3 者 (skill / engine / 実 agent) 責務境界の実機観察

### Step 16: ADR 起草

- [ ] `docs/decisions/<YYYY-MM-DD>-decision-e2e-verification.md` を新規作成
- [ ] Step 4-3 ADR (`2026-05-16-decision-verification-gate-design.md`) のフォーマットを踏襲
- [ ] 蒸留対象:
  - **コンテキスト**: Step 4-3 mock 段階の限界 + 実 agent E2E の必要性
  - **検討した代替案**: Q1〜Q8 の各案
  - **決定**: DI-1〜DI-8 の確定形
  - **根拠**: 設計判断の主軸 (engine の対外境界の検証 / cross-CLI 独立性 / 半自動の妥当性 / 構造的判定の必然性)
  - **結果 / トレードオフ**: 得たもの / トレードオフ / 観測したリスク (Episode と相互参照)

### GATE: Phase E 完了確認

- [ ] Step 13, 14, 15, 16 完了
- [ ] `tests/e2e_real_agent/` が整備済み、README に従って再現可能
- [ ] 完走実証ログが保存されている
- [ ] Episode + ADR が起草済み、相互参照リンク張り済み
- [ ] user に Phase E 完了報告

---

## ADR / Episode 記録 (Phase E Step 15, 16 と重複だが kickoff-to-plan SKILL の TODO として独立配置)

- [ ] **Episode** (Phase E Step 15): `docs/episodes/<YYYY-MM-DD>-episode-step-4-4-implementation.md`
- [ ] **ADR** (Phase E Step 16): `docs/decisions/<YYYY-MM-DD>-decision-e2e-verification.md`

## STOP: Step 4-4 実装完了 — user 報告 + PR 作成判断

- [ ] Phase A〜E 全 GATE クリア + Episode / ADR 記録完了を user に報告
- [ ] user の判断: PR 作成に進む / 追加レビュー (so-compare iter2) を挟む

---

## 最終検証 (KickOff §完了条件 8 項目に対応)

KickOff §完了条件のチェックボックス 8 項目を、Phase 実装後の最終検証 TODO として展開する。

**F-1 反映**: (7)(8) は **`full-complete` (物理前提が揃った環境で実 agent 完走)** / **`limited-complete` (物理前提が揃わない環境で Phase A〜D mock 完走まで)** の 2 段階判定とする:

- **full-complete**: 完了条件 (1)〜(8) すべて満たす (Phase E 含む)。本 Step を **完全に完了**として Step 4-5 に引き継ぐ
- **limited-complete**: 完了条件 (1)〜(6) を満たし、(7)(8) は「`tests/e2e_real_agent/` スクリプトと Episode テンプレートが整備済み、実完走実証は環境制約で未実施」と Episode に明記。本 Step を **環境制約付き完了**として Step 4-5 に引き継ぐ (full-complete への昇格を Step 4-5 着手者が物理前提を整えてから実施可)

- [ ] **(1)** `@@OE_EXIT:0` (target) と `@@OE_VERIFY:{pass|fail|warn}` (reviewer) が両方 emit される
  - **F-2 反映**: target marker raw は `capture.sh` で保存しないため、**代理指標 `session_end.state == "success"` を audit log から確認** する
  - 検証方法: `check_cycle_complete.sh` 内で audit log の最後の `session_end.state` を確認 (Phase D Step 12 (1))。reviewer の `@@OE_VERIFY` は KVS の `verification[$pid].marker_raw` で直接確認
- [ ] **(2)** `state/{session_id}.state.json` に `state: success` と `verification[].result` が記録される
  - 検証方法: `check_cycle_complete.sh` 内で `validate-session-state.sh` を呼ぶ + `jq` 構造判定 (Phase D Step 12 (2))
- [ ] **(3)** `audit/{session_id}.jsonl` に主要 6 イベント (`session_start`, `state_change`, `session_end`, `verification_started`, `verification_completed`, `cleanup`) が記録される
  - **F-6 反映**: `verification_protocol_error` は optional (0 件以上)、`circuit_breaker_triggered` は **0 件** であることを期待 (1 件以上で本サイクルは完走失敗扱い、Phase E Step 14 で再実行)
  - 検証方法: `check_cycle_complete.sh` 内で `jq -s --arg ev "<event>" 'map(select(.event_type == $ev)) | length'` で各イベントを確認 (Phase D Step 12 (3))
- [ ] **(4)** `wez notify` が呼ばれ、本文に `pass={} fail={} warn={} fail_rate={} protocol_errors={} timeouts={}` が展開される
  - **F-10 反映**: 実 wez は OS 通知に流して捕捉不能のため、`tests/e2e_real_agent/bin/wez` shim を PATH 先頭に置いて notify サブコマンドだけログ記録する設計を採用 (Phase E Step 13)
  - 検証方法: `check_cycle_complete.sh` 内で `${OE_MOCK_LOG_DIR}/notify.log` の正規表現マッチを確認 (Phase D Step 12 (4))
- [ ] **(5)** shellcheck クリーン + 既存 299 mock assertions 回帰なし
  - 検証方法: `shellcheck` 全対象 + `bash tests/test_*.sh` (Phase A GATE Step 6)
- [ ] **(6)** [#91](https://github.com/stlwolf/ai-development-hub/issues/91) の CLI ディスパッチャが少なくとも 2 CLI (`cursor-agent` + `claude -p`) で動作
  - 検証方法: `_oe_spawn_build_cli_command` 動作確認 (Phase A Step 2) + 通電確認スクリプト (Phase B Step 7, 8) + E2E 完走 (Phase D)
- [ ] **(7-full)** 実 agent E2E スクリプトが `tests/e2e_real_agent/` に存在し、cursor-agent + claude CLI 環境で **1 回完走実証**済み
  - 検証方法: Phase E Step 13 (整備) + Step 14 (実証) + 完走ログ保存
- [ ] **(7-limited)** 実 agent E2E スクリプトが `tests/e2e_real_agent/` に存在し、**README + check_cycle_complete.sh の仕様が整備済み**、実完走実証は環境制約で未実施
  - 検証方法: Phase E Step 13 (整備) + README に limited-complete スキップ条件記載
- [ ] **(8-full)** Step 4-5 (architecture-sketch 更新) のフィードバック材料として、実 agent E2E の **完走 Episode** が記録される
  - 検証方法: Episode に observed cost (claude 側、cursor 側は N/A) + verify_result の傾向 + reproducibility 観察 + 教訓を記録 (Phase E Step 15)
- [ ] **(8-limited)** 実 agent E2E は未実施だが、Plan + integration design が整備済みであることが Episode に記録される (Step 4-5 着手者が full-complete に昇格させる経路を明示)
  - 検証方法: Episode に環境制約 + 未完了項目 + full-complete 昇格手順を記録 (Phase E Step 15)

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

## 進め方 (F-13 反映で so-compare iter1 / iter2 の関係を明示)

1. ✅ Discussion (status: closed、QDD Q1〜Q8 合意)
2. ✅ KickOff (status: confirmed、DI-1〜DI-8 確定)
3. ✅ Plan 起草 (本ドキュメント、status: draft)
4. ✅ **so-compare iter1 (Plan 段階)** 実行 → F-1〜F-16 反映 (本コミット)
5. → docs PR 作成 + マージ (Discussion + KickOff + Plan)
6. → 実装 PR で Phase A〜E を順次実装
7. → Phase E iter1 で完走実証、未完走時は本 Plan に F-* 追記 + 再実装 (so-compare iter2 を待たない、Plan に随時反映)
8. → Phase E iter1 安定後、**so-compare iter2 (実装段階レビュー)** を Phase A〜E 全実装に対して 1 回実行 → F-SO-* 反映
9. → 実装 PR マージ後、Episode + ADR の完成版を確認、Step 4-4 完了報告

iter1 と iter2 の **時系列分離**: Phase E iter1 (実 agent 観察) → Plan / 実装 修正 → 安定後に iter2 (全体レビュー)。両者を時系列で連続させない (Step 4-3 と同じ運用)。

## Plan iter1 修正履歴 (so-compare 2026-05-17)

`tmp/so-20260517-003036/` の so-compare iter1 結果から本 Plan に反映した修正項目 16 件。

### Critical (6 件、必須修正)

| ID | 内容 | 反映先 |
|----|------|--------|
| **F-1** | Phase E スキップ可と完了条件の両立 → `full-complete` / `limited-complete` 2 段階判定 | §最終検証 §全体 + 完了条件 (7)(8) 分割 |
| **F-2** | target marker raw 直接検証不可 → `session_end.state == "success"` 代理指標 | §最終検証 (1) + Phase D Step 12 (1) |
| **F-3** | composer-2 退避条件の定量化 (1 回試行 + 1 リトライ + 失敗で gpt-4.1 退避) + KickOff §DI-2 更新方針 | Phase A Step 1 |
| **F-4** | `claude -p -w` workspace 外 skill アクセス可否を Phase A Step 1 で実機確認 + 回避策 (a)(b)(c) 提示 | Phase A Step 1 |
| **F-5** | `bin/oe --task-file <path>` オプション追加 (Markdown shell expansion 破綻対策) | Phase A 新 Step 5 + Phase C Step 10 |
| **F-6** | `check_cycle_complete.sh` の `jq` クエリを Plan で具体化、event_type ホワイトリスト + `circuit_breaker_triggered` の扱い明記 | Phase D Step 12 + §最終検証 (3) |

### Strong (9 件、Concern 修正)

| ID | 内容 | 反映先 |
|----|------|--------|
| F-7 | 物理前提実機確認に API key / claude-safe / sonnet-4-6 アクセス権の最小通電確認追加 | Phase A Step 1 |
| F-8 | `oe_spawn` wrapper も ai_model 引数伝播 | Phase A Step 4 |
| F-9 | `OE_VERIFY_AI_CLI` デフォルト変更による既存 assertion 影響 → mock test 側で明示 export | Phase A Step 6 |
| F-10 | wez notify capture: wez ラッパー shim 方式で PATH 先頭配置 | Phase D Step 12 (4) + Phase E Step 13 |
| F-11 | DI-1 `task.description` の具体化 (既存スタブ置換明示、関数名/位置ピンポイント、スコープ制約、shellcheck 報告義務、退避経路) | Phase C Step 9 |
| F-12 | Phase B Step 8 に skill ロード通電確認 (2 個目のプロンプト) を追加 | Phase B Step 8 |
| F-13 | Phase E iter1 と so-compare iter2 の関係明示 | §進め方 + Phase E Step 14 |
| F-14 | cost 計測の現実性 (cursor 側は N/A 明記) | Phase E Step 13, 15 |
| F-15 | mock/real 共通 lib 同期 Gate 条件追加 | Phase A GATE |

### Minor (1 件、本 Plan 内に取り込み)

| ID | 内容 | 反映先 |
|----|------|--------|
| M2 | `tests/e2e_real_agent/.gitignore` で `.tmp_*` パターン追加 | Phase E Step 13 |

### M1 (PR 作成時対応) / M3 (派生 Issue 候補) は本 Plan に取り込まず、別途処理

- M1: `Closes #91` を PR description に追記 (本 PR 作成時対応)
- M3: capture --lines 200 の env 可変化 → 派生 Issue 候補 (本 Plan スコープ外、Step 4-5 で判断)

### F-16: 完全性チェック表で STOP / ADR を「拡張ルール」と注記

下記「完全性チェック」表の脚注 (※印) として明記。

## 完全性チェック

`kickoff-to-plan` SKILL の Step 4 に従い、KickOff からの変換完全性を確認する。

### 必須 (全合格)

| 突合項目 | KickOff | Plan | 結果 |
|---------|---------|------|------|
| 完了条件チェックボックス数 → 最終検証 TODO 数 | 8 件 | 8 件 (F-1 で (7)(8) を full/limited 2 段階表現に変更、件数は維持) | ✅ |
| DI 数 → 実装 Step 配置数 (DI 対応分) | 8 件 | 8 件 (DI-1=Phase C Step 9、DI-2=Phase A+B+D、DI-3=Phase A、DI-4=Phase A Step 3-5、DI-5=Phase E Step 13, 14、DI-6=Phase A Step 6 + Phase E、DI-7=Phase D Step 12、DI-8=最終検証) | ✅ |
| STOP 指示数 → STOP TODO 数 | 0 (KickOff 明示なし) | 1 (Phase E 完了後)※ | ✅※ (拡張ルール、F-16 反映) |
| 全ての GATE が独立 TODO 項目 (Step 子 TODO に埋没していない) | — | 5 件全て独立 (Phase A/B/C/D/E 各末尾) | ✅ |
| 「〜等」「〜など」で省略された項目がない | — | 0 件 | ✅ |

※ **F-16 反映: STOP 0→1 は拡張ルール** — KickOff §進め方には STOP 明示なし。Plan §「変換上の判断メモ §4」で「ユーザー指定により Phase E 完了後に補強」と明記済み。`kickoff-to-plan` SKILL §「STOP は最重要 gate」の趣旨 (Mode 切替の停止指示) に沿った拡張であり、必須突合ルールには違反するが、SKILL 解釈として許容範囲。同じく Phase E Step 16 の ADR も KickOff には明示なし (KickOff §完了条件 (8) は Episode のみ言及)、Plan §「変換上の判断メモ」で拡張ルールとして説明。

### 推奨

| 突合項目 | KickOff | Plan | 結果 |
|---------|---------|------|------|
| 着手前タスク項目数 → Plan 内反映数 | 6 件 (housekeeping + 物理前提) | 6 件 (Plan §Context + Phase A Step 1) | ✅ |
| スコープ外項目数 → スコープ外記載数 | 6 件 (KickOff §スコープ外) | 6 件 Context §スコープ外 | ✅ |
| 概算時間が Step 名に含まれている | — | KickOff 原文に概算時間なし、Plan も含めず | ✅ (KickOff 準拠) |
| Phase 数 → Step 配置 | 5 Phase | Phase A: 6 Step (Step 1-6、F-5 新 Step 5 追加) / Phase B: 2 (7-8) / Phase C: 2 (9-10) / Phase D: 2 (11-12) / Phase E: 4 (13-16)、合計 16 Step | ✅ (F-5 で新 Step 追加、後続 renumber) |

### 内容の検証

| 突合項目 | 結果 |
|---------|------|
| KickOff の表現がそのまま使われている | ✅ DI-1〜DI-8 の名称・決定内容、`@@OE_VERIFY:`、`OE_TARGET_AI_CLI` 等の用語を原文保持 |
| コード例・コマンド例 | ✅ Phase A Step 2 の CLI ディスパッチャ署名、Phase A Step 4 の旧/新 cli_command 形式、Phase D Step 12 の jq クエリ、Phase E Step 13 のディレクトリ構成 + wez shim を Plan 内で具体化 |
| frontmatter の related 参照が Context または Phase に含まれている | ✅ 全 9 件が「設計入力」「駆動層入力」「観測層 Issue」「スコープ外」に分配 |
| 引き継ぎの「解決済み」が Context に含まれている | ✅ Step 4-3 PR #94 完了、Discussion 全 Q closed を Context に明記 |

## 物理前提の実機確認結果 (Phase A Step 1 で追記する)

> Phase A Step 1 実施時に、本セクションを追記する。Plan が変更されるため commit が必要。
>
> 確認項目 (F-3, F-4, F-7 反映):
> - `cursor-agent` 実 invocation 仕様 (バイナリ名 / 引数形式): (TBD)
> - `claude -p` 実 invocation 仕様 + `--model claude-sonnet-4-6` 指定方法: (TBD)
> - **F-4**: `claude -p -w "$(pwd)"` で workspace 外の `canonical/skills/...` skill ファイルを Read tool で読めるか、回避策 (a)/(b)/(c) のどれを採用するか: (TBD)
> - **F-7**: claude API 認証 + claude-sonnet-4-6 アクセス権 (最小通電確認 `claude -p "echo ok" --model claude-sonnet-4-6`): (TBD、PASS/FAIL を記録)
> - **F-7**: claude vs claude-safe のどちらを採用するか (TTY 競合確認結果): (TBD)
> - **F-3**: `composer-2` の Bash + Markdown 実力確認 (1 回試行 + 1 リトライ + 失敗で gpt-4.1 退避):
>   - 1 回目: (TBD、PASS/FAIL 詳細)
>   - 2 回目 (1 回目 FAIL 時): (TBD)
>   - 採用モデル: (composer-2 / gpt-4.1)
>   - 退避時の KickOff §DI-2 更新: (実施 / 不要)
