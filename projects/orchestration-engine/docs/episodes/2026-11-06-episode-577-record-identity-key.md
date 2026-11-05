---
id: "01M6PD1REX2CDA6WZRCZS8EYC2"
title: "#577 engine の記録の鍵を tmux のペインから切り離し、こちらで作る ID にする（設計）"
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

# #577 engine の記録の鍵を tmux のペインから切り離し、こちらで作る ID にする（設計）

**この episode は着手時（2026-11-06）に枠を作り、作業しながら追記している。** 後追いで再構成した節があれば、その節の冒頭に `reconstructed` と書く。

## なぜこの作業が始まったか

owner と統括が #355（統括の復帰）の見取り図を読む中で、統括の復帰がいつも手作業になるのは、engine の記録が tmux のペインの番号（と tmux server の pid）を「誰か」の鍵に兼ねているためだ、という見立てになった（2026-11-06・#577 の背景）。復帰の工程を足す前に、記録の持ち方を変える。この委譲は設計まで（brief の終端は P3）。

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

これが本当なら、設計の要（resume したセッションが自分の ID を知る道）は「自分のペインの拍動から引く」という間接の道でなく、直接の道を持てる。ただし、文書化されているか、`/clear` や `/resume` で値が変わるか、`claude --resume <id>` で起こしたときに resume した id になるかは、この時点では確かめていない（公式の文書を確かめに出した）。確かめるまでは、この道を設計の土台に置かない。

昇格の印: セッションの環境の `CLAUDE_CODE_SESSION_ID`・`CLAUDE_PID` が、#355 と handoff-state.sh の「名乗る経路が無い」の前提を崩す（確かめた範囲は 2.1.318 の1セッション）

### 公式の文書で確かめた結果（2026-11-06・原文を curl で取って該当の行を読んだ）

