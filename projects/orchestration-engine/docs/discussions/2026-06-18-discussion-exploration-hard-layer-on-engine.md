---
id: "01KVB99PWPZY3NCZJN22KKSX15"
title: "探索クラスタ hard 層 × cockpit/engine substrate（クロスセッション・ラリー統合）"
date: 2026-06-18
type: discussion
status: draft
related:
  - type: design_context
    ref: "https://github.com/stlwolf/ai-development-hub/issues/169"
    reason: "CLI cockpit 傘 Issue。本 substrate（spawn/verify/観測/盤面）の親トラック"
  - type: design_context
    ref: "https://github.com/stlwolf/ai-development-hub/issues/24"
    reason: "hook 自動注入 = Stage C 決定論トリガの landing 点"
  - type: design_context
    ref: "projects/orchestration-engine/README.md"
    reason: "engine MVP（spawn=生成 / verify=反証 / monitor / circuit breaker / state KVS / audit）= hard 層を載せる substrate"
---

# 見取り図: 探索クラスタ hard 層 × cockpit/engine substrate

> 出自: CLI cockpit セッション（%16）⇄ 探索原則クラスタ統括セッション（%3）のクロスセッション・ラリー（turn1-6, `oe-send` ＋ 駆動層 doc ポインタで往復）を統合・清書したもの。揮発スクラッチ（`/tmp/rally-explore-cockpit/`）から駆動層へ昇格保存。
>
> **これは合意済みの実行計画ではない。**「やるか/どこまで/どこにぶら下げるか」はユーザー決定事項（末尾★）。

---

## 1. 何が分かったか（ラリーの核）

- 探索原則クラスタ（#75/#161/#76/#77/#78）は**完了・クローズ済み**。soft 層（傘原則＋軟床＋so-compare＋設計/バグ調査の両層2）は landed。
- 意図的に defer したのは **hard 層＝「確定をモデルに委ねず決定的に止める」機構**。
- 確定した接続: **orchestration-engine MVP（Phase4 稼働中）が hard 層を載せる substrate**。cockpit(#174-179) は「自動同梱」でなく「載せられる土台を整える」レイヤ。
- **認識訂正（重要）**: 生成/反証の物理分離は engine MVP に**既にある**（spawn=生成 / verify=別 reviewer spawn）。#77/#78 設計時にこれを hard・defer に丸めたのは過剰 defer。よって「分離」は新規実装でなく**既存 substrate の形式化**。
- 残る真の欠落は2つ: **(B) 収束/差分の確定的判定**（thesis 核心「収束をモデルに委ねない」）と **(C) 決定論トリガ**（landed skill/hook は全て advisory）。

## 2. 3 ステージ見取り図（engine 列＝cockpit 確定 / skill 列＝探索 確定）

| Stage | engine 側（cockpit 所有） | skill 側（探索 所有） | 依存/前提 | コスト |
|---|---|---|---|---|
| **A: 反証 verb** | `oe-refute --claim <doc> [--lanes N] [--rubric consensus\|exploration]` → `{verdict, reason}`。既存 spawn+capture+verify の薄ラッパー。state/audit 記録 | ① claim doc 入力契約（#77 `tmp/dj-*` / #78 `tmp/hypothesis-NNN.md` → verb 入力）② verdict を確定時 artifact にその場で書き戻し ③ so-compare 呼び → `oe-refute --rubric exploration` の1行差し替え | **なし（既存 MVP に今乗る・#175/#174 非依存）** | 小 |
| **B: verify-gate-reject**（新 engine issue） | reject 条件（収束未達/差分ゼロ/反証多数）を rubric 述語化。audit に探索メトリクス emit `{refute_rounds, converged, reject_reason, breadth_axis5, grounding_axis3}` | skill 側の「収束未達なら確定保留」分岐を verb verdict に委譲 | (b)拡張可能 verify ＋ (c)#177 | 中 |
| **#177 instrument/観測** | B が emit したメトリクスを read-only 表示。before/after 測定経路。LOGIC は載せない | クラスタ soft 層の実効を before/after で測る | B とセット | 小〜中 |
| **C: 決定論トリガ #24** | hard ゲート hook を engine run-context で spawn 子に決定論発火 | hypothesis-gate/skill の「確定の瞬間に発火」を advisory→決定論へ昇格 | (a)検証済みトリガ（asyncRewake/PostToolUse-context の spot-check） | 大 |

- verdict は**共有エンベロープ `{verdict: refuted\|survived, reason}` 固定 ＋ rubric プロファイル差し替え**。`consensus`=so-compare 流用（問題認識/方針/リスク）、`exploration`=breadth(軸5)/grounding(軸3) 第一級。探索の問いは「合意」でなく「探索を尽くしたか」なので軸が違う。
- gates: 各 engine issue は Episode + 設計SO + 実装SO（engine フロー）。

## 3. hard 着手の受け入れ条件（探索クラスタ視点）

- (a) 検証済みの決定論トリガ（#24 or engine run-context が確定局面で注入できる）
- (b) 拡張可能な verify ゲート（収束未達/差分ゼロ/反証多数で reject を表現）
- (c) 効果測定経路（#177 で hard が実際に探索品質を上げるか before/after 観測）
- → **Stage A は (a)(b)(c) 無しでも今着手可**（既存 substrate の形式化）。B は (b)(c)、C は (a) が前提。

---

## ★ ユーザー決定事項（whether-to-act がまず先）

1. **やるか / 後回しか / 見送りか**（decision-pacing）。Stage A/B/C は選択肢であって着手前提ではない。
2. **どこまでやるか**。推奨: **Stage A だけ先に着手 → #177 整備後に効果を測ってから B/C を判断**（incremental ＋ 効果未検証と整合。A/B/C を一括コミットしない）。
3. **新 issue のぶら下げ先**。ここで生まれる新 issue（`oe-refute` / verify-gate-reject）は **engine トラックの issue**。**探索クラスタの「実装で新 issue を増やさない」ポリシー（#77/#78・ユーザー決定）とは別物**（探索クラスタは完了・クローズ済み）。帰属先は cockpit 傘 #169 か engine 用の新グルーピングか — #19(engine Epic) は close 済みで空いている。
4. **効果はまだ未検証**。soft 層の実効は未測定。hard の価値は「測ってから」が筋（#177 が測定経路＝(c)条件）。

## 分担（着手するなら）

- **engine（cockpit）**: `oe-refute` verb 実装、verify-gate-reject issue、#177 instrument、#24 配線。
- **skill（探索）**: 確定前 forcing → engine step マッピング、verdict→確定時 artifact 書き戻し、skill 参照差し替え、限界記述の更新。
- 疎結合: skill は既に「hard は engine/#24 待ち」と limits 明記済み → engine が verb を出したら参照差し替えで接続。

## ユーザー判断の結果（2026-06-18）

- **Stage A に着手**（推奨どおり）。**B/C は #177 測定後に判断（保留）**。
- 新 issue は **#169 配下**にぶら下げる。
- 実行は**子セッションに委譲し PR まで自律 → 親レビュー → 人が手順検証**（オーケストレーション検証の継続）。
