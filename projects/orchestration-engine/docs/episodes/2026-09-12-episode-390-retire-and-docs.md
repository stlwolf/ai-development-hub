---
id: "01M2ASD0XX4THEK3ZJJ97VC4Q8"
title: "統括の計画的な交代を verb にする — 残りの実装（retire と文書）"
date: 2026-09-12
type: episode
status: draft
related:
  - type: derived_from
    ref: "projects/orchestration-engine/docs/plans/2026-09-12-plan-390-retire-and-docs.md"
    reason: "この episode が記録する単位の plan"
  - type: reference
    ref: "projects/orchestration-engine/docs/episodes/2026-09-11-episode-390-supervisor-planned-succession.md"
    reason: "PR-1（prepare と状態収集）と PR-2（take と start と交代イベント）の記録。設計の経緯・ゲート1 と2 の軌跡・実測値はそちらにある"
tags: [orchestration-engine, succession, cockpit, retire, handoff]
---

# 統括の計画的な交代を verb にする — 残りの実装（retire と文書）

## なぜこの作業が始まったか

統括セッションは context を使い切るたびに交代するが、その工程は 14 代にわたって手作業だった。owner が「一つの指示で明確にフローが決まっていて、確実に引き継げる」形を求め（2026-09-11）、#390 で verb にする作業が始まった。`prepare`（状態を集めて引き継ぎ文書を書く）と `take`（後継が席を取る）と `start`（後継のペインを起こす）は着地または着地待ちで、**残っているのは `retire`（前任を閉じてよいかを判定して閉じる）と文書と受入である。**

この episode はその残りを記録する。**前の episode を引き継ぐのではなく、別の単位として立てた**理由は次のとおりである。

## この episode が別に立っている理由

当初は1本の episode で PR を4本またぐ予定だった。`document-format.md` は committed 層の plan を「実装の最初の PR と一緒に着地させる」と定めており、**1本の plan と episode を4つの PR にまたがらせた時点でその形が壊れていた**（着地した文書が後続の PR で変わり続ける）。owner の裁定（2026-09-12）で残りを1つの PR にまとめることになり、plan も episode もこの単位で立て直した。

- 前の episode は PR-1 と PR-2 の記録として `stable` で閉じてある。
- **設計の経緯（DJ-1 から DJ-12）・ゲート1 と2 の軌跡・棄却した案・実測値は、前の plan と前の episode が正本である。** ここには写さない。
- この episode に書くのは、`retire` と文書と受入の作業で新しく起きたことだけである。

## 作業の記録

（着手時はここから追記する。着手は PR #393 が master へ着地したあと。）