- `CLAUDE_CODE_SESSION_ID` は文書化されている [verified] (https://code.claude.com/docs/en/env-vars.md の表の `CLAUDE_CODE_SESSION_ID` の行)。Bash と hook の子プロセスに入り、hook の入力の `session_id` と一致し、`/clear` で更新される。`--resume <session-id>` で起こしたときは resume した id が入る。**ただし `--continue` と、id を付けない `--resume` では、起動したときの id が入ることがある**と書かれている。つまり「resume したセッションが自分の session_id を知る道」は、owner が id を指定して `claude --resume <id>` で戻したときだけ確かである。（**訂正**: この読みは誤り。下の「訂正: `--continue` の文は MCP server の子プロセスについての文だった」の節）
- `CLAUDE_PID` は文書化されている（v2.1.214 以降）[verified]（同じ表の `CLAUDE_PID` の行）。Claude Code 自身の pid で、Bash と hook の子プロセスに入る。プロセスの生死を pid と開始時刻で確かめる材料になる。
- `CLAUDE_CODE_MESSAGING_SOCKET` は、セッション間で文を送る機能（cross-session messaging・v2.1.224 以降）の受け口である [verified] (https://code.claude.com/docs/en/cross-session-messaging.md)。同じマシンのセッションどうしが、tmux を通らずに文を送れる。送る道を tmux の send-keys から切り離す別の道になりうるが、届き方（受領印の hook が走るか・内側の制御で止まるか）がいまの道と違う。この issue で採るかは owner に聞く（範囲の外の候補）。
- statusLine の入力にも `session_id` がある [unverified-summary]（文書の確認に出した道具の報告による・https://code.claude.com/docs/en/statusline.md）。

この結果で、確定版の「設計の要は、resume したセッションが自分の ID を知る道である。いまの Claude Code にはセッションが自分の session_id を名乗る経路が無い」は、**前提が変わった**。経路はある。残る穴は、id を付けない resume と `/clear` である。（**訂正**: id を付けない resume を穴とした根拠は、下の「訂正」の節のとおり誤読だった）

### 実機で確かめた2つの観測（2026-11-06・この子の自分のペインだけを読み取りで見た）

- `CLAUDE_CODE_SESSION_ID` の値の名前の拍動の sidecar があり、その中の pane は自分の `TMUX_PANE`、server_pid は `$TMUX` の2番目の値と一致した [verified]（`~/.claude/state/oe-heartbeat/<session_id>.json` を cat した）。つまり「自分の session_id → 拍動 → いまのペイン」は、セッションの内側から1手で引ける。
- `CLAUDE_PID` は、ペインの端末の前面のプロセスグループの番号（`ps -t <tty> -o pid,tpgid` の tpgid）と一致した [verified]。このペインは `oe-delegate` が claude をペインのコマンドとして起こしたので、`#{pane_pid}` も同じ値だった。シェルで始まるペインでは `#{pane_pid}` はシェルになるが、tpgid は claude を指す（#355 の 2026-11-05 のコメントの実測）。前面のプロセスグループには claude の子（MCP のサーバなど）も同じ tpgid で並ぶので、claude 本人は「pid が tpgid と一致する行」で取る。
- `ps -o lstart` の出力はロケールで形が変わる（この環境では日本語の曜日が出た）。開始時刻を記録して比べるなら `LC_ALL=C` で固定する。

## P2: owner への問い（2026-11-06）

owner が決める判断4件を、問いのファイル（統括のワークスペースの根の作業層 `.oe/question-577-1.json`・`build.py check` 済み）で統括へ送った（`oe-send` の exit 0。宛先は `oe-tree` に生きた root として出ることを確かめた）。4件は、ID が席を指すか代を指すか・移行の段取り・送る道を Claude Code のセッション間の文を送る機能へ替えるか・resume のときに session_id を指定して打つことを決まりにするか、である。3件目と4件目は、確定版に無い問いで、上の「発見」から出た。答えを待つあいだは、答えに依らない棚卸しと設計を進める。

## P2: 棚卸しと網羅の確かめ（2026-11-06）

### 進め方

- 棚卸しは、読むだけの調査の道具を2つ並べて回した。1つは engine の `bin/` と `lib/` の全ファイル（36本に入るかどうかに関係なく）、もう1つはそれ以外（hook・statusLine・scripts・schema・配布しているスキルの文）である。どちらにも、ペインの使い方を鍵・宛先・本人確認・表示に分け、行番号を付けるよう頼んだ。結果は discussion の §3 に表として写した。
- 調査の報告のうち、影響の大きい4つを行に当てて確かめた。`oe-vitals` が拍動をペインだけで絞ること、`oe-confirm` の既知の印が `pane|%N` で server の pid を持たないこと、`oe-report` の `/tmp/oe-parent-<N>` がペインの数字だけであること、出来事の schema で `server_pid` を持つのが `supervisor_succession` だけであること、である。4つとも報告どおりだった。表の残りの行は `[unverified-summary]` のままにした。

### 網羅の確かめ（パターンの外からの対照）

negative knowledge `01M07QDKE73BTK0Q3K90FE4G9T` を当てた。統括の36本は `TMUX_PANE|pane_id|#\{pane` の1つのパターンから出していて、そのパターンで選んだ対照は同じ盲点を持つ。対照は2つ、パターンの外から選んだ。

- **記録の置き場から逆にたどった。** `~/.claude/state/` の置き場の名前12個（`oe-delegate`・`pane-issue`・`oe-heartbeat`・`oe-events`・`oe-confirm`・`oe-vitals`・`oe-view`・`hook-firing`・`session-branch`・`session-named`・`oe-receipt-diag`・`mcp-discover`）と、board と引き継ぎ文書の目印（`START-HERE`・`現統括`・`handoff.md`）で、`canonical`・`projects`・`scripts` のコードのファイルを `grep -rlF` で引いた。36本に入らないのに記録を読み書きするファイルが7本出た。`bin/oe-send`・`bin/oe-list`・`bin/oe-status`・`lib/seat.sh`・`canonical/claude/statusline/statusline-oe-heartbeat.sh`・`scripts/measure-delivery-arrival.py`・`scripts/validate-board.sh` である。拍動を書く producer は、36本の走査が見たディレクトリ（`canonical/hooks/scripts`）の外にあった。`oe-send` と `lib/seat.sh` は、どちらもペインを主の鍵か宛先に使う中心のファイルなのに、パターンの語（`TMUX_PANE` など）を1つも含まない。
- **出来事の型の一覧から逆にたどった。** `oe-events.jsonl` の型を数えると5つ（`message_sent` 4,691件・`prompt_received` 3,562件・`child_spawned` 430件・`report_received` 195件・`supervisor_succession` 33件・2026-11-06 の時点）だった。各型の書く側と読む側を、2つ目の調査で洗った。

網羅の主張は「上の2つの対照と、36本の走査と、2つの調査が使った語で走査した範囲では、表の外は見つかっていない」に限る。

昇格の印: 「パターンの外の対照」で36本の外から7本が出た。中心の2本（`oe-send`・`lib/seat.sh`）がパターンの語を含まないことは、knowledge item 01M07QDKE73BTK0Q3K90FE4G9T の新しい観測になる

## P2: ゲート1（ゼロベースの代替探索・2026-11-06）

- `so-compare --with codex,cursor` に、初期案A・B・C と暗黙の前提5つと選択肢拡張の節を渡した。プロンプトと出力は統括のワークスペースの根の `tmp/577-record-identity/` にある。Codex は `gpt-6.1-sol`（設定から解決）で170秒、Cursor は `composer-2.5`（指定）で86秒、どちらも初回で返った。
- 新しいカテゴリの案が、2つのレーンで合わせて7つ出た（重なる1つを数えると8件）。採否は discussion の §7 の探索木に書いた。全部を採らなかったのは、案F（常駐の管理プロセス）・案E'（出来事の再生）・案F'（ワークスペースへの置き場）・案G（長寿の中継）、一部を採ったのは案E（保留）と案H（hook の観測）、owner に聞いたのは案D（送る道）である。
- 案A への指摘のうち、設計の判断を足したもの: 所有の番号（epoch）・確定の点を席の記録1つにして交代の途中で止まっても再実行で直る形・server を pid と開始時刻で区別・拍動の引き方を1つの関数に・`/clear` の定義・Enter の前の確かめ直しと残る穴の明記・`oe-register link` の原子性。
- 判断の分かれ目: Codex は「人が管理する復帰を1コマンドにするのか、重複の resume や交代中の報告まで自動で扱うのか」で案C と案A が分かれる、と書いた。確定版の「望む結果」と owner の答え（生きていないことを機械で確かめる）は後者を求めているので、案A を残した。この判断の理由は discussion の §7「案C の境目」にある。
- 新しいカテゴリの案が出たので、暫定の停止条件（「新しいカテゴリが出なければ確定に進んでよい」）には当たらない。出た案はそれぞれ採否を決めた。2周目のゼロベースの探索は回さず、ゲート2（設計SO）で、採った形がさらに崩れるかを見る。

## P2: ゲート2（設計SO・2026-11-06）

- `so-compare --with codex,cursor` に、discussion の §5〜§7 を読ませて7つの検証点を渡した。**Codex は返らなかった。** 10秒で `timeout_status=error` になり、stderr の末尾に利用上限の行（「try again at 4:41 AM」）があった。ゲート1 の Codex は同じ日の約30分前に返っていたので、ゲート1 で上限に達したと見られる [speculation]。brief の決まりで、Cursor（`composer-2.5`・指定・111秒）の1レーンで進めた。そのことを plan の「設計SO」の節に書いた。
- 指摘は11件（高2・中7・低2）で、9件を採った。採否の表は discussion の §8 にある。
- 判断の理由として残しておくもの:
  - 高の2件（#188 の frontmatter・board schema の §9）は、どちらも「前の決定の文が、この設計と食い違ったまま残る」という指摘だった。設計の中身ではなく、置き換えの範囲の書き方の抜けである。decision の案の関係の表に、置き換えるものと上書きするものを1行ずつ足した。
  - 登記の link の原子性（中）は採らなかった。登記は移行のあいだの写しになり、正本は席の記録である。写しの原子性を直す手間は、正本を移せば要らなくなる。
  - 旧い子の報告の取り違え（中）は、旧い子に新しい環境変数を渡せないことから来る。旧い子も自分のペインは確かに知っているので、自分のペインから自分の席を引く形にした。他人のペインを引くのと違い、使い回しの穴が無い。
- 2レーンの多様性が得られていないことを、報告で統括に伝える（やり直すかは統括が決める）。

## 訂正: `--continue` の文は MCP server の子プロセスについての文だった（2026-11-06）

- 何が起きたか: 統括から知らせが来た。公式の文書の env-vars の `CLAUDE_CODE_SESSION_ID` の行で、「`--continue` と id を付けない `--resume` では起動したときの id が入ることがある」は、MCP server の子プロセスについての文の続きにある、という読みである。原文を文ごとに区切って読み直すと、行は「Bash と hook では hook の session_id と一致し `/clear` で更新される」「MCP server の子プロセスは起こされたときの id を持ち続ける」「`--resume <id>` では resume した id を受け取り、hook と Bash と一致する」「`--continue` と id なしの `--resume` では起動したときの id を受け取ることがある」の順で、後ろの2文の主語は MCP server の子プロセスである。統括の読みが正しい。
- なぜ取り違えたか: 原文を curl で取り、行を開いて `[verified]` を付けたが、確かめたのは「その行にその文がある」ことまでで、「その文の主語が Bash と hook である」ことは確かめていなかった。文書の確認に出した道具の報告も同じ文を Bash と hook の側に並べていて、そのまま受けた。`[verified]` の付け方として、文があることと、その文が主張を支える（entailment）ことを分けて見るべきだった。
- 影響: DJ-7 の推奨（id を付けた resume を決まりにする）は、この誤読を前提にしていた。owner への問いも同じ前提で書いたので、統括が問いを取り下げ、「実機で確かめてから決まりにするかを決める」を推奨にした問いに置き換えた。ゲート1 とゲート2 のプロンプトにも誤読の文を「確認済みの事実」として渡していて、ゲート2 の Cursor の DJ-7 の表（「id なしでは 2 が使えない」）はその前提に立っている。3 の道の確かめ（workspace の一致と owner の確かめ）は、どの resume の形でも要るので残した。
- 直したもの: discussion の §2.2 と DJ-7、decision の案の「前提の変化」2・D7・「残る穴」、plan の N2。DJ-7 は、owner の答えが届くまで確定しない。

昇格の印: 一次の行を開いて `[verified]` を付けても、確かめたのが「文がある」までで「文の主語が主張の対象である」までではなかった。表の1つの行に複数の主語の文が並ぶ文書で起きる
