---
id: "01M1VVYR9SCDMEF78SF7J0ESH2"
title: "#303 / #344 段階1 — 空返しの分類と入力拒否の契約を設計する（実行記録）"
date: 2026-09-07
type: episode
status: draft
source: "https://github.com/stlwolf/ai-development-hub/issues/303"
scope: orchestration-engine
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/344"
    reason: "同じ委譲アークで扱うもう一方の issue。レーンへ渡す前の入力拒否の契約"
  - type: design_context
    ref: "projects/orchestration-engine/docs/episodes/2026-09-07-episode-375-cursor-default-composer.md"
    reason: "同じ委譲アークの前段（PR-0）。cursor 既定モデルの変更"
tags: [so-compare, oe-refute, oe-review, classification, timeout, usage-limit]
---

# #303 / #344 段階1 — 空返しの分類と入力拒否の契約を設計する（実行記録）

**なぜこの作業が始まったか**: SO のレーンが返らないとき、`so-compare` は原因の違う複数の故障を `timeout_empty` という1つの値に畳んでいる。上限で塞がれたレーンを「時間切れ」と読むと、待っても直らないものを待ち、実害（#299 で重い欠陥3件が2レーン締めのあとに出た）が繰り返す。段階1 は実装せず、分類の契約と拒否の契約を plan にするところまでを作る。

## 前提（着手時点で確定していること）

- 段階1 は plan-first。実装・マージ・issue close はしない。終端は plan と gate 2 の結果を報告して STOP。
- SO は並行で回さない。1本ずつ走らせ、空で返ったレーンは時間をずらしてそのレーンだけ再走する。
- 委譲 brief が採用した negative knowledge が5件ある。closure でその全件へ観測を1レコードずつ書き戻す。

## 随時追記

### 2026-09-07 P-1（実例と証拠の集約）

作業層の報告に全文がある。`/Users/eddy/work/repos/github.com/stlwolf/ai-development-hub/.oe/report-303-P1.md`。

要点だけ本文にも残す。**当リポの SO 出力 114 ディレクトリ・レーン記録 276 件を走査し、stdout が空だったレーン 45 件の stderr と stdout を内容まで開いた。** 結果、空返しに見える故障は3種ではなく7種の形があった。

判断に効いた発見は3つある。

1. **上限の文言が出る場所がレーンごとに違う。** codex は stderr に出し（`ERROR: You've hit your usage limit ... try again at 4:03 AM`・2026-09-05）、claude は stdout に出す（`You've hit your session limit · resets 12:50am (Asia/Tokyo)`）。片方だけを検査する設計では claude の上限を取り逃す。
2. **上限は `timeout_empty` の外にもいる。** codex の上限は `error`（exit 1・4秒）、claude の上限は `error_partial`（exit 1・stdout 61バイト）に落ちている。`timeout_empty` を細分するだけでは拾えない。
3. **それでも分けられない形が残る。** claude には exit 124・経過が上限ちょうど・stdout も stderr も `raw.json` も 0 バイトという、普通の時間切れと記録が完全に一致する上限疑いがある（#303 本文の実行）。**meta からは区別できない**ので、分類は「分けられないものがある」前提で作る。

**当初は「claude は上限のとき何の証拠も残さない」で結論しかけた。** 45件を meta の数値だけで分類したところで止めていればそうなっていた。`error_partial` の2件（stdout が 60〜80 バイトしかないレーン）を中身まで開いたときに、claude の上限文言と通信断の文言が出てきた。**数値の分類で足りたと思った時点が止まりどころで、そこで中身を開いたのが分かれ目だった。**

昇格の印: 空返しの調査で meta の数値だけを見て打ち切ると、短い stdout に入った故障の文言を丸ごと落とす
