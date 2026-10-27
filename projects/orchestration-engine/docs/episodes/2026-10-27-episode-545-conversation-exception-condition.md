---
id: "01M5YKPV0M0YNAA0Z8MWVGN9XZ"
title: "#545 判断ボードの「会話で聞いてよい」例外を、見える条件で決める形にする"
date: 2026-10-27
type: episode
status: draft   # 着手時に枠を作った（2026-10-27）。closure はマージ前
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/545"
    reason: "本 episode の作業対象"
  - type: reference
    ref: "https://github.com/stlwolf/ai-development-hub/issues/545#issuecomment-6441281074"
    reason: "着手時の認識合わせの確定版（統括が投稿・深掘りなし）。この単位はこれを前提にする"
  - type: derived_from
    ref: "projects/orchestration-engine/docs/plans/2026-10-27-plan-545-conversation-exception-condition.md"
    reason: "この episode が記録する作業の計画"
  - type: reference
    ref: "projects/orchestration-engine/docs/decisions/2026-10-25-decision-538-judgment-board-flow.md"
    reason: "直す例外を決めた decision（決定7 の承認に含まれた境目）"
  - type: reference
    ref: "projects/orchestration-engine/docs/decisions/2026-10-24-decision-466-page-lifecycle-in-flow.md"
    reason: "判断ボードの流れの決定（決定1・5・7・10・24）。例外はこの上に立っている"
tags: [orchestration, human-page, supervisor, delegation, skill]
knowledge_observations:
  - "01M486Z2ND07GQWV1GHS1SVB0J"
  - "01M5PKRS6WECYZTYFC4WXANW50"
  - "01M5PKRS5MGHNHR2JS5C1TSPS9"
  - "01M5T897YCWY13GFTADD3136EC"
---

# #545 判断ボードの「会話で聞いてよい」例外を、見える条件で決める形にする

**この episode は着手時に枠を作り、作業しながら追記している。** 後追いで再構成した節があれば、その節の冒頭にその旨を書く。

## なぜこの作業が始まったか

2026-10-27、別のリポジトリの統括が「子を起こしてよいか」を、`judgment-board-flow` の「使わないとき・境目」の1つ目（owner が会話に居て一緒に考えている対話の中の問いは、判断ボードに載せず会話で聞いてよい）に当たると判断して会話で聞いた。そのあと約30分で、子の報告や CI の知らせが6件以上会話に割り込み、統括は同じ問いを5回書き直した。owner は「流れると上を見る必要がある」「子の返しは制御できない」と指摘した。例外に当たるかを統括のその場の判断で決めていることが原因で、この単位はその条件を外から見えるもので決める形に直す。

## この単位の入力

- brief: 統括（cockpit 21代目）が 2026-10-27 に発行した `.oe/brief-545-conversation-exception.md`（作業層・消える）。plan-first で、最初の終端は P3（plan を報告して止まる）、委譲全体の終端は I3（PR を作って報告する）。マージ・worktree の掃除・issue の close・sync はしない。
- 認識合わせ: 確定版 https://github.com/stlwolf/ai-development-hub/issues/545#issuecomment-6441281074 （深掘りなし）。
- scope: 「使わないとき・境目」の1つ目を外から見える条件で決める形に直す。案1（生きた子が1体でもいれば使わない）と案2（owner の次の発言に答えが無ければ判断ボードへ移す）の採否、子の報告を owner の発言から除く見分け方、owner が黙っているときに移す条件、子を起こしたあとの扱い、台帳の `route` の値、決めた理由の置き場を plan で決める。触らないもの: 判断ボードの作業の表と分け方（#539）・出し忘れを知らせる道具（#540）・任せた範囲のまとめ（#541）。出力の型とルールは、直す必要が出たら理由を plan に書いて GATE 3 で聞く。
- SO: 設計 weak（Codex 1レーン・ゲート2）/ 実装 weak（Codex 1レーン・ゲート4）+ Copilot 1ラウンド。Codex が返らなければ Cursor のレーンに1回だけ切り替えてよく、切り替えたら理由をこの episode に書く。
- 注入された negative knowledge: 4件（frontmatter の `knowledge_observations`）。closure で全件に観測を書き戻す。

