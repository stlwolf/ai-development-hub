---
id: "01M6XCD1P0SVJZYMA56Y5M6CTC"
title: "#355 統括が応答しないときの復帰を verb 1本に畳む"
date: 2026-11-08
type: plan
status: draft   # 設計まで。ゲート3 の承認を待つ
so:
  design: weak
  impl: weak
  reason: "復帰の設計は decision #577 と見取り図で大枠が決まっていて、plan で決めるのは verb の内側の順と境界である。設計SO は Codex の1レーン（返らなければ Cursor に1回だけ）、実装SO は1レーンと Copilot の1ラウンド（brief の指定）"
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/355"
    reason: "本 plan の issue"
  - type: reference
    ref: "https://github.com/stlwolf/ai-development-hub/issues/355#issuecomment-6719836978"
    reason: "着手時の認識合わせの確定版（通し直し・2026-11-08）。この plan はその各項目を網羅する（「確定版の項目との対応」の表）"
  - type: design_context
    ref: "projects/orchestration-engine/docs/decisions/2026-11-06-decision-577-record-identity-key.md"
    reason: "復帰の前提（lease と generation・binding・D5 の張り替えの決まり・D9 の生死の確かめ・D11 の移行・D13 の event・D15 の申し送り）"
  - type: design_context
    ref: "projects/orchestration-engine/docs/discussions/2026-07-13-discussion-supervisor-succession-recovery-and-observability.md"
    reason: "復帰を verb にする元の設計材料（§4 の原則・§5 の増分）"
  - type: reference
    ref: "projects/orchestration-engine/docs/episodes/2026-11-08-episode-355-supervisor-recovery.md"
    reason: "この plan の作業の記録"
tags: [orchestration, supervisor, recovery, lease, plan]
---

# #355 統括が応答しないときの復帰を verb 1本に畳む

## 背景

統括のセッションが落ちたりペインが消えたりしたあと、同じ会話を `claude --resume` で開き直しても、統括の席・登記・子の報告先が死んだペインを指したまま残る。2026-09-09 から 10-30 までの5回の復帰では、そのたびに統括が手で3〜4つの直し（登記・board の現統括の行・子のつけかえ・宛先の通知）をした [unverified-summary]（復帰の見取り図 https://claude.ai/artifact/4vEcRUnnAHYUVhkXeMpY1i の「実例」の表）。

#577 で、統括と子の「誰か」は tmux のペインでなく lease の記録（`lease_id` と `generation` と `binding`）で持つようになった [verified]（`projects/orchestration-engine/docs/decisions/2026-11-06-decision-577-record-identity-key.md` の D1・D12・D14）。この plan は、その上に、resume した統括が1回打てば復帰が終わる verb を作る。

## この plan の範囲

- 範囲: 復帰の verb（名前は DJ-1）・その verb が使う小さな直し（`oe_lease_claim` が張り替える前の `binding` を `rebinds` に残すことと lease の schema・`oe_seat_rewrite` の註の種類の引数・`oe-vitals` の通知の重複抑止のキーと通知を止める口・`oe-send --to-parent` の保留の記録・event の型）・テスト・`bin/README.md` と配布するスキルの復帰の工程・クラッシュ drill 1回。
- 範囲の外:
  - サスペンドと resume に近い形（owner の 2026-10-17 の補足）。確定版のとおり別の issue に派生させる。
  - `SessionStart` hook による自動の復帰（issue 本文のスコープ外。verb を土台にして後で足す）。
  - #577 PR-6（移行の片付け）。この issue の drill が PR-6 の条件である（decision #577 の D11）ことだけを書き、片付けは別の子が行う。
  - #576（統括のセッション名）。別の子が並行して進めている。この plan は #576 が入ることを前提にしてよいが、名前に頼らない経路も残す（DJ-9）。
  - 母集団の拡大（登記に無い生存セッションを cockpit に出す話）と、`$TMUX` が消える根本原因（#338）。

## 前提（読んで確かめた事実）

- P-1 同じ会話を resume しても `generation` は進まない。`generation` は交代（`oe_lease_advance`）でだけ進む [verified]（`projects/orchestration-engine/lib/lease.sh:11`）。
- P-2 `oe-lease bind` は、本人の Bash から打つと、いまの `generation` の `binding` を自分のプロセスに張り替え、自分の session_id を登録する。張り替えるのは、前の `binding` のプロセスが生きていないと確かめられたときか、もう自分のときだけで、生きているか分からなければ断る（rc 5）。張り替えと登録は1回の書き込みである [verified]（`projects/orchestration-engine/bin/oe-lease:106` 以降の `bind)` の節・`lib/lease.sh` の `oe_lease_claim`）。
- P-3 `OE_LEASE_ID` を持つ子は、`oe-send --to-parent` で親の lease のいまの `generation` へ送る。lease の記録から送り先を引き、送る前にペインのフォアグラウンドのプロセスが `binding` と一致するかを確かめる [verified]（`projects/orchestration-engine/bin/oe-send:14`・decision #577 の D6 と D14）。したがって、統括が同じ lease に戻れば、こういう子の lease の親を書き換える必要は無い。`oe-delegate` は #577 PR-2 から子に `OE_LEASE_ID` を渡している [verified]（`projects/orchestration-engine/bin/oe-delegate:208`）。
- P-4 registry（`~/.claude/state/oe-delegate/`）は、移行のあいだ lease と両方書いている。registry をキーとして読むのをやめる最後の切り替えは、この issue の drill のときに一度に行ってよい（decision #577 の D11・plan #577 の PR-5 の行）[verified]（`projects/orchestration-engine/docs/plans/2026-11-06-plan-577-record-identity-key.md:93`）。それまでは `oe-tree`（既定の表示）などが registry を読むので、復帰でも registry を直す必要がある。
- P-5 heartbeat の sidecar のファイル名は session_id である [verified]（`canonical/claude/statusline/statusline-oe-heartbeat.sh:9` と `:98`）。同じ会話を resume すると、同じファイルが新しいペインで上書きされる。ほかの session_id の古い sidecar は、lease のペインを引く関数の候補にならない（候補は `generation` の session_id の並びか、sidecar の `lease_id` と `generation` が一致するものだけ）[verified]（`projects/orchestration-engine/lib/heartbeat-resolve.sh:9-14`）。
- P-6 `oe-vitals` は統括の lease を見つけると、`binding` のプロセスが無いと確かめられたときだけ death の知らせを出す [verified]（`projects/orchestration-engine/bin/oe-vitals` の冒頭の「統括の lease を読む」の注記）。二重通知を抑えるキーは `death|<session_id>` である [verified]（`projects/orchestration-engine/bin/oe-vitals:447`）。
- P-7 event の schema は、応答しない前任からの復帰を `supervisor_succession` の型で書かないと決めている [verified]（`projects/orchestration-engine/schemas/oe-events.schema.json:75`）。`lease_bound` の型には `bind_reason: rebind` がある [verified]（`projects/orchestration-engine/lib/event-bus.sh:186-198`）。
- P-8 `oe-register root` は、自分の lease が `oe_lease_whoami` で引ければその lease を使い、`binding` は張り替えない [verified]（`projects/orchestration-engine/bin/oe-register:47` 以降）。
- P-9 hub の統括の lease は、いま1つで、`generation` 1（取り込みで作られた）である [verified]（`~/.claude/state/oe-lease/` を読むだけで確かめた・2026-11-08）。
- P-10 `oe-handoff retire` は、閉じてよいかを lease の前の `generation` の `binding` とペインのフォアグラウンドのプロセスで判定する。シェルで始まるペインの前任も閉じられる [verified]（`projects/orchestration-engine/bin/oe-handoff` の `cmd_retire` の「lease の記録」の節・decision #577 の D9）。

