---
id: "01KRXJ27NN0Y25B9PY7F246YJG"
title: "Step 4-5 Plan: architecture-sketch.md frozen 化 + Phase 4 完了報告 + Phase 5 direction KickOff(draft)"
date: 2026-05-18
type: plan
status: ready
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/19"
    reason: "Epic #19 Phase 4 MVP の最終 Step"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/103"
    reason: "Step 4-5 観測層 Issue"
  - type: source_material
    ref: "projects/orchestration-engine/docs/discussions/2026-05-18-discussion-step-4-5-architecture-sketch-feedback.md"
    reason: "Step 4-5 Discussion (status: closed、QDD 9 Q closed)"
  - type: source_material
    ref: "projects/orchestration-engine/docs/plans/2026-05-18-kickoff-step-4-5-architecture-sketch-feedback.md"
    reason: "Step 4-5 KickOff (status: confirmed、DI-1〜DI-8)"
tags: [orchestration, mvp, step-4-5, plan, architecture-sketch, frozen, epic-close, doc-only]
---

# Step 4-5 Plan: architecture-sketch.md frozen 化 + Phase 4 完了報告 + Phase 5 direction KickOff(draft)

> KickOff [`2026-05-18-kickoff-step-4-5-architecture-sketch-feedback.md`](2026-05-18-kickoff-step-4-5-architecture-sketch-feedback.md) (status: confirmed、DI-1〜DI-8) を Phase / Step に展開した実行計画。doc only で コード変更なし、Phase 構造は軽量 4 Phase。

## Context

