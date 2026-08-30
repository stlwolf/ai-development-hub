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

### 2026-08-30 gate 4（実装SO）の指摘を反映

`oe-review --lanes 2 --base master`（audit_id `202608300840051JKTM5D489ND`）は **refuted**。**2レーンとも attempt 1 で返った**（codex 161秒 / cursor 236秒）。前単位の教訓（材料をインラインし `SO_TIMEOUT` を上げる）を適用した結果である。

**両レーンが同じ2件を独立に指した。**

**1. 改行による拍動レコードの注入（High）。** 拍動表を `join(US)` の生文字列で持っていたので、producer が保持する `display_name` 内の改行がそのままレコード境界になる。単にモデル名が切れるだけでなく、`"\n%60<US>1<US>77<US>Forged"` のような値で**別ペインの拍動を偽装して注入できる**。codex は実際に偽の `%60` 行が生成されることを確認したと書いている。`sanitize_out` は awk の後なので区切りの修復には使えない。

**前単位で同じ型を学んでいたのに再発させた。** `oe-threads` は `@tsv` → TAB を US へ変換する形でこれを潰しており、その理由もコメントに書いてある。今回は「US なら値に出ないから安全」と考えて `join` を使い、**値の中の改行という別の経路を見ていなかった**。修正は `oe-threads` と同じ形に揃えた。

**2. observer の身元が取れないときの fail-open（High）。** `#{pid}` が空のとき `$spid == ""` として**非空の `server_pid` を持つ sidecar を全部通していた**。しかも `SERVER_PID`（`$TMUX` 由来）が既に在るのに使っていなかった。前単位の gate 4 で cursor が指摘したのと**同じ型を別の場所で再発**させている。修正は `#{pid}` → `$TMUX` → fail-closed の順にした。

**3. 非 object の valid JSON が数えられない（Medium・codex）。** 配列や文字列は `select(type == "object")` で黙って捨てられ、jq は成功するので遅い経路にも落ちず、`BEAT_MALFORMED` に計上されない。「壊れた sidecar は note で開示する」という自分の契約を満たしていなかった。jq 側で件数を数えて先頭行で返す形にした。

**テストの作りも1件間違えた。** fail-closed の回帰を `TMUX=''` で書いたが、**`oe-tree` は `$TMUX` 無しでは起動しない**ので、アサートは「fail-closed が効いた」ではなく「何も出なかった」で通っていた。**間違った理由で通るテスト**だったので、到達する経路（`#{pid}` だけが空）で書き直した。fail-closed 自体は防御として残すが、到達しないことを明記した。

最終状態は 88/0（既存 61 + 新規 27）、両 bash で全件パス。既存の観測 verb も不変。

昇格の印: 「値に出ない区切り」を選んだ時点で終わりにせず、値の中の改行がレコード境界になる経路を見る

### 2026-08-30 Copilot レビュー1ラウンド

行コメントは付かず、レビュー本文で1点の指摘（`Changes recommended`）。

> Updated docs/comments claim "1 フレームあたり jq は 1 プロセス" in a way that can be misread as overall frame cost, but the command uses jq in multiple other places, so the wording should be clarified to avoid misinformation.

**成立する。しかも私自身の実測と食い違っていた。** 測ったのは「拍動あり 20 回 / 拍動なし 18 回 → 拍動が増やすのは 2 回」で、**フレーム全体が 1 プロセスになったことは一度も無い**。それなのにコメントと README と plan に「1 フレームあたり jq は 1 プロセス」と書いていた。受入条件も「1フレームの jq プロセス数が sidecar 件数に比例しない」と、全体の回数で書いていた（測っていたのは増分なので、条件と測定がずれている）。

3箇所（verb のコメント・`bin/README.md`・plan の DJ-7 と最終検証）を、増分で言い切る形に直した。

**この誤りは自分の測定値を見ていれば気づけた。** 20 と 18 という数字を並べて書いておきながら、要約の一文が「1 プロセス」のままだった。**数値を出したあとに、その数値で要約文を検算していない。**

### 2026-08-30 Copilot が来るまでの待ち時間について（自己訂正）

私は「12分待ったが Copilot レビューは未着」と報告し、Copilot 無しで進める案を owner に出した。**これは早合点だった** — レビューはその直後に付いていた（`submitted_at` 09:06:27Z）。owner が URL を示して指摘した。

前回（PR #351）が約4分で付いたため、12分を「来ない」の根拠にしてしまった。**サンプル1件の所要時間を閾値として扱った**のが誤りである。加えて、GraphQL 経由（`gh pr view --json reviews`）では author が `copilot-pull-request-reviewer`、REST 経由では `copilot-pull-request-reviewer[bot]` と表記が違う。今回の判定は前者で書いたが、両方を見るか、そもそも「未着」を宣言せずに待つべきだった。

昇格の印: 外部の非同期プロセスに「来ない」と宣言するとき、サンプル1件の所要時間を閾値にしない