## 設計判断

owner に聞くものは「ゲート3 の問い」に出し、ここには推奨を書く。印の無いものは自分で決めた。

### DJ-1 verb の名前と置き場（owner に聞く・Q1）

- 選択肢: (a) 新しい verb `oe-recover`。(b) 仮称どおり `oe-reseat`。(c) `oe-lease recover` の subcommand。(d) `oe-handoff recover` の subcommand。
- 推奨: (a)。
- 理由: decision #577 の D16 は「`seat` は current_supervisor の意味から外す方向（#564）なので使わない」と決めている [verified]（decision #577 の D16）。(b) はそれに反する。(c) は `oe-lease` が「記録の読み書きを呼ぶだけ」の verb で、board・registry・送信まで持たせると役割が混ざる。(d) は `oe-handoff` の冒頭が「応答しない前任からの復帰は本 verb の担当ではない（#355 の別 verb）」と書いている [verified]（`projects/orchestration-engine/bin/oe-handoff:13`）。`recover` は `oe_lease_advance` の `recover` の語と合う。

### DJ-2 同じ会話の復帰は `generation` を進めず、`binding` を張り替える（owner に聞く・Q2）

- 選択肢: (a) 同じ会話を resume したときは `binding` の張り替え（`oe_lease_claim`）だけにし、`generation` は進めない。別の会話が死んだ lease を引き取るとき（会話を戻せないとき）は対象にしない。(b) (a) に加えて、別の会話が引き取るときは `oe_lease_advance ... recover` で `generation` を進める口を持つ。(c) 復帰でも必ず `generation` を進める。
- 推奨: (a)。
- 理由: `generation` は「その lease に座った1つの会話」で、resume では進まない（P-1・decision #577 の D1）。同じ会話なのに進めると、1つの会話が2つの `generation` に分かれ、退任した `generation` の session_id の並びに自分の id が残る。`oe_lease_claim` は session_id が同じ lease の別の `generation` にあれば rc 8 で止まる [verified]（`projects/orchestration-engine/lib/lease.sh` の `oe_lease_claim` の注記）ので、(c) はいまの lib の決まりとも食い違う。(b) の「会話を戻せない」場合は5回の実例に無い。来たときは、新しい会話を `oe-handoff` で立てるか、別の issue で足す。
- 壊れないかの確かめ（設計SO の S-11）: `oe-tree --lease` は、いまの `binding` の pid と開始時刻で生死を決めるので、`generation` を進めなくても壊れない。`oe-handoff retire` は `current_generation - 1` の `binding` を前任として照らすので、復帰の直後に前のペインを retire で閉じることはできない。復帰では retire を使わず、前のペインは DJ-6 の案内で扱う。復帰のあとに計画的な交代（`take` で `generation` を進める）をすれば、復帰した会話は前の `generation` になり、retire で閉じられる。
- 確定版との違い: 確定版は「generation を進めて席を取り」と書いている。この DJ はそれと違うので、owner に確かめる（ゲート3 の Q2）。決まったら確定版との違いとして episode に残す。

### DJ-3 verb の流れ（自分で決めた・設計SO で作り直した）

verb は resume した本人が自分の Bash から打つ。lease の記録の1回の書き込み（`binding` の張り替え）を commit point にする。commit point より後の工程は、**前の `binding` やいまの registry を手がかりにせず、いまの lease の記録といまの観測から、あるべき状態をまるごと作り直す**形にする。前の情報に頼る工程が残ると、張り替えたあとに止まったとき、打ち直しでその情報を引けなくなるためである（設計SO の指摘・下の「設計SO」の S-1）。途中で止まったら、同じ verb をもう一度打てば、同じあるべき状態に向けて足りない書き込みだけを行う。