- Phase 4 MVP は [PR #97](https://github.com/stlwolf/ai-development-hub/pull/97) merge で完了 (Step 4-0〜4-4)
- Phase 4 で得た学びを `projects/orchestration-research/synthesis/architecture-sketch.md` に反映、frozen 化し Epic [#19](https://github.com/stlwolf/ai-development-hub/issues/19) を close
- 役割案 X 採用 (Phase 3 snapshot + Phase 4 完了報告の 2 層構造、新たな living 役割なし)
- synthesis/ 他 3 文書は touch しない、architecture-sketch.md のみ更新

## Phase A: 駆動層 doc 起草

### Step 1: Plan 起草 — **本ファイル**、完了

### Step 2: Phase 5 direction KickOff (status: draft) の骨格 + 客観部起草

- [ ] ファイル: `projects/orchestration-engine/docs/plans/2026-05-18-kickoff-phase-5-direction.md`
- [ ] status: draft (DI 未確定、Phase 5 着手時に正式 confirmed 化)
- [ ] 客観部 (5 項目の構造 + Path α/β/γ の選択肢列挙):
  - 1. 背景・現状認識 (Phase 4 完了時点の engine 到達点と限界)
  - 2. Path 候補 + 主要 DI 候補
    - Path α: MVP 継続改良 (派生 Issue #92 / #93 / #98〜#102 を順次消化、検証ゲート v2 等)
    - Path β: 本実装移行 (production 用途化、別プロジェクトでの dogfood、配布形態 CLI package?)
    - Path γ: MVP を停止し別 Epic に注力 (#20 wezterm-ai-mode / #24 フック拡充 / #37 Harness Engineering)
  - 3. 各 Path の利益 / リスク / 必要工数の見積もり — **空欄テンプレート** (Step 3 で user 入力)
  - 4. 現時点の傾き — **空欄テンプレート** (Step 3 で user 入力)
  - 5. 判断時期 / 判断のトリガー + 次アクション — Step 2 で叩き案、Step 3 で user 確認

### Step 3: Phase 5 direction KickOff の主観部 (項目 3-4) を user 入力依頼

- [ ] Step 2 で空欄テンプレートを user に提示
- [ ] user 入力を受けて項目 3 (各 Path の見積もり) / 項目 4 (現時点の傾き) を確定
- [ ] Step 5 で他 Step と整合確認 (項目 5 のトリガー定義との整合)

### Phase A GATE

- [ ] Step 1-3 完了
- [ ] Phase 5 direction KickOff の客観部 + 主観部 + 判断トリガーが揃う
- [ ] user に Plan 承認確認

## Phase B: architecture-sketch.md 更新差分

> 編集対象: `projects/orchestration-research/synthesis/architecture-sketch.md` (1 ファイルのみ)

### Step 4: 冒頭 frozen 宣言追加 (KickOff DI-8)

- [ ] 冒頭の `> Q&A 形式の設計議論（Issue #18）を経て...` の引用ブロックの直下に「**文書ステータス (2026-05-18 更新)**」引用ブロックを追加
- [ ] 文言は KickOff DI-8 §冒頭 の通り (Phase 3 素案 + Phase 4 完了報告の 2 層構造 frozen の説明、redirect 先 3 つ明示)

### Step 5: §3 認知協調層への 1 段落追記 (KickOff DI-2)

- [ ] §3 末尾に Phase 4 確定事項として 1 段落追加:
  - 「ゲートが実行されたか」問題は Step 4-3 で `verification_completed` audit + `verification_summary` 集計 + `circuit_breaker_triggered` の組み合わせで構造的に証明する形に確定
  - reviewer 出力経路は file redirect (`tee`) に確定 (Step 4-4)
  - ADR (`2026-05-16-decision-verification-gate-design.md` / `2026-05-18-decision-reviewer-output-file-redirect.md`) リンク

### Step 6: §4 正準エージェント定義への 1 段落追記 (KickOff DI-2)

- [ ] §4 末尾に Phase 4 確定事項として 1 段落追加:
  - envelope schema = `schemas/envelope.schema.json`
  - audit schema = `schemas/audit-log.schema.json`
  - state schema = `schemas/session-state.schema.json`
- [ ] §4 「未決定事項」表に各項目の Phase 4 結果を注記 (`→ Phase 4 で確定` / `→ 派生 Issue #N`)

### Step 7: §5 MVP 構成「最初のユースケース」を 1 文追記 (KickOff DI-2)

- [ ] §5 「最初のユースケース」を Step 4-4 で実機 1 サイクル完走実証済みと明記 (PR #97 + 実機 smoke 2 回目への参照)

### Step 8: §9 フェーズ計画 Phase 4 全 [x] + Phase 5 未定注記 (KickOff DI-2)

- [ ] §9 の Phase 4 表 (4-1〜4-5) のチェックボックスを `[x]` に更新 (本 Step 完了時点で 4-1〜4-5 全完了)
- [ ] §9 末尾に短い注記を追加:
  > 「Phase 5 (もしあれば) のスコープは本 Step 時点では未定。orchestration-engine の MVP 後拡張は派生 Issue 群 (#92 / #93 / #98〜#102) で個別管理。次の大きなフェーズが必要になった時点で別 Epic として起票する」

### Step 9: §11 新節「Phase 4 完了報告 (2026-05)」を末尾追加 (KickOff DI-3 + DI-6)

- [ ] §11 構造 (5 サブ節、~50 行):
  - 11.1 到達点 (3-5 行): Phase 4 全 Step 完了、mock 306 assertions、実機 smoke 1 サイクル完走、target=cursor-agent/composer-2、reviewer=claude/sonnet-4-6
  - 11.2 設計判断の集約 (~10 行): ADR 5 件への参照リスト (各 1 行サマリ + リンク)
    - Step 4-1 ADRs (3 件): cleanup-strategy / permission-separation-mvp / issue-20-phase-convergence
    - Step 4-3 ADR: verification-gate-design
    - Step 4-4 ADR: reviewer-output-file-redirect
  - 11.3 観察された設計事実 (3-5 件、計 ~15 行): Step 4-1〜4-4 Episode から抽出。候補:
    - mock 限界 — 実機 smoke が viewport-only な wez pane capture バグを検出 (Step 4-4)
    - 駆動層 dogfood — Discussion/KickOff/Plan のみで Cursor → Claude Code 引き継ぎ成立 (Step 4-3 / 4-4)
    - so-compare 2 段階 — 実装前 Critical 発見 + 実装後品質チェックの両輪 (Step 4-3 / 4-4)
    - 出力経路の非対称性 — target (短文 wez capture) と reviewer (長文 file redirect) で同じ pane capture が違う結果 (Step 4-4)
    - (候補追加可) Step 4-2 Phase E integration、Step 4-3 limited-complete / full-complete 2 段階判定
  - 11.4 派生 Issue (MVP 後拡張候補、表 ~10 行): #92 / #93 / #98 / #99 / #100 / #101 / #102 を 1 行 / Issue で集約
  - 11.5 文書ステータス更新 (frozen 宣言、~5 行): KickOff DI-8 §11.5 末尾の通り

### Step 10: 差分 review

- [ ] `git diff master..HEAD -- projects/orchestration-research/synthesis/architecture-sketch.md` で差分確認
- [ ] 行数が概ね +60〜+100 行に収まることを確認 (in-place 追記 + §11 新節)
- [ ] 既存セクション (§1, §2, §6, §7, §8, §10) は touch していないことを確認

### Phase B GATE

- [ ] Step 4-10 完了、差分 review 通過、user 承認

## Phase C: Episode 起草

### Step 11: Episode (`2026-05-18-episode-step-4-5-implementation.md`) 起草

- [ ] Step 4-3 / 4-4 Episode のフォーマット踏襲 (frontmatter、概要、Phase 別記録、観察と学び、関連リンク)
- [ ] 内容構成:
  - (A) 元実装フェーズ — Discussion (9 Q closed) + KickOff (8 DI) + Plan (4 Phase 10 Step) の起草、driving layer doc の整備
  - (B) architecture-sketch.md 更新差分 — Step 4-10 の作業記録 (実際に書いた内容、選んだ観察事実、書ききった差分行数)
  - (C) Phase 5 direction KickOff (draft) — 起草プロセス、項目 3-4 の user 入力受領、確定した方向感
  - (D) Phase 4 全体の総括 — Step 4-0 から 4-5 までの全 5 Step を振り返り (主観入りの retrospective)
- [ ] 観察と学び (3-5 件):
  - 駆動層 doc 主導で Phase 4 全完走できた (5 Step 連続)
  - architecture-sketch を frozen 化したことで synthesis/ ディレクトリ全体が真の frozen に
  - Phase 5 方向感を独立 KickOff(draft) に切り出したことで Step 4-5 のスコープ純度が保たれた
  - Epic close 直前で派生 Issue 7 件 (open) が backlog として可視化された

### Step 12: 関連 doc との整合確認

- [ ] Episode から Plan / KickOff / Discussion へのリンクが正しい (双方向参照)
- [ ] architecture-sketch.md 冒頭の redirect 先 3 つ (decisions / README / episodes) のパスが正しい
- [ ] Phase 5 direction KickOff の関連リンク (派生 Issue 7 件、別 Epic 候補 #20 / #24 / #37) が正しい

### Phase C GATE

- [ ] Step 11-12 完了、Episode が他 doc と整合、user 確認

## Phase D: PR 作成 + Epic close

### Step 13: PR description ドラフト

- [ ] タイトル (Conventional Commits): `docs(orchestration-engine): Step 4-5 architecture-sketch.md frozen 化 + Phase 4 完了報告 (Closes #19)`
- [ ] 本文構成:
  - Summary (Phase 4 完了報告、役割案 X 採用、Phase 5 direction draft 含む)
  - 変更ファイル (~5 件):
    - `projects/orchestration-research/synthesis/architecture-sketch.md` (更新)
    - `projects/orchestration-engine/docs/discussions/2026-05-18-discussion-step-4-5-...md` (新規)
    - `projects/orchestration-engine/docs/plans/2026-05-18-kickoff-step-4-5-...md` (新規)
    - `projects/orchestration-engine/docs/plans/2026-05-18-plan-step-4-5-...md` (新規、= 本ファイル)
    - `projects/orchestration-engine/docs/plans/2026-05-18-kickoff-phase-5-direction.md` (新規、status: draft)
    - `projects/orchestration-engine/docs/episodes/2026-05-18-episode-step-4-5-implementation.md` (新規)
  - Test plan (doc only なので shellcheck 等は不要、文書整合のみ)
  - `Closes #19` (Epic close)
  - `Refs #103` (Step 4-5 sub-issue)
  - `Refs #92 #93 #98 #99 #100 #101 #102` (派生 Issue、本 PR スコープ外)

### Step 14: PR 作成

- [ ] feature branch を push (`git push -u origin feature/#103_step-4-5-architecture-sketch-feedback`)
- [ ] `gh pr create` で PR 作成
- [ ] Copilot レビュー対応 (もしあれば、Step 4-4 のパターン踏襲)

### Step 15: merge 後の確認

- [ ] PR merge 後、Epic #19 が auto-close されることを確認
- [ ] Issue #103 が auto-close されることを確認 (Refs ではなく Closes で参照する場合)
- [ ] 派生 Issue (#92 / #93 / #98〜#102) は open のまま (本 PR では close しない)
- [ ] worktree / branch のクリーンアップ (Step 4-4 と同パターン: feature branch 削除、worktree は無いので削除不要)

### Phase D GATE (Epic #19 close)

- [ ] Step 13-15 完了、PR merged、Epic #19 closed、Phase 4 完全終了

## 残論点 (本 Plan で扱わない、Phase 5 以降)

- 派生 Issue 7 件 (#92 / #93 / #98〜#102) の優先度仕分け → Phase 5 direction KickOff の項目 4 (現時点の傾き) で扱う
- synthesis/ 他 3 文書 (context-foundation / skills-level-patterns / harness-engineering-mapping) の更新 → Phase 5 もしくは別 Epic
- orchestration-engine の本実装移行 (CLI package 化、production 用途、別プロジェクトでの dogfood) → Phase 5 Path β の検討事項
- 別 Epic への移行 (#20 / #24 / #37) → Phase 5 Path γ の検討事項

## 参考

- KickOff: [`2026-05-18-kickoff-step-4-5-architecture-sketch-feedback.md`](2026-05-18-kickoff-step-4-5-architecture-sketch-feedback.md)
- Discussion: [`2026-05-18-discussion-step-4-5-architecture-sketch-feedback.md`](../discussions/2026-05-18-discussion-step-4-5-architecture-sketch-feedback.md)
- 更新対象: [`architecture-sketch.md`](../../../orchestration-research/synthesis/architecture-sketch.md)
- Step 4-4 Episode (フォーマット参考): [`2026-05-18-episode-step-4-4-implementation.md`](../episodes/2026-05-18-episode-step-4-4-implementation.md)
- Phase 4 ADR 5 件: [`docs/decisions/`](../decisions/)
