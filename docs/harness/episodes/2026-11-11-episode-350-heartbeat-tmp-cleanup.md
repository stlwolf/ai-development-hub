---
id: "01M73GDHNESS6GFGVCEJ7J56RT"
title: "#350 statusLine の拍動の producer が一時ファイル（.hb.*）を残すのを直す"
date: 2026-11-11
type: episode
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/350"
    reason: "本 episode の作業対象"
tags: [statusline, heartbeat, bash, harness]
---

# #350 statusLine の拍動の producer が一時ファイル（.hb.*）を残すのを直す

## なぜこの作業が始まったか

statusLine の拍動の producer（`canonical/claude/statusline/statusline-oe-heartbeat.sh` の `_oe_heartbeat_write`）は、`mktemp` で一時ファイルを作り、`jq` で本体を書いて `mv -f` で置き換える。`trap` が無いので、途中で終わると `.hb.*` が置き場に残る。起票時（2026-08-27）は 35 件、2026-11-06 は 1100 件、今日は 1247 件残っている。issue の見立て（`mktemp` と `mv` のあいだで落ちて残る）は未検証だったので、直す前に Claude Code が statusLine を打ち切るときのシグナルを確かめた。統括の小さな直しの委譲（3件のうち3件目）として受けた。

## この単位の入力

- brief: 統括の委譲の書面（gitignored の作業層）。認識合わせと plan は owner の指示で省いた。
- 注入された knowledge item: 統括の採用は0件。着手時に `knowledge-list --strict` を見て、`01M579XZNAT7EXY4VPGRM9J8JW`（bash で変数の直後に ASCII 以外の文字を置かない）が当たる。足したテストと注釈は日本語の文の中で変数を展開するので、`${…}` で囲み、確かめの grep を当てた（S1-3）。
- SO モード: 実装SO は弱・Codex 1レーンと Copilot 1ラウンド。
- 決まり: `oe-lease gc` は `.hb.*` を触らない（#577・判断ボードの Q78）ので、gc の側には足さない。残っている `.hb.*` は消さず、件数と消すコマンドの案を報告に書く。

## 作業の記録

### S1-0: 着手（2026-11-11 02:20 頃）

- baseline: `origin/master` `74237b2`（#570 で effort を足したあとの producer）。
- ブランチ: `fix/#350_heartbeat_tmp_cleanup`。#481・#572 と同じく、デスクトップアプリが用意した worktree の中でブランチを切った。調べたのは #572 の Copilot を待つあいだで、受け手のセッションが利用の上限で止まったため、直しは上限が戻ったあと（04:50 頃から）に行った。

### S1-1: 打ち切りのシグナルを実物で確かめた結果（2026-11-11 02:20〜02:24 頃）

公式ドキュメント（https://code.claude.com/docs/en/statusline）は「新しい更新が来たら実行中のスクリプトを cancel する」とだけ書き、シグナルの種類は書いていない。そこで実物で確かめた。

確かめ方: Claude Code 2.1.322 を、別の tmux サーバー（`tmux -L`）の中で `claude --settings <ファイル>` で起こし、statusLine を確かめ用のスクリプトに替えた。ユーザーの設定ファイルは変えていない。プロンプトは送らず、待っている状態で動かした。

1. 1つめのスクリプトは、TERM・INT・HUP・QUIT・PIPE・USR1・USR2・ALRM の trap で受けたシグナルを記録し、4秒眠る。`refreshInterval: 1` にした。
   - 24回起動し、24回とも次の更新で SIGTERM を受けた。最後まで眠り終えた回は0だった。
   - スクリプトの親は `claude` で、process group は自分の pid だった（pgid = pid）。
   - セッションを閉じたとき（tmux のサーバーを kill した）も、実行中のスクリプトに SIGTERM が届いた。
2. 2つめのスクリプトは、SIGTERM を受けても終わらずに1秒ごとに記録し、子のプロセス（同じく trap つき）を持つ。`refreshInterval: 3` にした。
   - 子のプロセスにも SIGTERM が届いた。process group に送っていると読める。
   - 親の trap は、前面の `sleep 1` が終わるまで遅れて走った（bash は前面の子が終わるまで trap を遅らせる）。
   - SIGTERM を無視した親は、その後1〜2秒で記録が途絶えた。SIGKILL が続いたと見ているが、SIGKILL は捕まえられないので記録に出ず、推測である。