1. 自分を確かめる。`CLAUDE_PID` と `CLAUDE_CODE_SESSION_ID` と `TMUX_PANE` を読み、自分のペインのフォアグラウンドのプロセスが自分であることを `oe_tpi_verify_pane` で確かめる（`oe-handoff take` と同じ）。
2. 自分の lease を決める。`oe_lease_whoami`（環境変数か、session_id の照合）で決める。決まらなければ `--lease <lease_id>` を受け、`oe-lease bind` と同じ確かめ（workspace の一致・統括の lease なら `--owner-confirmed`）を通す（decision #577 の D7 の方法3）。自分の session_id がその lease のどの `generation` にあるかを読み、それがいまの `generation` でなければ止まる（D8。交代のあとに前任を resume した取り違え。環境変数の `OE_GENERATION` だけでは決めない・S-6）。
3. lease ごとの復帰のロック（`<lease の記録>.recover.lock`）を取る。同じ lease の復帰を同時に2つ走らせない（同じ claude から2本打った場合を含む・S-3）。ロックは verb が終わるまで持つ。取れなければ「別の復帰が走っている」と出して止まる。
4. いまの `binding` を見て、3つに分ける。
   - 自分である: 張り替えは要らない（落ち方 a で、すでに `oe-lease bind` を打ったか、前の復帰が張り替えたあとに止まった）。5 を飛ばして 6 へ。
   - 生きていない（`oe_tpi_proc_state` が dead）: 5 へ。
   - 生きている・分からない: 止まる（rc 5）。案内は DJ-6 のとおり理由で分ける。
5. `binding` を張り替える（`oe_lease_claim`・commit point）。**張り替える前の `binding`（pid・開始時刻・`bound_at`）を、同じ1回の書き込みで、その `generation` の `rebinds` の並びに足す**（lease の記録と schema に項目を1つ足す・S-1）。取り合いに負けたら（rc 3・rc 5）止まる。
6. 派生の工程。どの書き込みも、書く直前に lease を読み直して `binding` が自分のままであることを確かめ、自分でなくなっていたら書かずに止まる（S-3）。確かめてから書くまでの窓は残る（「残る穴」）。
   1. board の現統括の行（統括の lease のときだけ）: 表示を自分のペインに書き換える。いまの `oe_seat_rewrite` は註の文が「退任申告済み・停止待ち」に決まっているので、註の種類を渡す引数を足し、復帰では「前のペイン `%N` は応答なし・復帰で張り替え」と書く。前のペインの番号は board のいまの表示から読む（前の `binding` からは引かない）。`oe-handoff retire` は「退任申告済み」の形の註だけを前任として読むので、復帰の註を前任と読み違えないことをテストで確かめる（S-4）。書き換えたあと同じ規則で読み直す（`oe_seat_verify`）。
   2. registry（移行のあいだだけ・P-4）: いまの tmux server の registry に、自分のペインの行を書く。統括の lease なら親は空（root）、委譲の lease なら親の lease を `oe_lease_resolve_pane` で引いたペインを親にする（引けなければ書かずに「済んでいない」に出す）。続けて、lease の記録で自分の lease を親に持つ子ごとに、子の lease から `oe_lease_resolve_pane` でいまのペインを引き、そのペインの行を、親を自分のペインにして書く。引けない子は書かずに一覧に出す。**registry だけを書く関数（`oe_reg_record`）を直接使い、`oe-register root` と `oe-register link` は使わない。** この2つは lease の記録にも書く（`link` は子の lease の親を書き換えて `epoch` を進め、`root` は親が空の子に親を書く）ので、「子の lease の記録は書き換えない」と食い違う（S-2）。前の registry の行は手がかりにしない。tmux を起こし直すと、記録のたびに前の server の行は消える（`lib/delegate-registry.sh:78` の `oe_reg_gc`）うえ、前のペインの番号は別のペインに使い回されうるためである（S-5）。
   3. 古い子の一覧: registry にだけ居て、lease の記録に居ない子（#577 より前に起こした子で、`OE_LEASE_ID` を持たない）を一覧にする（DJ-5）。
   4. 届かなかったかもしれない報告を一覧にする（DJ-7）。
7. 検算: 次の4つを別々に判定して出す（S-7）。lease のいまの `binding` が自分であること・`binding` のプロセスが alive であること・`oe-lease resolve <自分の lease>` が自分のペインを返すこと（heartbeat がまだ新しいペインで書かれていなければ「未確認」と出し、失敗にはしない）・`oe-tree --lease` の自分の行が alive であること。`oe-vitals` の行は drill で見る（verb の中では判定に使わない。観測できないときも「検知なし」になり、成功と区別できないため）。
8. 復帰の event を1行書き、済んだことと済んでいないこと（理由つき）を出す（DJ-4）。済んでいないものがあれば終了コードを 1 にする。

統括でない lease（委譲の子）も同じ verb で戻せる。そのときは 6-1（board）を飛ばす。落ち方 c（tmux ごと再起動）は、セッションごとに resume して、それぞれがこの verb を打つ手順にする。親と子のどちらが先に戻っても、6-2 は lease の記録から作り直すので、あとから戻ったほうが自分と相手の行をそろえる（先に戻った子は親のペインを引けず「済んでいない」を出すが、親が戻ったときに親の 6-2 が子の行を書く）。

残る穴（受け入れるもの）:

- 6 の確かめと書き込みのあいだの窓。そのあいだに別のプロセスが `binding` を取ると、古い復帰が board か registry を1回書きうる。次に正しい持ち主が verb か `oe-handoff take` を打てば、あるべき状態に戻る。decision #577 の D5 が「保証するのは正本の `binding` が1つになるまで」としたのと同じ範囲である。
- `oe-handoff take`（計画的な交代）と復帰が同時に走る場合。`take` は前の `binding` の生死を問わずに `generation` を進めるので、復帰の verb はそれより後の書き込みを 6 の確かめで止める。`take` の側に復帰のロックを見させる直しは、この issue では入れない（実例が無く、`take` は前任が申告したときだけ打つ）。

### DJ-4 復帰の event の型（自分で決めた）

