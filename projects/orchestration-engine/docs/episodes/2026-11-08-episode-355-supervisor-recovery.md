---
id: "01M6XCD1N8KVH8DYNCPG5Z4F5W"
title: "#355 統括が応答しないときの復帰を verb 1本に畳む（設計）"
date: 2026-11-08
type: episode
status: stable
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
  - type: reference
    ref: "projects/orchestration-engine/docs/decisions/2026-11-08-decision-355-supervisor-recovery.md"
    reason: "この単位から昇格した decision（D1〜D4）"
  - type: reference
    ref: "projects/orchestration-engine/docs/knowledge/items/01M6XN85N408CMMERA12QR1C3F.md"
    reason: "この単位から収穫した negative knowledge（非対話の wrapper の中で起こした claude は、前面のプロセスで本人を確かめられない）"
tags: [orchestration, supervisor, recovery, lease, design]
promotion:
  - subject: "同じ会話の復帰では generation を進めず binding だけを張り替える"
    verdict: required
    ref: ["本文: 確定版の「generation を進めて席を取る」は、いまの lib の決まりと合わない", "本文: ゲート3（2026-11-08）"]
  - subject: "復帰の派生の工程は前の情報でなく lease の記録といまの観測から作り直す"
    verdict: required
    ref: "本文: 一番大きく動いたところ: 派生の工程を「前の情報で直す」から「lease からまるごと作り直す」に変えた"
  - subject: "送れなかった送信は delivery_held に残し、要照合の履歴として出す"
    verdict: required
    ref: ["本文: `delivery_held` の主張を弱めた", "本文: GATE 4: 実装SO（2026-11-08）"]
  - subject: "前の claude が生きていれば verb は閉じず、閉じるのは owner である"
    verdict: required
    ref: "本文: ゲート3（2026-11-08）"
  - subject: "verb の名前を oe-recover にする"
    verdict: not-required
    ref: "本文: verb の名前"
  - subject: "oe-vitals の death の重複抑止のキーを lease と binding の組にする"
    verdict: not-required
    ref: ["本文: `oe-vitals` の二重通知のキーに穴がある", "本文: I3: `delivery_held` と `oe-vitals`（2026-11-08）"]
  - subject: "止まったときの案内に状況と次にやることを出す（H1）"
    verdict: not-required
    ref: "本文: ゲート3（2026-11-08）"
  - subject: "非対話の wrapper の中で起こした claude は前面のプロセスで本人を確かめられない"
    verdict: required
    ref: "本文: drill の1回目: seed が rc 6 で黙って止まった（2026-11-08）"
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

## I3: `delivery_held` と `oe-vitals`（2026-11-08）

- `lib/target-resolve.sh` は、lease の宛先を確かめられずに外れた理由を終了コードに畳んでいた。理由を `OE_TARGET_WHY`（closed / unresolved / not_self / no_binding / unknown）にも残すようにした。送る・送らないの判定と終了コードは変えていない。
- `bin/oe-send` は、`--to-parent` で親の lease へ送れなかったときだけ `delivery_held` を書き、「送れなかったことを残した。報告のファイルは置いたままにして」と出す。`OE_LEASE_ID` の無い子（親の lease が無い）は書かない。
- `bin/oe-vitals` は、統括の lease で判定した death の重複抑止のキーを `death|<lease_id>|<generation>|<binding の pid>|<開始時刻>` にした。`OE_VITALS_NOTIFY=0` で通知を止める口を足した。context の知らせと board で判定したときのキーは変えていない。
- テスト: T-9 は `tests/test_target_resolve.sh` の (D)(7)(8)、T-10 は `tests/test_lease_handoff.sh` の (H)。偽の `wez` を置いて、通知の回数を数えた。
- 気づいたこと（直していない）: `bin/oe-send:28` の `OE_TARGET_CALLER` に shellcheck 0.11.0 が SC2034（warning）を出す。master の同じファイルでも出る。source した lib が読む変数で、`-x` を付けても消えない。この PR の範囲の外として報告に書く。

## I4: 手順の置き場（2026-11-08）

