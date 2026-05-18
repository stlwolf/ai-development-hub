---
id: "01KRXJ27JHWE1M1DGH7TA9J9KK"
title: "Step 4-5 KickOff: フィードバック → architecture-sketch.md 更新 + Epic #19 close"
date: 2026-05-18
type: kickoff
status: confirmed
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/19"
    reason: "Epic #19 Phase 4 MVP の最終 Step (Phase 4 完了 + Epic close)"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/103"
    reason: "Step 4-5 観測層 Issue (本 KickOff の主スコープ)"
  - type: source_material
    ref: "projects/orchestration-engine/docs/discussions/2026-05-18-discussion-step-4-5-architecture-sketch-feedback.md"
    reason: "本 KickOff の正本 (QDD 9 Q closed、status: closed)"
  - type: source_material
    ref: "projects/orchestration-research/synthesis/architecture-sketch.md"
    reason: "本 Step の更新対象 (Phase 3 Synthesis 成果、frozen 化候補)"
  - type: source_material
    ref: "projects/orchestration-engine/docs/episodes/2026-05-18-episode-step-4-4-implementation.md"
    reason: "Phase 4 最終 Step (Step 4-4) Episode (フィードバック抽出元)"
  - type: source_material
    ref: "projects/orchestration-engine/docs/decisions/"
    reason: "Phase 4 で確定した ADR 5 件 (§11 設計判断集約の参照先)"
  - type: design_context
    ref: "projects/orchestration-engine/docs/plans/2026-05-16-kickoff-step-4-4-e2e-verification.md"
    reason: "Step 4-4 KickOff (DI 構造のテンプレート)"
tags: [orchestration, mvp, step-4-5, kickoff, architecture-sketch, feedback, frozen, epic-close]
---

# Step 4-5 KickOff: フィードバック → architecture-sketch.md 更新 + Epic #19 close