- 新しい型 `supervisor_recovery` を足す（decision #577 の D13「`binding` の張り替え（復帰）の型を足す」・discussion 2026-07-13 の §5 (2)）。統括でない lease の復帰も同じ型で書き、lease の `kind` を入れる。
- 項目: `recovery_id`（復帰の1回を見分ける ULID。打ち直しでは、`rebinds` の最後の要素の時刻と組で同じ復帰と分かる）・`lease_id`・`generation`・`kind`・前の `binding`（pid と開始時刻・`rebinds` の最後の要素から読む）・新しいペイン・`server_pid`・`complete`（派生の工程が全部済んだか）・済んでいない工程の名前の並び。同じ `generation` の中で復帰が続いても、`recovery_id` と前の `binding` で1回ずつ見分けられる（設計SO の S-6）。
- schema のトップレベルの `generation` の説明は、いまは交代の型だけのものなので、復帰の型でも使うと書き足す。
- `lease_bound`（`bind_reason: rebind`）も、`oe-lease bind` と同じく張り替えのときに書く。`supervisor_recovery` は復帰の工程全体の結果を1行で残すためのもので、`complete: false` の行を探せば「変換が終わっていない」を見つけられる（discussion 2026-07-13 の §5 (2) の「conversion incomplete」）。
- schema（`schemas/oe-events.schema.json`）に型と必須の項目を足し、`supervisor_succession` の説明の「#355 はこの型で書かない」の文に、行き先の型の名前を足す。

### DJ-5 `OE_LEASE_ID` を持たない古い子の扱い（自分で決めた）

- verb はこの子たちを一覧にし、宛先を伝える文の `oe-send` のコマンドを、コピーして打てる形で出す。自動では送らない。
- 理由: decision #577 の D11 は「`PARENT_TMUX_PANE` しか持たない子は古い宛先のまま終わらせる」と決めている。子に送るのは外へ出る操作で、送るかどうかは統括が子の状態を見て決める。#577 が入った 2026-11-07 より前に起こした子だけが当たるので、数は少なく、PR-6 までに無くなる。

### DJ-6 前のペインに残ったプロセスを閉じる工程（owner に聞く・Q3）

- 何が起きるか: 落ち方 b で、前のペインに前の claude のプロセスが生きて残っていると、DJ-3 の 3 で止まる（生きている `binding` は張り替えない・decision #577 の D5）。2026-11-05 の交代では、AI が打つ `tmux kill-pane` を自動モードの判定器が止めた（確定版の「issue に書いていないが要ること」）。前のプロセスが終わってシェルだけ残ったペインは、`binding` の張り替えを止めないので、閉じなくても復帰は終わる。
- 選択肢: (a) verb は閉じない。止まったときは、前のペインとプロセスを示し、owner が打つコマンド（`tmux kill-pane -t %N`）を出す。閉じたあとに verb を打ち直す。(b) verb に `--close-stale` を持たせ、前の `binding` のプロセスが前のペインのフォアグラウンドにいることを確かめてから閉じる。打つのは owner の承認を得た統括。(c) verb が確かめてから自動で閉じる。
- 推奨: (a)。
- 理由: 生きている前のプロセスは、本当に止まっているのか、作業の途中なのかを verb では見分けられない（decision #577 の D9 は heartbeat の古さや画面では決めないと決めている）。閉じる判断は人に残し、verb はその材料（pid・開始時刻・前のペインの候補）を出す。(b) は判定器が verb のコマンドを止めるかどうかが実機で分からず、止められれば (a) と同じになる。人が打つ操作は1回増えるが、この形は5回の実例のうち1回（10-27 の hub）だけである。
- 案内の分け方（設計SO の S-8 で足した）: `binding` には前のペインが残っていないので、ペインの番号を当て推量で出すと別のペインを閉じさせうる。そこで案内を理由で分ける。
  - 前のプロセスが生きていて、board の表示のペインか registry の行のペインのフォアグラウンドに居ると `oe_tpi_verify_pane` で確かめられた: そのペインを閉じる `tmux kill-pane -t %N` を出す。
  - 生きているが、どのペインのフォアグラウンドにも居ない（ペインごと消えたのにプロセスが残った・background に移った）: ペインの番号は出さず、pid と開始時刻と、`ps -p <pid> -o pid,lstart,command` で本人を確かめてから閉じる手順を出す。
  - 生きているか分からない（`ps` の問い合わせが失敗した・開始時刻が無い）: 閉じるコマンドは出さず、何が分からなかったかを出して、owner の判断に回す。
  - どの場合も、安全に止まることを優先する。分からない状態から verb 1回で必ず戻れるとは約束しない。

### DJ-7 落ちていたあいだの報告の拾い方と `delivery_held`（owner に聞く・Q4）

- 何が起きるか: 統括が落ちているあいだに子が `oe-send --to-parent` を打つと、送る前の確かめ（decision #577 の D6）で外れて送らずに失敗する（P-3）。報告の本体はファイル（`.oe/report-<issue>*.md`）に残るが、統括はどのファイルが来たかを知らない。decision #577 の D15 は、送れないときの保留（`delivery_held`）と拾い方を #355 で決めると申し送った。
- 選択肢: (a) `oe-send --to-parent` が親の lease へ送れなかったとき、`delivery_held` の event（送り元の lease・宛先の親の lease・送ろうとした1行・`--brief` のパス・失敗の種類）を残す。復帰の verb は、自分の lease あての `delivery_held` を「送れなかった送信の履歴（要照合）」として一覧にする。(b) 新しい event を足さず、verb は workspace の `.oe/report-*.md` と `.oe/question-*.json` を時刻で絞って一覧にする。(c) verb は拾わず、スキルの工程で統括が `oe-confirm` と `oe-undelivered` を打つ。(d) 報告を lease あての受け箱（報告の ID・本文の参照・回収したか）に置き、tmux への送信は「新しい報告がある」の知らせに下げる（設計SO の代替 N3）。
- 推奨: (a)。この issue では「未回収の報告の一覧」とは名乗らず、要照合の履歴として出す。(d) は別の issue の候補として残す。
- 理由: (a) は送れなかったことを送る側が事実として残すので、統括が落ちていた時刻を推し量らずに拾える。ただし設計SO が示したとおり、送れなかった送信の履歴は未回収の報告の集合と同じではない（一時的に確かめが外れたあと再送で届いたもの・同じ報告を何度も送ったものが混ざる・event の追記は best-effort で、空でも「無い」と言えない・S-9）。そこで、一覧には送り元の lease と `--brief` のパスで同じものを畳み、同じ送り元からあとで送れた記録（`message_sent`）があればその印を付け、最後に「この一覧は要照合で、空でも取りこぼしが無いとは言えない」と書く。(b) は時刻の推し量りに頼り、関係ない報告も混ざるので、(a) の補いとして同じ一覧の下に別の見出しで出す。(c) は送れずに失敗した送信が記録に残らないので拾えない [unverified-summary]（見取り図の「まだ無いもの」・`projects/orchestration-engine/bin/oe-send` の解決の失敗で exit する節）。(d) は報告の正本を新しく作るので、この issue の範囲を越える。
- 絞り方: 一覧の下限は、`rebinds` の最後の要素（前の `binding`）の `bound_at` とする（S-1 で足した記録から読むので、打ち直しでも同じ下限になる）。回収したかの印は付けない。
- 範囲: (a) は `oe-send` の `--to-parent` の失敗の経路に event の追記を1つ足すだけで、送る・送らないの判定は変えない。宛先の解決に失敗したときは送り先の lease が環境に残らない（`lib/target-resolve.sh` の解決の節）ので、解決の前に親の lease を読んでおく。

