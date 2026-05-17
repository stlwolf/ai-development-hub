---
id: "01KRR7BP14TWDWQFVSBYYB4K5V"
title: "Step 4-4 E2E 検証 (実 agent で 1 サイクル完走) の設計判断（質問駆動設計）"
date: 2026-05-16
type: discussion
status: closed
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/19"
    reason: "Epic #19 Phase 4 MVP 実装の Step 4-4 設計判断"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/95"
    reason: "Step 4-4 観測層 Issue（本 Discussion の親）"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/91"
    reason: "Step 4-4 着手前必須: AI CLI 起動オプションを実 CLI 仕様に修正"
  - type: source_material
    ref: "projects/orchestration-engine/docs/discussions/2026-05-15-discussion-step-4-3-verification-gate.md"
    reason: "Step 4-3 Discussion（QDD 7 Q closed、検証ゲート v1 の設計判断正本）"
  - type: source_material
    ref: "projects/orchestration-engine/docs/episodes/2026-05-16-episode-step-4-3-implementation.md"
    reason: "Step 4-3 実装エピソード（so-compare 2 段階レビューの結果、mock 限界の認識）"
  - type: source_material
    ref: "projects/orchestration-engine/docs/decisions/2026-05-16-decision-verification-gate-design.md"
    reason: "Step 4-3 ADR（検証ゲート v1 アーキテクチャの確定形）"
  - type: source_material
    ref: "https://github.com/stlwolf/ai-development-hub/pull/94"
    reason: "Step 4-3 全成果物 PR（マージ済み、本 Step の基盤）"
  - type: design_context
    ref: "projects/orchestration-engine/docs/discussions/2026-05-13-discussion-engine-scope-and-goals.md"
    reason: "Step 4-0 Discussion（MVP スコープ・UC・3 主要ユースケースの正本）"
  - type: design_context
    ref: "canonical/skills/adversarial-review/SKILL.md"
    reason: "Compliance Review プロンプト規約 (検証 agent 動作の基盤)"
tags: [orchestration, mvp, step-4-4, question-driven-design, e2e-verification, real-agent, dogfood]
---

# Step 4-4 E2E 検証 (実 agent で 1 サイクル完走) の設計判断（質問駆動設計）

