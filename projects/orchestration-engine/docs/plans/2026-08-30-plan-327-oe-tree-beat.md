---
id: "01M17EVWB1DTTEJXSKFVDM44JQ"
title: "#327 cockpit の親子ツリーにモデル名とコンテキスト% を出す — 実装プラン"
date: 2026-08-30
type: plan
status: draft
source: "https://github.com/stlwolf/ai-development-hub/issues/327"
scope: orchestration-engine
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/327"
    reason: "本プランの起点"
  - type: derived_from
    ref: "projects/orchestration-engine/docs/plans/2026-08-27-plan-327-session-model-ctx.md"
    reason: "前単位。sidecar に model と server_pid を足し、読み取りの実装（oe-threads）を作った"
  - type: design_context
    ref: "projects/orchestration-engine/docs/episodes/2026-08-28-episode-327-session-model-ctx.md"
    reason: "前単位の実行記録。反証3周と実装SO 2回の一次記録がある"
tags: [engine, cockpit, oe-tree, statusline, heartbeat]
so:
  design: weak
  impl: weak
  reason: "gate 2 を1周通し、3レーンの指摘を反映済み。判断の幅は狭くないが、面と置き場と母集団は owner 裁定で確定している"
---

# #327 cockpit の親子ツリーにモデル名とコンテキスト% を出す — 実装プラン

## 目的の面（最初に固定する）

**`oe-tree` の行。** `Ctrl+Space` → `v` で開く popup が使っている面である。

```text
bind-key -T prefix v  display-popup -E -T " oe pick " -h 60% -w 70% -x C -y C "/Users/eddy/bin/oe-tree --pick"
```

`--pick` は内部モード `--pick-list` で通常の render を再利用するので、**行を変えれば popup の候補行も同時に変わる**。

**前単位が未達に終わった原因はここにある。** 前単位は「全 Claude セッションを1つの面に出す」と目的を立て、平坦な一覧の新 verb（`oe-threads`）を作った。しかし cockpit は親子関係を見る道具であり、owner が見ている面は `oe-tree` だった。**面の指定が最初に入っていなかったことが未達の原因**なので、本プランは面を冒頭に固定する。

## owner 裁定（2026-08-30・gate 2 の指摘を受けて）

gate 2 の3レーンが「私が勝手に決められない判断」を3つ指した。owner に返して確定させた。

| # | 判断 | 裁定 |
| --- | --- | --- |
| 1 | 置き場 | **行末に足す**（`~workspace` / `(you)` と同じ suffix 慣習）。試作の実測で決めた（下記） |
| 2 | `oe-tree` の read-set | **再裁定して sidecar を加える。** `oe-tree:40-44` は読む集合を閉じ「DJ-223-9・hg-1 裁定済み」と書いている。sidecar は第3のソースなのでこの線を動かす。**書き込みは引き続きしない・ペイン出力も読まない**（非検出境界は維持） |
| 3 | 母集団 | **変えない。** 登記に無い生存セッション（実測で %9 と %6）は cockpit に出ないままとする。owner の判断は「作業を分けたいから」で、別要件（ターミナルや PC が落ちたあとに親子関係をどう復元するか）と一緒に別単位で扱う |

## 置き場の実測（試作・2026-08-30）

plan を書く前に試作して測った。**前単位の失敗が「実機の面を見なかったこと」だったので、幅の確認を最後ではなく最初に置く。**

| | 最長 | 備考 |
| --- | --- | --- |
| popup の実効幅 | 約 116 桁 | client 幅 166 桁 × `-w 70%` |
| いまの `oe-tree` | 71 桁 | beat 無し |
| 案X（行末に足す）＝**採用** | 71 桁 | beat 付きの行は 63 桁。長ラベル行に beat が付いた最悪でも約 96 桁 |
| 案Y（`alive` の直後に挟む） | 96 桁 | beat を持ちえない `gone` 行にも場所取りが要り、全行が 25 桁太る |

案X の弱点は「幅が足りなくなるとモデルが真っ先に切れる」ことで、これは受容する（現状 45 桁の余裕がある）。

## この単位が引き受けるもの