### DJ-8 `oe-vitals` の扱い（自分で決めた）

- 落ちているあいだの death の知らせは、そのまま残す。owner が「統括が応答しない」と気づく合図になるためである（見取り図の流れの最初の箱）。いまのキーでは session ごとに1回しか出ないので、鳴り続けることはない（P-6）。
- 二重通知を抑えるキーを、lease で判定したときは `death|<lease_id>|<generation>|<binding の pid>|<binding の開始時刻>` にする。いまのキー `death|<session_id>` のままだと、復帰したあとに同じ会話がもう一度落ちたとき、session_id が同じなので知らせが出ない（P-6 から導いた・[speculation] 実機ではまだ起きていない）。session_id はキーに使わない。heartbeat が無いときは `sup_sid` が `lease_id:generation` に替わる（`projects/orchestration-engine/bin/oe-vitals:321` の前後）ので、同じ `binding` の死でも sidecar の有無でキーが変わってしまうためである（設計SO の S-10）。board で判定したとき（lease が決まらない移行の逃げ道）は、いまのキーのままにする。既存の seen の記録の行は、キーの形が変わるので一致しなくなるだけで、消さない。並行に走った `oe-vitals` の二重通知（seen の確かめと追記が排他されていない）は、この issue では直さない。
- 検算（DJ-3 の 6）では `oe-vitals` を通知なしで走らせ、判定の行だけを読む。いまは通知を止める口が無いので、`wez` を探す経路を env（`OE_VITALS_NOTIFY=0`）で止める口を足す。テストの差し替えと同じ形にする。

### DJ-9 resume する session_id をどこから引くか（自分で決めた）

- verb に、resume の前に普通のシェルから打てる読むだけの subcommand（`oe-recover hint [-w <workspace>]`）を持たせる。その workspace の開いた統括の lease のうち、`binding` のプロセスが生きていないものについて、`OE_LEASE_ID=<lease_id> OE_GENERATION=<generation> claude --resume <session_id>` を、コピーして打てる形で出す（decision #577 の帰結の「復帰の手順が出すコマンド」）。session_id は lease の記録の、いまの `generation` の session_id の並びの最後のものを使う。
- 名前に頼らない経路はこの hint である。#576 が入れば、`claude --resume` の一覧で統括の会話を名前で見つけられるので、hint を打たずに一覧から選んでもよい。そのときも session_id の照合（decision #577 の D7 の方法2）で lease が決まる。
- `oe-tree --lease` の表示に session_id を出すかは、この plan では変えない。
- #247 から移った問い（席を取り直すとき session_id も宣言し直すか）は、`binding` の張り替えで自分の session_id を lease に登録する（P-2）ことで答えが出ている。lease の記録が session_id を持つので、board に session_id を書く必要は無い。この plan で閉じる。

### DJ-10 復帰の手順の置き場（自分で決めた）

- 人の工程（気づく・`oe-recover hint` を打つ・ペインで resume を打つ・「復帰して」と頼む）は、`projects/orchestration-engine/bin/README.md` の `oe-recover` の節に手順として書く。
- 統括の工程（verb を打つ・止まったときの判断・一覧に出た報告を読む・古い子へ宛先を送るかを決める・判断ボードを読み直す）は、配布するスキル `doc-flow-guardrail` の、いまの「復旧（前任が応答しない）は本スキルの範囲外」の行（`canonical/skills/doc-flow-guardrail/SKILL.md:167`）を、復帰の工程の短い節に置き換える。計画的な交代（④）と同じく、routing 先が同じ穴を持つので本スキルが持つ例外に当たる。
- 理由: 既存の形に合わせる。計画的な交代も、verb の使い方は `bin/README.md`、統括の工程はこのスキルの④にある。

### DJ-11 別のリポジトリの統括（自分で決めた）

- 同じ verb を使う。lease の記録は tmux server をまたいでマシンに1つで、workspace を持つ。board の置き場は `--board` か `OE_BOARD_FILE` で渡す（`oe-handoff take` と同じ）。`hint` は `-w` の workspace で絞る。

## 確定版の項目との対応

