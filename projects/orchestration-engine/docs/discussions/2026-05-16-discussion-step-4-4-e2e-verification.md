---
id: "01KRR7BP14TWDWQFVSBYYB4K5V"
title: "Step 4-4 E2E 検証 (実 agent で 1 サイクル完走) の設計判断（質問駆動設計）"
date: 2026-05-16
type: discussion
status: draft
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

> Step 4-3 ([PR #94](https://github.com/stlwolf/ai-development-hub/pull/94) マージ済み) で検証ゲート v1 が **wez mock 経由で 299 assertions PASS** の状態。本 Step は **実 agent で 1 サイクル完走** することを目的とする。
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
- [#93](https://github.com/stlwolf/ai-development-hub/issues/93) MVP 後拡張: 一時ファイル掃除 / nonce 付きマーカー偽陽性対策

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

**status**: open

**質問**: 「ツール改善タスクで 1 サイクル完走」の具体タスクは何にするか?

| 案 | 内容 | トレードオフ |
|----|------|-------------|
| A. ai-development-hub 内の小タスク (例: 既存 skill の小修正) | リポジトリ内完結、検証容易 | スコープが曖昧、検証 agent が「正しい修正」を判断しにくい |
| **B. orchestration-engine 自体の小機能追加 (例: F-SO-9 由来の小拡張)** | dogfood として整合、Step 4-5 の input にも繋がる | 自己参照、orchestration が orchestration を改修する複雑性 |
| C. wez CLI Phase 3 (`wez agent`) の一部設計支援 | Phase 3 ([#20](https://github.com/stlwolf/ai-development-hub/issues/20)) と合流、現実的価値高 | スコープ外の Phase 3 設計判断が混入 |
| D. 既存 ideas/ から 1 つ pick して projects/ への昇格作業 | 明確に「ツール改善」、独立性高 | ideas/ の凍結原則と矛盾しない選定が必要 |

**推奨**: **B. orchestration-engine 自体の小機能追加**

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

### Q2: 使用する実 CLI の選択

**status**: open

**質問**: target agent / 検証 agent でどの実 CLI を使うか?

| 案 | 内容 | トレードオフ |
|----|------|-------------|
| A. `cursor` のみ | 既存 envelope の default、参考実装が claude-safe / arena-compare 等で蓄積 | 単一 CLI なのでクロスチェック性なし |
| B. `claude -p` のみ | Compliance Review が claude 本体規約に最も近い | claude のみで完走、cursor / codex 動作未検証 |
| C. `codex -p` のみ | Codex がレビュー観点で精度高 (so-compare 経験) | claude / cursor 未検証 |
| **D. 1 サイクル目: `cursor` (target) + `claude -p` (検証) のクロス** | 異なる CLI で動作確認、検証 agent の独立性も担保 | 2 CLI 必要、起動オプション両対応必要 |
| E. 3 CLI 全部対応 | 完全網羅 | スコープ膨張、MVP 過剰 |

**推奨**: **D. cursor (target) + claude -p (検証) のクロス**

**根拠**:
- target / 検証で異なる CLI を使うことで、検証 agent の「独立性」が agent モデル/CLI レベルでも担保される (adversarial review の本質)
- cursor は既存 envelope の default、claude は Compliance Review skill の本家規約
- [#91](https://github.com/stlwolf/ai-development-hub/issues/91) で CLI ディスパッチャを実装する際、`cursor` と `claude -p` の 2 種に絞れば実装規模が小さい
- 3 CLI 対応は Step 4-5 以降で必要性が見えれば追加

**未解決の細部**: cursor / cursor-agent / claude / claude-safe / codex のうち実際の invocation 仕様。KickOff で確定。

---

### Q3: [#91](https://github.com/stlwolf/ai-development-hub/issues/91) (AI CLI 起動オプション修正) の組み込み方

**status**: open

**質問**: [#91](https://github.com/stlwolf/ai-development-hub/issues/91) の修正を本 Step とどう連動させるか?

| 案 | 内容 | トレードオフ |
|----|------|-------------|
| A. 別 PR で先に潰し、本 Step は #91 完了後に着手 | 関心分離が明確 | 2 PR、Step 4-4 着手が遅れる |
| **B. 本 Step Plan の Phase A として組み込み (本 Step PR で同時マージ)** | 1 つの一貫した Step、レビューも一括 | スコープ膨張気味だが必然性あり |
| C. 本 Step の Discussion 段階で並行起動 (#91 を別ブランチで対応中に Discussion を進める) | 並行作業で時間効率↑ | コンフリクト管理が複雑 |

**推奨**: **B. 本 Step Plan の Phase A として組み込み**

**根拠**:
- [#91](https://github.com/stlwolf/ai-development-hub/issues/91) は Step 4-3 派生だが、本 Step (E2E 実 agent) では **必須の前提**。独立した PR にすると Step 4-4 が着手不可
- Step 4-3 と同じ Phase 構成 (A=前提整備、B〜E=本実装) を踏襲しやすい
- Discussion / KickOff / Plan に [#91](https://github.com/stlwolf/ai-development-hub/issues/91) の対応範囲を明示することで scope creep ではなく必然的拡張と認識できる
- 本 PR (docs) → [#91](https://github.com/stlwolf/ai-development-hub/issues/91) 対応 + 実装 PR の 2 段構成は Step 4-3 と同じパターン

---

### Q4: 検証 agent と target agent の CLI 関係

**status**: open

**質問**: 検証 agent と target agent で同一 CLI を使うか、別 CLI を使うか?

Q2 で「cross (cursor target + claude 検証)」を推奨したため、本 Q はその深堀り。

| 案 | 内容 | トレードオフ |
|----|------|-------------|
| **A. 別 CLI 固定 (cursor target + claude 検証)** | 独立性最大、adversarial review の本質 | 同一モデルでの再現性検証はできない |
| B. 同一 CLI 固定 (target / 検証両方 cursor or claude) | 単純、CLI 1 種で済む | 検証 agent の独立性が agent モデル/CLI レベルで担保されない |
| C. envelope で指定可能 (`OE_VERIFY_AI_CLI` 既実装 + target 側も同様の env var 化) | 柔軟、運用で選択可 | テストパターン爆発 |

**推奨**: **A. 別 CLI 固定 (cursor target + claude 検証)**

**根拠**:
- Q2 と同根拠: 異 CLI で検証 agent の独立性を担保
- `OE_VERIFY_AI_CLI` は既に Step 4-3 で実装済み (F-SO-6)、target 側も同様の env var (例: `OE_TARGET_AI_CLI`) を追加すれば運用切替も可
- KickOff / Plan で envelope schema の `task.ai_cli` フィールド追加を検討する余地あり (本 Discussion ではスコープに留める)

---

### Q5: 実 agent E2E の自動化境界

**status**: open

**質問**: 実 agent E2E をどこまで自動化するか?

| 案 | 内容 | トレードオフ |
|----|------|-------------|
| A. 完全手動 (人間が `bin/oe "task description"` を実行して結果確認) | 単純、E2E の意義に忠実 | CI に乗らない、回帰検出が遅れる |
| **B. 半自動 (実 agent を起動するスモークテストを `tests/` 配下に追加、人間が結果を承認)** | 起動の再現性 + 人間判断の両立 | CLI key / 認証 / レート制限の管理が必要 |
| C. 完全 CI 自動 (GitHub Actions 等で実 CLI を呼ぶ) | 完全回帰検出 | API key の secret 管理、レート制限、コスト |

**推奨**: **B. 半自動 (スモークテストスクリプト + 人間承認)**

**根拠**:
- MVP では「1 サイクル完走の実証」が目的であり、CI で常時回す必要性は低い
- スモークテストを `tests/e2e_real_agent/` 等 (mock と分離) に配置することで、開発者が手元で `bash tests/e2e_real_agent/smoke_cursor_claude.sh` で再現できる
- 結果 (audit log / KVS の状態 / 実成果物) を人間が確認して承認 / 失敗判定
- 完全 CI 自動は Step 4-5 以降で必要性が確認された場合に追加

---

### Q6: mock テストとの併存

**status**: open

**質問**: 既存 wez mock E2E (`tests/test_e2e_smoke.sh` の 43 assertions) と実 agent E2E をどう併存させるか?

| 案 | 内容 | トレードオフ |
|----|------|-------------|
| **A. mock テストは現状維持、実 agent E2E は別ディレクトリ/別命名 (`tests/e2e_real_agent/`)** | 関心分離、CI ではモック側を回す | 2 系統のテスト保守 |
| B. mock テストを「real CLI モード」で再利用可能に拡張 (env var で切替) | テスト 1 セット、保守単純化 | mock と real の挙動差を吸収するロジックが複雑化 |
| C. mock テストは廃止、実 agent E2E のみ | 単純化 | CI で実 CLI 呼べない場合に回帰検出が完全に止まる |

**推奨**: **A. 別ディレクトリで併存**

**根拠**:
- mock テスト 299 assertions は「engine の内部構造の回帰検出」として価値が高く、廃止すべきでない
- 実 agent E2E は「engine の対外境界 (実 CLI) との接続性の検証」として目的が異なる
- 2 系統に分離することで、CI (mock) と開発者 / リリース前 (real) の役割分担が明確
- ディレクトリ案: `tests/e2e_real_agent/` (mock は `tests/test_*.sh` のまま)

---

### Q7: 実 agent の non-determinism への対処

**status**: open

**質問**: 実 agent は同じプロンプトに対して異なる応答を返す。E2E の合否判定をどうするか?

| 案 | 内容 | トレードオフ |
|----|------|-------------|
| A. 厳格判定 (出力が完全一致しないと FAIL) | 単純 | 実用上ほぼ常に FAIL、E2E が機能しない |
| **B. 構造的判定 (マーカー emit、KVS 書き込み、verification entry 生成、notify 呼び出しの 4 点を「成功」と定義)** | 実 agent の応答内容に依存しない、engine の動作のみを検証 | 「verify result が pass か fail か」は判定対象外 (cycle 完走自体は成功) |
| C. 統計判定 (3 回連続実行、majority decision) | 信頼性高 | コスト 3 倍、レート制限リスク |

**推奨**: **B. 構造的判定**

**根拠**:
- E2E の目的は「engine が実 agent と接続して 1 サイクル動く」ことの実証であり、検証結果の正確性ではない (それは検証 agent 自体の品質、本 Step スコープ外)
- mock テストでは marker emit / KVS / audit / notify を assertion している。同じ assertion を real agent でも適用する
- non-determinism は「verify_result が pass か fail か」の部分にのみ現れる。engine の動作 (spawn, capture, write, emit, cleanup) は決定的
- 統計判定は Step 4-5 以降で必要性が見えれば追加

---

### Q8: 完了条件 (1 サイクル完走の判定基準)

**status**: open

**質問**: 何をもって「1 サイクル完走」と判定するか?

Q7 の「構造的判定」を採用するなら、判定項目は engine 出力の 4 点に絞られる。それを完了条件として明文化する。

| 候補 | 内容 |
|------|------|
| (1) `@@OE_EXIT:0` (target) と `@@OE_VERIFY:{pass\|fail\|warn}` (reviewer) が両方 emit される | engine が両 marker を捕捉できる |
| (2) `state/{session_id}.state.json` に `state: success` と `verification[].result` が記録 | KVS が正しく書かれる |
| (3) `audit/{session_id}.jsonl` に主要 7 イベント (session_start, state_change, session_end, verification_started, verification_completed, cleanup, [optional protocol_error]) が記録 | audit log が正しく書かれる |
| (4) `wez notify` が呼ばれ、本文に summary が展開される | 通知が動く |
| (5) shellcheck クリーン + 既存 299 mock assertions 回帰なし | engine 全体の回帰検出 |
| (6) [#91](https://github.com/stlwolf/ai-development-hub/issues/91) の CLI ディスパッチャが少なくとも 2 CLI (cursor + claude) で動作 | Phase A 相当の完了 |
| (7) 実 agent E2E スクリプトが `tests/e2e_real_agent/` に存在し、再現可能 | 半自動テストの成立 |
| (8) Step 4-5 (architecture-sketch 更新) のフィードバック材料として、実 agent E2E の Episode が記録される | 後続 Step への引き継ぎ |

**推奨**: 上記 (1)〜(8) **すべて** を完了条件とする (KickOff で確定)。

**根拠**:
- (1)〜(4) は engine の動作実証 (Q7 構造的判定の実体)
- (5) は回帰防止
- (6) は [#91](https://github.com/stlwolf/ai-development-hub/issues/91) 取り込み (Q3)
- (7) は Q5 半自動の実体
- (8) は Step 4-5 への引き継ぎ準備

---

## 完了条件案 (仮置き)

全 Q closed 後、KickOff §「完了条件」に確定版として反映。Q8 の 8 項目をベースに記述する。

## 未解決の論点 (本 Discussion で扱わないもの)

- 具体的なツール改善タスクの選定 (Q1 で方向性のみ確定、具体は KickOff で決定)
- envelope schema への `task.ai_cli` フィールド追加 (Step 4-5 候補)
- 検証 agent 自体の品質評価 (検証結果が「正しいか」の判定、本 Step スコープ外)
- 3 CLI 全対応 (Step 4-5 以降の判断)

## 進め方

1. user が Q1 から順にレビューし、推奨案で OK か別案かを判断
2. 合意した Q から個別に `status: closed` + 決定内容を追記
3. 全 Q closed 後、本 Discussion 全体を `status: closed` に
4. KickOff の「仮置き」セクションを Discussion 結果で確定
5. `kickoff-to-plan` skill で Plan に変換 (Step 4-3 と同じ 5 Phase 構成想定: A=#91 修正 + envelope 拡張、B=実 agent spawn、C=検証フェーズ E2E、D=KVS / audit / notify アサーション、E=Episode + 統合テスト)
