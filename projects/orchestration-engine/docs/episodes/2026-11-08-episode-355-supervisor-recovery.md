---
id: "01M6XCD1N8KVH8DYNCPG5Z4F5W"
title: "#355 統括が応答しないときの復帰を verb 1本に畳む（設計）"
date: 2026-11-08
type: episode
status: in-development
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/355"
    reason: "本 episode の作業対象"
  - type: reference
    ref: "https://github.com/stlwolf/ai-development-hub/issues/355#issuecomment-6719836978"
    reason: "着手時の認識合わせの確定版（通し直し・2026-11-08・深掘りなし）。この単位はこれを前提にする"
  - type: reference
    ref: "projects/orchestration-engine/docs/decisions/2026-11-06-decision-577-record-identity-key.md"
    reason: "復帰の前提になる lease と generation の決定（D1〜D19）"
  - type: reference
    ref: "projects/orchestration-engine/docs/discussions/2026-07-13-discussion-supervisor-succession-recovery-and-observability.md"
    reason: "復帰を verb にする元の設計材料（§4・§5）"
  - type: reference
    ref: "projects/orchestration-engine/docs/plans/2026-11-08-plan-355-supervisor-recovery.md"
    reason: "この単位の plan"
tags: [orchestration, supervisor, recovery, lease, design]
---

# #355 統括が応答しないときの復帰を verb 1本に畳む（設計）

**この episode は着手時（2026-11-08）に枠を作り、作業しながら追記している。** 後追いで再構成した節があれば、その節の冒頭に `reconstructed` と書く。

## なぜこの作業が始まったか

統括のセッションが落ちたりペインが消えたりしたあと、同じ会話を resume しても、統括の席・登記・子の報告先が死んだペインを指したまま残り、統括が手で3〜4つの直しをしてきた（2026-09-09 から 10-30 までの5回・復帰の見取り図の「実例」）。#577 で「誰か」を lease の記録で持つようになったので、その上に復帰の verb を作る。この委譲は設計まで（brief の終端は P3）。

## P1: 着手（2026-11-08）

- worktree: `feature/#355_supervisor_recovery` を `origin/master`（`df16c60`）から作った。
- 確定版の照合: `issue-intake` の 1-2 の手順で、最後の行が `confirmed`・見出し4・URL が brief の「認識合わせ」欄と一致した。自分では認識合わせを通し直さない。
- 読んだもの: issue の本文とコメント全部（2026-09-11・09-15・10-06・10-18・11-05・11-08）、復帰の見取り図（artifact）、discussion 2026-07-13、decision #577 と discussion #577 の DJ-1〜DJ-7、`lib/lease.sh`・`bin/oe-lease`・`bin/oe-handoff` の take と retire・`lib/tmux-pane-identity.sh`・`bin/oe-vitals` の lease の判定・`bin/oe-send` の `--to-parent`・`lib/event-bus.sh` の `lease_bound`。

## P1: 設計判断の洗い出しで分かったこと（2026-11-08）

### 確定版の「generation を進めて席を取る」は、いまの lib の決まりと合わない

- `lib/lease.sh:11` は「generation は交代でだけ進む。resume では進まない」と書き、`oe_lease_claim` は session_id が同じ lease の別の generation にあれば rc 8 で止まる。同じ会話を resume して generation を進めると、1つの会話が2つの generation に分かれ、自分の id が退任した generation に残る。
- `oe-lease bind` は、前の binding のプロセスが死んでいれば同じ generation のまま binding を張り替える。復帰の lease の工程は、新しく書かなくても既にある。
- 判断: plan の DJ-2 で「進めず張り替える」を推奨にし、確定版との違いとしてゲート3 で owner に確かめる（Q2）。確定版を書いたのは統括で、decision #577 の D5 の「generation を進めてよいのは…復帰のとき」の文を読んだものと思われる [speculation]。D5 のその文は、別の会話が引き取る場合に当たる読み方ができる。

昇格の印: 「同じ会話の復帰は generation を進めず binding を張り替える」は、復帰の意味の決まりなので、ゲート3 で決まったら decision に残す候補である。

### 子の lease の親は書き換えなくてよい

- `OE_LEASE_ID` を持つ子は親の lease へ送る（`bin/oe-send:14`）。統括が同じ lease に戻れば、宛先は自動で新しいペインになる。確定版の「子の lease の親と登記のつけかえ」のうち、lease の側は要らない。registry の側だけが移行のあいだ残る（decision #577 の D11）。

### 「古い拍動 sidecar の掃除」は verb の工程にしない

- sidecar のファイル名は session_id なので、同じ会話を resume すれば同じファイルが新しいペインで上書きされる（`canonical/claude/statusline/statusline-oe-heartbeat.sh:9`・`:98`）。ほかの session_id の sidecar は、lease のペインを引く関数の候補にならない（`lib/heartbeat-resolve.sh:9-14`）。消さなくても誤った宛先にはならないので、`oe-lease gc` に任せる。