- `oe-tree` の各行の末尾に、そのペインの **モデル名** と **コンテキスト%** を出す。
- `--pick`（popup）の候補行にも同じものが出る（同じ render を通るため自動）。

## この単位が引き受けないもの

- **母集団の変更**（上記の裁定3）。登記に無い生存ペインを出すことと、落ちたあとの親子関係の復元は別単位。
- `oe-threads` の統合や廃止・変更。**本単位では1バイトも触らない**（gate 2 の指摘により lib 切り出しを取り下げたため）。
- ambient（pane-border）・検知・pane option ストア。
- tmux の bind 変更（面を差し替えないので不要）。

## 設計判断（gate 2 の3レーンの指摘を反映）

| DJ | 判断 | 案 | gate 2 で変えた点 |
| --- | --- | --- | --- |
| DJ-1 | 置き場 | 行末に足す | owner 裁定＋試作の実測で確定 |
| DJ-2 | 出す内容 | `display_name` と `CTX%`。幅で切らないが、表示上限（codepoint）は掛ける | 「切らない」だけでは外部入力に対して無防備という指摘を反映 |
| DJ-3 | 読み取りの置き場 | **`oe-tree` に inline で実装する。lib へ切り出さない。`oe-threads` は触らない** | 「lib 共用は exit 政策と server 身元の取り方を持ち込む」「inline で十分という代替が未探索」の指摘を反映。3消費者が揃ってから切り出す（前単位と同じ基準） |
| DJ-4 | 帰属の解決 | 鮮度窓内の候補が1件なら確定・複数なら曖昧・0件なら無し。突合は `server_pid` と `pane` の組で、**`server_pid` が空の旧 sidecar は pane 単独で突合する劣化動作**（`oe-threads` と同じ） | 前版の「厳密突合」は誤記。legacy degrade を落とすと既存の記録が全部帰属しなくなる |
| DJ-5 | 曖昧の表示 | 「beat が無い」と「帰属が曖昧」を同じ空表示に潰さない。曖昧は `ambiguous` と出す | 「安全」と「不明」が見分けられない、という指摘を反映 |
| DJ-6 | degrade 方針 | **`oe-tree` を殺さない。** sidecar が読めなくてもトポロジ表示は出す。exit code は変えない。ただし**黙って捨てず note で開示する**（`oe-tree:445-448` の「無い物を捏造しない・黙って捨てない」不変条件に従う） | `oe-threads` の「読めなければ exit 2」を持ち込むと、装飾の不具合でトポロジが死ぬ |
| DJ-7 | 走査コスト | **dir 全体を1回の jq で舐めて pane→beat の対応表を作る。** ファイルごとに jq を起動しない | `--watch` は2秒ごとに自分を再 exec し、`--pick` も候補取得のたびに再帰起動する。実ホームの sidecar は 176 件あり、1ファイル1プロセスだと「2秒ごとに 176 プロセス」を popup の常設経路に持ち込む |
| DJ-8 | 対応表の持ち方 | bash 3.2 に連想配列が無いので、US 区切りの1文字列に畳んで pane で引く（`oe-tree` の `ENTRIES` と同じ idiom） | 対応表の持ち方自体が判断対象という指摘を反映 |
| DJ-9 | sanitize | `model.display_name` は外部ファイルの中身なので、既存の `sanitize_out` を通す | `oe-tree` は外部由来を必ず出力チョークポイントで畳む設計 |

## Pre-Implementation

- [ ] READ: `projects/orchestration-engine/bin/oe-tree:508-545` — render と suffix の組み立て
- [ ] READ: `projects/orchestration-engine/bin/oe-tree:440-460` — note の出し方（`_note_fd`）と「黙って捨てない」不変条件
- [ ] READ: `projects/orchestration-engine/bin/oe-threads:240-269` — 帰属解決（**前版は行番号を間違えていた**）
- [ ] READ: `projects/orchestration-engine/tests/test_oe_tree.sh:24-60` — `cp` + `lib` symlink のハーネスと mock の分岐

## HG-1: owner HG（gate 3）

- [ ] plan を owner に提示して承認を得る
- [ ] baseline を承認の記録と同じ場所に残す

## Step 1: 読み取りを `oe-tree` に足す