- `projects/orchestration-engine/bin/README.md` に `oe-recover` の節（使い方・人が打つ手順・verb がすること・exit）を足し、索引の本数を 27 から 28 にした。`oe-vitals` の節の重複抑止のキーの文を直した。`projects/orchestration-engine/README.md` の表と木に `oe-recover` を足した。
- `canonical/skills/doc-flow-guardrail/SKILL.md` の「復旧（前任が応答しない）は本スキルの範囲外」の行を、⑤「応答しない統括の復帰」の節に置き換えた。計画的な交代（④）と同じく、routing 先が同じ穴を持つので本スキルが持つ例外にし、冒頭の「例外が2つ」を3つにした。description にも発火の場面を1つ足した。スキルの文は hub のパスに頼らず、コマンド名と「verb 解決規約」で引いた `$oe_bin/README.md` で書いた。

## CHECK（2026-11-08）

- engine の `tests/test_*.sh` 61 本を走らせ、60 本が終了コード 0。落ちた1本は `tests/test_home_unset.sh` の「`_oe_home_usable` の定義は1種類」で、master（`df16c60`）の作業ツリーでも同じく落ちる。`lib/handoff-state.sh` の定義が複数行で書かれていて、1行の定義と別の種類に数えられるためで、この PR の変更から来たものではない。範囲の外として報告に書く。
- 触ったファイル（`bin/oe-recover`・`lib/lease.sh`・`lib/seat.sh`・`lib/event-bus.sh`・`lib/target-resolve.sh`・`bin/oe-vitals`・`scripts/validate-lease.sh`・足したテスト）は shellcheck を通る。`bin/oe-send` の SC2034 と `tests/test_handoff_take.sh` の SC2329 は master から残っているもので、I1 と I3 に書いた。

## GATE 4: 実装SO（2026-11-08）

- レーン: Codex の1レーン（`gpt-6.1-sol`・設定から解決・224秒・リトライなし）。依頼文と回答は hub の作業ディレクトリの `tmp/355-supervisor-recovery/so-355-impl-prompt.md` と `so-355-impl/codex-stdout.txt`。
- 指摘は8件（高1・中6・低1）で、すべて採って直した。

| 番号 | 指摘 | 重さ | 直し |
|---|---|---|---|
| 1 | 自分のペインの本人確認が「分からない」でも先へ進み、本人でないペインを board と registry に書きうる | 高 | 分からないときは何も書かずに止まる |
| 2 | 死んだ復帰のロックを2つが同時に引き取ると、あとの持ち主のロックを消せる | 中 | `lib/lease.sh` の `_oe_lease_lock`（引き取りのロックを持つ1人だけが片づける）に置き換えた |
| 3 | pid を書く前に落ちると、空のロックを永久に引き取れない | 中 | 同上（空のまま古くなったロックを引き取る） |
| 4 | `still_mine` が、閉じられた lease への書き込みを止めない | 中 | lease が開いていることも見る |
| 5 | binding が自分のとき、取り込みで作られた lease に session_id を登録しない | 中 | binding が自分でも、session_id が無ければ登録する |
| 6 | 二重に落ちると、送れなかった送信の一覧の下限が縮む | 中 | 下限の決め方を直した（plan の補正 H2） |
| 7 | 子の lease の記録を読み損ねると、黙って飛ばして complete にする | 中 | 読めなかった記録は「済んでいない」に入れる |
| 8 | テストの「死んだ pid」999999 を本物のプロセス表で判定している | 低 | 生きていない pid を探して使う |

- 指摘6は実装の誤りではなく、plan の DJ-7 の「最後の要素」という決め方そのものの穴だった。設計SO（P2）で S-1 を直したとき、打ち直しで前の binding を引けることだけを見て、打ち直しが二重になったときの下限までは当てていなかった。
- 足したテストを含め、`tests/test_oe_recover.sh` は 92 件が通り、関係する9本も終了コード 0。

## I5: クラッシュ drill の準備（2026-11-08）

- drill の道具を hub の作業層 `tmp/355-supervisor-recovery/drill.sh` に置いた（commit しない）。`up` が使い捨ての統括と子を tmux の新しいウィンドウに立て、記録の置き場（lease・heartbeat・registry・event）と board を `tmp/355-supervisor-recovery/drill/` に向ける。`claude --session-id` で会話の session_id を前もって決め、`seed` で2つを lease の binding にする。
- 子を `oe-delegate` で起こさなかった理由: `oe-delegate` は tmux の新しいペインでコマンドを起こすので、ペインの環境は tmux server の環境から来る。記録の置き場を一時ディレクトリに向ける環境変数が子に渡らず、子がいまの置き場に書いてしまう。drill は2つとも、環境変数を付けたコマンドで直接立てる。
- 依頼の手順は統括のワークスペースの根の `.oe/request-355-drill.md`。owner が打つのは、立てる・結び付ける・落とす・送れないことを残す・hint・resume・「復帰して」で、計測の対象は hint から後である。統括に H2 の申告と一緒に送った（`oe-send` の exit 0）。手順 7 の知らせを待つ。

