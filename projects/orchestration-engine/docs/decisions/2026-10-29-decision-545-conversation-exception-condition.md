---
id: "01M61NMJM9QPMN7ZJY30JW6R36"
title: "判断ボードに載せず会話で聞いてよい問いを、生きた子の数と owner の言葉で始めた問答で決め、次に届いた入力が答えでなければ判断ボードへ移す"
date: 2026-10-29
type: decision
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/545"
    reason: "本 decision が記録する owner の判定（ゲート3 の Q49〜Q52・2026-10-27）の issue"
  - type: derived_from
    ref: "projects/orchestration-engine/docs/plans/2026-10-27-plan-545-conversation-exception-condition.md"
    reason: "判定の材料。設計判断 DJ-1〜DJ-9・ゲート1 とゲート2 の採否・GATE 3 の問い4つ"
  - type: reference
    ref: "projects/orchestration-engine/docs/episodes/2026-10-27-episode-545-conversation-exception-condition.md"
    reason: "作業の記録。SO の指摘と採否・判定の経緯"
  - type: design_context
    ref: "projects/orchestration-engine/docs/decisions/2026-10-25-decision-538-judgment-board-flow.md"
    reason: "一部だけを置き換える前の決定。決定7 のうち「owner が会話に居て始めた対話の中の問いは、今までどおり会話で聞き」の部分だけを置き換える（決定7 に追補を書いた）"
  - type: design_context
    ref: "projects/orchestration-engine/docs/decisions/2026-10-24-decision-466-page-lifecycle-in-flow.md"
    reason: "判断ボードの流れの決定（決定1・5・7・10）。この decision はその上に立つ"
  - type: future_hook
    ref: "https://github.com/stlwolf/ai-development-hub/issues/540"
    reason: "条件を当てるのは統括の手のまま。移した回数は台帳の moved_from で数えられ、知らせる道具が読める"
tags: [orchestration, human-page, supervisor, delegation, skill, decision]
---

# 判断ボードに載せず会話で聞いてよい問いを、生きた子の数と owner の言葉で始めた問答で決め、次に届いた入力が答えでなければ判断ボードへ移す

## コンテキスト

`judgment-board-flow` には、owner がいまこの会話に居て一緒に考えている対話の中の問いは判断ボードに載せず会話で聞いてよい、という例外があった（#538 の decision の決定7 の承認に含まれた）。当たるかは統括がその場で判断していた。

2026-10-27、別のリポジトリの統括が、生きた子が3体いる状態で「子を起こしてよいか」をこの例外に当たると判断して会話で聞いた。約30分で子の報告や CI の知らせが6件以上割り込み、統括は同じ問いを5回書き直した。owner は「流れると上を見る必要がある」「子の返しは制御できない」と指摘した（#545）。

子は plan に4つの問い（GATE 3）を書き、統括が判断ボードの Q49〜Q52 として載せた。owner は 2026-10-27 に、Q49 と Q50 をページで推奨どおりに選び、会話で「全部推奨で OK」と答えた。補足は無かった。

## 決定

1. **会話で聞いてよい問いは、統括の下に生きた子が1体もいないとき（`oe-tree` で見る）か、owner が自分の言葉で始めた問答（認識合わせの深掘り・設計の相談）の中の、その問答の対象についての問いだけにする。会話で聞いた問いのあと、次に届いた入力が owner の答えか問いについての質問でなければ、その場で判断ボードへ移す。** 問答は、会話に始まりと終わりの1行を残し、深掘りは issue の深掘り中の版で見える。作業を進めるための確認や許可は、問答の途中でも会話で聞かない。会話で答えを待つ問いは同時に1つまでにする。移すときは会話で問いを書き直さず、閾値と待つ期間に関係なくカードにしてすぐ載せる。（Q49）
2. **深掘りや設計の相談の途中に割り込みが来たら、待っている1問だけを判断ボードへ移し、問答は続ける。** owner が次に会話で発言したら、問答の次の問いをまた会話で聞いてよい。（Q50）
3. **会話で聞いたこと自体は台帳に書かず、移したときに書く `asked` に `moved_from: conversation` を足す。** `ledger.py` は、`moved_from` のある行の `route` が `board` であることを確かめる。（Q51）
4. **この plan（commit `965b161`）で実装に進む。** 決めた理由をこの decision に書き、#538 の decision の決定7 に追補を1行書くことも、この承認に含まれる。`question-driven-design`・`issue-intake`・出力の型・ルールは直さない。（Q52）

## 根拠

- **入口と出口の両方を置く理由（決定1）。** 入口だけでは、子のいる統括で認識合わせの深掘りと設計の相談まで判断ボードの往復になる。出口だけでは、子が多く割り込みが来ると聞く前から分かっていても、1回は会話に書いて流れる。
- **入口の問答を owner の言葉と残る1行で決める理由（決定1）。** 「どのスキルの手順を動かしているか」で決める初稿の形は、ゲート1 の設計SO が「子を起こしてよいか」も設計の相談に分類できると指摘し、統括の解釈に戻ると分かった（plan の「ゲート1」節）。
- **出口を「次に届いた入力」1つにする理由（決定1）。** owner が黙って知らせだけが続くときにも移るきっかけが来る。`oe-send` の1行には既定で `[oe:<26文字>]` の印が付くが、印を外して送られた子の入力を owner の発言と読み違えても、問いに答えていなければ移る。
- **待っている1問だけを移す理由（決定2）。** 子の返しは止められないので、問答を守るには割り込みを後回しにするしかなく、そのあいだ止まる子の問いが止まり続ける。問答ごと移すと、深掘りの1問ごとに判断ボードとの往復になる。
- **移したときだけ台帳に書く理由（決定3）。** 書く手間は移した回数分で済み、例外が流れた回数を #540 の道具が数えられる。会話で聞くたびに書く形は、その出し先だけ問いのファイルを任意にする例外が要り、深掘りの問いの1つずつに key を振る手間が増える。

## 結果

- `canonical/skills/judgment-board-flow/` の SKILL.md（description・いつ使うか・使わないとき・境目・2.1〜2.4・2.6〔新設〕・4・6・7・9・13・14 節）と `ledger.py`・テストを直した。
- `canonical/CATALOG.md` の `judgment-board-flow` の行と、#538 の decision の決定7 の追補を書いた。
- 範囲の外として申し送った案（問答だけを受け持つ別のセッション・子の報告や知らせを受信箱に集める）は、episode の follow-up にある。
