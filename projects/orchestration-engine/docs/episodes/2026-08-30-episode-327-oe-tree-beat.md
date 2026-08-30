---
id: "01M18WRGJJC1DNJ2EE321M0R87"
title: "#327 cockpit の親子ツリーにモデル名とコンテキスト% を出す — 実行記録"
date: 2026-08-30
type: episode
status: in-development
source: "https://github.com/stlwolf/ai-development-hub/issues/327"
scope: orchestration-engine
related:
  - type: derived_from
    ref: "projects/orchestration-engine/docs/plans/2026-08-30-plan-327-oe-tree-beat.md"
    reason: "本 episode が実行する plan"
  - type: design_context
    ref: "projects/orchestration-engine/docs/episodes/2026-08-28-episode-327-session-model-ctx.md"
    reason: "前単位の実行記録。読み取りの実装（oe-threads）と、面を取り違えて未達に終わった経緯がある"
tags: [engine, cockpit, oe-tree, statusline, heartbeat]
---

# #327 cockpit の親子ツリーにモデル名とコンテキスト% を出す — 実行記録

**なぜこの作業が始まったか**: 前単位で sidecar にモデル名を書き、読み取る verb も作ったが、**owner が実際に見ている面に出していなかった**ため目的未達だった。cockpit は `Ctrl+Space` → `v` で開く popup で、その実体は `oe-tree --pick` である。本単位はその行に情報を載せる。

## 前提（着手時点で確定していること）

- gate 2（設計SO・3レーン）を1周通し、指摘を plan に反映済み。**3レーンとも attempt 1 で返った**（codex 168秒 / claude 351秒 / cursor 202秒）。前単位で収穫した knowledge item（材料をインラインし上限を上げる）をそのまま適用した結果である。
- gate 3（owner HG）は 2026-08-30 に通過。baseline は plan の「HG-1 の記録」節（承認 commit `f315c8c`）。
- owner 裁定3件: 置き場は行末 / `oe-tree` の read-set に sidecar を加える再裁定を認める / 母集団は変えず未登記セッションは別単位。
- 実装はこのセッションが行う（委譲しない）。

## 随時追記

### 2026-08-30 着手前の試作（幅の確認を最初に置いた）

plan を書く前に、置き場の2案を試作して実測した。**前単位の失敗が「実機の面を見なかったこと」だったので、幅の確認を最後ではなく最初に置いた。** gate 2 の claude レーンが「安い早期確認が Pre-Implementation に無い」と指摘したのが直接のきっかけである。

| | 最長 | 備考 |
| --- | --- | --- |
| popup の実効幅 | 約 116 桁 | client 幅 166 × `-w 70%` |
| 案X（行末） | 71 桁 | beat 付きの行は 63 桁 |
| 案Y（`alive` の直後） | 96 桁 | beat を持ちえない `gone` 行にも場所取りが要り全行が太る |

owner は案X を選んだ。試作は plan 確定後に削除した（コミットしていない）。

昇格の印: 置き場の判断は、実測なしでは「慣習に合う」以上のことが言えない