### `oe-vitals` の二重通知のキーに穴がある

- キーは `death|<session_id>`（`bin/oe-vitals:447`）。復帰のあとに同じ会話がもう一度落ちると、session_id が同じなので知らせが出ない、とコードから読める（実機では起きていない）。plan の DJ-8 でキーに binding を足す。

### verb の名前

- 仮称 `oe-reseat` の `seat` は、decision #577 の D16 が「使わない」と決めた語である。plan の DJ-1 で `oe-recover` を推奨にし、owner に確かめる（Q1）。

### 決め方の分け

- owner に聞く: DJ-1（名前）・DJ-2（generation）・DJ-6（前のプロセスを閉じる工程）・DJ-7（`delivery_held`）・drill の対象。
- 自分で決めた: DJ-3（流れ）・DJ-4（event の型）・DJ-5（古い子）・DJ-8（`oe-vitals`）・DJ-9（session_id の引き方）・DJ-10（手順の置き場）・DJ-11（別のリポジトリ）。どれも decision #577 か既存の形から導けるためである。

## P2: 設計SO（2026-11-08）

- レーン: Codex の1レーン（`so-compare --codex-only -w <worktree>`・`SO_TIMEOUT=600`）。`gpt-6.1-sol`（設定から解決）・`codex-cli 0.166.0`・198秒・リトライなし・判定「Issues Found」。依頼文と回答は、hub の作業ディレクトリの gitignored な `tmp/355-supervisor-recovery/`（`so-355-design-prompt.md` と `so-355-design/codex-stdout.txt`）に置いた。依頼文に `.oe/` の中身は入れていない。
- 採否は plan の「設計SO」の表（S-1〜S-11・N1〜N3）が正本である。ここには、判断が動いたところだけを書く。

### 一番大きく動いたところ: 派生の工程を「前の情報で直す」から「lease からまるごと作り直す」に変えた

- 最初の案は、registry の親のペインが前のペインのままの子を探してつけかえる、board の前のペインを前の binding から書く、という「前の情報を手がかりに直す」形だった。Codex は、`oe_lease_claim` が前の binding を残さずに上書きするので、張り替えたあとに止まると打ち直しで前の情報を引けないこと、tmux を起こし直すと前の server の registry は記録のたびに消えること、前のペインの番号は使い回されうることを挙げた。3つとも、コードを読んで当たっていると確かめた（`lib/lease.sh:283-290`・`lib/delegate-registry.sh:78`）。
- 直し: 前の binding は、張り替えと同じ1回の書き込みで `rebinds` に残す。registry は、lease の記録の親子から、いまのペインを引いて作り直す。前の registry と前のペインの番号は手がかりにしない。
- 撤回したもの: 「子の registry のつけかえに `oe-register link` を使う」。`link` は子の lease の親も書き換えて `epoch` を進める（`bin/oe-register:71-85`）ので、「子の lease は書き換えない」と食い違っていた。最初の案を書くとき、`oe-register` の lease の側の副作用を読んでいたのに（P1 で `lease_root_best_effort` を読んだ）、`link` の側を当てていなかった。

昇格の印: 「復帰の派生の工程は、前の情報でなく lease の記録といまの観測から作り直す」は、復帰の verb の設計の要なので、decision に残す候補である。

### `delivery_held` の主張を弱めた

- 最初の案は「送れなかった報告を拾える」と書いた。Codex は、送れなかった送信の履歴は未回収の報告の集合と同じではない（再送で届いたもの・同じ報告の繰り返しが混ざる・event の追記は best-effort）と指摘した。一覧は「要照合の履歴」として出し、空でも取りこぼしが無いとは言わない形に変えた。報告の受け箱（Codex の N3）は別の issue の候補として owner に見せる。

### 採らなかったもの

- N1（owner の普通のシェルで動く一括の復帰の道具）: decision #577 の D17（session_id の登録は本人の verb だけ）を変えることになる。
- N2（board と registry を書かず、読むときに作る）: registry は #577 の PR-5・PR-6 で読むのをやめる方向で、この drill がその条件である。この issue で先取りすると #577 の移行の順を崩す。

## P3: draft PR とゲート3 の問い（2026-11-08）

- plan と episode を `a0c9623` で commit し、draft PR #597 に載せた。
- ゲート3 の問いは6枚（verb の名前・generation の扱い・前のプロセスを閉じる工程・`delivery_held`・drill の対象・実装に進むか）で、統括のワークスペースの根の作業層に置いた（`build.py check` は誤りなし）。報告のファイルを書き、統括へ1行送った（`oe-send` の exit 0）。
- 報告の宛先は brief の明示を採った。送る前に `oe-tree` で、宛先のペインが hub の root の `cockpit` として alive であることを確かめた。
- ここで止まる。ゲート3 の承認の記録が届くまで実装に進まない。

