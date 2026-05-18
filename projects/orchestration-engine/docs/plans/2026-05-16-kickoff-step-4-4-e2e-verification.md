---
id: "01KRRKYVDH94KZK1HABKYXCTKH"
title: "orchestration-engine Step 4-4 E2E 検証 (実 agent で 1 サイクル完走) KickOff"
date: 2026-05-16
type: kickoff
status: confirmed
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/19"
    reason: "Epic #19 Phase 4 MVP 実装の Step 4-4（観測層・親 Epic）"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/95"
    reason: "Step 4-4 観測層 Issue (本 KickOff の主スコープ)"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/91"
    reason: "Step 4-4 着手前必須 → 本 Step Phase A に組み込み (DI-3)"
  - type: source_material
    ref: "projects/orchestration-engine/docs/discussions/2026-05-16-discussion-step-4-4-e2e-verification.md"
    reason: "Step 4-4 Discussion (QDD 全 8 Q closed、本 KickOff の確定根拠)"
  - type: source_material
    ref: "projects/orchestration-engine/docs/episodes/2026-05-16-episode-step-4-3-implementation.md"
    reason: "Step 4-3 Episode (実装 + 2 段階 so-compare の経緯、本 Step の入力)"
  - type: source_material
    ref: "projects/orchestration-engine/docs/decisions/2026-05-16-decision-verification-gate-design.md"
    reason: "Step 4-3 ADR (検証ゲート v1 アーキテクチャ、本 Step の基盤)"
  - type: source_material
    ref: "https://github.com/stlwolf/ai-development-hub/pull/94"
    reason: "Step 4-3 全成果物 PR (マージ済み、本 Step の基盤)"
  - type: source_material
    ref: "projects/orchestration-engine/docs/discussions/2026-05-13-discussion-engine-scope-and-goals.md"
    reason: "Step 4-0 Discussion (MVP スコープ・3 UC・arena 反映済み、全体スコープの正本)"
  - type: design_context
    ref: "canonical/skills/adversarial-review/SKILL.md"
    reason: "Compliance Review プロンプト規約 (検証 agent 動作の基盤)"
  - type: design_context
    ref: "projects/orchestration-engine/README.md"
    reason: "プロジェクト概要・観測層/駆動層分離・Step 一覧"
tags: [orchestration, mvp, step-4-4, kickoff, e2e-verification, real-agent, dogfood, cli-dispatcher]
---

# Step 4-4: E2E 検証 (実 agent で 1 サイクル完走) — KickOff