| 確定版の項目 | この plan での扱い |
|---|---|
| 前の generation の binding が生きていないことの確認 | DJ-3 の 4（`oe_tpi_proc_state`・decision #577 の D9） |
| generation を進めて席を取る | DJ-2 で「進めず binding を張り替える」に変える（Q2） |
| board の現統括の行を表示として書き換える | DJ-3 の 6-1 |
| 子の lease の親と登記のつけかえ | lease の親は書き換えない（P-3）。registry は DJ-3 の 6-2 で、lease の記録から作り直す |
| 古い拍動 sidecar の掃除 | 同じ会話の sidecar は上書きされ、ほかの sidecar は候補にならない（P-5）ので、verb は消さない。古い sidecar は `oe-lease gc`（decision #577 の D4）に任せる |
| 復帰の event の記録 | DJ-4 |
| 検算 | DJ-3 の 7 |
| 落ち方 a と b を2モードで・c は b の繰り返し | モードは verb が `binding` を見て自分で分ける（DJ-3 の 4）。c は DJ-3 の最後の段落で、registry を lease の記録から作り直すので、前の server の行が消えていても戻せる |
| 人が打つのは resume と「復帰して」の1回ずつ | DJ-9（hint）・DJ-10 |
| session_id を引く経路 | DJ-9 |
| #576 との関係 | DJ-9 |
| #577 PR-6 は drill のあと | 範囲の外に書いた |
| 子の報告の取りこぼしと `delivery_held` | DJ-7（Q4） |
| 前のペインに残ったプロセスを閉じる工程 | DJ-6（Q3） |
| `oe-vitals` の死の知らせ | DJ-8 |
| ［別モデル］手で resume したペインでも次の take / retire が通る | `binding` を張り替えるので、復帰のあとの計画的な交代（`take` のあとの `retire`）は lease で判定できる（P-10・DJ-2 の S-11）。テストに入れる（T-6） |
| ［別モデル］途中で落ちたときの打ち直しと、復帰の重なり | DJ-3 の commit point・`rebinds` の記録・あるべき状態をまるごと作り直す派生の工程・復帰のロック・書く直前の確かめ。テストに入れる（T-4・T-5・T-11） |
| 達成を見る数 | 「達成を見る数の測り方」の節 |
| #247 から移す問い | DJ-9 の最後 |
| 「復帰」の定義（a〜e の5形） | a・b・c を扱う。d（background への fork）は `binding` のプロセスが替わるので、fork 先から打てば b と同じに張り替わる（前のプロセスが生きていれば DJ-6）。e（アカウントの切り替え）は a か b の形で現れる |

## ゼロベースの代替（ゲート1）

verb を新しく作る前提を外して、ほかの形を1度並べた。

| 案 | 内容 | 採らない理由 |
|---|---|---|
| Z1 verb を作らずスキルだけ | 統括が `oe-lease bind`・`oe-register root`・board の書き換え・`oe-register link` を順に打つ手順をスキルに書く | いまの手作業そのもので、手数が減らない。途中で止まったときの打ち直しの決まりが手順の文に頼る |
| Z2 `oe-lease bind` を太らせる | bind の中で registry と board と event も書く | `oe-lease` は記録を読み書きするだけの verb で、board の置き場や送信を持たない（`projects/orchestration-engine/bin/oe-lease:4-5`）。役割が混ざる |
| Z3 `SessionStart` hook で自動 | resume した瞬間に hook が bind と派生の工程を走らせる | issue 本文が「後の砂糖」とした（Claude Code の公開の仕様に依る）。verb ができれば、hook は verb を呼ぶだけで後から足せる |
| Z4 `oe-handoff take` に復帰を足す | 前任が応答しないときの分岐を take に入れる | take は前任の申告（引き継ぎ文書）を前提にしている。分かれ目は前任が申告できるかの1点で、#390 のときに分けた（issue のコメント 2026-09-11） |

ゼロベースの結果は、元の案（新しい verb）と同じところに戻った。Z3 は verb の上に足せる形として残る。

## 設計SO（ゲート2・弱・Codex の1レーン）

- レーン: Codex（`gpt-6.1-sol`・設定から解決・`codex-cli 0.166.0`・198秒・リトライなし）。判定は「Issues Found」。依頼文と回答は episode の「P2」に置き場を書いた。
- 採否の表（重さは Codex の付けたもの。採ったものは本文の DJ に S-番号で入れた）:

| 番号 | 指摘 | 重さ | 採否 | 入れた先・理由 |
|---|---|---|---|---|
| S-1 | 張り替えのあとに止まると、前の `binding` の情報が lease から消え、打ち直しで引けない | 高 | 採った | DJ-3 の 5（`rebinds` に残す）と 6（前の情報に頼らず作り直す） |
| S-2 | `oe-register link` と `root` は子の lease の記録も書き換え、「子の lease は書き換えない」と食い違う | 高 | 採った | DJ-3 の 6-2（`oe_reg_record` を直接使う） |
| S-3 | compare-and-swap は張り替えのあとの書き手を止めない。同じ claude から2本打つと両方が「自分」の分岐を通る | 高 | 採った（一部） | DJ-3 の 3（復帰のロック）と 6（書く直前の確かめ）。確かめと書き込みのあいだの窓と、`take` との同時の走りは「残る穴」に書いた |
| S-4 | `oe_seat_rewrite` の註は「退任申告済み・停止待ち」に決まっていて、復帰の註を渡せない | 中 | 採った | DJ-3 の 6-1（註の種類の引数・retire が読み違えないテスト） |
| S-5 | tmux を起こし直すと前の server の registry は消え、前のペインの番号は使い回されうるので、前の registry から子を探せない | 高 | 採った | DJ-3 の 6-2（lease の記録から作り直す） |
| S-6 | `whoami` は環境変数の `OE_GENERATION` を優先し、session_id と `generation` の整合を保証しない。復帰の各回を `generation` だけでは見分けられない | 中 | 採った | DJ-3 の 2（session_id のある `generation` で決める）と DJ-4（`recovery_id`） |
| S-7 | 検算の「`oe-vitals` が death でない」は、観測できないときも通る | 中 | 採った | DJ-3 の 7（4つを別々に判定・`oe-vitals` は drill で見る） |
| S-8 | `binding` にペインが無いので、閉じるペインの番号を当て推量で出すと別のペインを閉じさせうる。分からない状態から必ず戻れるとは言えない | 高 | 採った | DJ-6 の「案内の分け方」 |
| S-9 | `delivery_held` は送れなかった送信の履歴で、未回収の報告の集合ではない。下限の時刻も決まっていない | 高 | 採った | DJ-7（要照合の履歴として出す・下限は `rebinds` の `bound_at`） |
| S-10 | `oe-vitals` の `sup_sid` は heartbeat の有無で変わるので、キーは lease と `binding` の組が安定する | 中 | 採った | DJ-8 |
| S-11 | 復帰の直後に前のペインを retire で閉じることはできない（retire は前の `generation` を照らす） | 中 | 採った | DJ-2 の「壊れないかの確かめ」と T-6 の書き方 |
| N1 | owner の普通のシェルで動く一括の復帰の道具にする | 高 | 採らない | session_id の登録を本人の verb に限る decision #577 の D17 を変えることになり、本人確認を渡す仕組みが新しく要る。owner の手数も減らない |
| N2 | board と registry を書かず、読むときに lease から作る | 高 | 採らない（この issue では） | registry は #577 の PR-5・PR-6 で読むのをやめる方向で、この drill がその条件である。board は decision #577 の D12 で「take が書き続ける表示」と決めてあり、変えるなら decision を変える。PR-6 のあとは DJ-3 の 6-2 が要らなくなる |
| N3 | 報告を lease あての受け箱に置き、tmux は知らせにする | 高 | 採らない（別の issue の候補） | 報告の正本を新しく作り、transport の決定（decision #577 の D10）に触れる。DJ-7 の (d) として owner に見せる |