### drill の1回目: seed が rc 6 で黙って止まった（2026-11-08）

- 何が起きたか: owner が手順1（`up`）を通したあと、手順2（`seed`）が何も出さずに止まった。統括が `bash -x` で確かめ、`oe_lease_bind` が rc 6（コマンドが claude でない）を返し、`set -e` で黙って終わっていたと分かった。
- 原因: `up` は tmux に「`cd … && . env.sh && … claude …; exec bash`」を渡していた。非対話の `bash -c` はジョブ制御を持たないので、claude を自分と同じプロセスグループで起こす。ペインの端末の前面のプロセス（pid と tpgid が一致する行）はその bash（comm `bash`）になり、`oe_tpi_pane_foreground` は bash を返した。
- 直し: claude を `exec` で起こす形にした（`OE_LEASE_ID=… exec claude …`）。ペインの最初のプロセスも前面のプロセスも claude になる。`oe-delegate` と `oe-handoff start` も同じ形で起こしている。`seed` は、失敗したところで理由（前面のプロセスの pid とコマンド名・lib の戻り値）を出してから止まるようにした。
- 分かったこと: 非対話の wrapper（`bash -c "…; claude …"`）の中で claude を起こすと、前面のプロセスで本人を確かめる仕組み（decision #577 の D6・D9）は claude を見つけられない。対話のシェルで打った claude は、シェルがジョブ制御で別のプロセスグループに置くので、この問題は起きない。owner が resume を打つのは対話のシェルなので、復帰の手順そのものは当たらない。ただし、wrapper の中で claude を起こす使い方をすると、`oe-recover` は自分のペインの本人確認（DJ-3 の 1）で止まる（実装SO の指摘1 の直しで、分からないときと一致しないときは止まる）。
- 昇格の印: 「lease の本人確認は、claude がペインの前面のプロセスグループの長であることを前提にしている。非対話の wrapper の中で起こすと成り立たない」は、`oe-*` の verb で claude を起こす場所すべてに当たる前提なので、decision #577 の D6 の帰結に足す候補である。

昇格の印: 非対話の wrapper の中で起こした claude は、前面のプロセスで本人を確かめられない（decision #577 の D6 の前提）

### drill の2回目: resume した統括で oe-recover が exit 127（2026-11-08 22:10 ごろ）

- 何が起きたか: owner が手順6まで打ったが、resume した drill の統括（新しいペイン）で `oe-recover` が exit 127（PATH に無い）で止まった。統括が確かめ、`oe-recover hint` を打ったペイン（`env.sh` を読み込み済み）と、resume の1行を打ったペイン（新しいペインで `env.sh` を読み込んでいない）が別だったと分かった。本物の記録は無傷だった（統括が lease 9件のまま・`supervisor_recovery` 0件を確かめた）。owner は同じペインで `env.sh` を読み込み、resume と「復帰して」をやり直す。計測では、この失敗した試行を除いて数える。
- drill の側の原因: `hint` が出す1行は `OE_LEASE_ID`・`OE_GENERATION` と resume だけを持ち、PATH と記録の置き場の環境変数（`OE_*_DIR`）を持たない。本番は既定の置き場なので要らないが、drill は置き場を一時ディレクトリに向けているので、同じペインで `env.sh` を読み込まないと動かない。依頼の手順5は「新しいペインで env.sh を読み込み、hint を打ち、出た1行をそのペインで打つ」と書いていたが、hint と resume を同じペインで打つことを強く書いていなかった。
- 足すかを決めたこと（drill の hint の1行に、drill 用の前置きを付けるか）: 付けない。`hint` が、既定でない置き場の環境変数（`OE_LEASE_DIR` など）が設定されているときだけ、それを出す1行に付ける案は考えられる。ただしそれは drill のためだけの働きで、本番の利用者は既定の置き場を使う。drill の依頼の文で「hint と resume を同じペインで打つ」を強く書くほうが範囲が小さい。次に drill を回す人のために、この節を残す。
- 本番にも当たる抜け（直した）: resume した統括が `oe-recover` を素の名前で打つと、本番でも同じ exit 127 になる。`oe-*` は原則 PATH に無く、起動方法は `doc-flow-guardrail` の「verb 解決規約」節で決めるからである。drill の統括は依頼の文（「PATH にある」）に従って素の名前で打った。I4 で足した ⑤ の手順1が「verb 解決規約」節を指していなかったので、1文足した。級は補正（承認した I4 の節の書き漏れを直すだけで、手順は変えない）として申告する。

