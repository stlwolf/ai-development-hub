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

### 2026-08-30 実装（Step 1〜4）完了

`oe-tree` の行末に拍動を足した。テストは 78/0（既存 61 + 新規 17）、両 bash で全件パス。既存の観測 verb も不変（threads 67 / registry 35 / home_unset 62 / status 27 / select 35 / jump 38 / ident 14）。

**gate 2 の指摘どおり、走査コストは実測で受けた。** 1 フレームあたり jq は **2 回**（sidecar 176 件に対して）。内訳は拍動の一括読み 1 回と、モデル名の `sanitize_out` 1 回である。拍動なしの版が 18 回なので、**件数に比例していない**ことが数で言える。フレーム時間は 313ms（master 283ms・+30ms）で、`--watch` の 2 秒 tick に対して十分だった。

**テストで実バグを1件捕まえた。** `gone` のノードにも拍動が付いていた。sidecar は pane を名乗るだけなので、tmux にそのペインが無くても新しい記録があれば付いてしまう。これは pane 再利用の誤帰属そのものである。`alive` と `?`（tmux 不明）にだけ出す形へ直した。**plan には「gone では何も足さない」と書いていたのに、実装で落としていた**ので、テストが仕様と実装の差を捕まえた形になる。

**テストハーネスに無いものが2つあった。** `test_oe_tree.sh` には部分一致の helper（`ckc`）が無く、完全一致の `ck` だけだった。他のテストファイルには在るので、在るつもりで書いてしまった。もう1つは mock tmux の `#{pid}` 分岐で、これは gate 2 の cursor レーンが事前に指摘していたとおり、足さないと pid が title 経路へ落ちて server 突合が壊れる。

昇格の印: sidecar は pane を名乗るだけなので、pane の生死は必ず別の source で確かめる