記録は作業者の scratchpad（`350/probe.log`・`350/probe2.log`）にあり、リポジトリの外の一時の場所なので、ここに要点を写した。

判断: issue の見立ては筋が通る。打ち切りは SIGTERM で届き、producer は trap を持たないので、`mktemp` のあとで受けると bash は既定の動き（終わる）で消え、temp が残る。process group に届くので `jq` も同時に終わり、bash の trap はすぐ走る。そのため、TERM の trap で temp を消せば足りる。SIGKILL まで待たれる場面（trap が1〜2秒以上かかる）は、この producer の trap が `rm -f` だけなので起きない。

### S1-2: 直し方（2026-11-11 04:50 頃）

`_oe_heartbeat_write` の `mktemp` の前に、TERM・INT・HUP の trap を置いた。trap は自分の temp だけを `rm -f` して、シグナルに合った終了コード（143・130・129）で終わる。`mv` か `rm` で片付けたあとに `trap - TERM INT HUP` で戻す。

判断の why:

- trap は `mktemp` の前に置き、`tmp=""` で始めた。temp ができてから trap を置くまでの隙間を作らないためである。`tmp` が空のうちに受けたときは、`rm -f ""` が何もしない。残る隙間は、`mktemp` を走らせているコマンド置換の中で受けた場合（ファイルはできたが `tmp` に入る前）だけで、これは trap では塞げない。
- 消すのは自分の temp だけにした。置き場全体の古い temp を次の起動で掃除する案は採らなかった。並列のセッションが同じ置き場に書くので、ほかのセッションの書きかけを消さないための年齢の閾値が要り、その設計は issue の owner の補足（不要ファイルの掃除をどうするかは今のタイミングでなくてよい）の範囲に入る。
- 打ち切られたときは表示を出さずに終える。打ち切られたスクリプトの出力は Claude Code が使わないので、表示を壊さないという不変条件には当たらない。
- INT と HUP も同じ扱いにした。セッションを閉じたときに届いたのは SIGTERM だったが、端末を閉じる経路などで HUP が届いても同じく temp を残さない。

### S1-3: テストの場面と結果（2026-11-11 04:52 頃）

`tests/canonical/claude/statusline/test_oe_heartbeat_producer.sh` に [18] を足した。本体を書く `jq`（引数に `--argjson` を含む呼び出し）だけを、pid を残して眠る stub に替え、書きかけの temp ができたことを確かめてから、producer と stub の両方に SIGTERM を送る（process group に届くのを写す）。temp が残らないこと、sidecar を書かないこと、終了コードが 143 であることを見る。producer は、テストを走らせる bash（`$BASH`）と `/bin/bash` の両方で回す。

```text
$ bash tests/canonical/claude/statusline/test_oe_heartbeat_producer.sh   # GNU bash 5.2.37
=== RESULT: PASS=125 FAIL=0 ===
$ /bin/bash tests/canonical/claude/statusline/test_oe_heartbeat_producer.sh   # 3.2.57
=== RESULT: PASS=125 FAIL=0 ===
$ shellcheck canonical/claude/statusline/statusline-oe-heartbeat.sh tests/canonical/claude/statusline/test_oe_heartbeat_producer.sh
（出力なし・exit 0）
```

陽性対照: 同じテストを、直す前の producer（`origin/master` の版を scratchpad に写したもの）に当てると、[18] の「temp を残さない」が bash 5 と `/bin/bash` の両方で落ちた（`want=[0] got=[1]`・PASS=123 FAIL=2）。テストは直したことを見分けている。終了コード 143 の項目は直す前でも通る（既定の動きでも SIGTERM で 143 になる）ので、見分けるのは temp の項目である。

knowledge item `01M579XZNAT7EXY4VPGRM9J8JW` の確かめの grep（`LC_ALL=C grep -nE '\$[A-Za-z_][A-Za-z0-9_]*[^[:space:] -~]'`）を、2つのファイルの足した行（`git diff origin/master` の `+` の行）に当てた。どちらも当たりは無かった（終了コード 1）。

### S1-4: 残っている .hb.* の件数（2026-11-11 02:24 頃）

