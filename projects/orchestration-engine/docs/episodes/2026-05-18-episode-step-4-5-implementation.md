---
id: "01KRXJ27RSJEHDBK6T89HJMTT5"
title: "Step 4-5 実装エピソード — architecture-sketch.md frozen 化 + Phase 4 完了報告 + Phase 5 direction KickOff(draft) (Epic #19 close)"
date: 2026-05-18
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/19"
    reason: "Epic #19 Phase 4 MVP の最終 Step (本 Episode は Epic close の節目を記録)"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/103"
    reason: "Step 4-5 観測層 Issue (本 Episode の主スコープ)"
  - type: source_material
    ref: "projects/orchestration-engine/docs/discussions/2026-05-18-discussion-step-4-5-architecture-sketch-feedback.md"
    reason: "Step 4-5 Discussion (status: closed、QDD 9 Q closed)"
  - type: source_material
    ref: "projects/orchestration-engine/docs/plans/2026-05-18-kickoff-step-4-5-architecture-sketch-feedback.md"
    reason: "Step 4-5 KickOff (status: confirmed、DI-1〜DI-8)"
  - type: source_material
    ref: "projects/orchestration-engine/docs/plans/2026-05-18-plan-step-4-5-architecture-sketch-feedback.md"
    reason: "Step 4-5 Plan (4 Phase 15 Step、doc only)"
  - type: source_material
    ref: "projects/orchestration-engine/docs/plans/2026-05-18-kickoff-phase-5-direction.md"
    reason: "Phase 5 direction KickOff (status: draft、本 Step Phase A で起草)"
  - type: source_material
    ref: "projects/orchestration-research/synthesis/architecture-sketch.md"
    reason: "本 Step の更新対象 (Phase 4 完了報告反映 + frozen 化)"
  - type: source_material
    ref: "projects/orchestration-engine/docs/episodes/2026-05-18-episode-step-4-4-implementation.md"
    reason: "Step 4-4 Episode (本 Episode のフォーマット参考、Phase 4 最後の Step の経緯)"
tags: [orchestration, mvp, step-4-5, episode, implementation, architecture-sketch, frozen, epic-close, doc-only]
---

# Step 4-5 実装エピソード — architecture-sketch.md frozen 化 + Phase 4 完了報告 + Phase 5 direction KickOff(draft)