## 作業の記録

### P1: worktree・確定版の照合・参照の読み（2026-10-27）

- worktree `fix/#545_conversation_exception_condition` を `wt switch --create` で作った。起点は `origin/master` の `9b9e9df` で、brief の git-head と一致する。
- 認識合わせは `issue-intake` の 1-2 の手順で確かめた。最後の行は `confirmed`・見出し4つ・URL は brief の「認識合わせ:」欄と文字列として一致した。確定版を前提にし、自分では通し直さない。
- 報告の宛先の統括は `oe-tree` に root `cockpit` として生きて出ていて、委譲子の自分はその子として出ている。
- 読んだもの: #545 の本文と確定版。`judgment-board-flow` の SKILL.md（全文）と `ledger.py` の型と規則の部分・検査の `route` の行。#538 の decision（全文）と plan の該当の行（DJ-20・R23・ゲート2 の指摘2・問い7）と episode の該当の行。#466 の decision の決定の節。`issue-intake`（全文）・`question-driven-design`（該当の行）・html-one-pager の会話に触れる行・出力の型の該当の1文。注入された knowledge item 4件。
- **例外の出どころ**: 例外は #466 の decision には無く、#538 の plan の DJ-20（ゲート2 の設計SO の指摘2 で `question-driven-design` と判断ボードが答える場所を争うと分かり、境目を足した）で入り、#538 の decision の決定7（Q47）の承認に含まれた。plan の問い7 の推奨の中身に「今までどおり会話で1つずつ聞く」と書かれていた。

### P2: plan の初稿（2026-10-27）

- 初稿は、案1 を入口（生きた子がいれば会話で聞かない。ただし owner の発言で始まった問答の手順＝`issue-intake` の提示と深掘り・`question-driven-design` の中は除く）、案2 を広げたものを出口（owner でない入力が届くか、owner の次の発言に答えが無ければ移す）にした。見分け方は `[oe:<26文字>]` の印で、迷ったら移す側に倒した。
- **見分けの手がかりは道具の中にあった。** `oe-send` は既定で1行の末尾に ` [oe:<26文字>]` の印を付ける（`projects/orchestration-engine/lib/delegate-send.sh:239-243`）。確定版は「子の報告は owner の発言と同じ形で割り込む」と書いていたが、形は同じでも印で見分けられる。印は受領印のための相関の識別子として入ったもので、出どころの見分けに使う決まりはまだどこにも無い。

昇格の印: `oe-send` の `[oe:<26文字>]` の印を、入力の出どころの見分けにも使う決まりとして engine の側に持たせるか（いまは受領印の相関の識別子としてだけ書かれている）

- 子を起こすことを移すきっかけにしなかった（DJ-5）。起こす手順のスキル（`delegate-task`）にも規則を置くことになり、発火する場所が増える。注入した knowledge item `01M5PKRS5MGHNHR2JS5C1TSPS9`（「いつ〜する」の規則は読まれる場所に置く）を、置き場を増やさない向きに使った。
- 打ち消す側を `canonical/` 全体と engine の `bin/`・`lib/`・統括の引き継ぎ文書で探した（knowledge item `01M486Z2ND07GQWV1GHS1SVB0J` の4つの向き）。表の外にあったのは、同じスキルの5節「マージの依頼は会話で頼む」だった（R18）。依頼で問いではないので直さない。

### ゲート1: ゼロベースの代替探索の結果と採否（2026-10-27）

- Codex（`gpt-6.1-sol`・設定から解決・codex-cli 0.164.0）が63秒・初回で返った。依頼文と出力は worktree の `tmp/545-conversation-exception/so-gate1-prompt.md` と `so-gate1/`。採否の表は plan の「ゲート1」節にある。
- **入口の例外は、統括の解釈に戻っていた（指摘・高）。** 初稿の (b) は「どのスキルの手順を動かしているか」で決める形で、「子を起こしてよいか」も設計の相談の一部だと統括が読めば例外に入る。2026-10-27 の統括も「一緒に考えている」と読んで例外を使ったので、同じ穴を言い換えただけだった。 (b) を、issue の深掘り中の版か owner の言葉での依頼で始まり、会話に始まりと終わりの1行を残す問答に限った。認識合わせの提示（深掘りの前の1往復）は (b) から外した。

