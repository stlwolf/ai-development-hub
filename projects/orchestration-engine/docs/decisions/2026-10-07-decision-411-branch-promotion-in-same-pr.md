---
id: "01M4AEC4GBWY16MKCRRVDMRKZ9"
title: "枝の作業から出た昇格は同じ PR に入れてマージ前に着地させる — ゲート6 の昇格は作業層に残ったものに絞る"
date: 2026-10-07
type: decision
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/411"
    reason: "本 decision が記録する owner の裁定（2026-10-07）と、仕様・スキルの文面をそろえた単位"
  - type: derived_from
    ref: "projects/orchestration-engine/docs/discussions/2026-07-12-discussion-doc-flow-stocktake.md"
    reason: "DJ-2（作業層の昇格義務）と DJ-8 の (6)（merge 後の昇格判定）。本 decision は DJ-8 の (6) の昇格を作業層に残ったものに絞る。DJ-8 の本文は書き換えず、同 discussion の末尾の追補から本 decision を指す"
  - type: modification_target
    ref: "canonical/orchestration-spec/document-format.md"
    reason: "「ゲート配置」節（表の行5・行6・plan の着地先）と「昇格義務」節（判定タイミング・1行版）を本 decision に合わせて書き分けた"
  - type: reference
    ref: "docs/harness/episodes/2026-10-07-episode-411-promotion-timing-in-pr.md"
    reason: "上流の断定の裏取り・canonical 全体の洗い出し・実装SO の記録。本 decision は durable な判断に絞る"
  - type: reference
    ref: "docs/harness/plans/2026-10-07-plan-411-promotion-timing-in-pr.md"
    reason: "直した箇所ごとの前後の文面と、変更前に落ちて変更後に通る受入の検査"
  - type: evidence_for
    ref: "https://github.com/stlwolf/ai-development-hub/issues/288#issuecomment-5628399099"
    reason: "hub での実例。子が「判定までが closure の担当で、実行はゲート 6」と書いて decision を PR に入れず、マージと掃除のあとで発覚した"
  - type: evidence_for
    ref: "projects/orchestration-engine/docs/decisions/2026-09-11-decision-watchdog-outside-session.md"
    reason: "上の実例で、本体の PR に入らず後から別に入った decision"
  - type: evidence_for
    ref: "docs/orchestration-engine/episodes/2026-08-07-episode-288-promotion-slot.md"
    reason: "「実行は定義上マージ後」を前提の1つにして、required に行き先を足す案を退けた判断。本 decision でこの前提が枝の作業から出た昇格について崩れる"
  - type: future_hook
    ref: "https://github.com/stlwolf/ai-development-hub/issues/305"
    reason: "作業層に残った昇格と catch-all の実行主体の置き場。本 decision は決めていない"
  - type: future_hook
    ref: "https://github.com/stlwolf/ai-development-hub/issues/288"
    reason: "2026-08-07 の判断の見直し（推奨のみ・本 decision の「結果」節）"
tags: [doc-flow, promotion, decision, gate-5, gate-6, pr-package]
---

# 枝の作業から出た昇格は同じ PR に入れてマージ前に着地させる

## コンテキスト

`document-format.md`「昇格義務」節の判定タイミング (2) は、v2（2026-07-13）から「昇格の実行は §11 ゲート6（merge 後の後始末）＝ worktree 掃除の前に行う」と書いていた。この文の元の動機は、棚卸し discussion（2026-07-12）の DJ-2 と §5 の「実害」(1) である。作業層（`.oe/`）にだけ生まれた設計級の文書が、どの PR にも入らずに git の外に滞留していた。(2) はそれを掃除の前に救うための文で、枝の作業から出た decision をいつ PR に入れるかは決めていなかった。同じ discussion の DJ-8 も、ゲート6（merge 後）に「昇格判定」を置いていた。

ところが字面は「昇格の実行はマージ後」なので、枝の作業から出た decision にもそう読めた。委譲の固定節の昇格規則と 1行版も「closure・worktree 掃除の前に」と書いており、掃除はマージ後なので、マージ後の別 PR を許す字面だった。その結果、次の3回が起きた。

- hub: #336 の委譲子が closure の報告に「判定までが closure の担当で、実行はゲート 6」と書き、`required` と判定した decision を本体の PR に入れなかった。統括はその報告を通し、owner がマージし、統括が worktree を消したあとで owner が「なぜ PR に含めなかったのか」と指摘した。decision は後から別に入った。
- 別リポジトリで2回（統括が先方の PR の中身で確かめた）。1回は、マージの後に decision を入れるための別 PR が立った。もう1回は、統括が同じ読みで「decision はマージ後」と提案し、owner に是正されて本体の PR に decision が入った。

knowledge（negative knowledge の item）は、`episode-retrospective` の収穫フローで既に「in-PR 相乗りが既定・後で別途にしない」と決まっていた。decision だけが取り残されていた。

## 決定

owner は 2026-10-07 に次のように裁定した（別リポジトリの統括のセッションへの直接入力・原文のまま）。

