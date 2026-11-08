---
id: "01M6XN6AXT75HC9DPXDMNAZ0Q0"
title: "#355 応答しない統括の復帰は、同じ会話のまま binding を張り替え、派生の記録を lease から作り直す"
date: 2026-11-08
type: decision
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/355"
    reason: "本 decision の issue"
  - type: derived_from
    ref: "projects/orchestration-engine/docs/plans/2026-11-08-plan-355-supervisor-recovery.md"
    reason: "設計の判断 DJ-1〜DJ-11・補正 H1/H2・設計SO と実装SO の採否"
  - type: derived_from
    ref: "projects/orchestration-engine/docs/episodes/2026-11-08-episode-355-supervisor-recovery.md"
    reason: "作業の記録。SO の採否・撤回・クラッシュ drill の結果"
  - type: design_context
    ref: "projects/orchestration-engine/docs/decisions/2026-11-06-decision-577-record-identity-key.md"
    reason: "前提の決定（lease と generation・D5 の張り替えの決まり・D9 の生死の確かめ・D15 の申し送り）"
tags: [orchestration, supervisor, recovery, lease, decision]
---

# #355 応答しない統括の復帰は、同じ会話のまま binding を張り替え、派生の記録を lease から作り直す

ゲート3（2026-11-08）で owner が plan の問い Q92〜Q97 に推奨どおり答え、実装とクラッシュ drill 1回で確かめた判断を残す。verb の使い方は `projects/orchestration-engine/bin/README.md` の `oe-recover` の節、統括の工程は配布するスキル `doc-flow-guardrail` の ⑤ が正本で、この文書には「なぜそう決めたか」だけを書く。

## 決定

### D1 同じ会話の復帰では generation を進めず、binding だけを張り替える

- 決まり: 統括が落ちたあと、同じ会話を resume して戻るときは、lease のいまの generation の binding を、resume したプロセスに張り替える。generation は進めない。張り替えるのは、前の binding のプロセスが生きていないと機械で確かめられたときだけである（decision #577 の D5・D9）。張り替える前の binding は、同じ1回の書き込みで lease の記録の `rebinds` に残す。
- 棄却した案: (a) 復帰でも必ず generation を進める（認識合わせの確定版が当初そう書いていた）。(b) 張り替えに加え、別の新しい会話が死んだ持ち場を引き取るときは generation を進める口を持つ。
- 理由: generation は「その持ち場に座った1つの会話」で、交代でだけ進む（decision #577 の D1・`lib/lease.sh` の言葉の定義）。同じ会話で generation を進めると、1つの会話が2つの generation に分かれ、自分の session_id が退任した generation に残る。lease の lib は、session_id が同じ lease の別の generation にあれば登録を止める（rc 8）ので、(a) は lib の決まりとも食い違う。(b) の「会話を戻せない」場合は5回の実例に無かった。
- 当時の前提（偽になりうるもの）: `claude --resume` で同じ会話を開き直せること。会話を戻せない落ち方が実際に起きるようになれば、(b) を足す議論を再開する。
- 帰結: 復帰の直後に、前のペインを `oe-handoff retire` で閉じることはできない（retire は前の generation の binding を前任として照らすため）。前のペインは D4 で扱う。復帰のあとに計画的な交代をすれば、復帰した会話は前の generation になり、retire で閉じられる。

### D2 復帰の派生の工程は、前の情報でなく、lease の記録といまの観測から作り直す

- 決まり: binding の張り替えを commit point にし、そのあとの board の現統括の表示と registry は、前の binding・前の registry・前のペインの番号を手がかりにせず、いまの lease の記録（親子）といまの観測（heartbeat と、ペインの前面のプロセス）から、あるべき状態をまるごと作り直す。書く直前に、binding がまだ自分で lease が開いていることを確かめる。子の lease の記録は書き換えない。
- 棄却した案: (a) 前の registry で親のペインが前のペインのままの子を探し、`oe-register link` でつけかえる（最初の案）。(b) board と registry を書かず、読むときに lease から作る（設計SO の代替案）。
- 理由: (a) は3つの理由で成り立たなかった（設計SO の指摘をコードで確かめた）。張り替えのあとに止まると前の binding を打ち直しで引けない。tmux を起こし直すと registry は記録のたびに前の server の分を消し、前のペインの番号は別のペインに使い回されうる。`oe-register link` は子の lease の親も書き換えて epoch を進める。(b) は registry を読むのをやめる #577 PR-5・PR-6 の方向と同じだが、この issue の drill がその移行の条件なので、先取りすると移行の順を崩す。board は decision #577 の D12 で「交代の verb が書き続ける表示」と決めてある。
- 当時の前提: registry は移行のあいだ lease と両方書いている（decision #577 の D11）。#577 PR-6 で registry をキーとして読むのをやめれば、registry を作り直す工程は要らなくなる。
- 帰結: 親と子のどちらが先に戻っても、あとから戻ったほうが registry をそろえる。

