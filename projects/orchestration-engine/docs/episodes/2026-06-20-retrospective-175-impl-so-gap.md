---
id: "01KVHY0HCHF3W76B8W24PD6TVX"
title: "#175 追記振り返り — 実装SO 未実施とゲート記述の不整合（記録のみ・元 episode/コードは非修正）"
date: 2026-06-20
type: episode
status: stable
related:
  - type: refines
    ref: "projects/orchestration-engine/docs/episodes/2026-06-20-episode-175-spawn-layout.md"
    reason: "元 #175 closure episode の SO ゲート記述の不整合を、修正せず追記で正確化する"
  - type: relates_to
    ref: "https://github.com/stlwolf/ai-development-hub/pull/192"
    reason: "本件の対象 PR（merge 済）"
  - type: relates_to
    ref: "https://github.com/stlwolf/ai-development-hub/issues/24"
    reason: "実装SO の機械ゲート化は hook 自動注入（hard 層）と同族・routing 先候補"
tags: [orchestration-engine, retrospective, so-gate, process, negative-knowledge]
---

# #175 追記振り返り: 実装SO 未実施とゲート記述の不整合

> `reconstructed` / addendum: 本ノートは #175 closure 後にユーザー指摘で判明した不整合を **記録するための追記**。元 episode（`2026-06-20-episode-175-spawn-layout.md`）と確定コード（`4426f17`）は **意図的に修正しない**（ユーザー指示）。SO ゲートに関しては本ノートが正確な参照。

## なぜ書くか

#175 の engine SO ゲート充足の記述が不正確だったとユーザー指摘で判明。honesty のため、**実際にやっていない部分を正確に参照して残す**（コード・元 episode は変更しない）。

## 正確な事実（やったこと / やっていないこと）

- **実施した SO = 設計SO のみ・2 回**:
  - oe-refute run1: audit_id `20260620043537W4YCNF4DJ0HS` / `--rubric exploration` / **実装前** / claim=案C
  - oe-refute run2: audit_id `20260620044126WKFA3FJSZ8K2` / `--rubric exploration` / **実装前** / claim=案C+
  - いずれも **design/breadth レンズ（option-expansion つき）= 設計SO**。
- **実装後にやったこと**: `shellcheck` / テスト（bash 5.2.37・forced 3.2.57）/ kill-switch smoke。= **自己検証**であって外部SOではない。
- **やっていない**: **実装SO（実コードの欠陥検出レンズ・option-expansion なしの `so-compare`）を PR 前に回していない**。
- 結果: 実コード欠陥 **C1**（`oe_board_apply` の partial 分岐が rc 早期 return で dead code）は **PR 後の Copilot が捕捉**。実装SO を省いた穴が後段ゲートに流れた構図。

## 不整合の所在（元 episode のどこが過大か・修正はしない）

- 元 episode「status」の *「engine 運用ゲート（Episode + so-compare = oe-refute 2 本）通過 ✓」* は、**その 2 本が両方とも設計SO**である事実を明示せず、ゲート充足を過大に書いた。
- 「ゲートと SO」節も *"heavy: 意図起動の oe-refute 2 本"* とだけ書き、**実装SO 不在に触れていない**。
- engine 標準（`[[feedback_engine_driving_layer_flow]]` / cockpit memory・#176 確定）は「**設計so+実装so の両方**・設計soだけで実装soを省略しない」。本作業は **設計SO のみ**で標準から逸脱しており、元 episode はこの逸脱を記載していない（選択的省略に近い）。

## kickoff は義務を伝えていたか（自己遵守ミスの確認）

- **伝えていた**。kickoff（`.oe/2026-06-20-kickoff-175-spawn-layout.md`）:
  - L19: 「engine 作業の規律（**設計/実装のゲート**等）も同様に適用」＋「**プロジェクトの標準に従う**」
  - L21: 「設計判断（DJ）と**検証（SO 等）の証跡**を PR / ドキュメントに明示する」
- 逐語の「実装SO をやれ」というステップは無い（HOW は標準に委任）が、**"実装のゲート" を名指し＋標準参照**で実装SO の義務は伝わっていた。→ kickoff の曖昧さではなく **私（実装子）の自己遵守ミス**。

## 機械化の方向（ブレスト結論・routing のみ・本ノートでは実装しない）

- 失敗の本質は「SO が走ったか」でなく「**実装SO（code-defect レンズ）が走ったか**」を見る必要がある点。現状 `oe-refute` は exploration レンズのみ → **実装SO を識別可能な独立アーティファクト化**（例: rubric=impl の audit イベント）が前提。これが無いと「SO 走った」だけ見るゲートは本件を **誤通過**させる。
- enforcer 案: `gh pr create` を **PreToolUse hook** で artifact 不在なら deny（`hypothesis-gate`(#78) / `block-destructive` と同機構）。**doer=skill/verb（ergonomic）× enforcer=hook（外せなさ）の役割分離**。
- **非対称**: 設計SO=advisory 据え置き、**実装SO だけ hook**。スコープは projects/engine 限定（共通 canonical rule には上げない）。
- 較正注意: **コードに触る diff のときだけ発火**（docs-only PR では発火させない）。限界: hook は「**走った**」を保証するだけ（質は Copilot/人）。
- routing: 探索 hard 層 defer（#24 hook 自動注入 / #159 start-side / #185 lifecycle）と同族 → **#24 の sub か新 issue 候補**。do-nothing/defer も正当（#177 観測後に駆動率で判断）。

## 蒸留シグナル

- **negative knowledge**: 「**SO を回した ≠ 必要な SO を回した**」。設計SO と実装SO はレンズが別物で、設計SO 完了は実装SO を代替しない。closure で「so-compare 通過」と書くときは **どの種類の SO か（rubric）を明示**しないと過大記述になる。
- **プロセス**: 実装SO の **機械ゲート化**（artifact 識別 → PR-create PreToolUse hook・非対称・projects 限定）は検討候補。昇格は %32/人の判断。

## status

記録のみ（stable）。元 episode・コードは **意図的に非変更**。本ノートが #175 の SO ゲートに関する正確な参照。Step4 外部チェックは本追記の性質（自己申告の honest 訂正・低リスク・コード非変更）につき不要と判断。