## ゲート3（2026-11-08）

- owner は Q92〜Q97 の6件とも推奨どおりに答えた（判断ボード・統括が回収）。承認の記録は統括のワークスペースの根の `.oe/decision-355-gate3.md`（plan @ `2d32816`）。
- 確定版との違い: 確定版の「generation を進めて席を取る」は、統括が「書き方の誤り」と認めた（承認の記録の Q93）。plan の DJ-2（同じ会話の復帰は generation を進めず binding を張り替える）が正である。確定版は書き直さず、この節を違いの記録にする。
- Q94 に owner の補足「状況がわかりやすい説明と、next action のサジェスチョンをちゃんと出すこと」が付いた。統括の指示で、plan に補正 H1 として書き込んだ（plan の「ゲート3 のあとの変更」）。補足は Q94 のカードに付いたが、統括の指示の言い方（verb の止まったときの案内の要件）に合わせ、verb が止まるときのすべてに当てた。範囲を広げた読みなので、申告のときに統括に見せた。

## I1: lib の直し（2026-11-08）

- `oe_lease_claim` と `oe_lease_bind` は、別のプロセスへ binding を張り替えるとき、張り替える前の binding に `replaced_at` を足して、その generation の `rebinds` に同じ1回の書き込みで足すようにした。binding が無いところへの最初の書き込みと、本人がもう一度取るときは足さない。lease の schema と `scripts/validate-lease.sh` に、任意の項目として `rebinds` を足した。
- `oe_seat_rewrite` に7つ目の引数として註の種類（`handoff` が既定・`recover`）を足した。復帰の註は「前のペイン `%N` は応答なし・復帰で張り替え」で、「前任 `%N`」の形を使わない。`oe-handoff retire` は「前任 `%N`」の最初の一致を閉じる相手として読むので、復帰の註の前のペインを閉じる相手と読まないことをテストで確かめた（`tests/test_handoff_take.sh` の [37]）。
- 確かめ: `test_lease.sh`（136）・`test_handoff_take.sh`（139）を含む関係の13本がすべて終了コード 0。触ったファイルは shellcheck を通った。
- 気づいたこと（直していない）: `tests/test_handoff_take.sh:487` の `rmdir()` に、shellcheck 0.11.0 が SC2329（info）を出す。master の同じファイルでも出るので、この変更から来たものではない。既存の disable は SC2317 で、0.11.0 では番号が SC2329 に分かれたものと思われる [speculation]。この PR の範囲の外として報告に書く。

## I2: verb `oe-recover`（2026-11-08）

- `bin/oe-recover` を足した。本体（resume した本人が打つ）と `hint`（resume の前に普通のシェルから打つ・読むだけ）の2つの入口を持つ。流れは plan の DJ-3 の 1〜8 のとおりで、止まるときと済んでいない工程が残るときは、H1 の3つの節（いまの状況・書いたもの／書かなかったもの・次にやること）を出す。
- step の境の動き: plan では event の型（schema と `lib/event-bus.sh` の関数）を I3 に置いていたが、verb が `supervisor_recovery` を書くので I2 で足した。`delivery_held` の関数と schema も同じときに足した（`oe-send` から呼ぶのは I3）。中身は plan の DJ-4・DJ-7 のままで、記録の級の直し（step の中の順を入れ替えただけ）と読む。
- schema の `reason` は交代の型の enum なので、`delivery_held` の理由は `held_reason` という別の項目にした（同じ名前を2つの意味に使わない）。
- 撤回: schema を最初に JSON として読み書きしたら、ファイル全体の書式が変わって差分が 265 行になった。自分の変更だけだったので元に戻し、文字列の置き換えで足し直した（差分 39 行）。
- テスト `tests/test_oe_recover.sh`（84 件）: T-1〜T-8・T-11〜T-13。偽の ps・tmux・kill・date に差し替え、足がかりの `oe-tree` も偽の bin に置き、`~/bin` を PATH から外し、state の置き場を一時ディレクトリに向けた（negative knowledge `01M5T897YCWY13GFTADD3136EC`）。最後に本物の置き場が書かれていないことを確かめる。
- テストを書く途中で2つ外れ、どちらもテストの偽物の不足だった。1つは、偽の tmux が `list-panes -F '#{pane_id} #{pid}'`（registry の掃除が server の pid を確かめる書式）に答えず、掃除が走らなかったこと。もう1つは、T-11 で binding を途中で移す仕掛けを偽の `date` に置いたら、board の日付より先に、張り替えの時刻を作る呼び出しで動いたこと。偽の `date` は `+%Y-%m-%d` のときだけ動くようにした。
- 出力の実物を1回見て（成功の場合と、前の claude が生きている場合）、「前の binding（… から）のあいだ」の言い方を「前の binding が張られた時刻（…）より後」に直した。