## I5: クラッシュ drill の結果（2026-11-08 22:15 JST・3回目の試行で通った）

落とし方は落ち方 b（`tmux kill-pane` で統括のペインごと消す）。使い捨ての統括の lease `20261108130815PTK22S76GVBR`・子の lease `202611081308155CB17RB8WDAG`。記録の置き場はすべて `tmp/355-supervisor-recovery/drill/` に向けた（統括が、本物の lease が9件のままで `supervisor_recovery` が0件であることを確かめた）。

### 確かめる3点（`drill.sh check`・22:20 ごろ）

| 確かめること | 結果 |
|---|---|
| `oe-tree --lease` に統括が alive として出る | 出た: `drill-cockpit  supervisor gen 1  alive  %628`。子も `alive  %626` で統括の下に出た |
| 統括の heartbeat の sidecar が pane と server_pid を持つ | 持つ: `{"pane":"%628","server_pid":"739","lease_id":"20261108130815PTK22S76GVBR","generation":1}` |
| `oe-vitals` が偽の知らせを出さない | 出さない: `現統括 %628は健全（beat fresh/0m · ctx=7% · pane=alive）→ 検知なし`（`OE_VITALS_NOTIFY=0`・lease で判定） |

- lease の記録: generation は 1 のまま、binding は pid 83766（復帰した claude）、`rebinds` に落ちた claude の pid 26398、session_id は1つ。DJ-2（generation を進めない）のとおりである。
- event: `supervisor_recovery` が1行・`complete: true`・`undone: []`・前の binding 26398・ペイン `%628`。
- 落ちていたあいだの子の送信（`drill.sh held`）は `delivery_held`（`not_self`・brief つき）として残り、統括の報告によれば `oe-recover` の一覧に1件出た。

### 子の報告が新しいペインに届く（`drill.sh deliver`）

- 子として `oe-send --to-parent` を打つと、`sent to %628（lease 20261108130815PTK22S76GVBR generation 1）`・終了コード 0 だった。復帰した統括の会話の記録に、その1行が 13:20:50Z に入力として入っていることを確かめた（会話の記録の user の行）。子の lease の親は書き換えていない。

### 達成を見る数: 復帰1回に人が打つ操作の回数

- 数え方は統括の指示のとおり、失敗した試行を除く（1回目は 22:10 ごろの exit 127、2回目は session_id の末尾1文字が欠けた resume の打ち間違い）。
- owner: `oe-recover hint` が1回・resume の1行が1回・「復帰して」が1回。Bash の実行の許可の数は、統括の知らせに無く、会話の記録からも見分けられなかったので「未確認」とする。
- 統括（resume した会話）: 「復帰して」（13:15:20Z）を受けてから打ったコマンドは `oe-recover` の1回だけで、登記・board・つけかえのコマンドは0回だった（会話の記録の tool_use を数えた。13:20 以降の Read と ls は、届いた子の報告に応じたもので、復帰の工程ではない）。
- 比べると: いままでは「owner の指示1 + resume をセッションの数 + 統括の手作業3〜4」だった。今回は「owner の hint 1 + resume 1 + 復帰して 1（+ 許可は未確認）+ 統括の verb 1」で、統括の手作業は0になった。owner の手数は hint の1回が増えた。そのかわりに session_id を探す工程は無くなった。

### drill の手順の側で分かったこと（次に回す人のため）

- 1回目: `up` が非対話の wrapper の中で claude を起こしていて、前面のプロセスが bash になり seed が止まった（上の節）。
- 2回目: hint を打ったペインと resume を打ったペインが別で、drill の環境（PATH と置き場）が resume した会話に渡らなかった（上の節）。
- 3回目の前: resume の1行を手で打ち直したときに session_id の末尾1文字が欠け、「no session match」になった。hint の1行はコピーして打つ前提で、手で打ち直すと誤りうる。

## closure（2026-11-08・PR #597 の Copilot のレビューの前に書き、レビューのあとに足す）