- 指摘のうち3つは、コードを読んで確かめた。`oe-register link` が `lease_link_best_effort` で子の lease の親を書き換えること（`projects/orchestration-engine/bin/oe-register:71-85`）、registry の記録のたびに `oe_reg_gc` が走ること（`projects/orchestration-engine/lib/delegate-registry.sh:78`）、`oe_lease_claim` が前の `binding` を残さずに上書きすること（`projects/orchestration-engine/lib/lease.sh:283-290`）[verified]。`oe_seat_rewrite` の註が決まった文であることも読んで確かめた（`projects/orchestration-engine/lib/seat.sh:118` 以降）[verified]。
- 未検証の仮定の判定（Codex）: A1 と A2 は「成り立たない」、A3 は広い保証としては「成り立たない」、A4 と A5 は「条件付き」。A1・A2 は S-1・S-2・S-5 の直しで、A3 は S-3 の直しと「残る穴」で受けた。

## 実装の分け方（PR の単位）

1つの PR にする。verb・`oe-send` の保留の記録・`oe-vitals` のキーと通知の口・event の schema・テスト・`bin/README.md`・スキルの節は、どれも復帰の1つの流れの部品で、分けると drill を通せる状態にならない。この plan と episode も同じ PR に載せる。

## 達成を見る数の測り方

- 数: 復帰1回に人が打つ操作の回数。人は owner と統括の両方を数える。いまは「owner の指示1 + resume をセッションの数 + 統括の手作業3〜4」で、目標は「owner の指示1 + `oe-recover hint` 1 + resume をセッションの数 + 統括の verb 1」である。統括の手作業（verb の外で打つ、登記・board・つけかえのコマンド）を0にすることが目標の中身である。
- 測り方: drill のあいだ、owner が打ったもの（シェルのコマンドと、統括への頼み）を episode に1行ずつ書く。統括の側は、drill の統括の会話の記録（transcript の jsonl）から、「復帰して」を受けてから `supervisor_recovery` の event（`complete: true`）が書かれるまでの Bash の呼び出しを数え、`oe-recover` 以外に登記・board・つけかえのコマンドが無いことを確かめる。結果は episode に書く。

## クラッシュ drill（受入）

- 対象（Q5）: 推奨は、使い捨ての統括を1つ、子を1つ立てて行う形である。state の置き場（`OE_LEASE_DIR`・`OE_HEARTBEAT_DIR`・`OE_DELEGATE_STATE_DIR`・`OE_EVENT_DIR`）と board を一時ディレクトリに向け、tmux は本物を使う。いまの統括と子の記録には触れない。
- 手順:
  1. 準備（実装の子）: 一時ディレクトリに workspace と board と state の置き場を作り、統括と子を起こすコマンド（env を付けた `claude`）を出す。
  2. 立てる（owner）: 出たコマンドで、使い捨ての統括を新しいペインに立てる。統括は `oe-lease create --root` で lease を作り、`oe-delegate` で子を1つ起こす。
  3. 落とす（owner）: 統括のペインを `tmux kill-pane` で閉じる（落ち方 b）。子は残す。
  4. 待つあいだ（実装の子）: 子に `oe-send --to-parent` で1行送らせ、送れずに失敗して `delivery_held` が残ることを見る。`oe-vitals`（通知なし）が death を出すことを見る。
  5. 復帰（owner）: 普通のシェルで `oe-recover hint -w <workspace>` を打ち、出たコマンドを新しいペインで打つ。resume した統括に「復帰して」と頼む。
  6. 復帰（統括）: `oe-recover` を1回打つ。
  7. 確かめる3点（実装の子）: `oe-tree --lease` に統括が alive として出る。統括の heartbeat の sidecar が `pane` と `server_pid` を持つ。`oe-vitals`（通知なし）が death を出さない。加えて、子が `oe-send --to-parent` で送った1行が新しいペインに届くこと、`oe-recover` の一覧に 4 の `delivery_held` が出ることを見る。
  8. 片付け（実装の子）: 一時ディレクトリを消す。使い捨てのペインは owner が閉じる。
- 偽物と本物の境（negative knowledge の item `01M5T897YCWY13GFTADD3136EC`）: 自動のテストは、偽の tmux・偽の ps・一時ディレクトリの state に差し替える。偽の `bin/` に足がかりの `oe-tree` ごと置き、`~/bin` を PATH から外し、存在しないペインの番号を使う。「記録されたのは偽物だけ」と「本物の呼び出しが無い」の両方を見る。drill だけは本物の tmux を使い、state は一時ディレクトリに向ける。生きている `~/.claude/state/` には書かない。
- #577 PR-6 との関係: この drill は、#577 PR-6（registry の両方書きをやめるなど）の条件である（decision #577 の D11）。PR-6 は別の子が行う。

