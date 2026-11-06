---
id: "01M6PD1REX2CDA6WZRCZS8EYC2"
title: "#577 engine の記録のキーを tmux のペインから切り離し、こちらで作る ID にする（設計）"
date: 2026-11-06
type: episode
status: in-development
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/577"
    reason: "本 episode の作業対象"
  - type: reference
    ref: "https://github.com/stlwolf/ai-development-hub/issues/577#issuecomment-6664844569"
    reason: "着手時の認識合わせの確定版（統括が投稿・深掘りなし）。この単位はこれを前提にする"
  - type: reference
    ref: "projects/orchestration-engine/docs/decisions/2026-06-19-decision-188-identity-unification.md"
    reason: "一部を置き換える前の決定（pane の層で identity を統一しない・永続の対応表を作らない）"
  - type: reference
    ref: "projects/orchestration-engine/docs/discussions/2026-11-06-discussion-577-record-identity-key.md"
    reason: "棚卸しの表と設計の判断"
  - type: reference
    ref: "projects/orchestration-engine/docs/plans/2026-11-06-plan-577-record-identity-key.md"
    reason: "この単位の plan"
  - type: reference
    ref: "projects/orchestration-engine/docs/decisions/2026-11-06-decision-577-record-identity-key.md"
    reason: "この単位の decision の案（proposed）"
tags: [orchestration, registry, identity, supervisor, delegation, design]
---

# #577 engine の記録のキーを tmux のペインから切り離し、こちらで作る ID にする（設計）

**この episode は着手時（2026-11-06）に枠を作り、作業しながら追記している。** 後追いで再構成した節があれば、その節の冒頭に `reconstructed` と書く。

## なぜこの作業が始まったか

owner と統括が #355（統括の復帰）の見取り図を読む中で、統括の復帰がいつも手作業になるのは、engine の記録が tmux のペインの番号（と tmux server の pid）を「誰か」のキーに兼ねているためだ、という見立てになった（2026-11-06・#577 の背景）。復帰の工程を足す前に、記録の持ち方を変える。この委譲は設計まで（brief の終端は P3）。

## P1: 着手（2026-11-06）

- worktree: `feature/#577_record_identity_key` を `origin/master`（`0662dab`）から作った。
- 確定版の照合: `issue-intake` の 1-2 の手順で、最後の行が `confirmed`・見出し4・URL が brief の「認識合わせ」欄と一致した。自分では認識合わせを通し直さない。
- 参照を読んだ: decision #188・#206・#238/#239・#238 の board schema（§9 の amendment まで）、discussion 2026-07-13、#355 の本文とコメント（2026-09-15・2026-11-05）、#355 の見取り図のデータ（読むだけ）。

## 発見: セッションは自分の session_id を環境変数で知っている（2026-11-06）

確定版と #355・`lib/handoff-state.sh` の注記は、どれも「セッションが自分の session_id を名乗る経路が無い」を前提にしている（`lib/handoff-state.sh` の `oe_hs_session_for_pane` の上の注記「セッションが自分の id を名乗る経路が無いかぎり、この窓は閉じない」）。この子のセッション（Claude Code 2.1.318）の Bash の環境を読むと、次の変数があった。

- `CLAUDE_CODE_SESSION_ID`: このセッションの id（scratchpad のディレクトリ名と一致した）。
- `CLAUDE_PID`: claude のプロセスの pid。
- `CLAUDE_CODE_MESSAGING_SOCKET`（`/tmp/cc-socks/<pid>.sock`）と、その token。
- `TMUX_PANE` と `PARENT_TMUX_PANE`（`oe-delegate` が渡したもの）。

これが本当なら、設計の要（resume したセッションが自分の ID を知る方法）は「自分のペインの heartbeat から引く」という間接の方法でなく、直接の方法を持てる。ただし、文書化されているか、`/clear` や `/resume` で値が変わるか、`claude --resume <id>` で起こしたときに resume した id になるかは、この時点では確かめていない（公式の文書を確かめに出した）。確かめるまでは、この方法を設計の土台に置かない。

昇格の印: セッションの環境の `CLAUDE_CODE_SESSION_ID`・`CLAUDE_PID` が、#355 と handoff-state.sh の「名乗る経路が無い」の前提を崩す（確かめた範囲は 2.1.318 の1セッション）

### 公式の文書で確かめた結果（2026-11-06・原文を curl で取って該当の行を読んだ）