tier は heavy である（設計SO と実装SO を明示して起動した・撤回があった・選択肢を比べて棄却した・昇格がある）。この節は本文を指すだけで、本文の再掲はしない。

### closure gate

- Context: `本文: なぜこの作業が始まったか`
- 次の消費者: #577 PR-6（移行の片付け）を担う子と統括。この drill が PR-6 の条件で、registry を作り直す工程（DJ-3 の 6-2）は PR-6 のあとに要らなくなる。次に復帰の流れを触る人（報告の受け箱・`SessionStart` hook・サスペンドと resume）も読む。
- status: stable。達成度は「達成」（受入の4つ: 確定版の各項目・テスト・クラッシュ drill・達成を見る数）。ただし owner の許可の数は未確認（`本文: 達成を見る数: 復帰1回に人が打つ操作の回数`）。
- evidence anchor: SO の依頼文と回答は hub の作業層 `tmp/355-supervisor-recovery/` にあり、git の対象外である。要点（判定・指摘の件数・採否）は plan の「設計SO」の表と `本文: GATE 4: 実装SO（2026-11-08）` に写してある。drill の数値（pid・lease_id・event）は `本文: I5: クラッシュ drill の結果（2026-11-08 22:15 JST・3回目の試行で通った）` に写してある。
- SO 証跡: 設計SO `本文: P2: 設計SO（2026-11-08）`・実装SO `本文: GATE 4: 実装SO（2026-11-08）`。
- 観測の書き戻し: brief で注入された negative knowledge は `01M5T897YCWY13GFTADD3136EC` の1件で、`followed`（ref `#355`）を1件書き戻した。根拠は `tests/test_oe_recover.sh` の足場（偽の bin に足がかりの `oe-tree`・`~/bin` を外す・置き場を一時ディレクトリ・本物の置き場を見る）で、Bash 組み込みの `kill -0` が偽物を通らない抜けを実装SO が見つけたことも注記した（`本文: GATE 4: 実装SO（2026-11-08）`）。
- 認識合わせの抜け: 確定版に無かった要件は2つ見つかった。どちらも見つけたその場で本文に書いた。1つは「generation を進める」が lib の決まりと合わないこと（`本文: 確定版の「generation を進めて席を取る」は、いまの lib の決まりと合わない`・ゲート3 で owner が確定版の書き方の誤りと認めた）。もう1つは、resume した統括が `oe-recover` を verb 解決規約で引く必要があること（`本文: drill の2回目: resume した統括で oe-recover が exit 127（2026-11-08 22:10 ごろ）`）。後者は hub の文脈の置き場（スキル）に入れた。どちらも `issue-intake` の固定の問いに足す種類ではない。

### 事実・失敗

- 確定版の「generation を進める」が lib の決まりと合わなかった: `本文: 確定版の「generation を進めて席を取る」は、いまの lib の決まりと合わない`
- 最初の派生の工程の案（前の registry を手がかりに `oe-register link`）は、設計SO の指摘で撤回した: `本文: 一番大きく動いたところ: 派生の工程を「前の情報で直す」から「lease からまるごと作り直す」に変えた`
- schema を JSON として書き直して差分が膨らみ、元に戻した: ``本文: I2: verb `oe-recover`（2026-11-08）``
- テストの偽物の不足が2つ（偽の tmux の書式・偽の date の仕掛けの位置）: ``本文: I2: verb `oe-recover`（2026-11-08）``
- 実装SO の指摘8件（高1）: `本文: GATE 4: 実装SO（2026-11-08）`
- drill の1回目（wrapper の中の claude）と2回目（hint と resume が別のペイン）と、3回目の前の session_id の打ち間違い: `本文: drill の1回目: seed が rc 6 で黙って止まった（2026-11-08）`・`本文: drill の2回目: resume した統括で oe-recover が exit 127（2026-11-08 22:10 ごろ）`・`本文: drill の手順の側で分かったこと（次に回す人のため）`

### 決定と根拠

- 昇格した decision: `projects/orchestration-engine/docs/decisions/2026-11-08-decision-355-supervisor-recovery.md`（D1〜D4）。棄却した案と理由は decision と plan の DJ が持つ。

### 昇格の判定（frontmatter の `promotion` と1対1）

