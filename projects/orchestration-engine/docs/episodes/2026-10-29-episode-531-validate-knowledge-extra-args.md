---
id: "01M61WAP4QWCVT700TR1KXNHH8"
title: "#531 validate-knowledge が2つ目以降のファイル引数を黙って捨て、1つ目だけ見て OK を出す"
date: 2026-10-29
type: episode
status: stable   # closure 2026-10-29（PR #553 の Copilot のラウンドの後・マージ前）。達成
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/531"
    reason: "本 episode の作業対象"
  - type: reference
    ref: "https://github.com/stlwolf/ai-development-hub/pull/553"
    reason: "この単位の PR"
tags: [orchestration, knowledge, validator]
promotion:
  - subject: "2つ目の対象は全件検証でなく exit 2 で拒む"
    verdict: not-required
    ref: "本文: S1: 再現と呼び出し元の確かめ（2026-10-29）"
  - subject: "対象を受け取ったかを値の非空でなく別の印で持つ"
    verdict: not-required
    ref: "本文: S2: 実装SO（弱・Codex 1レーン）の結果と採否（2026-10-29）"
knowledge_observations:
  - "01KZ21M0N0FZ4YMR2R6DPHTWQ4"
---

# #531 validate-knowledge が2つ目以降のファイル引数を黙って捨て、1つ目だけ見て OK を出す

## なぜこの作業が始まったか

2026-10-23 の orchestration-engine の実装の監査（#484）で、`validate-knowledge` がハイフンで始まらない引数を最初の1つしか使わず、2つ目以降を黙って捨てることが見つかった。`validate-knowledge <木>/knowledge/items/*.md` のように glob で渡すと、先頭の1件だけを検証して OK を出し、2件目以降の壊れた item を見逃す。

**この episode は着手時に枠を作り、作業しながら追記している。** 後追いで再構成した節があれば、その節の冒頭にその旨を書く。

## この単位の入力

- brief: 統括（cockpit 21代目）が 2026-10-29 に発行した小さなコードの直し4件の brief（作業層・消える）の単位 U3。plan と認識合わせは owner の方針で省く。終端は U3-S3（報告を送る）。マージ・worktree の掃除・issue の close・sync はしない。
- scope: `projects/orchestration-engine/scripts/validate-knowledge.sh` の引数の処理。2つ目の対象の引数が来たら、使い方の行を出して exit 2 で終える。すべてのファイルを検証する形にはしない。
- SO: 実装 weak（Codex 1レーン）+ Copilot 1ラウンド。
- 注入された negative knowledge: 1件（frontmatter の `knowledge_observations`）。closure で観測を書き戻す。

## 作業の記録

### S1: 再現と呼び出し元の確かめ（2026-10-29）

- master `be0df85` で、正しい item と `id: bad` だけの item を2つ渡すと、`OK: <1つ目>` と exit 0 が出た。
- 2つ以上の対象を渡す呼び出しは `canonical/`・`scripts/`・`projects/` に無い（`grep -rn validate-knowledge` で、呼び出しはすべて1つの item かディレクトリ1つ）。拒む形にしても壊れる呼び出し元は無い。
- **直し方**: ハイフンで始まらない引数が2つ目に来たら、余分な引数を名指しする ERROR と使い方の行を stderr に出して exit 2 で終える。exit 2 はこの validator の「usage」の帯である。ERROR の文に、全件を見たいときはディレクトリを渡すことを添えた。
- **確かめた結果**: `tests/test_validate_knowledge.sh` に [52] を足した（7項目）。`/bin/bash` 3.2.57 と bash 5.2.37 の両方で PASS=267 FAIL=0。validate-knowledge.sh だけを変更前に戻すと [52] の6項目が落ちる（落ちないのは「対象1つ + `--verbose` は exit 0」で、今までどおりを確かめる項目）。`shellcheck` は2つのファイルで通る。

### S2: 実装SO（弱・Codex 1レーン）の結果と採否（2026-10-29）

Codex の1レーンが返った（`timeout_status=success`・100秒）。出力は作業層の `tmp/so-531-impl/` にある。指摘は1件で、ほかの観点（`--verbose` の位置、`--` やハイフンで始まる引数、正当な呼び方が壊れていないこと、exit 2 がヘッダの契約と合うこと、[52] が修正を外すと落ちること、2つ以上を拒む方針）は問題なしだった。

- **採用（中）: 先頭の空文字の引数が黙って捨てられる。** 対象を受け取ったかを `TARGET` の非空で見ていたので、`validate-knowledge "" valid.md` は空文字を「未受領」と見て、後ろの1件だけを検証して OK を出していた。受け取ったかを `HAVE_TARGET` で別に持つ形に直した。空文字だけを渡したときは今までどおり「見つからない」で exit 2 になる。[52] に2項目足し、最初の修正のコミットに対して落ちることを確かめた。テストは両方の bash で PASS=269 FAIL=0。
- 判定の記録: 最初の修正は、issue の文面（2つ目以降を捨てる）に合わせて「2つ目が来たか」を `TARGET` の値で判定していた。値で数えると、値が空の引数が数から漏れる。

### S2: Copilot の1ラウンド（2026-10-29）

Copilot のレビューは指摘0件（概要は「Approval recommended」）。返信の要る行の指摘は無い。

## closure（2026-10-29）

- **tier**: heavy。実装SO を意図して起動し、その指摘で修正を足したため。
- **次の消費者**: validate-knowledge を呼ぶ人とスキル（episode-retrospective の Step 5・6）。#532（同じファイルの directory mode）が U4 として続く。
- **事実・失敗**: 最初の修正は「2つ目が来たか」を `TARGET` の値で判定していて、先頭の空文字が数から漏れた。実装SO が拾った。`本文: S2: 実装SO（弱・Codex 1レーン）の結果と採否（2026-10-29）`
- **決定と根拠**: 全件検証にせず拒む判断は brief の scope が決めたもので、呼び出し元が無いことを確かめた。`本文: S1: 再現と呼び出し元の確かめ（2026-10-29）`
- **昇格の判定**: 2件とも `not-required`。1件目は brief（統括）が決めた範囲の判断で、コードのコメントに理由がある。覆すには確認（2つ以上を渡す呼び出し元が現れるか）で足りる。2件目はコードのコメントとテストが正本である。昇格の印は置いていない。
- **蒸留シグナル**: なし。「値で数えると空の値が数から漏れる」は自明な実装の注意で、収穫基準の非自明を満たさない。
- **follow-up**: 無い。#532 は brief で U4 として予定されている。
- **観測の書き戻し**: 注入された item は `01KZ21M0N0FZ4YMR2R6DPHTWQ4` の1件で、`no_opportunity` を書き戻した（合格条件を書く場面ではなかった）。
- Step4 辞退: 実装SO と Copilot が差分を見ており、指摘1件は本文に節を立てて記録済み / 既存チェックで覆った観点: 省略チェック（指摘1件が本文と事実・失敗に在る）・routing（follow-up 無し）・evidence anchor（SO の出力は `tmp/` だが要点を本文に転記済み）/ 未実施観点と判断: back-propagation は、他文書の欠陥を見つけていないので該当なし