- `CLAUDE_CODE_SESSION_ID` は文書化されている [verified] (https://code.claude.com/docs/en/env-vars.md の表の `CLAUDE_CODE_SESSION_ID` の行)。Bash と hook の子プロセスに入り、hook の入力の `session_id` と一致し、`/clear` で更新される。`--resume <session-id>` で起こしたときは resume した id が入る。**ただし `--continue` と、id を付けない `--resume` では、起動したときの id が入ることがある**と書かれている。つまり「resume したセッションが自分の session_id を知る方法」は、owner が id を指定して `claude --resume <id>` で戻したときだけ確かである。（**訂正**: この読みは誤り。下の「訂正: `--continue` の文は MCP server の子プロセスについての文だった」の節）
- `CLAUDE_PID` は文書化されている（v2.1.214 以降）[verified]（同じ表の `CLAUDE_PID` の行）。Claude Code 自身の pid で、Bash と hook の子プロセスに入る。プロセスの生死を pid と開始時刻で確かめる材料になる。
- `CLAUDE_CODE_MESSAGING_SOCKET` は、セッション間で文を送る機能（cross-session messaging・v2.1.224 以降）の inbox socket である [verified] (https://code.claude.com/docs/en/cross-session-messaging.md)。同じマシンのセッションどうしが、tmux を通らずに文を送れる。transport を tmux の send-keys から切り離す別の transport になりうるが、届き方（receipt の hook が走るか・内側の制御で止まるか）がいまの transport と違う。この issue で採るかは owner に聞く（範囲の外の候補）。
- statusLine の入力にも `session_id` がある [unverified-summary]（文書の確認に出した道具の報告による・https://code.claude.com/docs/en/statusline.md）。

この結果で、確定版の「設計の要は、resume したセッションが自分の ID を知る方法である。いまの Claude Code にはセッションが自分の session_id を名乗る経路が無い」は、**前提が変わった**。経路はある。残る穴は、id を付けない resume と `/clear` である。（**訂正**: id を付けない resume を穴とした根拠は、下の「訂正」の節のとおり誤読だった）

### 実機で確かめた2つの観測（2026-11-06・この子の自分のペインだけを読み取りで見た）

- `CLAUDE_CODE_SESSION_ID` の値の名前の heartbeat の sidecar があり、その中の pane は自分の `TMUX_PANE`、server_pid は `$TMUX` の2番目の値と一致した [verified]（`~/.claude/state/oe-heartbeat/<session_id>.json` を cat した）。つまり「自分の session_id → heartbeat → いまのペイン」は、セッションの内側から1手で引ける。
- `CLAUDE_PID` は、ペインの端末のフォアグラウンドのプロセスグループの番号（`ps -t <tty> -o pid,tpgid` の tpgid）と一致した [verified]。このペインは `oe-delegate` が claude をペインのコマンドとして起こしたので、`#{pane_pid}` も同じ値だった。シェルで始まるペインでは `#{pane_pid}` はシェルになるが、tpgid は claude を指す（#355 の 2026-11-05 のコメントの実測）。フォアグラウンドのプロセスグループには claude の子（MCP のサーバなど）も同じ tpgid で並ぶので、claude 本人は「pid が tpgid と一致する行」で取る。
- `ps -o lstart` の出力はロケールで形が変わる（この環境では日本語の曜日が出た）。開始時刻を記録して比べるなら `LC_ALL=C` で固定する。

## P2: owner への問い（2026-11-06）

owner が決める判断4件を、問いのファイル（統括のワークスペースの根の作業層 `.oe/question-577-1.json`・`build.py check` 済み）で統括へ送った（`oe-send` の exit 0。宛先は `oe-tree` に生きた root として出ることを確かめた）。4件は、ID が `lineage` を指すか `generation` を指すか・移行の段取り・ transport を Claude Code のセッション間の文を送る機能へ替えるか・resume のときに session_id を指定して打つことを決まりにするか、である。3件目と4件目は、確定版に無い問いで、上の「発見」から出た。答えを待つあいだは、答えに依らない棚卸しと設計を進める。

## P2: 棚卸しと網羅の確かめ（2026-11-06）

### 進め方

- 棚卸しは、読むだけの調査の道具を2つ並べて回した。1つは engine の `bin/` と `lib/` の全ファイル（36本に入るかどうかに関係なく）、もう1つはそれ以外（hook・statusLine・scripts・schema・配布しているスキルの文）である。どちらにも、ペインの使い方をキー・宛先・本人確認・表示に分け、行番号を付けるよう頼んだ。結果は discussion の §3 に表として写した。
- 調査の報告のうち、影響の大きい4つを行に当てて確かめた。`oe-vitals` が heartbeat をペインだけで絞ること、`oe-confirm` の `seen` の記録が `pane|%N` で server の pid を持たないこと、`oe-report` の `/tmp/oe-parent-<N>` がペインの数字だけであること、event の schema で `server_pid` を持つのが `supervisor_succession` だけであること、である。4つとも報告どおりだった。表の残りの行は `[unverified-summary]` のままにした。

### 網羅の確かめ（パターンの外からの対照）

negative knowledge `01M07QDKE73BTK0Q3K90FE4G9T` を当てた。統括の36本は `TMUX_PANE|pane_id|#\{pane` の1つのパターンから出していて、そのパターンで選んだ対照は同じ盲点を持つ。対照は2つ、パターンの外から選んだ。

- **記録の置き場から逆にたどった。** `~/.claude/state/` の置き場の名前12個（`oe-delegate`・`pane-issue`・`oe-heartbeat`・`oe-events`・`oe-confirm`・`oe-vitals`・`oe-view`・`hook-firing`・`session-branch`・`session-named`・`oe-receipt-diag`・`mcp-discover`）と、board と引き継ぎ文書の目印（`START-HERE`・`現統括`・`handoff.md`）で、`canonical`・`projects`・`scripts` のコードのファイルを `grep -rlF` で引いた。36本に入らないのに記録を読み書きするファイルが7本出た。`bin/oe-send`・`bin/oe-list`・`bin/oe-status`・`lib/seat.sh`・`canonical/claude/statusline/statusline-oe-heartbeat.sh`・`scripts/measure-delivery-arrival.py`・`scripts/validate-board.sh` である。heartbeat を書く producer は、36本の走査が見たディレクトリ（`canonical/hooks/scripts`）の外にあった。`oe-send` と `lib/seat.sh` は、どちらもペインを主のキーか宛先に使う中心のファイルなのに、パターンの語（`TMUX_PANE` など）を1つも含まない。
- **event の型の一覧から逆にたどった。** `oe-events.jsonl` の型を数えると5つ（`message_sent` 4,691件・`prompt_received` 3,562件・`child_spawned` 430件・`report_received` 195件・`supervisor_succession` 33件・2026-11-06 の時点）だった。各型の書く側と読む側を、2つ目の調査で洗った。

網羅の主張は「上の2つの対照と、36本の走査と、2つの調査が使った語で走査した範囲では、表の外は見つかっていない」に限る。

昇格の印: 「パターンの外の対照」で36本の外から7本が出た。中心の2本（`oe-send`・`lib/seat.sh`）がパターンの語を含まないことは、knowledge item 01M07QDKE73BTK0Q3K90FE4G9T の新しい観測になる

## P2: ゲート1（ゼロベースの代替探索・2026-11-06）

- `so-compare --with codex,cursor` に、初期案A・B・C と暗黙の前提5つと選択肢拡張の節を渡した。プロンプトと出力は統括のワークスペースの根の `tmp/577-record-identity/` にある。Codex は `gpt-6.1-sol`（設定から解決）で170秒、Cursor は `composer-2.5`（指定）で86秒、どちらも初回で返った。
- 新しいカテゴリの案が、2つのレーンで合わせて7つ出た（重なる1つを数えると8件）。採否は discussion の §7 の探索木に書いた。全部を採らなかったのは、案F（常駐の管理プロセス）・案E'（event の再生）・案F'（ワークスペースへの置き場）・案G（長寿の中継）、一部を採ったのは案E（保留）と案H（hook の観測）、owner に聞いたのは案D（transport）である。
- 案A への指摘のうち、設計の判断を足したもの: `epoch`・ commit point を `lineage` の記録1つにして交代の途中で止まっても再実行で直る形・server を pid と開始時刻で区別・heartbeat の引き方を1つの関数に・`/clear` の定義・Enter の前の確かめ直しと残る穴の明記・`oe-register link` の原子性。
- 判断の分かれ目: Codex は「人が管理する復帰を1コマンドにするのか、重複の resume や交代中の報告まで自動で扱うのか」で案C と案A が分かれる、と書いた。確定版の「望む結果」と owner の答え（生きていないことを機械で確かめる）は後者を求めているので、案A を残した。この判断の理由は discussion の §7「案C の境目」にある。
- 新しいカテゴリの案が出たので、暫定の停止条件（「新しいカテゴリが出なければ確定に進んでよい」）には当たらない。出た案はそれぞれ採否を決めた。2周目のゼロベースの探索は回さず、ゲート2（設計SO）で、採った形がさらに崩れるかを見る。

## P2: ゲート2（設計SO・2026-11-06）

- `so-compare --with codex,cursor` に、discussion の §5〜§7 を読ませて7つの検証点を渡した。**Codex は返らなかった。** 10秒で `timeout_status=error` になり、stderr の末尾に利用上限の行（「try again at 4:41 AM」）があった。ゲート1 の Codex は同じ日の約30分前に返っていたので、ゲート1 で上限に達したと見られる [speculation]。brief の決まりで、Cursor（`composer-2.5`・指定・111秒）の1レーンで進めた。そのことを plan の「設計SO」の節に書いた。
- 指摘は11件（高2・中7・低2）で、9件を採った。採否の表は discussion の §8 にある。
- 判断の理由として残しておくもの:
  - 高の2件（#188 の frontmatter・board schema の §9）は、どちらも「前の決定の文が、この設計と食い違ったまま残る」という指摘だった。設計の中身ではなく、置き換えの範囲の書き方の抜けである。decision の案の関係の表に、置き換えるものと上書きするものを1行ずつ足した。
  - registry の link の原子性（中）は採らなかった。registry は移行のあいだの複製になり、正本は `lineage` の記録である。複製の原子性を直す手間は、正本を移せば要らなくなる。
  - 旧い子の報告の取り違え（中）は、旧い子に新しい環境変数を渡せないことから来る。旧い子も自分のペインは確かに知っているので、自分のペインから自分の `lineage` を引く形にした。他人のペインを引くのと違い、使い回しの穴が無い。
- 2レーンの多様性が得られていないことを、報告で統括に伝える（やり直すかは統括が決める）。

## 訂正: `--continue` の文は MCP server の子プロセスについての文だった（2026-11-06）

- 何が起きたか: 統括から知らせが来た。公式の文書の env-vars の `CLAUDE_CODE_SESSION_ID` の行で、「`--continue` と id を付けない `--resume` では起動したときの id が入ることがある」は、MCP server の子プロセスについての文の続きにある、という読みである。原文を文ごとに区切って読み直すと、行は「Bash と hook では hook の session_id と一致し `/clear` で更新される」「MCP server の子プロセスは起こされたときの id を持ち続ける」「`--resume <id>` では resume した id を受け取り、hook と Bash と一致する」「`--continue` と id なしの `--resume` では起動したときの id を受け取ることがある」の順で、後ろの2文の主語は MCP server の子プロセスである。統括の読みが正しい。
- なぜ取り違えたか: 原文を curl で取り、行を開いて `[verified]` を付けたが、確かめたのは「その行にその文がある」ことまでで、「その文の主語が Bash と hook である」ことは確かめていなかった。文書の確認に出した道具の報告も同じ文を Bash と hook の側に並べていて、そのまま受けた。`[verified]` の付け方として、文があることと、その文が主張を支える（entailment）ことを分けて見るべきだった。
- 影響: DJ-7 の推奨（id を付けた resume を決まりにする）は、この誤読を前提にしていた。owner への問いも同じ前提で書いたので、統括が問いを取り下げ、「実機で確かめてから決まりにするかを決める」を推奨にした問いに置き換えた。ゲート1 とゲート2 のプロンプトにも誤読の文を「確認済みの事実」として渡していて、ゲート2 の Cursor の DJ-7 の表（「id なしでは 2 が使えない」）はその前提に立っている。3 の方法の確かめ（workspace の一致と owner の確かめ）は、どの resume の形でも要るので残した。
- 直したもの: discussion の §2.2 と DJ-7、decision の案の「前提の変化」2・D7・「残る穴」、plan の N2。DJ-7 は、owner の答えが届くまで確定しない。

昇格の印: 一次の行を開いて `[verified]` を付けても、確かめたのが「文がある」までで「文の主語が主張の対象である」までではなかった。表の1つの行に複数の主語の文が並ぶ文書で起きる

## P2: 新しい概念の名前を識別子にそろえた（2026-11-06）

- 何が起きたか: 統括から、owner の指摘として追加の指示が来た。新しい概念の名前に日本語の言い換え（席・代）を使わず、#564 の決まりの案（用語はそのままプログラムの識別子として書ける名前にし、日本語は説明にだけ使う）に合わせること、代は既存の識別子 `generation` を使うこと、持ち場の識別子は候補と推奨を問いにすること、である。`seat` は current_supervisor の意味から外す方向なので使わない。
- 判断: 持ち場の名前の候補を、既存のコードと文書の識別子とぶつからないかで絞った。`slot` はコードに24件、`actor` は `oe-ack` の「actor verb」の呼び方があり外した。残った `lineage`・`post`・`identity` を問いにし、`lineage` を推奨にした（discussion の DJ-17・統括のワークスペースの根の作業層 `.oe/question-577-2.json`）。ほかの新しい概念（`binding`・`epoch`・`delivery_held`）は、問いにせず discussion の §5.0 に置いた。既存の言い換え（登記・拍動・出来事・受領印）も、#564 の表の識別子（`registry`・`heartbeat`・`events`・`receipt`）にそろえた。
- 失敗と撤回: 4つの文書の語を一度に置き換える小さなスクリプトの後始末で、続く空白を1つに詰める正規表現が行頭の字下げまで詰め、frontmatter の YAML と入れ子の箇条書きを壊した。変わった行を読み直して気づき、置き換えの前に退避していた写しへ戻した（戻した結果は commit `23ce1ab` と同じだった）。2回目は、語の前後の文字を見て空白を足すか決める形にし、行頭を触らないようにした。「交代」「世代」の中の「代」は置き換えから除いた。
- 判断ボードの Q65〜Q67 と Q69 は owner が答えている途中なので、文は変えていない。答えは、席を `lineage`、代を `generation` に読み替えて入れる（discussion の §5.0 に書いた）。

## P2: 「道」と、ほかの造語の名前を直した（2026-11-06）

- 何が起きたか: owner が「道って何を指してんだ」と問い、統括から追加の指示が来た。「送る道」はコードの呼び方の `transport`（`lib/delegate-send.sh` の冒頭の注記）に、方法の意味の「道」（推し量る道・名乗る道・知る道）は「方法」に直し、ほかの造語の名前も output-format §8 と #564 の基準で見直すこと、である。
- 「道」は意味で4つに分かれていた。文を届ける手段（`transport`）、手段や手順（方法）、子を起こす経路（engine の `oe`（WezTerm）と `oe-delegate`（tmux）の名前で書いた）、書き込みの経路（コードの注記の呼び方の write path・`bin/oe-register` の冒頭）である。逃げ道は、`bin/oe-send` の案内の呼び方の「フォールバック」にした。
- 同じ基準で直したほかの名前: 鍵 → キー、写し → snapshot（events のとき・#206 の言葉）か複製（registry のとき）、既知の印 → `seen` の記録（ファイル名）、受け口 → inbox socket（公式の文書の呼び方）、名乗る verb・取り込みの verb・掃除の verb → `oe-lineage bind`・`oe-lineage adopt`・`oe-lineage gc`、確定の点 → commit point、従の記録 → 派生の記録、前面のプロセス → フォアグラウンドのプロセス、実装の段 → 実装の段階。動詞の「写す」と、コードの注記が使う「鮮度の窓」「機械の節」は残した。
- 判断ボードのカードは書き換えていない。

## P2: owner の答えを入れた（2026-11-06）

統括から、判断ボードで回収した owner の答えが届いた（2026-11-06 03:41 回収）。答えは席を `lineage`、代を `generation` に読み替えて、discussion の該当の DJ と decision の案に入れた。

- Q65（DJ-1）: `lineage` と `generation` の2段。補足「一意に決まるものを区別して2つのリレーションで持つ。1つの ID に2つの意味を持たせない」。置き場（DJ-2）は1つのファイルに並べる案のままで、その中で2つの表として持つ読みにした。ファイルを2つに分けるべきかは、この読みで足りるかをゲート3 で確かめる問いにした。
- Q66（DJ-11）: 両方書く。補足「復帰のテストのときに一気に切り替えてもよい」。registry をキーとして読むのをやめる最後の切り替え（PR-5）を、復帰のテストの時に一度に行ってよいと plan に書いた。
- Q67（DJ-10）: transport は tmux のまま。補足「Claude Code への依存を深めないので乗らない。issue にするまでもない」。別の issue は起こさない。最初の推奨にあった「inbox socket を属性として持てる形にしておく」も、依存を深める準備なので外した。
- Q69（DJ-7）: 「実機で確かめてから決まりにするかを決める」。補足「一次情報に当たろう。推測するな計測せよ」。resume の打ち方の決まりは設計で決めず、plan に I0（実装の最初の段階で計測する）を足した。
- Q70（DJ-17・1回目・`lineage`）: どの案も選ばれず取り下げ。補足「lineage は日本人には馴染みが無く一般的でない。一般的か・デファクトかが大きい」。

### DJ-17 の2回目の候補を一次情報で調べた

- 1回目の誤り: 候補を、既存のコードの識別子とぶつからないかだけで絞った。分野で一般に使われているかを調べていなかった。owner の基準は「一般的か・デファクトか」だった。
- 2回目は、owner が例に挙げた Kubernetes・leader election・actor の実装・エージェントの枠組みの公式の文書を、読むだけの取得の道具2つに分けて読ませ、候補の根拠にする文は自分で curl で原文を取り、文字列が一致することを確かめた。道具の報告の一部は「ページの要約からの引用」と自分で断っていたので、そのまま使わなかった。
- 決め手になったのは Kubernetes の Lease である。API が holderIdentity（いまの持ち主）と leaseTransitions（持ち主の入れ替わりの回数）を持ち、説明が「同じホスト名の新しい kube-apiserver のインスタンスは、新しい Lease を作らずに、既存の Lease を新しい holder identity で引き継ぐ」と書く。英語版と日本語版の両方で確かめた。この設計の持ち場（入れ替わっても1つ）と `generation`（入れ替わりの回数）と resume（新しいプロセスが既存の持ち場を引き継ぐ）が、そのまま対応する。
- `agent`（AutoGen の AgentId）と `actor`（Orleans と Akka）は、ほかの案にした。弱いところは、`agent` は Claude Code と hub の中で同じ語が3つの意味になること、`actor` は実装によって持ち場の側と実体の側のどちらを指すかが逆になることである。
- 問いは統括のワークスペースの根の作業層 `.oe/question-577-3.json` に置いた（推奨 `lease`）。答えが届くまで、文書の `lineage` は仮の名前のままにする。

昇格の印: 名前の候補を「コードの識別子と衝突しないか」だけで絞ると、分野で通じない名前が残る。owner の基準は「一般的か・デファクトか」で、確かめ方は公式の文書での出現である

## P2: セッション間の文を送る機能の「参考」を DJ-10 に残した（2026-11-06）

- 統括から、owner の言葉（受け取る側の制御の仕組みは、将来 transport を替えるときの参考になる）と、要点6つが届いた。原文を取り直し（前に取ったものと同じだった）、6つを節ごとに当てた。
- 5つは原文どおりだった。6つ目（送る側に受領の返事は無い）は、原文には「届いたことを送り手へ自動で知らせる」記述が無い、という形でしか確かめられない。原文に書かれているのは、受け手の Claude が返事をできることと、非対話のセッションで保留が期限を過ぎたときに送り手へ「expired」を返すことだけなので、その例外も添えて「書かれていない」と書いた。3つ目の後半（send-keys で `/clear` が実行されうる）は確かめていないので `[speculation]` にした。
- 別の issue は起こしていない。

## P2: transport の入口から参考を指す1行を、plan に足した（2026-11-06）

- owner が「参考に残しても transport を替えるときに埋もれる」と指摘し、統括から指示が来た。plan の PR-3 に、`lib/delegate-send.sh` の冒頭の説明へ DJ-10 の参考を指す1行を置く作業を足し、確定版に無い判断の N11 にした。DJ-10 の参考の節には、統括の見立て（届ける前の制御と、対話中のエージェントへの最後の一歩を分けて設計する・記録の正本はテキストのまま）を足した。
- 「唯一の入口」は、コードで `tmux send-keys` を呼ぶのがこのファイルだけであることで確かめた（`bin/oe-send` の2行は案内の文）。

## P2: 持ち場の名前が lease に決まり、plan-390 の裁定との関係を owner に確かめている（2026-11-06）

- owner の答え（判断ボードの Q71・04:09 回収）: `lease`。補足は「Kubernetes で使っているならデファクト感がある。リースは日本語としても一般的。統括も一通り終われば閉じて立て直すので、永続でない点も合う」。discussion・decision の案・plan の仮の名前 `lineage` を `lease` に置き換えた（`lease_id`・`oe-lease`・`~/.claude/state/oe-lease/`・`OE_LEASE_ID`）。**この episode の 04:09 より前の節は、そのときの仮の名前 `lineage` のまま残している。** DJ-17 の1回目の経緯も同じである。
- 統括が見つけた食い違い: #390 の plan のゲート3 の回答1 で、owner は「席に排他制御（lease と fencing）を入れない。停止を fencing の代わりに使う」と答えていた。そのとき棄却した案は「lease と fencing token による席（compare-and-swap・世代番号・consumer が token を検査）」で、理由は「新しい正本を作るので lean の決定に正面から反する」だった。この設計の `epoch` と compare-and-swap はそれに近い。統括が判断ボードに Q72 として載せた。
- 私がこれを見落とした理由: 棚卸しと前提の読みで、decision #238/#239 の lean の決定（seat の先送り）は読んだが、その決定を #390 で owner がもう一度確かめた裁定（plan-390 のゲート3）までは読んでいなかった。brief の参照の一覧にも plan-390 は無かったが、DJ-12 で board の席の CAS（`lib/seat.sh`）を作った単位として #390 を引いていたので、その plan のゲート3 は読める位置にあった。
- 用意したもの: decision の案に「plan-390 のゲート3 の回答1 との関係」の節を足し、近いところ（新しい正本・compare-and-swap・世代番号）と、違うところの見立て（consumer が token を検査して旧世代の操作を失効させる部分は入れていない・#390 の DJ-7 の「停止が fencing」は残す）を書いた。DJ-5 と D5 は、Q72 の答えまで確定しない。

昇格の印: 前の決定（ADR）を読むときは、その決定を owner があとで確かめ直した裁定（別の plan のゲート3）まで追う。ADR の本文だけでは、owner がその線をもう一度引いたことが見えない

## P2 の終わり: Q72 の答えを入れ、GATE 3 の問いを書いた（2026-11-06）

- owner の答え（判断ボードの Q72・04:25 回収）: `epoch` と compare-and-swap は入れるが、効かせるのは `lease` の記録への書き込みだけ。古い `generation` の送信やファイルの編集まで止める本格的な fencing は入れない。decision の案に「plan-390 の回答1 を、`lease` の記録への書き込みに限って更新する」と書き、関係の表にも1行足した。DJ-5 と D5 を確定した。
- 設計の問いは、これですべて答えが出た（Q65〜Q67・Q69・Q71・Q72。Q68 と Q70 は取り下げ）。
- GATE 3 の問いを plan に3つ書き、問いのデータを統括のワークスペースの根の作業層 `.oe/question-577-4.json` に置いた（2つのリレーションの読み・設計SO の弱さを受け入れるか・この plan で進むか）。

## P4: 分身レビューの指摘のうち、owner の判断を待たずに直す10件（2026-11-06）

統括からの追補の書面（統括のワークスペースの根の作業層 `.oe/brief-577-p4.md`）に従って直した。owner の判断が要る7件（判断ボードの Q76〜Q82）とゲート3（Q73〜Q75）には触っていない。指摘ごとに何をどこで直したかは、統括のワークスペースの根の作業層 `.oe/report-577-p4.md` にある。

- 抜けの中心は、書き手の名指しだった。DJ-5 と DJ-7 は「取り合いのときの決まり」と「復帰のときに本人が名乗る方法」だけを書き、新しく起こした子の最初の `binding` を誰がいつ書くかが無かった。`oe-delegate` の起動の確かめの時点で書く形（DJ-18）を推奨にした根拠は、`oe-delegate` が claude をペインのコマンドとして起こしていることと、この子のペインで `#{pane_pid}` が `CLAUDE_PID` と一致した実測である。起動から4秒のあいだの値は確かめていないので、plan の R4 にした。
- D11（古い子は古い宛先のまま）と D14（古い子も親の `lease` へ送れる）の食い違いは、ゲート2 の Cursor の指摘を採ったときに D14 だけを直し、D11 を見直さなかったことから来た。Q76 の答えまで D11 を正とする印を両方に付けた。
- #238/#239 の行は「先送りを始める」から「lean の決定を identity について覆す」に言い直した。`lease` は #238/#239 が退けた新しい正本そのもので、「始める」では覆していることが読めなかった。

### 分身が挙げた、原則の足りない観点（記録だけ・#404 へは統括が送る）

1. 書き込みや掃除の契機と、その書き手を名指しする観点。今回の DJ-18 の抜けがこれに当たる。
2. 計測の道具を、共通化の対象に巻き込まない観点（`scripts/measure-delivery-arrival.py` のような計測のスクリプトを、本番の読む側と同じ関数に寄せるかどうか）。
3. 前の decision を覆すときに、覆される側に印を残す扱い。今回、decision の案の「確定するときに直すこと」に、#188・#238/#239・board schema に付ける印の文を書いた。

## P5: 分身レビューへの owner の答え7件を入れた（2026-11-06）

統括からの追補の書面（統括のワークスペースの根の作業層 `.oe/brief-577-p5.md`）に従った。答えは判断ボードで 22:00 に回収されたもので、Q83 と Q84 は答えている途中なので触っていない。

- Q73（1つのファイルの中の2つの表）・Q82（PR-2 は分けない）は、推奨どおりで、文書の形は変わらない。
- Q76（守りの4つを外す）で、古い子も親の `lease` へ送れるようにする経路・hook の観測・server の開始時刻での区別・Enter の前の確かめ直しを外した。消さずに「owner の答え Q76 で外した」と印を付けて残した。外したものの多くは、ゲート1 とゲート2 の SO の指摘から足したものだった。owner の補足（復元の情報が揃っていればリスクは下がっている）は、SO の指摘を起きる確実さで重み付けせずに採っていたことを示している。
- Q77（移行中の `#N` のフォールバック）を DJ-15 と D14 と PR-3 に入れた。
- Q78（gc は `lease` と sidecar だけ・`take` のついで・`.hb.*` は別 issue）を DJ-4 と D4 と N5 に入れた。別 issue は統括が起票する。
- Q80（`delivery_held` は止める動きごと #355 へ）で DJ-16 を #355 へ回した。「止める動き」は、DJ-16 の「送れないときに止めて保留する」動きと読んだ。DJ-6 の送る前の確かめで外れたときに送らずに失敗で返すことは、いまの `oe-send` が生きていない宛先へ送らないのと同じ形なので残した。この読みは報告で統括に確かめる。

## P5: Codex でゲート2 をやり直した（2026-11-06）

- owner の答え（Q74）で、Codex の1レーンでゲート2 をやり直した。前のプロンプトを、owner がすでに決めたことを覆さずに崩れる場面を挙げる形に直し、指摘ごとに起きる確実さと被害を分けて書かせた。初回で返った（322秒）。
- 指摘は18件で、15件を採り、3件を採らなかった。採否と理由は discussion の §8 の「Codex でのやり直し」にある。
- 判断の理由として残しておくもの:
  - いちばん大きかったのは DJ-18 の穴である。P4 で「session_id は sidecar の `lease_id` が一致したら足す」としたが、手で立てた統括は環境に `OE_LEASE_ID` を持たないので、最初の session_id が登録されないままになる。P4 で書き手を名指しした（分身の観点1）のに、その書き手が手に入れられる値を確かめていなかった。本人が動かす verb が自分の環境の値で登録する形にした。
  - PR の並べ方の指摘（PR-3 の送信を PR-4 の交代より先に入れると、そのあいだの交代で報告が前任へ向く）は、「読む側を1つずつ切り替える」ときに、その読み手が頼る書き手が先に揃っているかを見ていなかったことから来た。PR-4 を PR-3 の前に入れた。PR の番号は変えず、並べ方の文で順を書いた。
  - 採らなかった3件は、一時的な不達で被害が低いもの・起きるには2つの偶然が重なるもの・owner がすでに決めた範囲（古い子は古い宛先のまま）の残りである。
- Q80 の「止める動き」の読み（DJ-16 の保留の動きと読み、DJ-6 の確かめで外れたら失敗で返すことは残した）は、報告で統括に確かめる。

## P5: 計測の道具を共通化から外した（2026-11-06）

- owner の答え（Q83・会話で「残していて」）で、計測の道具 `scripts/measure-delivery-arrival.py` を、heartbeat からペインを引く規則の共通化（N6）から外し、古い引き方のまま残すことにした。plan の PR-5 から「計測のスクリプト」を外し、理由（#299 で測った到達率 97.6%・74.7% と比べる物差しを変えない）を plan・discussion の DJ-3・decision の案の D3 に1文ずつ書いた。数字は #299 の episode の原文に当てた。
- これは P4 で記録した分身の観点2（計測の道具を共通化に巻き込まない）が、そのまま当たった例である。
- Q80 の読みは owner が確かめた（2026-11-06・統括経由）。保留してあとで届ける仕組みは #355 へ回し、DJ-6 の確かめで外れたら送らずに失敗の終了コードで返すことはこの issue に残す。文書は直していない（読みどおりだった）。discussion の DJ-16 に1行足しただけである。

## P6: Q84 の答えを入れ、ゲート3 の問いを書いた（2026-11-06）

- owner の答え（Q84）: 引き継ぎ文書の機械の節は、`lease` の記録から作る表示に変え、`oe-handoff retire` は読まない。補足は「正しく引ける道が1本になっている方がいい」。discussion の棚卸しの表と DJ-9、decision の案の D9、plan の PR-4 と「移行の終わり方」の表に入れ、確定版に無い判断に N17 として足した。Q83 も N18 として足した。
- 分身レビューへの答えはこれで全部入った。ゲート3 の問い（この plan で実装に進むか）を、P4〜P6 で変わった点の要約つきで、統括のワークスペースの根の作業層 `.oe/question-577-5.json` に書いた。