> Epic [#19](https://github.com/stlwolf/ai-development-hub/issues/19) Phase 4 MVP の最終 Step。Step 4-1〜4-4 (engine 実装) が [PR #97](https://github.com/stlwolf/ai-development-hub/pull/97) merge で完了した後、Phase 3 Synthesis 成果 `projects/orchestration-research/synthesis/architecture-sketch.md` (Issue #18) に Phase 4 で得た学びを反映し、文書全体を frozen 化することで Epic #19 を close。本 Episode は doc only の Step 4-5 を **(A) 駆動層 doc 起草フェーズ、(B) architecture-sketch.md 更新フェーズ、(C) Phase 5 direction KickOff(draft) 起草、(D) Phase 4 全体の振り返り** の 4 セクションで記録する。

## 概要

| フェーズ | 期間 (UTC) | 主な成果物 |
|---|---|---|
| (A) 駆動層 doc 起草 (Phase A) | 2026-05-18 07:54 〜 (継続セッション) | Discussion (9 Q closed) / KickOff (8 DI、status: confirmed) / Plan (4 Phase 15 Step、status: ready) / Phase 5 direction KickOff (status: draft、客観部 + 主観部) |
| (B) architecture-sketch.md 更新 (Phase B) | 同 (継続) | sketch.md +87 行 (冒頭 frozen 宣言 + §3 / §4 / §5 / §9 最小 in-place + §11 新節 5 サブ節)、§1 / §2 / §6 / §7 / §8 / §10 完全 untouched |
| (C) Episode 起草 (Phase C) | 同 (継続) | 本 Episode + 関連 doc 整合確認 |
| (D) PR 作成 + Epic close (Phase D) | 同 (継続予定) | PR `Closes #19`、Epic close、Step 4-5 sub-issue close |

---

## (A) 駆動層 doc 起草フェーズ (Phase A)

### Discussion (QDD 9 Q closed) → status: closed

ファイル: [`docs/discussions/2026-05-18-discussion-step-4-5-architecture-sketch-feedback.md`](../discussions/2026-05-18-discussion-step-4-5-architecture-sketch-feedback.md)

Step 4-3 / 4-4 Discussion のフォーマットを踏襲しつつ、本 Step では「architecture-sketch.md をどう扱うか」という user の根本的問いから出発:

> 「architecture-sketch.md の扱いがどうするか、archive とまではいかないけど research のディレクトリ自体は触んないからなら、そのファイルだけ更新されるのは多少違和感ある」

この問いを起点に、文書の役割 3 案 (X: Phase 3 snapshot として frozen / Y: post-impl synthesis として living / Z: そもそも不要) を比較し、**役割案 X を採用**。「synthesis = Phase 3 アウトプット」「engine/docs/ = Phase 4 以降のアウトプット」という棲み分けが明確化された。

途中、user の追加要件「Phase 5 / 本実装移行の現時点でのまとめを何らかの形で残したい」が登場し、初稿で本 Discussion 末尾に補遺セクションを追加する案 (Q9) を立てたが、user 指摘「ディスカッションというよりかは、次のプランに続くキックオフに近い」を受けて **独立 KickOff doc (status: draft) として切り出す形に方針変更**。この再構成により、本 Discussion のスコープ純度 (= architecture-sketch 議論に閉じる) が保たれた。

最終的に 9 Q を確定:

- Q1: 追記境界 = 新節 §11 + §9/§3/§4/§5 最小 in-place
- Q2: フィードバック抽出方針 = ADR 主、Episode は Phase サマリ、観察事実 3-5 件
- Q3: §9 フェーズ計画 = Phase 4 全 [x] + Phase 5 未定明記
- Q4: §11 構造 = ~50 行、5 サブ節
- Q5: §3 / §4 更新 = 各 1 段落の最小追記
- Q6: synthesis/ 他文書 = 完全 touch しない (frozen 維持)
- Q7: PR デリバラブル = 1 PR、5 文書セット + sketch 更新 + Phase 5 direction KickOff(draft)、Closes #19
- Q8: frozen 宣言文言 = 冒頭 + §11.5 末尾の 2 箇所、redirect 先 3 つ明示
- Q9: Phase 5 方向感の配置形式 = 独立 KickOff doc (status: draft)、本 Discussion 補遺案は棄却

### KickOff (8 DI、status: confirmed)

ファイル: [`docs/plans/2026-05-18-kickoff-step-4-5-architecture-sketch-feedback.md`](../plans/2026-05-18-kickoff-step-4-5-architecture-sketch-feedback.md)

Discussion 9 Q closed から DI-1〜DI-8 を抽出。Discussion 確定後すぐに status: confirmed として起草。Step 4-3 / 4-4 KickOff (DI 8〜9 個構成) と粒度を揃えた。

### Plan (4 Phase 15 Step、status: ready)

ファイル: [`docs/plans/2026-05-18-plan-step-4-5-architecture-sketch-feedback.md`](../plans/2026-05-18-plan-step-4-5-architecture-sketch-feedback.md)

doc only で軽量 4 Phase 構成:

- Phase A: 駆動層 doc 起草 (Step 1-3: Plan + Phase 5 direction KickOff 客観部 + 主観部)
- Phase B: architecture-sketch.md 更新 (Step 4-10)
- Phase C: Episode 起草 (Step 11-12)
- Phase D: PR 作成 + Epic close (Step 13-15)

Step 4-3 / 4-4 の Plan (Phase A〜E、22〜28 Step 構成) と比べると 1/3〜半分の規模だが、doc 更新のみのため Step 数は妥当。

### Phase 5 direction KickOff (status: draft、客観部 + 主観部)

ファイル: [`docs/plans/2026-05-18-kickoff-phase-5-direction.md`](../plans/2026-05-18-kickoff-phase-5-direction.md)

「Phase 5 / 本実装移行の現時点でのまとめ」を独立 KickOff として起草。`status: draft` で「Phase 5 着手時に正式 confirmed 化する前提のスナップショット」と明示。

客観部 (起草時に客観的に書ける範囲):

- 1. 背景・現状認識: Phase 4 到達点 (engine + 検証ゲート v1 + 観測層 + 駆動層 doc + テスト) と限界 (派生 Issue 7 件、未実装機能、運用上の課題)
- 2. Path 候補 3 案 + 主要 DI 候補
  - Path α: MVP 継続改良 (α-DI-1〜5)
  - Path β: 本実装移行 (β-DI-1〜5)
  - Path γ: 別 Epic 注力 (γ-DI-1〜4)

主観部 (user 入力で確定):

- 3. 各 Path の利益 / リスク / 工数: 起草時の叩き案を user が下方修正。Path α 全消化 ~1〜2 週、Path β 総計 1 ヶ月程度、Path γ ~1〜数ヶ月。共通制約 = セッション / コスト
- 4. 現時点の傾き: **大前提 = ゴール / 用途が未確定** (これが解消されないと純粋なブラッシュアップは空振り)。暫定意向 = Path α 寄り + β 視点 = 「実運用を見越した MVP 拡張」。Path γ は時期尚早
- 5. 判断時期: 短期 (1 日) / 中期 (1 週間) / 長期 (1 ヶ月)。3 ヶ月想定なし、セッション / コストが頭打ち要因
- 6. (新規) ゴール / 用途の具体化を最重要論点として独立化: 想定ゴール候補 5 案 (a〜e、現時点で未選択)、派生 Issue の本質性仕分けポリシー、ゴール未確定のまま着手しないものリスト

user の核心的な発言 (Phase 5 方向感の確定時):

> 「派生 issue 自体が根本的、本質的なこの MVP やオーケストラレーションツール仕様に対して課題としてあるなら、そっちは先にやるべきだが、多分そんなにかからないと思うけどね。問題はゴールを出してないところで、それが致命的に明らかに現状ですらボトルネックになるなら直すべきだが、ゴールが見えてない状態では、徒にブラッシュアップしても仕方ない気はする」

この発言で「ゴール未確定」が最重要論点として浮上、項目 6 が独立化された。

---

## (B) architecture-sketch.md 更新フェーズ (Phase B)

ファイル: [`projects/orchestration-research/synthesis/architecture-sketch.md`](../../../orchestration-research/synthesis/architecture-sketch.md)

Plan Step 4-10 を実施、+87 行追加 (Plan 想定 +60〜100 行内に収まる)。`§1` / `§2` / `§6` / `§7` / `§8` / `§10` は完全 untouched 確認。

### 編集箇所サマリ

| Step | 編集箇所 | 内容 |
|---|---|---|
| 4 | 冒頭引用ブロック直下 | 「文書ステータス (2026-05 更新)」引用ブロックを追加 (frozen 宣言 + redirect 先 3 つ) |
| 5 | §3 末尾 | 「Phase 4 確定事項」サブ節追加 (ゲート実行確認 + 出力経路 + skill mapping) |
| 6 | §4 末尾 | 「Phase 4 確定事項」サブ節追加 (3 スキーマ場所 + 「未決定事項」表の現状整理) |
| 7 | §5「最初のユースケース」 | 1 行追記 (target/reviewer 組み合わせ + PR #97 + check_cycle 全 PASS) |
| 8 | §9 Phase 4 表 | 「次フェーズ」→「完了、2026-05」、状態列 (✅) 追加、Phase 5 以降サブ節追加 |
| 9 | §11 新節 | 「Phase 4 完了報告 (2026-05)」 5 サブ節 (~55 行) |

### §11 内で選定した観察事実 4 件

Plan §「観察された設計事実 (3-5 件)」から最終的に **4 件** を選定:

1. **mock 限界 — 実機 smoke が viewport-only バグを検出** (Step 4-4)
2. **駆動層 doc サイクルでの dogfood 成立** (Step 4-3 / 4-4)
3. **so-compare 2 段階レビューの有効性** (Step 4-3 / 4-4)
4. **target / reviewer の出力経路非対称性** (Step 4-4)

Plan で候補として挙がっていた「Step 4-2 Phase E integration、Step 4-3 limited-complete / full-complete 2 段階判定」は枚数調整で除外。理由: §11 の主要メッセージ (実装で得た本質的学び) としては上記 4 件で十分網羅、5 件目以降は密度を薄める。

---

## (C) Phase 5 direction KickOff(draft) の独立化が効いた理由

本 Step で最も非自明だった設計判断は、**Phase 5 方向感を独立 KickOff(draft) として切り出した** こと (Discussion Q9 の方針転換)。初稿では本 Discussion 末尾の補遺セクションだったが、user 指摘で再構成した。

切り出しの利益:

- **Step 4-5 Discussion のスコープ純度が保たれた**: 「architecture-sketch の役割と更新方針」だけに集中、Phase 5 議論との混在を回避
- **Phase 5 着手時の入力資料として再利用しやすい**: `docs/plans/` に独立 doc として置かれているため、Phase 5 Discussion 起草時に直接参照可能
- **「現時点の方向感」と「確定 DI」が混在しない**: status: draft で明示的にスナップショット扱い
- **項目 6 (ゴール定義の論点) が独立節として明示できた**: user の「ゴール未確定」発言を最重要論点として可視化、Phase 5 着手前の必読箇所に

逆に補遺案のままだったら、Step 4-5 Discussion が「architecture-sketch frozen 化 + Phase 5 方向感」の二重スコープになり、後発者が「どちらの判断が本流か」を読み解きにくかった。**Discussion のスコープ純度を保つ判断は、QDD の運用上重要なパターンとして再認識された**。

---

## (D) Phase 4 全体の振り返り (Step 4-0〜4-5、2026-05)

Phase 4 全 6 Step (4-0 を含む) を経て、orchestration-engine が「設計 → 実装 → 検証 → フィードバック反映」の完全なサイクルを完走した。本 Episode は Phase 4 の幕引きとして、各 Step を簡潔に振り返る。

| Step | Issue | PR | 主成果 |
|---|---|---|---|
| 4-0 | [#81](https://github.com/stlwolf/ai-development-hub/issues/81) | (#82) | PJ 立ち上げ、scope/goal 確定、`projects/orchestration-engine/` 配置 |
| 4-1 | [#84](https://github.com/stlwolf/ai-development-hub/issues/84) | (#85, #86) | envelope schema + dispatcher 骨格 (Bash + jq)、3 ADR 確定 |
| 4-2 | [#87](https://github.com/stlwolf/ai-development-hub/issues/87) | [#88](https://github.com/stlwolf/ai-development-hub/pull/88) | 成果物パース + 状態管理 (`lib/capture.sh` + KVS schema)、wez pane 統合 |
| 4-3 | [#89](https://github.com/stlwolf/ai-development-hub/issues/89) | [#94](https://github.com/stlwolf/ai-development-hub/pull/94) | 検証ゲート v1 (adversarial review、`lib/verify.sh` + pane-keyed verification map)、ADR `verification-gate-design` |
| 4-4 | [#95](https://github.com/stlwolf/ai-development-hub/issues/95) | [#97](https://github.com/stlwolf/ai-development-hub/pull/97) | 実 agent (cursor-agent + claude) で 1 サイクル E2E 完走、ADR `reviewer-output-file-redirect` |
| 4-5 | [#103](https://github.com/stlwolf/ai-development-hub/issues/103) | (本 PR) | architecture-sketch.md frozen 化 + Phase 4 完了報告 + Phase 5 direction KickOff(draft) + Epic #19 close |

### Phase 4 の主要数値

- ADR 5 件 (Step 4-1 × 3、Step 4-3 × 1、Step 4-4 × 1)
- Episode 17 件 (Step 4-0 〜 4-5 ごとに 1〜13 件)
- Discussion 5 件 + KickOff 5 件 + Plan 5 件 (Step 4-1 〜 4-5 各 1 セット、Step 4-0 は Plan なし)
- mock テスト assertion 306 件 (8 suite)、shellcheck クリーン
- 派生 Issue 7 件 (open、MVP 後拡張候補)

### Phase 4 を通じて経験的に確立したパターン

- **駆動層 doc の 5 段サイクル**: Discussion → KickOff → Plan → Episode → ADR を Step 単位で 5 回連続成立 (Step 4-1 〜 4-5)
- **so-compare の 2 段階投入**: 実装前 (Plan stage) と実装後 (Implementation stage) で codex + claude を投入 (Step 4-3 から定着、Step 4-4 で grouping ミス検出に直接寄与)
- **検証 (Verification) と検証 (Validation) の分離**: engine の構造判定 (audit/KVS) と人間の意図確認 (Episode/ADR) を別経路で記録
- **mock + 実機の二段階テスト**: mock は構造的整合性、実機 smoke は viewport/wrap/timing 等の現実依存をカバー

### Phase 4 の限界 (Phase 5 以降への申し送り)

- **ゴール / 用途が未確定** (Phase 5 direction KickOff §6): orchestration-engine の真の用途 (本リポジトリ内 dogfood / 他プロジェクト導入 / Harness Engineering 寄与 / Negative Knowledge 基盤 / その他) が選択されていない
- **派生 Issue 7 件が open**: 本質性で仕分けて着手する方針 (Phase 5 direction KickOff §6.2)
- **single target pane / Compliance Review only / mock 限界対応**: 機能拡張の余地は明確だが、ゴール確定後に優先順位を仕分け

---

## 観察と学び (Step 4-5 固有)

1. **駆動層 doc 主導で Phase 4 全完走できた**: Step 4-1 〜 4-5 の 5 Step 連続、Discussion → KickOff → Plan → Episode → ADR のサイクルが破綻なく回った。ツール間引き継ぎ (Cursor → Claude Code) も driving layer doc のみで成立 (Step 4-3 / 4-4)。これが orchestration-engine 自体の主要 utility の一つ
2. **architecture-sketch を frozen 化したことで synthesis/ 全体が真の frozen に**: synthesis/ ディレクトリ内で「architecture-sketch だけが更新される」非対称性を解消、Phase 3 = synthesis、Phase 4 以降 = engine/docs の棲み分けが明確化
3. **Phase 5 方向感を独立 KickOff(draft) に切り出したことで Step 4-5 のスコープ純度が保たれた**: user 指摘「ディスカッションというよりかはキックオフに近い」を反映、Discussion 補遺案を棄却。QDD のスコープ純度は意識的に守る価値があると確認
4. **Epic close 直前で派生 Issue 7 件 (open) が backlog として可視化された**: §11.4 + Phase 5 direction KickOff §6.2 で本質性仕分けポリシーを記録。Phase 5 着手時に「何を優先するか」の判断材料が整った
5. **「ゴール未確定」を明示的に独立論点化したことで Phase 5 着手判断の前提条件が明確になった**: Phase 4 完了直後の自然な傾向 (= 派生 Issue 消化に流れる) を抑制、ゴール定義 Discussion を Phase 5 着手前にやる方針を確立

## 関連リンク

- Discussion: [`2026-05-18-discussion-step-4-5-architecture-sketch-feedback.md`](../discussions/2026-05-18-discussion-step-4-5-architecture-sketch-feedback.md) (status: closed)
- KickOff (Step 4-5): [`2026-05-18-kickoff-step-4-5-architecture-sketch-feedback.md`](../plans/2026-05-18-kickoff-step-4-5-architecture-sketch-feedback.md) (status: confirmed)
- Plan: [`2026-05-18-plan-step-4-5-architecture-sketch-feedback.md`](../plans/2026-05-18-plan-step-4-5-architecture-sketch-feedback.md) (status: ready)
- Phase 5 direction KickOff: [`2026-05-18-kickoff-phase-5-direction.md`](../plans/2026-05-18-kickoff-phase-5-direction.md) (status: draft)
- 更新対象 architecture-sketch: [`../../../orchestration-research/synthesis/architecture-sketch.md`](../../../orchestration-research/synthesis/architecture-sketch.md)
- Step 4-4 Episode (フォーマット参考): [`2026-05-18-episode-step-4-4-implementation.md`](2026-05-18-episode-step-4-4-implementation.md)
- Phase 4 ADR 5 件: [`docs/decisions/`](../decisions/)
- 派生 Issue 7 件: [#92](https://github.com/stlwolf/ai-development-hub/issues/92) / [#93](https://github.com/stlwolf/ai-development-hub/issues/93) / [#98](https://github.com/stlwolf/ai-development-hub/issues/98) / [#99](https://github.com/stlwolf/ai-development-hub/issues/99) / [#100](https://github.com/stlwolf/ai-development-hub/issues/100) / [#101](https://github.com/stlwolf/ai-development-hub/issues/101) / [#102](https://github.com/stlwolf/ai-development-hub/issues/102)
- Epic [#19](https://github.com/stlwolf/ai-development-hub/issues/19) (本 PR で close)