## テスト

- T-1 落ち方 a: `binding` が自分のときは張り替えずに派生の工程だけ行い、2回打っても同じ結果になる。
- T-2 落ち方 b: 前の `binding` のプロセスが無いとき、張り替え（`rebinds` に前の `binding` が1つ増える）・board の書き換え（復帰の註）・registry の自分と子の行・event を書く。子の lease の記録は1つも書き換わらない（ファイルの中身と `epoch` を前後で比べる。#577 の M1 と同じ見方）。
- T-3 前の `binding` のプロセスが生きている・分からないときは、何も書かずに止まる。案内が DJ-6 の3つの理由で分かれ、ペインを確かめられないときはペインの番号を出さない。
- T-4 打ち直し: 張り替えのあと board を書く前に止めた状態から、別のプロセスで resume して打ち直すと、`rebinds` から前の `binding` を読み、続きだけをやる。
- T-5 重なり: 2つのプロセスが同時に張り替えようとすると、片方が rc 3 か rc 5 で止まり、派生の工程に進まない。同じプロセスから2本打つと、2本目は復帰のロックで止まる。
- T-6 復帰したあと、計画的な交代（`take` で `generation` を進める）をすると、`oe-handoff retire` が復帰した会話のペインを lease で判定できる。board の復帰の註を retire が前任と読み違えない。
- T-7 退任した `generation` の session_id から打つと止まる（`OE_GENERATION` が違う値でも）。lease が決まらないときは `--lease` を求め、workspace が違えば止まる。
- T-8 `hint` は、生きていない統括の lease だけについて resume のコマンドを出し、何も書かない。`binding` が無い・session_id が無い lease は、理由を出してコマンドを出さない。
- T-9 `oe-send --to-parent` が親の lease へ送れないとき `delivery_held` を残し、送れたときは残さない。同じ送り元と `--brief` の失敗が何度あっても、復帰の一覧では1行に畳まれ、あとで送れた印が付く。
- T-10 `oe-vitals` の新しいキーで、同じ会話の2回目の death（`binding` が違う）が通知の対象になり、同じ `binding` の death は heartbeat の有無が変わっても1回だけになる。`OE_VITALS_NOTIFY=0` で `wez` を呼ばない。
- T-11 張り替えのあと、派生の工程の途中で `binding` がほかのプロセスに移ると、それより後の書き込みをせずに止まる。
- T-12 tmux を起こし直した状態（registry に前の server の行しか無い・前のペインの番号が別のペインに使い回されている）で、親が先に戻る場合と子が先に戻る場合の両方で、最後に戻った側の verb のあとに registry の親子が lease の記録と一致する。孫を1つ含める。
- T-13 board が渡されない・書けない・現統括の行が無いときは、board の工程だけを「済んでいない」に出し、ほかの工程は行い、終了コードを 1 にする。
- 既存のテスト（`test_lease*.sh`・`test_handoff_*.sh`・`test_oe_vitals.sh`・`test_delegate_send.sh`・`test_event_bus.sh`）と shellcheck を通す。

## 受入

- 確定版の各項目を、上の対応の表のとおり実装か手順で扱っている。
- テスト T-1〜T-13 と既存のテストと shellcheck が通る。
- クラッシュ drill を1回通し、確かめる3点と、子の報告が新しいペインに届くことを見る。
- 達成を見る数を drill で測り、統括の手作業が0であることを episode に書く。

## ステップ

### P1: worktree・確定版の照合・episode の枠・参照の読み・設計判断の洗い出し（完了）

### P2: 設計SO（弱・Codex の1レーン）を plan の案に当て、採否を episode に書く（完了）

### P3: plan を draft PR に載せ、ゲート3 の問いを `.oe/question-355-1.json` に書いて `build.py check` を通し、`.oe/report-355-p3.md` を書いて報告の宛先へ1行送り、止まる

### GATE 3: owner の plan 承認（承認の記録 `.oe/decision-355-gate3.md` が届いてから I に進む）

### I1: lib の直し（`oe_lease_claim` の `rebinds` と lease の schema・`oe_seat_rewrite` の註の種類）と、既存のテストが通ることの確認

### I2: verb `oe-recover`（DJ-1〜DJ-6・DJ-9・DJ-11）とテスト T-1〜T-8・T-11〜T-13

### I3: `oe-send` の `delivery_held`（DJ-7）・`oe-vitals` のキーと通知の口（DJ-8）・event の schema（DJ-4）とテスト T-9・T-10

### CHECK: 既存のテストと shellcheck を通す

### I4: `bin/README.md` と `doc-flow-guardrail` の節（DJ-10）

### GATE 4: 実装SO（弱・1レーン）

### I5: クラッシュ drill（Q5 の答えの対象で）と、達成を見る数の計測。結果を episode に書く

### I6: PR を ready にし、Copilot の1ラウンドを終え、episode を closure して報告し、止まる（マージ・worktree の掃除・issue の close はしない）

## GATE 3 の問い

- Q1（DJ-1）: verb の名前を `oe-recover` にしてよいか。
- Q2（DJ-2）: 同じ会話の復帰は `generation` を進めず `binding` を張り替える形にしてよいか（確定版の「generation を進めて」と違う）。
- Q3（DJ-6）: 前のペインに生きたプロセスが残っているとき、verb は閉じずに owner が打つコマンドを出す形にしてよいか。
- Q4（DJ-7）: `oe-send --to-parent` に `delivery_held` を足し、復帰の verb が「要照合の履歴」として一覧にする形にしてよいか（受け箱は別の issue の候補）。
- Q5（drill）: drill を、使い捨ての統括と子1つで、state を一時ディレクトリに向けて行ってよいか。
- Q6: この plan で実装に進んでよいか。

## ゲート3 のあとの変更

（まだ無い）