### D3 送れなかった送信は `delivery_held` として残し、復帰の verb は「要照合の履歴」として出す

- 決まり: 子が `oe-send --to-parent` で親の lease へ送ろうとして、送る前の確かめで外れたときだけ、`delivery_held` の event を残す（送る・送らないの判定は変えない）。復帰の verb は、自分の lease あての `delivery_held` を送り元と brief で畳んで出す。この一覧は「送れなかった送信の履歴（要照合）」で、未回収の報告の一覧とは名乗らない。下限は、最後に complete で終わった復帰より後に張り替えられた binding のうち、いちばん古いものが張られた時刻とする。
- 棄却した案: (a) 新しい event を足さず、報告のファイルを時刻で絞る（推し量りに頼り、関係ない報告も混ざる。補いとして同じ一覧の下に出す）。(b) verb は拾わず、`oe-confirm` と `oe-undelivered` に任せる（送れずに失敗した送信は記録に残らないので拾えない）。(c) 報告を lease あての受け箱に置き、tmux への送信を知らせに下げる（取りこぼしを無くせるが、報告の正本を新しく作り、decision #577 の D10 の transport の決定に触れる）。
- 理由: decision #577 の D15 が、保留と拾い方を #355 で決めると申し送った。送れなかったことを送る側が事実として残すので、統括が落ちていた時刻を推し量らずに拾える。ただし送れなかった送信の履歴は、再送で届いたものや同じ報告の繰り返しを含むので、未回収の報告の集合と同じではない（設計SO の指摘）。下限は最初「前の binding の時刻」だったが、復帰が二重に落ちると縮むので直した（実装SO の指摘・plan の H2）。
- 当時の前提: event の記録は best-effort で、空でも取りこぼしが無いとは言えない。(c) は、取りこぼしが実際に問題になったら再検討する。

### D4 前の claude が生きて残っているとき、verb は閉じず、閉じるのは owner である

- 決まり: いまの binding のプロセスが生きているか分からないときは、何も書かずに止まる。止まるときは、いまの状況・書いたもの／書かなかったもの・次にやることを出す。閉じるコマンド（`tmux kill-pane -t %N`）は、そのプロセスがどのペインの前面にいるかを確かめられたときだけ出し、確かめられなければペインの番号を出さない。
- 棄却した案: (a) verb に閉じるオプションを持たせ、owner の承認を得た統括が打つ。(b) verb が確かめてから自動で閉じる。
- 理由: 生きている前のプロセスが止まっているのか作業の途中なのかを、verb は見分けられない（decision #577 の D9 は heartbeat の古さや画面では決めない）。(a) は、AI が打つ閉じるコマンドを自動モードの判定器が止めるか実機で分からず、止められれば推奨と同じになる。owner の補足「状況がわかりやすい説明と、next action のサジェスチョンをちゃんと出すこと」（Q94）は、止まったときの案内の要件として verb のすべての止まり方に当てた（plan の H1）。
- 当時の前提: この形は5回の実例のうち1回（2026-10-27）だけだった。頻繁になれば (a) を再検討する。

## 確かめたこと

- クラッシュ drill 1回（2026-11-08・落ち方 b・使い捨ての統括と子・記録の置き場は一時ディレクトリ）で、`oe-tree --lease` に統括が alive で出ること・統括の heartbeat が pane と server_pid を持つこと・`oe-vitals` が偽の知らせを出さないこと・子の報告が新しいペインに届くことを確かめた。復帰1回に統括が手で打った登記・board・つけかえのコマンドは0回だった（`本文: I5: クラッシュ drill の結果（2026-11-08 22:15 JST・3回目の試行で通った）` 〔episode〕）。

## 決めていないこと

- 別の会話が死んだ持ち場を引き取る口（D1 の (b)）。
- 報告の受け箱（D3 の (c)）。
- `SessionStart` hook による自動の復帰（issue 本文の範囲外。verb の上に足せる形にしてある）。
- サスペンドと resume に近い形（owner の 2026-10-17 の補足。別の issue に派生させる）。