> 本 KickOff は Step 4-3 完了 ([PR #94](https://github.com/stlwolf/ai-development-hub/pull/94) マージ済み) を前提に、Step 4-4「E2E 検証 (実 agent で 1 サイクル完走)」のスコープ・確定 DI・着手前タスクを定義する。Discussion ([2026-05-16-discussion-step-4-4-e2e-verification.md](../discussions/2026-05-16-discussion-step-4-4-e2e-verification.md)) で全 8 Q closed の合意に基づき確定 (status: confirmed)。

## 背景

- [Epic #19](https://github.com/stlwolf/ai-development-hub/issues/19) Phase 4 MVP 実装の Step 4-4
- Step 4-3 で `bin/oe` + `lib/*.sh` 8 ファイル + 検証ゲート v1 (mock 経由 299 assertions PASS) が動作する状態
- 本 Step の主題: **実 agent (cursor-agent + claude -p) で 1 サイクル完走することの実証**
- Step 4-3 の so-compare 2 段階レビューで「mock では動くが実 agent では動かない」失敗モードが複数指摘されており、その解消が本 Step の核心

## ツール間引き継ぎコンテキスト

Step 4-0〜4-3 (主要な mock 段階) は Cursor Agent + Claude Code で実施。本 Step 以降は **実 agent (cursor-agent + claude -p) を実機で起動する**ため、CLI 認証 / API key / レート制限が物理前提になる。本 KickOff を読むエージェントは以下の物理前提を確認する必要がある。

### 物理前提 (実環境で必要なもの)

| CLI | 認証 | コスト |
|------|------|--------|
| `cursor-agent` | Cursor Pro/Business サブスク + login | サブスク内、composer-2 利用 |
| `claude -p` (or `claude-safe -p`) | `ANTHROPIC_API_KEY` 環境変数 or `claude login` | claude-sonnet-4-6 = ~$0.045/サイクル |

これらが揃わない環境では Phase A (Section 「実装範囲」参照) の途中まで実装は可能だが、E2E 完走 (Phase E) は不可。

### 読むべきドキュメント (優先順)

1. `README.md` — 目的、3 層モデル、観測層/駆動層分離、Step 一覧
2. Step 4-3 ADR: [`docs/decisions/2026-05-16-decision-verification-gate-design.md`](../decisions/2026-05-16-decision-verification-gate-design.md) — 検証ゲート v1 アーキテクチャの確定形 (本 Step の基盤)
3. Step 4-3 Episode: [`docs/episodes/2026-05-16-episode-step-4-3-implementation.md`](../episodes/2026-05-16-episode-step-4-3-implementation.md) — 実装の経緯 + so-compare 結果 + 派生課題
4. Step 4-4 Discussion: [`docs/discussions/2026-05-16-discussion-step-4-4-e2e-verification.md`](../discussions/2026-05-16-discussion-step-4-4-e2e-verification.md) — 本 KickOff の確定根拠
5. ADR 4 件: `docs/decisions/` (Step 4-1 由来 3 件 + Step 4-3 由来 1 件) — 既存の設計判断

### 現在の実装状態 (Step 4-3 完了時点)

```
projects/orchestration-engine/
├── bin/oe                    # エントリポイント
├── lib/
│   ├── constants.sh          # OE_VERIFY_MARKER_RE / OE_VERIFY_MANAGED_PANES 等
│   ├── envelope.sh           # oe_envelope_create
│   ├── spawn.sh              # oe_spawn_prepare_pane / oe_spawn_send (← #91 の修正対象)
│   ├── capture.sh            # 二値保持 (F3 反映)
│   ├── monitor.sh            # oe_monitor_loop + CB
│   ├── audit.sh              # 7+3 イベント emit
│   ├── verify.sh             # 検証ゲート v1 全機能
│   └── cleanup.sh            # 両ペイン kill + wez notify
├── schemas/                  # 5 ファイル (verification + summary 拡張済み)
├── scripts/                  # validate-envelope.sh + validate-session-state.sh
├── tests/                    # mock E2E 含む 8 スイート 299 assertions
├── audit/.gitkeep
└── state/.gitkeep
```

### テスト実行方法

```bash
cd projects/orchestration-engine
shellcheck ./bin/oe ./lib/*.sh ./tests/*.sh ./scripts/*.sh
for f in ./tests/test_*.sh; do echo "---- $f ----"; bash "$f" || exit 1; done
```

### 暗黙知 (ドキュメント外、Step 4-3 由来)

- Bash 3.2 互換 (macOS デフォルト、`declare -A` 連想配列不可)
- `wez pane split --wait-ready --timeout` (OE_SPAWN_WAIT_READY_SEC=10s)
- マーカー: `@@OE_EXIT:{code}` (Step 4-2 確定) + `@@OE_VERIFY:{pass|fail|warn}` (Step 4-3 確定)
- `oe_generate_session_id` / `_oe_verify_generate_session_id`: 14 桁数字 + 12 桁 Crockford base32 (SIGPIPE 対策で `head -c 4096 /dev/urandom | tr -dc ... | ${raw:0:12}` パターン)
- `OE_VERIFY_AI_CLI` env var (Step 4-3 F-SO-6) — 本 Step で `OE_VERIFY_AI_MODEL` + `OE_TARGET_AI_CLI` + `OE_TARGET_AI_MODEL` を追加

## 着手前タスク (チェックリスト)

Step 4-4 の Plan に入る前に、前 Step の陳腐化を解消し物理前提を確認する。

- [ ] `README.md` の状態テーブルを更新 (Step 4-3 を「完了」に、Step 4-4 を「着手準備中」に)
- [ ] Issue [#89](https://github.com/stlwolf/ai-development-hub/issues/89) (Step 4-3) が CLOSED 済みであることを確認 (PR #94 マージ後、housekeeping コメントで close 済み)
- [ ] Epic [#19](https://github.com/stlwolf/ai-development-hub/issues/19) の checkbox `4-3` が `[x]` になっていることを確認
- [ ] `shellcheck ./bin/oe ./lib/*.sh ./tests/*.sh ./scripts/*.sh` がクリーン
- [ ] `for f in ./tests/test_*.sh; do bash "$f" || exit 1; done` が全 PASS (299 assertions)
- [ ] 物理前提の確認: `cursor-agent --version` (or `cursor --version`) と `claude --version` が両方実行可能であることを開発者環境で確認
  - **NOTE**: 物理前提が揃わない開発者環境では Phase A 完了までは進められるが、Phase E (E2E 完走) は実施不可

## スコープ (確定 — [Discussion](../discussions/2026-05-16-discussion-step-4-4-e2e-verification.md) 全 8 Q closed)

### Step 4-4 の主題

**E2E 検証 (実 agent で 1 サイクル完走)**: 検証ゲート v1 ([PR #94](https://github.com/stlwolf/ai-development-hub/pull/94) で mock 経由 299 assertions PASS) を **実 agent (cursor-agent / composer-2 target + claude -p / claude-sonnet-4-6 検証)** で 1 サイクル動かし、engine の対外境界 (実 CLI 接続性) を構造的に検証する。

### 確定 DI (8 項目 — Discussion Q1〜Q8 から変換)

- **DI-1: 1 サイクル完走の対象タスク** = orchestration-engine 自体の小機能追加 (dogfood、Step 4-5 input に直結)。具体タスクは Plan で 1 つに絞る (候補: `OE_VERIFY_REVIEWER_SESSION_IDS` 追跡 / `OE_VERIFY_AI_CLI` envelope 指定可能化 / `oe_verify_summary_update` の audit 派生集計)
- **DI-2: CLI + モデル選択** =
  - target: `cursor-agent` + `composer-2` (Cursor 自社モデル、サブスク内コスト)
  - 検証: `claude -p` + `claude-sonnet-4-6` (Compliance Review の推論力 + Opus の 1/5 コスト ~$0.045/サイクル)
  - **`auto` ではなく明示指定**: 検証としての再現性 + 結果の比較可能性
- **DI-3: [#91](https://github.com/stlwolf/ai-development-hub/issues/91) 組み込み** = 本 Step Plan の **Phase A** として組み込み (本 Step の **実装 PR** で `Closes #91` を含めて同時マージ、本 docs PR は #91 を closed しない)。`lib/spawn.sh` に CLI ディスパッチャ `_oe_spawn_build_cli_command` を追加し、cursor-agent / claude -p / codex -p (スタブ) の 3 種に対応
- **DI-4: target / 検証 CLI 関係** = 別 CLI + 別モデル固定 + env var 化。新規 env var:
  - `OE_TARGET_AI_CLI` (デフォルト `cursor-agent`)
  - `OE_TARGET_AI_MODEL` (デフォルト `composer-2`)
  - `OE_VERIFY_AI_MODEL` (デフォルト `claude-sonnet-4-6`)
  - 既存 `OE_VERIFY_AI_CLI` (Step 4-3 F-SO-6、デフォルトは Step 4-4 で `claude` に変更)
- **DI-5: 自動化境界** = 半自動 (`tests/e2e_real_agent/` ディレクトリに分離、開発者が手元で実行 + 人間承認)。完全 CI 自動化は Step 4-5 以降
- **DI-6: mock テスト併存** = 別ディレクトリで併存 (CI=mock / 開発者=real)。既存 `tests/test_*.sh` 299 assertions は維持
- **DI-7: non-determinism 対処** = 構造的判定 (マーカー emit / KVS / audit / notify の 4 点を「成功」と定義)。`verify_result` の値 (pass/fail/warn) は assertion 対象外、Episode に観察記録
- **DI-8: 完了条件** = 後述 §「完了条件」の 8 項目 (Q8 全項)

### スコープ外

Discussion §「派生課題」と整合:

- envelope schema への `task.ai_cli` / `task.ai_model` フィールド追加 (Step 4-5 候補)
- 完全 CI 自動化 (Step 4-5 以降)
- 統計判定 (Q7 案 C、必要性が見えてから)
- 3 CLI 全対応 (現状 `codex -p` は CLI ディスパッチャにスタブとして残すが動作確認は cursor + claude のみ)
- 検証 agent 自体の品質評価 (Step 4-5 候補)
- 派生 Issue [#92](https://github.com/stlwolf/ai-development-hub/issues/92) (per-pane 変更ファイル検出 / 完了報告充実) の本格実装 — 必要性が運用で確認された場合のみ Step 4-5 で取り込み
- 派生 Issue [#93](https://github.com/stlwolf/ai-development-hub/issues/93): **前半** (reviewer 一時ファイル掃除 = `OE_VERIFY_REVIEWER_SESSION_IDS` 追跡) は **Phase C の DI-1 target task** として本 Step に取り込み済み (Plan Phase C Step 9 / 推奨デフォルト)。**後半** (nonce 付きマーカー偽陽性対策) は MVP 後拡張

## 完了条件 (確定 — Discussion §Q8 から転記)

- [ ] **(1)** `@@OE_EXIT:0` (target) と `@@OE_VERIFY:{pass|fail|warn}` (reviewer) が両方 emit される
  - 検証方法: audit log + KVS から確認
- [ ] **(2)** `state/{session_id}.state.json` に `state: success` と `verification[].result` が記録される
  - 検証方法: `validate-session-state.sh` で validation
- [ ] **(3)** `audit/{session_id}.jsonl` に必須 6 イベント (`session_start`, `state_change`, `session_end`, `verification_started`, `verification_completed`, `cleanup`) が記録される + optional `verification_protocol_error` は protocol 違反時のみ emit (正常完了時は 0 件)
  - 検証方法: `jq` でイベント件数確認 (必須 6 は 1 件以上、`circuit_breaker_triggered` は 0 件、`verification_protocol_error` は 0 件以上)
- [ ] **(4)** `wez notify` が呼ばれ、本文に `pass={} fail={} warn={} fail_rate={} protocol_errors={} timeouts={}` が展開される
  - 検証方法: notify log 確認
- [ ] **(5)** shellcheck クリーン + 既存 299 mock assertions 回帰なし
  - 検証方法: `shellcheck ./bin/oe ./lib/*.sh ./tests/*.sh ./scripts/*.sh` + `bash tests/test_*.sh` 各個
- [ ] **(6)** [#91](https://github.com/stlwolf/ai-development-hub/issues/91) の CLI ディスパッチャが少なくとも 2 CLI (`cursor-agent` + `claude -p`) で動作
  - 検証方法: `_oe_spawn_build_cli_command` 動作確認 + 既存 mock テスト通過
- [ ] **(7)** 実 agent E2E スクリプトが `tests/e2e_real_agent/` に存在し、再現可能 (cursor-agent + claude CLI 環境で 1 回完走実証)
  - 検証方法: `bash tests/e2e_real_agent/smoke_*.sh` で完走 + 結果ログを Episode に記録
- [ ] **(8)** Step 4-5 (architecture-sketch 更新) のフィードバック材料として、実 agent E2E の Episode が記録される
  - 検証方法: `docs/episodes/<date>-episode-step-4-4-implementation.md` に実 agent 動作観察 + コスト記録 (target / 検証それぞれ何 token / $ コストか)

## 想定 Plan 構成 (Step 4-3 と同じ 5 Phase 体系)

`kickoff-to-plan` SKILL で変換時に以下を Phase 構造として展開予定 (Plan で確定):

- **Phase A: [#91](https://github.com/stlwolf/ai-development-hub/issues/91) (CLI ディスパッチャ) + env var 拡張 (DI-3 + DI-4)**
  - `lib/spawn.sh` に `_oe_spawn_build_cli_command` を追加 (cursor-agent / claude -p / codex -p の 3 種、codex はスタブ)
  - `bin/oe` の `oe_main` で `OE_TARGET_AI_CLI` / `OE_TARGET_AI_MODEL` env var を読む
  - `OE_VERIFY_AI_MODEL` env var を新設 (既存 `OE_VERIFY_AI_CLI` と並行)
  - `oe_spawn_send` / `oe_verify_spawn` がディスパッチャ経由で送信するように改修
  - 既存 mock テスト 299 assertions に回帰なし
  - **Phase A 冒頭で物理前提の実機確認**: `cursor-agent` の正しい invocation 仕様、`claude -p ... --model claude-sonnet-4-6` の指定方法、composer-2 の Bash + Markdown 実力 (簡単な Bash 関数追加で動作確認、不安定なら gpt-4.1 退避案を Plan に明示)
- **Phase B: 実 agent spawn 経路の通電確認 (DI-2)**
  - 既存 mock テストを `OE_TARGET_AI_CLI=cursor-agent` / `OE_VERIFY_AI_CLI=claude` 環境下でも通るよう、必要なら mock を拡張
  - 単純 echo 系の最小プロンプトで cursor-agent / claude -p をそれぞれ単独起動し、`@@OE_EXIT` emit までを確認
- **Phase C: target 側のタスク実行確認 (DI-1)**
  - DI-1 で確定したタスク (Plan で 1 つに絞る) を `bin/oe --task-file <path>` で起動 (Plan Phase A Step 5 で `--task-file` オプションを実装、Markdown を shell expansion 経由で渡す破綻を回避)
  - cursor-agent が envelope を読んでタスクを完遂、`@@OE_EXIT:0` を emit するまでを確認
  - KVS に `state: success` が書かれることを確認
- **Phase D: 検証フェーズ E2E (DI-2 + DI-7)**
  - Phase C 完走後、`oe_verify_run_phase` 経由で claude -p が起動
  - `adversarial-review` SKILL の Compliance Review を実行、`@@OE_VERIFY:{result}` を emit
  - engine が二値検出 + write_kvs + verification_completed audit emit
  - 構造的判定 (Q7) の 4 点を assertion
- **Phase E: tests/e2e_real_agent/ 整備 + Episode 記録 (DI-5 + DI-6 + DI-8)**
  - `tests/e2e_real_agent/smoke_cursor_composer_claude_sonnet.sh` を作成
  - `tests/e2e_real_agent/check_cycle_complete.sh` を作成 (構造的判定の 4 点を assertion、validate-session-state.sh も呼ぶ)
  - `tests/e2e_real_agent/README.md` で環境前提 + 実行手順を明示
  - 実 agent で 1 サイクル完走を実証 (再現可能性確認)
  - Episode に observed cost + non-deterministic 観察 (verify_result の傾向) を記録

各 Phase 末尾に GATE を配置、Phase E 完了後に STOP を配置 (Step 4-3 と同じパターン)。

## 進め方

1. ✅ **着手前タスク**を完了する (上記チェックリスト、各項目を確認)
2. ✅ Step 4-4 の **Discussion** を `docs/discussions/` に作成 ([2026-05-16-discussion-step-4-4-e2e-verification.md](../discussions/2026-05-16-discussion-step-4-4-e2e-verification.md)、QDD 全 8 Q closed)
3. ✅ ユーザーに Discussion の内容を確認してもらう (1 問ずつの対話で合意)
4. ✅ 合意後、本 KickOff の「仮置き」セクションを確定版に更新 (本コミット、status: confirmed)
5. → `kickoff-to-plan` SKILL で Plan に変換 (次タスク)
6. → Plan 段階で **so-compare iter1** を実行 → 反映 → docs PR
7. → 実装 PR で Phase A〜E + **so-compare iter2** + Episode + ADR (Step 4-5 input に直結)

## リポジトリ規約 (CLAUDE.md / AGENTS.md より)

- Bash 3.2+ 互換、`set -euo pipefail`
- `shellcheck` を必ず通す
- Conventional Commits: `feat:`, `fix:`, `docs:`, `chore:`
- 箇条書きは `-` のみ (`*` `•` 禁止)
- ファイルパスはインラインコードで囲む
- 1 コミット 1 論理変更
- 蒸留パイプライン: Discussion → KickOff → Plan → Episode → Decision/ADR