`find ~/.claude/state/oe-heartbeat -maxdepth 1 -name '.hb.*' | wc -l` で 1247 件、そのうち空のものが 841 件だった。brief のとおり消していない。消すコマンドの案は報告の「問い」に書いた。

### S2-1: 実装SO の結果と採否（2026-11-11 04:55〜04:56 頃）

Codex 1レーン（`gpt-6.1-sol`・55秒・exit 0・`tool_status` は `not_observed`）の答えは「問題なし」だった。結果は `tmp/so-350/codex-stdout.txt`（gitignored）にある。観点ごとの答えは次のとおりで、どれも直す指摘ではないので、採否の対象は無い。

- trap の置き方: 自分の temp だけを消し、正常の経路と作成の失敗の経路では trap を戻している。`mktemp` がファイルを作ってからパスを返すまでの隙間は残る（S1-2 に書いたとおり）。
- 関数の中の `local` の `tmp` を trap が参照することは、bash 3.2 と 5.2 で正しく働く（Codex がファイルを作らない形で確かめた）。
- exit 143 で終えることは、表示を壊さない契約と食い違わない。直す前も SIGTERM では表示を出す前に終わっていた。
- [18] は stub の pid と temp ができるのを待ってからシグナルを送るので、決まった時間で打ち切る形より安定している。準備の待ちの上限（5秒）を、ひどく負荷が高いときに超える可能性はある。上限を超えると「書きかけの temp ができた（前提）」の項目で落ちるので、黙って通ることは無い。そのため直さない。

### S2-2: PR と Copilot のレビュー（2026-11-11 04:57〜05:00 頃）

draft の PR #635 を作り、Copilot にレビューを依頼した。依頼から約4分でレビュー（`d269851` 時点）が付き、「Approval recommended」で指摘は0件、行ごとのコメントも無い。返信が要るスレッドは無いので、未返信は0である。

## closure

tier は standard である。直す前に原因の見立てを実物で確かめ（S1-1）、見立てどおりだったので、判断の撤回は無い。確かめ方と結果は S1-1 に節を立てて書いてある。

- 次の消費者: PR #635 をマージする owner と、マージ後に sync を行う統括。残っている `.hb.*` を消すかを決める owner（報告の問い）。producer を次に直す担当は、S1-1 で打ち切りのシグナルが SIGTERM で process group に届くことを読める。
- status: stable（達成）。

### 受け入れ基準との対応

| 受け入れ基準（brief） | 結果 | 根拠 |
|---|---|---|
| 直す前に打ち切りのシグナルを手元で確かめ、確かめ方と結果を書く | 満たした。SIGTERM・process group | `本文: S1-1: 打ち切りのシグナルを実物で確かめた結果（2026-11-11 02:20〜02:24 頃）` |
| 打ち切られたときに temp が残らないことを見る場面をテストに足す・bash 5 と 3.2 で通す・shellcheck | 満たした。陽性対照も取った | `本文: S1-3: テストの場面と結果（2026-11-11 04:52 頃）` |
| 残っている .hb.* は消さず、件数と消すコマンドの案を報告に書く | 満たした（1247 件・案は報告の問い） | `本文: S1-4: 残っている .hb.* の件数（2026-11-11 02:24 頃）` |
| oe-lease gc の側には足さない | 足していない | `本文: S1-2: 直し方（2026-11-11 04:50 頃）` |

### 決定と根拠

- trap を `mktemp` の前に置き、自分の temp だけを消す。置き場全体の掃除は採らない（`本文: S1-2: 直し方（2026-11-11 04:50 頃）`）。

### 昇格の判定

昇格の候補は無い。打ち切りのシグナルが SIGTERM で process group に届くことは、producer の注釈に入れたので、producer を読む担当に届く。

### follow-up routing

1. `mktemp` がファイルを作ってからパスを返すまでの隙間で打ち切られた場合は、trap では塞げず、まれに temp が残りうる（S1-2）。完全になくすには置き場の古い temp を掃除する仕組みが要る。issue の owner の補足（不要ファイルの掃除は今のタイミングでなくてよい）のとおり、行き先は統括への報告で、掃除の仕組みを決める作業が扱う。
2. SIGTERM のあとに SIGKILL が続くかは推測のままである（S1-1）。producer の trap は `rm -f` だけなので、今回の直しには影響しない。