- [ ] read-set 宣言（`oe-tree:40-44`）に sidecar を追記し、**再裁定であることを明記する**（裁定2）
- [ ] dir 全体を1回の jq で舐め、`pane` → `{ts, ctx, model, server_pid}` の対応表を US 区切りで作る（DJ-7 / DJ-8）
- [ ] 鮮度窓・server identity・曖昧の判定を実装する（DJ-4 / DJ-5）
- [ ] 置き場が読めない・全件壊れは note で開示し、tree は出す（DJ-6）
- [ ] `sanitize_out` と表示上限を通す（DJ-2 / DJ-9）

## Step 2: 行末に出す

- [ ] `suffix` の組み立てに追加する（`~ws` / `(you)` の後ろ）
- [ ] `gone` と beat 無しでは何も足さない
- [ ] `--pick-list` にも同じ render を通して出ることを確認する

## Step 3: テスト（ハーネスの実態に合わせる）

- [ ] `OE_HEARTBEAT_DIR` を隔離する（実ホームに `%85` の sidecar が実在し、隔離しないとホスト依存になる）
- [ ] mock の `display-message` に **`#{pid}` の分岐**を足す（現状は `#{pane_id}` / zoom / title の3分岐で、pid が title 経路に落ちる）
- [ ] `NOW_EPOCH` と鮮度窓を固定する（`test_oe_threads.sh` と同じ形）
- [ ] beat fixture の後始末（`reset_beats` 相当）を足す。**足さないと後半の `--watch` / `--pick` ケースへ漏れる**
- [ ] 新ケース: beat 有り / 無し / `gone` / 鮮度切れ / 曖昧 / 別 server / 旧 sidecar（`server_pid` 空）/ 壊れた JSON / 制御文字入り `display_name`
- [ ] `--pick-list` と `--watch` に**末尾までアンカーした**検査を足す（既存の当該アサートは部分一致なので、中身が誤っていても通る）
- [ ] note を出すケースで既存の stdout 完全一致アサート3件（`:202-204` / `:211` / `:217`）を更新する

## GATE: テスト全パス（bash 3.2 と 5.2）

- [ ] `test_oe_tree.sh` / `test_oe_threads.sh`（不変の確認）/ `test_delegate_registry.sh` / `test_home_unset.sh` を両方で実行
- [ ] `shellcheck`
- [ ] **1フレームの実行時間を測る**（`--watch` の 2 秒 tick に対して妥当か。DJ-7 の受入）

## Step 4: doc

- [ ] `bin/README.md` の `oe-tree` 節に追記（read-set の再裁定も書く）
- [ ] `oe-threads` 節に「主役ではない」位置づけを追記

## REVIEW: gate 4 実装SO（2レーン・`SO_TIMEOUT` を上げる）

- [ ] `oe-review --lanes 2` を diff にかけ、指摘を修正する

## Step 5: PR と Copilot

- [ ] PR 作成（Refs #327）・Copilot 1ラウンド

## GATE: gate 5 episode closure（マージ前）

- [ ] episode を随時追記し、closure をマージ前に行う

## HG-2: gate 6（owner）

- [ ] **実機で `Ctrl+Space` → `v` を押し、popup の候補行にモデルとコンテキストが出ることを owner が目視する**
- [ ] マージ判断・issue close 判断・worktree 掃除

## 最終検証

- [ ] `oe-tree` の生存ノードの行末にモデル名とコンテキスト% が出る
- [ ] `--pick-list` の候補行にも出る（popup の面と同じ render であることの担保）
- [ ] `gone` ノードには何も足さない
- [ ] 鮮度切れ・別 server の sidecar を誤って足さない。旧 sidecar（`server_pid` 空）は pane 単独で帰属する
- [ ] 帰属が曖昧なとき、空表示ではなく `ambiguous` と分かる
- [ ] sidecar が読めなくても tree は出る。かつ黙って捨てず note で開示する
- [ ] 1フレームの jq プロセス数が sidecar 件数に比例しない
- [ ] `oe-threads` の出力が変わらない（本単位では触らないので当然だが、回帰として確認する）
- [ ] bash 3.2 と 5.2 の両方で全件パス
