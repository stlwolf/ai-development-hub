---
id: "01M873BQ785RFP0JWZ0HWMCY1C"
title: "#650 Claude Code と Codex の記憶の仕組みを調べ、ハーネスに入れられる調整と制御の候補を並べる"
date: 2026-11-24
type: episode
status: draft
related:
  - type: derived_from
    ref: "docs/harness/plans/2026-11-24-plan-650-agent-memory-survey.md"
    reason: "この episode の plan"
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/650"
    reason: "本 episode の issue"
tags: [harness, memory, claude-code, codex, research]
---

# #650 Claude Code と Codex の記憶の仕組みを調べ、ハーネスに入れられる調整と制御の候補を並べる

## なぜ始まったか

2026-11-15 に、engine が起こした Codex の子の中で Codex の記憶を整理する会話が裏で動き、頼んだ作業の内容が owner の Codex の記憶に入り、頼んでいない報告も親へ送ってきた。記憶に何が入り、人がどこまで制御できるかを、まとまった形で確かめたことが無かったので、Claude Code と Codex の両方を調べる issue が起こされた（#650）。

## 認識合わせ（2026-11-24）

- 最初の下書きは、issue 本文どおり「比べて、決めること4つを決める」形だった。owner は、主の調査と望む結果は「ハーネスとして記憶をどう扱うか」で、出発点は「ハーネスに記憶を調整するものか制御するものを入れるのか、入れられるのか」だと指した。engine で記憶をどう使うかは別の話とした。
- 深掘りで決まったことは4つある。
  - 対象は Claude Code と Codex の両方である（ハーネスには当然 Codex も含む）。
  - 層を2つに分ける。この issue はハーネスの層（エージェントごとの記憶の扱い）を扱う。engine の層は、利用者ごとにハーネスがある前提で、engine の動きを変な方向に走らせないためにだけ、エージェントに依らない形で記憶を制御する話で、別の issue にする。
  - この issue は、いまの状態を調べる調査の issue で、ハーネスに何を入れるかは決めない。ほかの要素と絡んで発展する余地を残す。
  - 進め方は、Claude Code の側が両方を先に調べて文書を埋め、そのあと Codex がその文書を確かめて埋める。issue 本文の「それぞれが相手を知らない前提で調べる」から変えた。
- 確定版: https://github.com/stlwolf/ai-development-hub/issues/650#issuecomment-7134862521

## plan と設計SO（2026-11-24）

- 設計SO（so-compare の Codex 1レーン）は must 5件・should 3件を返し、8件とも採った。いちばん効いたのは、手元の試しの組み方の指摘である。最初の形（同じ一時ディレクトリで2回打つ）では、1回目のファイルが残り、設定の効果を比べられなかった。
- ゲート3 は owner が承認した（2026-11-25・会話）。

## 作業の記録