> Step 4-3 ([PR #94](https://github.com/stlwolf/ai-development-hub/pull/94) マージ済み) で検証ゲート v1 が **wez mock 経由で 293 assertions PASS** の状態 (Step 4-3 Episode 記録準拠)。本 Step は **実 agent で 1 サイクル完走** することを目的とする。
>
> 本 Discussion は **draft 状態で起草**し、各 Q について **推奨案を提示**した上で user との 1 問ずつの対話で確定する。全 Q 合意後に status: closed にし、KickOff の仮置きセクションを確定版に反映する。

## 進め方の前提

- `question-driven-design` スキル適用。実装前に設計ツリーを質問で網羅的に掘り下げ、暗黙の前提を明示化する
- Step 4-3 KickOff §「想定 DI」の枠組みに沿って 8 問を扱う (Step 4-3 は 7 問だった)
- 合意結果は後続の KickOff (起草予定) で DI に変換、`kickoff-to-plan` で Plan 化、実装は Step 4-3 と同じ Phase 構成を踏襲する

## Step 4-3 までの入力 (本 Step の基盤)

### orchestration-engine 側 (Step 4-3 完了時点)

- `bin/oe` + `lib/*.sh` 8 ファイル — エンベロープ生成、ペイン spawn、ポーリング監視、6 値分類、KVS、監査ログ、クリーンアップ、検証ゲート v1
- `schemas/` 5 ファイル — envelope / failure-taxonomy / exit-code-mapping / audit-log / session-state (verification + verification_summary 拡張済み)
- `lib/verify.sh` — `oe_verify_run_phase` 独立ループ (F1 / F2)、二値保持 (`OE_SCAN_EXIT_CODE` + `OE_SCAN_VERIFY_RESULT`、F3)、pane-keyed map (F5)、`use_skills: [adversarial-review]` 疎結合 (F4)
- `@@OE_EXIT:{code}` + `@@OE_VERIFY:{pass|fail|warn}` の 2 マーカー仕様
- `wez notify` 完了通知 (DI-6)、`cleanup.sh` で通常 + 検証両ペイン kill

### 既知の課題 (派生 Issue として記録済み)

- [#91](https://github.com/stlwolf/ai-development-hub/issues/91) **本 Step 必須**: `${ai_cli} --prompt` が実 CLI (`claude -p` / `codex -p`) と不整合
- [#92](https://github.com/stlwolf/ai-development-hub/issues/92) Step 4-5 候補: 変更ファイル検出 per-pane 化 / 完了報告内容の充実
- [#93](https://github.com/stlwolf/ai-development-hub/issues/93): **前半** (reviewer 一時ファイル掃除 = `OE_VERIFY_REVIEWER_SESSION_IDS` 追跡) は **Phase C で dogfood task として取り込み** (KickOff §DI-1 / Plan Phase C Step 9 で確定)。**後半** (nonce 付きマーカー偽陽性対策) は MVP 後拡張

### Step 4-3 so-compare レビューで認識された設計上の限界

so-compare (Codex + Claude 並列) で「mock では動くが実 agent では動かない」失敗モードが複数指摘された:

- AI CLI 起動オプションの実 CLI 整合 ([#91](https://github.com/stlwolf/ai-development-hub/issues/91))
- skill 出力 → `@@OE_VERIFY` マッピングが検証 agent に届く保証の弱さ (F-SO-1 で task.description に明示済みだが、実 agent での確実性は未検証)
- 検証ペイン capture の `--lines 200` で verbose な review 出力が枠外に流れる可能性
- 検証 agent への完了報告が貧弱 ([#92](https://github.com/stlwolf/ai-development-hub/issues/92) で対応予定)

本 Step は **実 agent で 1 サイクル動かすことで、これらの mock 限界を実証的に確認 + 修正** することが目的。

## 設計質問と推奨案

各 Q の `status` は個別に管理 (open / closed)、全 Q closed で本 Discussion 全体を closed にする。

### Q1: 1 サイクル完走の対象タスク (UC-1 の具体化)

**status**: closed

**質問**: 「ツール改善タスクで 1 サイクル完走」の具体タスクは何にするか?

| 案 | 内容 | トレードオフ |
|----|------|-------------|
| A. ai-development-hub 内の小タスク (例: 既存 skill の小修正) | リポジトリ内完結、検証容易 | スコープが曖昧、検証 agent が「正しい修正」を判断しにくい |
| **B. orchestration-engine 自体の小機能追加 (例: F-SO-9 由来の小拡張)** | dogfood として整合、Step 4-5 の input にも繋がる | 自己参照、orchestration が orchestration を改修する複雑性 |
| C. wez CLI Phase 3 (`wez agent`) の一部設計支援 | Phase 3 ([#20](https://github.com/stlwolf/ai-development-hub/issues/20)) と合流、現実的価値高 | スコープ外の Phase 3 設計判断が混入 |
| D. 既存 ideas/ から 1 つ pick して projects/ への昇格作業 | 明確に「ツール改善」、独立性高 | ideas/ の凍結原則と矛盾しない選定が必要 |

**決定**: **B. orchestration-engine 自体の小機能追加**

**根拠**:
- 検証 agent が「正しい変更か」を判断するには、target task の要件 (envelope の task.description) が明確である必要がある。orchestration-engine の既存仕様 (schemas / KickOff / Episode) は明確に書かれているため、判断基準が揃いやすい
- dogfood の正統性: orchestration が orchestration の改修を駆動できれば、MVP の有効性が最も強く実証される
- Step 4-5 (architecture-sketch 更新) のフィードバックインプットとして直接活きる
- 具体タスク候補例 (Plan で確定):
  - `OE_VERIFY_AI_CLI` のデフォルト値を `cursor` 以外に変更可能にする小拡張
  - `cleanup.sh` の `OE_VERIFY_REVIEWER_SESSION_IDS` 追跡 (派生 #93 の前半)
  - `oe_verify_summary_update` の集計を audit JSONL からも導出できる関数追加

**未解決の細部**: 具体タスクは KickOff / Plan で 1 つに絞る。本 Discussion ではスコープの方向性のみ確定。

---

### Q2: 使用する実 CLI とモデルの選択

**status**: closed

**質問**: target agent / 検証 agent でどの実 CLI とモデルを使うか?

#### CLI レベルの選択

| 案 | 内容 | トレードオフ |
|----|------|-------------|
| A. `cursor` のみ | 既存 envelope の default、参考実装が claude-safe / arena-compare 等で蓄積 | 単一 CLI なのでクロスチェック性なし |
| B. `claude -p` のみ | Compliance Review が claude 本体規約に最も近い | claude のみで完走、cursor / codex 動作未検証 |
| C. `codex -p` のみ | Codex がレビュー観点で精度高 (so-compare 経験) | claude / cursor 未検証 |
| **D. 1 サイクル目: `cursor` (target) + `claude -p` (検証) のクロス** | 異なる CLI で動作確認、検証 agent の独立性も担保 | 2 CLI 必要、起動オプション両対応必要 |
| E. 3 CLI 全部対応 | 完全網羅 | スコープ膨張、MVP 過剰 |

**CLI 決定**: **D. cursor (target) + claude -p (検証) のクロス**

#### モデルレベルの選択

deterministic な実行を担保するため `auto` ではなく **明示指定** を要件とした (検証としての再現性 + 結果の比較可能性確保)。

**Target (cursor) モデル選択**:

| 候補 | コスト感 | 独立性 (claude-sonnet-4-6 との関係) | 適性 |
|------|--------|------------------------------|------|
| **composer-2 (Cursor 自社最新)** | Pro/Business サブスク内、最安系 | ◎ model 系列完全独立 | coding 特化、orchestration-engine 小機能追加に適合 |
| claude-sonnet-4-6 (Cursor 経由) | サブスク内 | × 同モデル、共通バイアス | 高品質だがクロス独立性なし |
| gpt-5 / gpt-4.1 | Cursor plan 依存 | ◎ OpenAI 系で独立 | 安定、独立性は composer-2 と同等 |

**Target モデル決定**: **composer-2** (Cursor 自社最新、サブスク内コスト、model 系列完全独立)

**検証 (claude -p) モデル選択**:

| 候補 | コスト感 (1 サイクル) | 適性 (Compliance Review) |
|------|------------------|------------------------|
| claude-haiku-4-5-20251001 | ~$0.01 | 推論やや弱、ニュアンス検出に不安 |
| **claude-sonnet-4-6** | ~$0.045 | バランス◎、パターン認識 + 構造判定に十分 |
| claude-opus-4-7 | ~$0.20 | Compliance Review に過剰 |

**検証モデル決定**: **claude-sonnet-4-6** (Sonnet 4.6 で十分、Opus は過剰、Haiku は判定品質に不安)

#### 確定構成

| 役割 | CLI | モデル | コスト |
|------|------|--------|--------|
| target agent | `cursor-agent` | `composer-2` (Cursor 自社) | Pro/Business サブスク内 |
| 検証 agent | `claude -p` | `claude-sonnet-4-6` | ~$0.045/サイクル |

#### 根拠

- target / 検証で異なる CLI かつ異なる model 系列を使うことで、検証 agent の独立性が CLI + model の二重レベルで担保される (adversarial review の本質)
- `composer-2` は Cursor 自社最新、サブスク内コスト + deterministic な指定が可能。`claude-sonnet-4-6` は Compliance Review のパターン認識 + 構造判定に十分な推論力 + Opus の 1/5 のコスト
- 半自動 (Q5) で実行回数は限定的 (5-10 回想定) → 合計コスト $0.5 以下
- 3 CLI / 多モデル対応は Step 4-5 以降で必要性が見えれば追加

#### 未解決の細部 (KickOff で確定)

- `cursor-agent` の実際の invocation 仕様 ([#91](https://github.com/stlwolf/ai-development-hub/issues/91) Phase A 冒頭で実機確認)
- composer-2 の Bash + Markdown 実力 (Plan の Phase A 冒頭で「簡単な Bash 関数追加」で動作確認、不安定なら gpt-4.1 への退避案を Plan に明示)
- claude-sonnet-4-6 を CLI 引数で指定する方法 (`claude -p ... --model claude-sonnet-4-6 ...` 等、Plan で確定)

---

### Q3: [#91](https://github.com/stlwolf/ai-development-hub/issues/91) (AI CLI 起動オプション修正) の組み込み方

**status**: closed

**質問**: [#91](https://github.com/stlwolf/ai-development-hub/issues/91) の修正を本 Step とどう連動させるか?

| 案 | 内容 | トレードオフ |
|----|------|-------------|
| A. 別 PR で先に潰し、本 Step は #91 完了後に着手 | 関心分離が明確 | 2 PR、Step 4-4 着手が遅れる |
| **B. 本 Step Plan の Phase A として組み込み (本 Step PR で同時マージ)** | 1 つの一貫した Step、レビューも一括 | スコープ膨張気味だが必然性あり |
| C. 本 Step の Discussion 段階で並行起動 (#91 を別ブランチで対応中に Discussion を進める) | 並行作業で時間効率↑ | コンフリクト管理が複雑 |

**決定**: **B. 本 Step Plan の Phase A として組み込み**

**根拠**:
- [#91](https://github.com/stlwolf/ai-development-hub/issues/91) は Step 4-3 派生だが、本 Step (E2E 実 agent) では **必須の前提**。独立した PR にすると Step 4-4 が着手不可
- Step 4-3 と同じ Phase 構成 (A=前提整備、B〜E=本実装) を踏襲しやすい
- Discussion / KickOff / Plan に [#91](https://github.com/stlwolf/ai-development-hub/issues/91) の対応範囲を明示することで scope creep ではなく必然的拡張と認識できる
- 本 PR (docs) → [#91](https://github.com/stlwolf/ai-development-hub/issues/91) 対応 + 実装 PR の 2 段構成は Step 4-3 と同じパターン

---

### Q4: 検証 agent と target agent の CLI / モデル関係

**status**: closed

**質問**: 検証 agent と target agent で同一 CLI / モデルを使うか、別 CLI / 別モデルを使うか?

Q2 で「cross (cursor-agent/composer-2 target + claude -p/sonnet-4-6 検証)」を確定したため、本 Q はその固定方針の確認。

| 案 | 内容 | トレードオフ |
|----|------|-------------|
| **A. 別 CLI + 別モデル固定** (Q2 確定構成) | 独立性最大、adversarial review の本質 | 同一モデルでの再現性検証はできない |
| B. 同一 CLI / 同一モデル | 単純、CLI 1 種で済む | 検証 agent の独立性が CLI / モデルレベルで担保されない |
| C. envelope で指定可能 (target / 検証両方を env var 化) | 柔軟、運用で選択可 | テストパターン爆発 |

**決定**: **A. 別 CLI + 別モデル固定 + env var 化 (target / 検証両方)**

**具体的な実装方針** (Plan で確定):
- `bin/oe` の `oe_main` で `OE_TARGET_AI_CLI` / `OE_TARGET_AI_MODEL` env var を読む (デフォルト = `cursor-agent` / `composer-2`)
- `oe_spawn_send` の引数に ai_cli + ai_model を追加して `_oe_spawn_build_cli_command` に伝播
- `OE_VERIFY_AI_CLI` (既実装) と並行で `OE_VERIFY_AI_MODEL` env var を追加 (デフォルト = `claude` / `claude-sonnet-4-6`)
- envelope schema への `task.ai_cli` / `task.ai_model` フィールド追加は Step 4-5 候補

---

### Q5: 実 agent E2E の自動化境界

**status**: closed

**質問**: 実 agent E2E をどこまで自動化するか?

| 案 | 内容 | トレードオフ |
|----|------|-------------|
| A. 完全手動 (人間が `bin/oe "task description"` を実行して結果確認) | 単純、E2E の意義に忠実 | CI に乗らない、回帰検出が遅れる |
| **B. 半自動 (実 agent を起動するスモークテストを `tests/` 配下に追加、人間が結果を承認)** | 起動の再現性 + 人間判断の両立 | CLI key / 認証 / レート制限の管理が必要 |
| C. 完全 CI 自動 (GitHub Actions 等で実 CLI を呼ぶ) | 完全回帰検出 | API key の secret 管理、レート制限、コスト |

**決定**: **B. 半自動 (スモークテストスクリプト + 人間承認)**

**具体的な実装方針** (Plan で確定):
- `tests/e2e_real_agent/` ディレクトリ新設 (mock テスト `tests/test_*.sh` と完全分離)
- 起動スクリプト: 環境変数 (`OE_TARGET_AI_CLI` / `OE_TARGET_AI_MODEL` 等) を明示セット → `bin/oe` 呼び出し → 結果ファイルパス出力
- 完走条件チェッカー (`tests/e2e_real_agent/check_cycle_complete.sh`): audit / KVS / notify ログから Q8 の判定項目を確認
- 環境前提を README で明示: `cursor-agent` (Pro/Business サブスク) + `claude` CLI (API key) の両方が必要
- 完全 CI 自動は Step 4-5 以降で必要性が確認された場合に追加

---

### Q6: mock テストとの併存

**status**: closed

**質問**: 既存 wez mock E2E (`tests/test_e2e_smoke.sh` の 40 assertions、Step 4-3 Episode 記録準拠) と実 agent E2E をどう併存させるか?

| 案 | 内容 | トレードオフ |
|----|------|-------------|
| **A. mock テストは現状維持、実 agent E2E は別ディレクトリ/別命名 (`tests/e2e_real_agent/`)** | 関心分離、CI ではモック側を回す | 2 系統のテスト保守 |
| B. mock テストを「real CLI モード」で再利用可能に拡張 (env var で切替) | テスト 1 セット、保守単純化 | mock と real の挙動差を吸収するロジックが複雑化 |
| C. mock テストは廃止、実 agent E2E のみ | 単純化 | CI で実 CLI 呼べない場合に回帰検出が完全に止まる |

**決定**: **A. 別ディレクトリで併存**

**具体的な実装方針** (Plan で確定):
- `tests/test_*.sh` → 既存 mock テスト、CI 対象 (回帰検出)
- `tests/e2e_real_agent/*.sh` → 実 agent E2E、開発者が手元で実行 (Q5 半自動)
- `tests/e2e_real_agent/README.md` で環境前提 (cursor-agent + claude CLI 両方) + 実行手順を明示
- shellcheck は両方対象に含める

---

### Q7: 実 agent の non-determinism への対処

**status**: closed

**質問**: 実 agent は同じプロンプトに対して異なる応答を返す。E2E の合否判定をどうするか?

| 案 | 内容 | トレードオフ |
|----|------|-------------|
| A. 厳格判定 (出力が完全一致しないと FAIL) | 単純 | 実用上ほぼ常に FAIL、E2E が機能しない |
| **B. 構造的判定 (マーカー emit、KVS 書き込み、verification entry 生成、notify 呼び出しの 4 点を「成功」と定義)** | 実 agent の応答内容に依存しない、engine の動作のみを検証 | 「verify result が pass か fail か」は判定対象外 (cycle 完走自体は成功) |
| C. 統計判定 (3 回連続実行、majority decision) | 信頼性高 | コスト 3 倍、レート制限リスク |

**決定**: **B. 構造的判定**

**具体的な実装方針** (Plan で確定):
- `tests/e2e_real_agent/check_cycle_complete.sh` で以下を assertion (Q8 の判定項目と整合):
  - `@@OE_EXIT:0` (target) と `@@OE_VERIFY:{pass|fail|warn}` (reviewer) が両方 emit
  - `state/{session_id}.state.json` に `state: success` + `verification[].result` 記録
  - `audit/{session_id}.jsonl` に主要 7 イベント記録
  - `wez notify` が呼ばれ、本文に summary 展開
- `verify_result` の値 (pass/fail/warn) は assertion 対象外、Episode に観察記録として残す
- 統計判定は Step 4-5 以降で必要性が見えれば追加

---

### Q8: 完了条件 (1 サイクル完走の判定基準)

**status**: closed

**質問**: 何をもって「1 サイクル完走」と判定するか?

Q7 の「構造的判定」を採用するなら、判定項目は engine 出力の 4 点に絞られる。それを完了条件として明文化する。

| # | 完了条件 | 検証方法 |
|---|---------|---------|
| (1) | `@@OE_EXIT:0` (target) と `@@OE_VERIFY:{pass\|fail\|warn}` (reviewer) が両方 emit される | audit log + KVS から確認 |
| (2) | `state/{session_id}.state.json` に `state: success` と `verification[].result` が記録 | `validate-session-state.sh` で validation |
| (3) | `audit/{session_id}.jsonl` に必須 6 イベント (`session_start`, `state_change`, `session_end`, `verification_started`, `verification_completed`, `cleanup`) が記録 + optional `verification_protocol_error` は protocol 違反時のみ emit (正常完了時は 0 件) | `jq` でイベント件数確認 |
| (4) | `wez notify` が呼ばれ、本文に `pass={} fail={} warn={} fail_rate={} protocol_errors={} timeouts={}` が展開される | notify log 確認 |
| (5) | shellcheck クリーン + 既存 299 mock assertions 回帰なし | `shellcheck` + `bash tests/test_*.sh` |
| (6) | [#91](https://github.com/stlwolf/ai-development-hub/issues/91) の CLI ディスパッチャが少なくとも 2 CLI (`cursor-agent` + `claude -p`) で動作 | `_oe_spawn_build_cli_command` 動作確認 + 既存 mock テスト通過 |
| (7) | 実 agent E2E スクリプトが `tests/e2e_real_agent/` に存在し、再現可能 (cursor-agent + claude CLI 環境で 1 回完走実証) | `bash tests/e2e_real_agent/smoke_*.sh` で完走 + 結果ログを Episode に記録 |
| (8) | Step 4-5 (architecture-sketch 更新) のフィードバック材料として、実 agent E2E の Episode が記録される | `docs/episodes/<date>-episode-step-4-4-implementation.md` に実 agent 動作観察 + コスト記録 |

**決定**: 上記 (1)〜(8) **すべて** を完了条件とする (KickOff §「完了条件」に転記)。

**根拠**:
- (1)〜(4) は engine の動作実証 (Q7 構造的判定の実体)
- (5) は回帰防止
- (6) は [#91](https://github.com/stlwolf/ai-development-hub/issues/91) 取り込み (Q3)
- (7) は Q5 半自動の実体
- (8) は Step 4-5 への引き継ぎ準備

---

## 完了条件 (確定)

Q8 の (1)〜(8) を完了条件として KickOff §「完了条件」に転記する。

## 未解決の論点 (本 Discussion で扱わない / Plan で詰める)

- **Q1 の具体タスク選定**: Q1 で方向性 (orchestration-engine 自体の小機能追加) のみ確定、具体は KickOff / Plan で 1 つに絞る (候補例: `OE_VERIFY_REVIEWER_SESSION_IDS` 追跡、`OE_VERIFY_AI_CLI` envelope 指定可能化、`oe_verify_summary_update` の audit 派生集計)
- **`cursor-agent` の実 invocation 仕様**: Plan Phase A 冒頭で実機確認 obligation 化
- **composer-2 の Bash + Markdown 実力**: Plan Phase A 冒頭で「簡単な Bash 関数追加」で動作確認、不安定なら gpt-4.1 への退避案を Plan に明示
- **`claude -p ... --model claude-sonnet-4-6` の明示指定方法**: Plan Phase A で確定

## 派生課題 (本 Step スコープ外、後段で判断)

- envelope schema への `task.ai_cli` / `task.ai_model` フィールド追加 (Step 4-5 候補)
- 検証 agent 自体の品質評価 (検証結果が「正しいか」の判定、本 Step スコープ外)
- 3 CLI 全対応 (Step 4-5 以降の判断、現状 `codex` は CLI ディスパッチャにスタブとして残す)
- 完全 CI 自動化 (Step 4-5 以降)
- 統計判定 (Q7 案 C、必要性が見えてから)

## 進め方 (履歴)

1. ✅ user が Q1 から順にレビュー、推奨案 or 別案で判断 (Q1〜Q8 全て closed)
2. ✅ 合意 Q ごとに `status: closed` + 決定内容を追記
3. ✅ 本 Discussion 全体を `status: closed` に
4. → KickOff の「仮置き」セクションを Discussion 結果で確定 (次タスク、起草予定)
5. → `kickoff-to-plan` skill で Plan に変換 (Step 4-3 と同じ 5 Phase 構成、確定版は KickOff / Plan 参照): **A**=[#91](https://github.com/stlwolf/ai-development-hub/issues/91) 修正 + env var 拡張 + `bin/oe --task-file`、**B**=実 agent spawn 通電確認 (probe_target / probe_verify + skill load)、**C**=DI-1 target task 完遂 (orchestration-engine 小機能追加、`OE_VERIFY_REVIEWER_SESSION_IDS` 追跡 = #93 前半取り込み)、**D**=検証フェーズ E2E + 構造的判定 4 点、**E**=`tests/e2e_real_agent/` 整備 + 1 回完走実証 + Episode + ADR
6. → Plan 段階で so-compare (iter1) → 反映 → docs PR
7. → 実装 PR (Phase A〜E + so-compare iter2 + Episode + ADR)