- 同じ会話の復帰では generation を進めず binding だけを張り替える: required → decision の D1 に入れた（この PR）。複数の解釈が実際にあり（確定版が逆を書いた）、覆すには generation の意味の議論が要り、新しく入る人も同じ分岐に立つ。
- 復帰の派生の工程は前の情報でなく lease の記録といまの観測から作り直す: required → decision の D2（この PR）。最初の案が実際にあり、棄却の理由は実物の確認だけでは復元できない。
- 送れなかった送信は delivery_held に残し、要照合の履歴として出す: required → decision の D3（この PR）。decision #577 の D15 が申し送った判断で、受け箱の案との比較が残る。
- 前の claude が生きていれば verb は閉じず、閉じるのは owner である: required → decision の D4（この PR）。自動で閉じる案との比較で、価値判断（作業の途中のプロセスを守る）を含む。
- verb の名前を oe-recover にする: not-required。理由（seat を使わない）は decision #577 の D16 が持ち、名前は `bin/README.md` を読めば正しく使える（1段目で外れる）。
- oe-vitals の death の重複抑止のキーを lease と binding の組にする: not-required。理由はコードの注記（`bin/oe-vitals` のキーの直前）にあり、正本だけを見て正しく使える（1段目で外れる）。
- 止まったときの案内に状況と次にやることを出す（H1）: not-required。owner の要件で、手順は `bin/README.md` とスキル ⑤ にあり、覆すのに議論は要らない。
- 非対話の wrapper の中で起こした claude は前面のプロセスで本人を確かめられない: required → negative knowledge として収穫した（`projects/orchestration-engine/docs/knowledge/items/01M6XN85N408CMMERA12QR1C3F.md`・この PR）。decision #577 の D6 の前提に足すかは、#577 の仕組みについての判断なので、この PR では入れない（下の follow-up）。

### 蒸留シグナル

- decision: 上の D1〜D4（入れた）。knowledge store: 1件（入れた）。skill: `doc-flow-guardrail` ⑤（入れた・I4）。rule: なし。

### 残課題と行き先

- decision #577 の D6 の帰結に「前面のプロセスで本人を確かめるのは、claude が前面のプロセスグループの長であることが前提」を足すか: 行き先は統括（#577 の仕組みの判断なので、決めるのは #577 の側の担当）。報告に書く。knowledge item は収穫済みなので、教訓そのものは store にある。
- #577 PR-6 の条件（この drill）が満たされた: 行き先は統括（PR-6 は別の子が行う）。報告に書く。
- 別の会話が死んだ持ち場を引き取る口・報告の受け箱・`SessionStart` hook の自動の復帰・サスペンドと resume に近い形: 行き先は decision の「決めていないこと」と issue #355 の範囲外の記録。issue にするかは owner と統括が決める（報告に書く）。
- master から残っている検査の失敗（`bin/oe-send` の SC2034・`tests/test_handoff_take.sh` の SC2329・`tests/test_home_unset.sh` の helper の数え方）: 行き先は統括（issue にするかの判断）。この PR では直さない。報告に書く。
- drill の hint の1行に drill 用の前置きを付けるか: 追わない（理由は `本文: drill の2回目: resume した統括で oe-recover が exit 127（2026-11-08 22:10 ごろ）`）。
- owner の Bash の許可の数: 確かめられなかった。追わない（目標の中身は「統括の手作業を0にする」で、許可の数はそれに効かない）。

### Step 4（外部チェック）

PR の Copilot のレビューのあとに、`so-compare` で closure の focused check を1回入れる（下に結果を足す）。

### 形式メモ

- 拾えたもの: 撤回（派生の工程・schema の書き直し）と、drill の3回の失敗。拾えなかったもの: owner の許可の数。皮（KPT/YWT）は使っていない。摩擦: SO の回答が作業層にしか無いので、要点を本文に写す手間が要った。


## I6: #576 のセッション名を hint に足した（2026-11-08）

- #576（統括のセッション名）が master `0433e18` に入ったと統括から知らせが来た。`oe-recover hint` が、セッション名の記録（hook との約束の形）を読むだけで引き、名前があれば `claude -r '<名前>'` の1行も出すようにした。一覧から探す道（`claude -r cockpit`・↓・Ctrl+A）も出す。plan の補正 H3 として申告する。
- このブランチは `df16c60` から切ったので #576 のコードを持たないが、名前の記録の形は hook との約束なので、lib を使わずに記録の形だけを読んだ。master との衝突は無い（`git merge-tree` で確かめた）。