> Epic [#19](https://github.com/stlwolf/ai-development-hub/issues/19) Phase 4 MVP の **最終 Step**。Step 4-0〜4-4 (Phase 4 全実装) が [PR #97](https://github.com/stlwolf/ai-development-hub/pull/97) merge で完了し、orchestration-engine が実 agent で 1 サイクル E2E 完走する状態に到達。本 Step は Phase 4 全体で得たフィードバックを `projects/orchestration-research/synthesis/architecture-sketch.md` (Phase 3 Synthesis 成果) に反映し、Epic #19 を close する。
>
> Step 4-5 Discussion ([`2026-05-18-discussion-step-4-5-architecture-sketch-feedback.md`](../discussions/2026-05-18-discussion-step-4-5-architecture-sketch-feedback.md)、status: closed) の QDD 9 Q から DI を抽出。役割案 X (architecture-sketch を Phase 3 snapshot + Phase 4 完了報告の 2 層構造で frozen 化、新たな living 役割は与えない) を採用。

## 目的

1. **architecture-sketch.md の更新**: Phase 4 全実装で得た学びを最小限反映し、文書全体を frozen 化
2. **Phase 5 方向感の捕捉**: 「MVP 継続 / 本実装移行 / 別 Epic 注力」の 3 Path を独立 KickOff doc (status: draft) として記録
3. **Epic #19 の close**: Phase 4 全 5 Step (4-1〜4-5) 完了の節目

## 進め方

- 本 KickOff の Phase 構造に従い、軽量 4 Phase で進める (doc only、コード変更なし)
- 各 Phase 完了時に GATE で user 確認
- 全 Phase 完了後に PR 作成、`Closes #19` で Epic close

## 確定設計事項 (DI)

Discussion §「確定状況サマリ」(9 Q closed) から抽出。

### DI-1: architecture-sketch.md の役割は Phase 3 snapshot + Phase 4 完了報告の 2 層構造 frozen 文書 (Discussion 役割案 X)

- 新たな living 役割は与えない。設計の真正な記録は engine 配下の ADR 群が担う
- synthesis/ ディレクトリ全体は frozen 維持 (architecture-sketch だけが 2 層構造)

### DI-2: 更新の追記境界 — 新節 §11 + 既存節への最小 in-place (Discussion Q1)

- **新節 §11「Phase 4 完了報告 (2026-05)」を末尾追加** (~50 行、5 サブ節)
- **§9 フェーズ計画**: Phase 4 全 Step (4-1〜4-5) を `[x]` チェック + Phase 5 未定注記
- **§3 認知協調層**: 1 段落追記 (verification_completed + summary + circuit_breaker で「ゲート実行確認」が確定、reviewer 出力経路は file redirect に確定、ADR リンク)
- **§4 正準エージェント定義**: 1 段落追記 (envelope/audit/state schema 場所明記、未決定事項を「Phase 4 で確定」/ 「派生 Issue」に分類)
- **§5 MVP 構成**: 1 文追記 (「最初のユースケース」を Step 4-4 で実機 1 サイクル完走実証済みと明記)

### DI-3: フィードバック抽出方針 — ADR 主、Episode は Phase サマリ、観察事実 3-5 件 (Discussion Q2)

§11 (新節) に集約する内容:

1. **到達点** (1 段落)
2. **設計判断の集約** = ADR 5 件への参照リスト (各 1 行サマリ + リンク)
   - Step 4-1: cleanup-strategy / permission-separation-mvp / issue-20-phase-convergence
   - Step 4-3: verification-gate-design
   - Step 4-4: reviewer-output-file-redirect
3. **観察された設計事実** (3-5 件): mock 限界 / 駆動層 dogfood / so-compare 2 段階 / 出力経路の非対称性 など
4. **派生 Issue 集約** = #92 / #93 / #98〜#102 (7 件) を表形式
5. **frozen 宣言 + redirect** (DI-8 で具体)

### DI-4: synthesis/ 他文書は完全に touch しない (Discussion Q6)

- `context-foundation.md` / `skills-level-patterns.md` / `harness-engineering-mapping.md` の 3 件は本 Step スコープ外
- 必要なら派生 Issue として別途扱う

### DI-5: Phase 5 方向感は独立 KickOff doc (status: draft) として作成 (Discussion Q9)

- ファイル: `projects/orchestration-engine/docs/plans/2026-05-18-kickoff-phase-5-direction.md`
- status: `draft` (DI 未確定、Phase 5 着手時に正式 confirmed 化する前提)
- 内容構成 (5 項目):
  1. 背景・現状認識 (Phase 4 完了時点の engine 到達点と限界)
  2. Path 候補 + 各主要 DI 候補 (Path α: MVP 継続改良 / Path β: 本実装移行 / Path γ: 別 Epic 注力)
  3. 各 Path の利益 / リスク / 必要工数の見積もり (現時点の主観、確定値ではない明示)
  4. 現時点の傾き (どの Path が濃いか、暫定意向)
  5. 判断時期 / 判断のトリガー + 次アクション
- 項目 3 と 4 は user の主観が必要。Plan 段階で空欄テンプレート提示 → user 入力 → 確定の流れ

### DI-6: §11 文書量と構造 — ~50 行、5 サブ節 (Discussion Q4)

```
## 11. Phase 4 完了報告 (2026-05)

### 11.1 到達点 (3-5 行)
### 11.2 設計判断の集約 — ADR 5 件 (各 1 行サマリ + リンク、合計 ~10 行)
### 11.3 観察された設計事実 (3-5 件、各 2-3 行で計 ~15 行)
### 11.4 派生 Issue (MVP 後拡張候補、表 ~10 行)
### 11.5 文書ステータス更新 (frozen 宣言 + redirect、~5 行)
```

### DI-7: PR デリバラブル — 1 PR、Discussion+KickOff+Plan+Episode+sketch 更新+Phase 5 direction KickOff(draft) (Discussion Q7)

PR に含める成果物:

- `projects/orchestration-research/synthesis/architecture-sketch.md` 更新差分
- 本 Discussion (status: closed、既に commit 済)
- 本 KickOff (Step 4-5、status: confirmed)
- 新 Plan (`2026-05-18-plan-step-4-5-architecture-sketch-feedback.md`)
- 新 Episode (`2026-05-18-episode-step-4-5-implementation.md`)
- 新 Phase 5 direction KickOff (`2026-05-18-kickoff-phase-5-direction.md`、status: draft)

PR description: **Closes #19** + Refs 派生 Issue 群。新 ADR 作成不要。

### DI-8: frozen 宣言文言 — 冒頭 + §11.5 末尾の 2 箇所、redirect 先 3 つ明示 (Discussion Q8)

**冒頭の引用ブロック直下** (現状の `> Q&A 形式の設計議論...` の直下):

```markdown
> **文書ステータス (2026-05-18 更新)**
>
> 本文書は Phase 3 Synthesis 完了時点の素案 (§1〜§10) に、Phase 4 MVP 完了報告 (§11、2026-05) を加えた **2 層構造の frozen 文書**。以降の orchestration-engine の設計判断は [`projects/orchestration-engine/docs/decisions/`](../../orchestration-engine/docs/decisions/) 配下の ADR を正本とし、本文書には追記しない。
>
> Phase 4 完了時点の engine の使い方 / 構成は [`projects/orchestration-engine/README.md`](../../orchestration-engine/README.md)、Step ごとの経緯は [`projects/orchestration-engine/docs/episodes/`](../../orchestration-engine/docs/episodes/) を参照。
```

**§11.5 文書ステータス更新セクション末尾**:

```markdown
本文書はここで frozen とする。Phase 5 以降 (もしあれば) の orchestration-engine の進化は別 Epic + engine 配下の Discussion/KickOff/Plan/Episode/ADR で記録する。
```

## 残論点 (本 KickOff 時点で未確定、Plan / 実装で扱う)

- **観察事実 3-5 件の最終選定** (DI-3 §11.3): Plan 段階で Step 4-1〜4-4 の Episode 15+ 件から候補抽出、user レビューで確定
- **Phase 5 direction KickOff 項目 3-4 (主観部)**: Plan 段階で空欄テンプレート → user 入力 → 確定
- **§4 「未決定事項」表の更新分類** (DI-2 §4): Plan 段階で Phase 3 当時の項目を「Phase 4 で確定 / 派生 Issue / 未確定継続」に仕分け

## Phase 構造 (軽量 4 Phase、doc only)

### Phase A: 駆動層 doc 起草

- 本 KickOff (= 本ファイル) — **完了**
- Plan (`2026-05-18-plan-step-4-5-architecture-sketch-feedback.md`)
- Phase 5 direction KickOff (`2026-05-18-kickoff-phase-5-direction.md`、status: draft) の骨格 + 客観部 (Path α/β/γ の選択肢列挙)

GATE: user に Phase 5 direction KickOff の項目 3-4 (主観部) を入力依頼、Plan 承認

### Phase B: architecture-sketch.md 更新差分

- 冒頭 frozen 宣言追加
- §3 / §4 / §5 / §9 の in-place 更新
- §11 新節追加 (5 サブ節)

GATE: 差分 review、user 承認

### Phase C: Episode 起草

- `2026-05-18-episode-step-4-5-implementation.md` 起草
- 内容: Discussion (9 Q closed) + KickOff (8 DI) + Plan + 実装 (sketch 更新 + Phase 5 KickOff draft) の経緯記録

GATE: user 確認

### Phase D: PR 作成 + Epic close

- PR タイトル: `docs(orchestration-engine): Step 4-5 architecture-sketch.md frozen 化 + Phase 4 完了報告 (Closes #19)`
- PR description: 全成果物 + Closes #19 + Refs 派生 Issue 群
- merge 後に Epic #19 が close される確認

## 参考

- Discussion: [`2026-05-18-discussion-step-4-5-architecture-sketch-feedback.md`](../discussions/2026-05-18-discussion-step-4-5-architecture-sketch-feedback.md) (status: closed、9 Q closed)
- Step 4-4 Episode: [`2026-05-18-episode-step-4-4-implementation.md`](../episodes/2026-05-18-episode-step-4-4-implementation.md)
- Phase 4 ADR 5 件: [`docs/decisions/`](../decisions/)
- 更新対象: [`projects/orchestration-research/synthesis/architecture-sketch.md`](../../../orchestration-research/synthesis/architecture-sketch.md)
- 派生 Issue 候補: #92 / #93 / #98 / #99 / #100 / #101 / #102 (7 件、本 PR スコープ外)