> だからディシジョンは最終的にマージされる前に決定されるだけの話だけど、コンポーネントフローとしては正式にはマージ前だよ。だって分離したら意味なくね？いや、単独でそのPRと関係ないところから生まれたのは当然マージされた後なんだけど、マージされたタイミングで昇格のポイントが出てるんだから、ブランチの作業内でそこに含まれてないとパッケージとしてはおかしいでしょう。つうかそれ普通にやってたんだけど、なんでそこたまにそうなるんだよ。その書き方だと変なルールになるな。

これを受けて、昇格を出どころで2種類に分ける。

- **枝の作業から出た昇格**: その枝の作業（plan・episode・closure と、枝の作業で使った作業層の文書や `tmp/` の証跡）から出た設計級 / durable なもの。**遅くともマージ前に、同じ PR に入れる。** 実行するのはその枝の担当（委譲なら子）である。一次の錨は判断が生まれたその場に置く印で、その場で書いてよい。closure（ゲート5）の昇格の判定は最後の確認にあたる。別 PR に分けてよいのは、owner が明示的にそう裁定したときだけである。
- **作業層に残った昇格**: どの PR にも紐づかずに作業層に残ったもの。枝を持たない作業で生まれたものと、枝の作業から出た昇格の取りこぼしが入る。ゲート6 で worktree 掃除の前に拾う。取りこぼしをここで拾ったときは、それ自体が逸脱であり、昇格は別 PR になる。

**DJ-8 の (6) は覆さない。(6) の昇格判定を、作業層に残った昇格の拾い上げに絞る。**

## 根拠

- **PR は判断と根拠を一緒に着地させる単位である。** 枝の作業の中で判断が生まれたなら、その判断はその PR の一部である。decision だけを分けると、本体の PR は判断の根拠を欠いたまま着地し、decision の PR は本体の変更から切り離される。owner の言う「パッケージとしてはおかしい」はこのことである。
- **(2) の元の動機は残せる。** (2) が守ろうとしたのは、作業層にだけ在るものが掃除で消えることだった。それは作業層に残った昇格として、ゲート6 に残す。枝の作業から出たものの取りこぼしもここに入れると、#289 の事例2（ゲート6 の昇格確認を飛ばし、探索木を昇格せずに worktree を破棄した件）のような取りこぼしも、掃除の前の最後の網で拾える。
- **knowledge の先例と同じ向きにそろう。** knowledge は既に in-PR が既定である。ただし knowledge の「別 PR に分けてよい3つの条件」（heavy で単独のレビューを要する／当該 PR の scope から明確に外れる／owner が明示的に defer を指示した）は写さなかった。owner の裁定は「分けたら意味がない」であり、「heavy だから分ける」余地を残すと同じ分離がまた起きる。scope から外れるものは、定義上その枝の判断ではない。
- **実行者に名前を付ける。** owner は「それ普通にやってた」と言う。普通にやっていた側（枝の担当）に、規則の上で名前が無かった。closure のチェックリストは判定までを担う（2026-08-05 の分担）ので、実行者は closure ではなく枝の担当として書く。

棄却した案:

- **「マージ後」のまま、ゲート6 に「decision の PR を立てる」工程を足す。** owner の裁定に反する。本体と decision が別の PR に分かれ、1往復多くなる（#336 の是正がまさにそれだった）。
- **「closure で昇格を行う」と書く。** 一次の錨（印を置いたその場で書く）が弱まり、closure まで先送りされる。closure は最後の確認であって、義務を closure に移すのではない。
- **(2) を書き換えて「昇格はマージ前」だけにする。** 作業層にだけ在るもの（枝を持たない作業の産物）を拾う位置が消え、DJ-2 の動機が守れない。

## 結果

- 仕様（「ゲート配置」節の表の行5・行6・plan の着地先、「昇格義務」節の判定タイミングと1行版）、委譲の固定節（plan-first・昇格規則）と routing 表の行5・行6、`episode-retrospective`（「昇格の判定」節の対象外と `required` の行）、`unmet-gate-check`（due の表の「PR → merge」と「merge 後」の行・判定規則の例）を、2種類の名前でそろえた。どれも同じ PR に入っている。
- **#288 の 2026-08-07 の判断の前提が1つ崩れる。** その判断は、`required` に行き先を足す案を3つの理由で退けた。1つ目の「実行は定義上マージ後なので、closure 時点の `required` は常に未着地」は、枝の作業から出た昇格について成り立たなくなる。closure の時点で `required` は同じ PR に入っているか、マージ前に入るかのどちらかになるためである。2つ目（値域を閉じられない）は弱まり、3つ目（消費者に依存する欄を足す自己矛盾）は残る。見直しは #288 / #305 の側に残した（推奨のみ）。
- **#305 の論点が縮む。** 枝の作業から出た昇格の実行主体はここで決まった（その枝の担当）。#305 に残るのは、作業層に残った昇格と catch-all の実行主体である。
- **進行中の委譲は古い固定節を持っている。** マージ前に組まれた brief には「closure・worktree 掃除の前に」の文が残る。新しい規則を伝える工程と、完了前の照合の baseline の扱いは、統括がマージ後に扱う。
- **注意: 本 decision は自分自身に当てた。** 本 decision は、それが直した規則どおり、生まれた枝の PR に入ってマージ前に着地している。