昇格の印: 例外の条件を「どの手順を動かしているか」で書くと、書き手の解釈に戻る。始まりを相手の言葉と、残る印（会話の1行・issue の版）で見える形にする

- **出口を2つから1つにまとめた。** 初稿は「owner でない入力」と「owner の次の発言に答えが無い」の2つで、前者は印の見分けに頼っていた。印を外して送られた子の入力を owner の発言と読み違える穴（指摘・高）を、「次に届いた入力が owner の発言でその問いに答えるか尋ねるものでなければ移す」の1つにして塞いだ。見分けが要るのは「答えとして受け取ってよいか」だけになった。
- **深掘りを割り込みで終わらせるか守るかは、owner に問う（指摘・高）。** 推奨は、待っている1問だけを移し、問答は owner の次の発言で続ける形にした。守る案（割り込みに1行で受け取りだけ返し、問答のあとで扱う）は、止まる子の問いを止め続け、owner が途中で居なくなると移るきっかけが来ないので退けた。
- 範囲の外の代替案2つ（問答だけを受け持つ別のセッション・子の報告や知らせを受信箱に集めて統括が取りに行く）は、報告の届け方を変える engine の仕組みの話である。follow-up として統括へ申し送る。

### ゲート2: 設計SO（弱・Codex 1レーン）の結果と採否（2026-10-27）

- Codex（`gpt-6.1-sol`・設定から解決・codex-cli 0.164.0）が55秒・初回で返った。依頼文は plan の全文とスキルの現在の文の抜き書きで、出力は worktree の `tmp/545-conversation-exception/so-gate2/`。採否の表は plan の「設計SO」節にある。13件のうち12件を採り、1件（GATE 3 の問いの節が空）は依頼文を作った時点の版のためで当たらなかった。
- **直す節を2.1 の前置きだけにしたのは、打ち消す側の見落としだった（指摘・高）。** 移した問いを「すぐ載せる」と決めたが、実際に出し直すかを決めるのは2.2（閾値）・2.3（待つ期間は止まる問いのときだけ）・2.4（出し直すときに載せる問い）で、前置きに書いても3つの節に逆の指示が残る。knowledge item `01M486Z2ND07GQWV1GHS1SVB0J` の (3)「足した運用と逆を言う既存の規則」を、同じスキルの隣の節で踏んだ。打ち消す側を探すとき、ほかのスキルは探したが、直す節の隣で同じ判断をしている節を「同じ節の一部」と思って表に載せていなかった。

昇格の印: 打ち消す側を探すとき、ほかのスキルだけでなく、直す節と同じ判断（いつ出すか・載せるか）を担う同じ文書の隣の節も1行ずつ表に載せる

- **移した問いの扱いが、2.1 の順に当て直す形と `route` を `board` に決める形で食い違っていた（指摘・高）。** 移す問いは2.1 に当て直さず、いつもカードにする形に決めた。会話で聞いた時点で、統括は owner に答えてもらうと決めていたからである。
- 回収の途中の確かめ（7節の段3）も、会話で答えを待つ問いだと指摘された。確かめる問いのカードはすでに判断ボードにあるので、割り込まれたら未回答のカードのまま残す形にした（DJ-6b）。
- 問い2 に「割り込まれたら問答ごと判断ボードへ移す」案を足し、3つの案を流れやすさ・子が止まる時間・答える場所の往復で比べた。

### P3: commit・push・報告して止まる（2026-10-27）

- plan と episode を `965b161` で push した（PR はまだ作らない）。GATE 3 の問いは統括のワークスペースの根の `.oe/question-545-1.json`（4枚・`build.py check` 誤りなし）に書いた。報告の宛先の統括が `oe-tree` に root `cockpit` として生きて出ていることを確かめ、plan と問いのファイルのパスを `oe-send` で1行送った（exit 0）。GATE 3 の答えを待つ。
