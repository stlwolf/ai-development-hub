---
id: "01KXB7Z05HKKG5PRCH5G48PNXM"
title: "#250 episode — #238/#239 proposal 群の蒸留昇格（昇格規則の初回実地サンプル・設計SO で過剰 prune を是正）"
date: 2026-07-12
type: episode
status: stable
related:
  - type: task_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/250"
    reason: "本 episode が記録するタスク（昇格漏れの一回性掃除・昇格規則の初回適用）"
  - type: pull_request
    ref: "https://github.com/stlwolf/ai-development-hub/pull/252"
    reason: "蒸留成果の PR"
  - type: promotion_rule
    ref: "https://github.com/stlwolf/ai-development-hub/issues/249"
    reason: "本 episode の『何を残し何を落としたかの判断基準』が v2 昇格規則の材料"
  - type: distilled_doc
    ref: "projects/orchestration-engine/docs/discussions/2026-07-12-discussion-238-239-succession-watchdog-design-rationale.md"
    reason: "昇格先の discussion doc"
tags: [orchestration, distillation, promotion, succession, watchdog, episode, closure, reconstructed]
---

# #250 episode — proposal 群の蒸留昇格（昇格規則の初回実地サンプル）

> **reconstructed**: 本 episode はリアルタイム追記でなく、作業完了後（PR #252 作成後・マージ前）に再構成した。追記ログと同じ証拠価値は持たない。

## Context（なぜこの作業が始まったか）

ドキュメントフロー棚卸し（`2026-07-12-discussion-doc-flow-stocktake.md`・DJ-2）で「設計級コンテンツが gitignored な作業層に生まれたら蒸留フローへ昇格する義務」を規約化した。その **初回実地適用**が #250 — #238/#239 の設計 proposal 3本（`.oe/` 滞留）の未蒸留分を committed discussion へ移し、git の外に設計級コンテンツを残さないようにする。plan-first ゲート付きで親統括 `%173` から委譲された。

## 次の消費者

- **#249（v2 昇格規則）の設計者**: 本 episode の「[判断基準](#昇格判断の基準-249-材料)」節が、昇格の include/exclude ルールを明文化する材料。
- **docs/#238 worktree を掃除する親/owner**: [残課題](#残課題--follow-up-routing)の dead-pointer 判断（掃除前）。
- **将来の蒸留担当（別 proposal 群）**: 「既 committed との差分で未蒸留を判定する」手順の先例。

## 何が起きたか（事実・失敗・転回）

- **plan-first**: source 3本 + decision doc ×2 + 棚卸し §6.1 + 既 committed 群（episode ×4・PR-B plan・merged PR）を読み、`.oe/plan-250-distill.md` に include/exclude 表を書いて STOP・親へ報告 → 承認。
- **核心発見（scope を規定）**: proposal 執筆（7/9）後に段階1（PR-A/B/C=#245/#246/#244）が着地し、**plan-stage1 の実装内容は code 化・既 commit・一部 supersede で吸収済み**だった。特に plan-stage1 の看板根拠「beat-staleness=プロセス死検知」は後段の PR-B 設計SO（audit `20260710165558WHKWV6XCJXXA`）に反証され「death=tmux確定gone」へ転回済み。→ kickoff の文言（「proposal 2本 + plan-stage1 の未蒸留分」）より狭い arch レベルへ scope を純化する判断を親へ確認し、承認された（親が A/B/C を committed source と fact-check）。
- **設計SO で過剰 prune を捕捉（失敗の是正）**: 弱 `oe-refute` exploration 3レーン（audit `20260712130417P0X8CSTCK5D5`）が **refuted**。claude/cursor が material に「過剰 prune」を指摘、**codex はレーン error（partial）**。最も刺さった指摘: **蒸留計画 §4.1 で「残す」と確定した段階ロードマップ（段階0-3/PR-1..10）を、成果物 doc に silently 落としていた**（plan と成果物の自己不整合）。しかもそのロードマップには committed 側から宙吊り参照（段階0 episode「PR-9 候補据え置き」）があり、PR-9 が何かは gitignored proposal でしか解決できなかった。→ §3.4 を追補し宙吊り参照を解決。加えて round findings の durable substance 追記・前提修正（「decision doc は結論のみ」は不正確）・重複箇所の pointer 化を反映。弱SO ゆえ 1周で reconcile・iterate せず。

## 決定と根拠（棄却した案と棄却理由）

- **arch レベルに純化・plan-stage1 を再蒸留しない**（採用）: 実装内容は merged code + PR 各 doc に既出・一部 supersede。再蒸留は全文転写かつ古い前提の復活になる。棄却した対案 = 「kickoff 文言どおり plan-stage1 も蒸留し直す」→ 重複生産で昇格の意味（滞留解消）に反する。cursor レーンはこの再蒸留省略を refute したが、claude レーンが一次で scope の妥当性を confirm し、owner も承認済のため維持。ただし cursor の指摘した **dead-pointer 残件は正当**として §6.1 に surface。
- **discussion 型を選択**（decision/episode でなく）: 出力は「探索・却下・軌跡」＝ 確定でも実行記録でもない。DJ-6（設計判断が多い→discussion）に整合。

## <a id="昇格判断の基準-249-材料"></a>昇格判断の基準（#249 材料）— 何を残し何を落としたか

本タスクで実際に使った include/exclude の判断規則。#249 v2 昇格規則の骨子候補:

- **落とす①（既出）**: 既 committed（decision / episode / merged code / PR plan）に要旨が既出なもの。要旨の重複は昇格価値ゼロ。
- **落とす②（supersede）**: 後段の作業で反証・上書きされた根拠（例: beat-staleness=プロセス死）。**残すと古い前提を復活させ読者を誤導する**ため、supersede は「既出」より強い drop 理由。
- **落とす③（boilerplate/全文）**: test 方針・config 詳細・link list・verification 凡例・全文転写。durable な「なぜ」を含まない。
- **残す①（committed にゼロか要約のみ + durable）**: 代替案の全体像・却下ロジック・探索の軌跡・divergence の reconcile 記録。decision doc が結論に圧縮して落とす「why-not」。
- **grounding は自己申告でなく実証**: 「committed に無い」は **grep で欠落を実証**（audit id 不在・grep ヒットゼロ）してから残す/落とすを決めた。蒸留者の自己判断だけに寄せない。
- **境界の nюanс（SO が修正させた）**: 「decision doc は結論のみ」は不正確 — decision は結論 + 要約根拠を持つ。よって「重複させない」は **重なる結論を pointer 化し、探索・却下の側の詳細のみ残す**という運用に落ちる。全否定でも全転写でもない中間。
- **include 判断と成果物の突合が要る（今回の失敗）**: 計画で「残す」と決めたブロックを成果物で落とすと過剰 prune になる。**include/exclude 表 → 成果物の逐次突合**を昇格規則の checkpoint にすべき（今回は SO が代替したが、機械突合できると強い）。

## わかったこと（W）

- 蒸留は「source → 成果物」の一方向でなく、**source 執筆後に committed 側が進む（実装着地・後段 SO）と未蒸留分が縮む/supersede される**。→ 未蒸留判定は必ず「現時点の committed との差分」で行う（source を単独で読むと過剰蒸留する）。
- 蒸留物にも設計SO は効く。本件は「探索の de-converge を記録する doc」自身が設計SO で de-converge された（過剰 prune → 是正）＝ メタに一貫した構図。

## 蒸留シグナル（昇格候補）

- **skill/rule 昇格候補**: 上記「昇格判断の基準」は #249 v2 昇格規則へ直接投入する（消費者=#249 設計者）。単発でなく規則化の材料ゆえ routing 先あり。
- Decision 昇格: なし（本件は既存 decision の裏の探索記録であり、新規決定ではない）。
- negative knowledge（#62）候補: 「計画 include 判断と成果物の突合漏れ＝過剰 prune」は転用可能な anti-pattern だが、まず #249 規則の checkpoint として扱う（重複注入を避ける）。

## 残課題 / follow-up routing

- **committed 側の plan-stage1 dead-pointer**（設計SO cursor が surface）: decision `:109` / PR-B plan `:40` / board-schema decision `:137` が gitignored `plan-stage1.md` を「詳細と根拠」正本として参照 → docs/#238 掃除で dead-end 化。**行き先 = discussion doc §6.1 + PR #252 本文に surface 済み。掃除前に owner が (a)移す/(b)張替/(c)許容 を判断**（本 PR では実装しない）。
- **docs/#238 worktree + branch の掃除**: 本 episode の蒸留 merge 後、per-file 昇格確認 + 上記 dead-pointer 判断を経て **親/owner が実施**（HG）。子（本タスク）はやらない。
- 「追わない」宣言: plan-stage1 の Q3-Q8 実装根拠の完全移設は追わない（owner 承認 scope 外・PR 各 doc に分散 committed 済み。ただし dead-pointer 判断で覆りうる）。

## status

- **stable** / 達成度: **達成**（未蒸留の arch レベル設計級コンテンツを committed discussion へ昇格・設計SO 通過・PR #252 landing）。#250 の core（滞留解消）は達成、worktree 掃除は親/owner の残タスク（keep-open せず、掃除は別 HG アクション）。

## Step4（heavy tier 外部チェック）

Step4 辞退: 本サイクルで既に意図的な設計SO（`oe-refute` 3レーン）を doc に当て、その **refutal・reconciliation・partial（codex error）を本 episode に選択的省略なく記録**した / 既存チェックで覆った観点: 省略チェック（SO refutal を「何が起きたか」headline に明示）・routing 網羅（dead-pointer/掃除/追わない宣言に全て行き先）・evidence anchor（audit id 3件 + committed パスを本文転記・揮発 tmp/ 依存なし）・back-propagation（dead-pointer を doc §6.1 + PR へ反映） / 未実施観点と判断: なし（4観点すべて低リスクで本文が自己完結。closure 品質の追加 so-compare は同サイクル SO と重複ゆえ辞退）。最終的な external eyes は親 `%173` の HG レビューが担う。

## 形式メモ（効果測定・#113）

- チャネル骨格で拾えたもの: 「決定と根拠（棄却案）」「蒸留シグナル（routing 先あり）」が #249 材料として自然に埋まった。
- 拾えなかったもの: 特になし。「昇格判断の基準」は標準セクション外の追加見出しにしたが、これが本 episode の主成果。
- 皮（KPT/YWT）: 使わず（出力型セクションで足りた）。
- 摩擦: 低〜中。SO 反映で doc 修正 6箇所 + episode 再構成。heavy の Step4 辞退定型で摩擦を抑えた。
