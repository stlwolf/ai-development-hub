---
id: "01M6PD1REX2CDA6WZRCZS8EYC2"
title: "#577 engine の記録のキーを tmux のペインから切り離し、こちらで作る ID にする（設計）"
date: 2026-11-06
type: episode
status: stable   # 達成（I0〜I6）。移行の負債5つは #603 で追う
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
    reason: "この単位の decision（2026-11-07 に accepted）"
promotion:
  - subject: "「誰か」のキーを lease_id と generation の記録にする（D1〜D19）"
    verdict: required
    ref: "本文: I1: decision を accepted に上げ、置き換えた側に印を足した（2026-11-07）"
  - subject: "外す条件を満たさない移行の負債を #603 へ移す"
    verdict: required
    ref: "本文: I6: 外したものと、一緒に入れたもの（2026-11-09）"
  - subject: "セッションの環境の CLAUDE_CODE_SESSION_ID と CLAUDE_PID が「名乗る経路が無い」の前提を崩す"
    verdict: not-required
    ref: "本文: 発見: セッションは自分の session_id を環境変数で知っている（2026-11-06）"
  - subject: "パターンの外の対照で36本の外から7本が出た"
    verdict: not-required
    ref: "本文: 網羅の確かめ（パターンの外からの対照）"
  - subject: "[verified] は文がある所までで、文の主語が主張の対象であるかを確かめていなかった"
    verdict: not-required
    ref: "本文: 訂正: `--continue` の文は MCP server の子プロセスについての文だった（2026-11-06）"
  - subject: "名前は分野で一般的か・デファクトかで選び、公式の文書での出現で確かめる"
    verdict: not-required
    ref: "本文: DJ-17 の2回目の候補を一次情報で調べた"
  - subject: "前の ADR を読むときは、owner があとで確かめ直した裁定まで追う"
    verdict: not-required
    ref: "本文: P2: 持ち場の名前が lease に決まり、plan-390 の裁定との関係を owner に確かめている（2026-11-06）"
  - subject: "並行の仕組みへの小さな直しは、新しい窓を作っていないかを数えてから採る"
    verdict: not-required
    ref: "本文: I1: Copilot の1ラウンド（PR #580・2026-11-06）"
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

## I0: resume の値の計測（2026-11-06・ゲート3 承認のあと）

- ゲート3 は owner の「このplanで進めて」で承認された（plan @ `4cec7e8`・統括の記録は作業層 `.oe/decision-577-gate3.md`）。
- 計測の方法: 書面のとおり `CLAUDE_CONFIG_DIR` を一時ディレクトリに向けると「Not logged in」で動かなかった。`--bare` もキーチェーンを読まないので使えない。`--setting-sources project` でユーザーの設定（配っている hook と statusLine）を読まずに起こし、念のため `TMUX_TMPDIR` と engine の state の置き場を一時ディレクトリに向けた。hook が万一走っても、本物のペインと `~/.claude/state/` に届かない形である（negative knowledge `01M5T897YCWY13GFTADD3136EC` の「引き方を最後までたどる」を当てた）。
- 失敗と直し: 1回目は `--allowedTools` が後ろの引数を全部取り込み、問いの文が渡らなかった。2回目は `Bash(echo:*)` の許可が `$` を含むコマンドに合わず止められた。問いの文を標準入力から渡し、`printenv CLAUDE_CODE_SESSION_ID` だけを許す形にした。
- 結果は discussion の DJ-7 にある。新しいセッション・`--resume <id>`・`--continue` の3つで、Bash の値は会話の id と一致した（会話の記録の道具の出力で確かめた）。id を付けない `--resume` は `-p` で使えない。`oe-delegate` が起こした子には親の id は引き継がれない。
- DJ-7 は「resume の打ち方を決まりにしない」と決めた。plan の「ゲート3 のあとの変更」に H1（補正）として書いた。
- 生きている state に書かれていないことを、試した id で heartbeat・events・受領の診断を走査して確かめた。試したセッションの会話の記録は `~/.claude/projects/` の一時ディレクトリの名前の下に残っている（3件・消していない）。

## I1: PR-1（lease の記録の lib と verb）（2026-11-06）

- G0 で、統括が H1 を補正として受け付けた（対話の一覧から選ぶ resume は計測しない）。
- 足したもの（既存の verb は変えていない）: `lib/lease.sh`・`lib/tmux-pane-identity.sh`・`lib/heartbeat-resolve.sh`・`bin/oe-lease`・`schemas/oe-lease.schema.json`・`scripts/validate-lease.sh`・`tests/test_lease.sh`。
- 書いている途中の失敗: タブ文字をそのまま書いたところが3つあり、記憶にある「Write で制御文字が化ける」罠を避けるため変数に替えた。heartbeat の sidecar を `read` で読む区切りにタブを使うと、空の項目（lease_id の無い sidecar）で列がずれるので、空を `-` で埋めて投影する形にした。bash 3.2 では `$( )` の中の `case` の `)` を読み違えるので、テストの1か所を `if` に替えた。
- テストの効き目は、壊した写しで確かめた（ps の失敗を「死んでいる」に畳むと3件、ほかの lease の session_id の確かめを外すと1件落ちる）。

### I1: 実装SO（Codex の1レーン・2026-11-06）

- `so-compare --codex-only`（`gpt-6.1-sol`・224秒・初回で返った）。プロンプトと出力は統括のワークスペースの根の `tmp/577-record-identity/impl-pr1-prompt.md` と `tmp/577-record-identity/so-impl-pr1/`。
- 採ったもの:
  - 高: `bind` の verb は binding を書いてから session_id を登録していたので、session_id がほかの lease にあると binding だけが変わって残った。binding と session_id の登録を、共通のロックの中で1回の書き込みにする `oe_lease_claim` を足し、`bind` と `create --root` はそれを使う形にした。
  - 高: `ps -p` の終了コード1を「そのプロセスが無い」だけと扱っていたが、問い合わせの失敗でも1が返る（Codex が Apple の adv_cmds と procps-ng のソースを挙げた）。終了コード1で空のときは `kill -0` でもう一度確かめ、「No such process」のときだけ死んでいるとする形にした。
  - 中: 同じ lease の別の generation（退任した代など）にある session_id を、いまの generation に登録できた。どの generation にあっても重ねない形にした。
  - 中（確実さは低・被害は高）: 置き去りのロックを2つのプロセスが同時に引き取ると、生きたロックを持ち去りうる。持ち去ったロックの持ち主が読んだ持ち主と同じかを確かめ、違えば戻す形にした。直しが小さいので採った。
  - 中（設計との照合）: 名乗る方法3（会話の記録の lease_id を渡す）の workspace の一致と、統括の lease の owner の確かめが verb に無かった。`bind` で自分の session_id が記録に無いときは workspace の一致を確かめ、統括の lease なら `--owner-confirmed` を求める形にした（exit 10）。直している途中で、workspace のどちらかのディレクトリが無いと、どちらの値も空になって一致と読む穴も見つけて直した。
  - 低: 検査のスクリプトが `started_at`・`retired_at` の型と、`successor` が整数かを見ていなかった。schema に合わせた。
- 採らなかったもの: gc の並行の更新（参照の一覧を作ったあとに登録された session_id の sidecar を消しうる。重さ・確実さ・被害すべて低で、次の heartbeat で戻る。Codex も必須の直しにしないと書いた）。テストの最後の確かめが本物の置き場を読むこと（読むだけで書かない）。
- テストは119件になり、bash 5 と bash 3.2 の両方で通った。

### I1: 既存のテストで前から落ちているもの（範囲の外・直していない）

- 既存のテストを bash 5 と bash 3.2 で全部回したところ、`tests/test_home_unset.sh`（2件）と `tests/test_oe_confirm.sh`（2件）が落ちた。master（`0662dab`）でも同じ4件が落ちるので、PR-1 の前からある失敗である。`test_home_unset.sh` の1件は、`_oe_home_usable` の定義が1種類であることを見る検査で、`lib/handoff-state.sh` だけが複数行の定義になっている。PR-1 の新しい2つの lib の定義は、ほかの12か所と同じである。報告で統括に知らせる。

### I1: Copilot の1ラウンド（PR #580・2026-11-06）

- draft の PR #580 を作り、`gh pr edit 580 --add-reviewer @copilot` で依頼した。依頼の一覧は空のままだったが、記憶にある実測のとおり、レビューはあとから届いた。
- 指摘は2件で、どちらも置き去りのロックの引き取りについてだった。実装SO の指摘を受けて足した「持ち去ってから持ち主を確かめ、違えば戻す」形は、戻すまでのあいだに3つ目の書き手がロックを取れる、という指摘（1件目）と、`mv` が失敗すると再試行の上限に届かずに回り続ける、という指摘（2件目）である。どちらも正しかった。
- 直し: 生きたロックを一時的にでも動かさない形に組み直した。引き取りは「引き取りのロック」（`<lock>.reclaim`）を取れた1人だけが行い、その中で持ち主が死んでいることを確かめ直してから消す。ループは1回ごとに必ず再試行の数を増やす。テストに、生きたロックを引き取らないことと、引き取りのロックが置き去りでも詰まらないことを足した（124件・bash 5 と bash 3.2 の両方で通る）。両方のスレッドに、変更の要約とコミット（`9d33dad`）を添えて返信した。未返信は0件である。
- 振り返り: 実装SO の指摘に対して私が足した直しが、別の窓を開けていた。「直しが小さいので採った」としたが、ロックの引き取りのような並行の仕組みは、小さい直しでも新しい窓を作る。並行の直しは、直したあとの窓を数えてから採るべきだった。

昇格の印: 並行の仕組み（ロック・compare-and-swap）への小さな直しは、直したあとに新しい窓を作っていないかを数えてから採る。実装SO の指摘への直しが、Copilot に別の窓を指摘された（PR #580）

### I1: decision を accepted に上げ、置き換えた側に印を足した（2026-11-07）

- owner の指示（統括経由）で、decision の案を accepted に上げる作業と、#188・#238/#239・board schema に印を足す作業を、PR-2 ではなく PR-1（#580）に入れた。plan の表の「既存の振る舞いに触るか」は verb の動きの話で、文書の印はそれに当たらない、という理由である。統括は一度「PR-2 の branch で行う」と指示し、owner がそれを取り消した。
- 印の文は decision の「確定するときに直すこと」のとおりにした。#188 は frontmatter の `superseded_by` に1文を足し、#238/#239 は frontmatter に `superseded_by` の行を足し、board schema は末尾に §10 の追記の節を足した。どれも本文は変えていない。
- 訂正: 既存のテストの前からの失敗のうち `tests/test_home_unset.sh` の件数は、環境で変わる。`TMUX` があると1件（`_oe_home_usable` の定義が1種類でない）、`TMUX` を外すと `oe-register --help` の1件が加わって2件になる（master の写しで両方を確かめた）。I1 の節の「2件」は、本物のペインに触れないように `TMUX` を外して回したときの数である。

## I2: PR-2（書く側を lease と registry の両方書きにする）（2026-11-07）

- PR-1（#580）は master の `d2b5a99` にマージされた。書面のとおり origin/master を feature ブランチに merge してから始めた（rebase はしない）。
- 足したもの: `oe-delegate` が子の lease を作り、子のコマンドに `OE_LEASE_ID` と `OE_GENERATION` を入れ、起動を確かめた時点でフォアグラウンドのプロセスが claude なら binding を書く。`oe-register` の root と link。heartbeat の producer の `lease_id` と `generation`。events の endpoint の lease と型 `lease_bound`。一度だけの取り込み `oe-lease adopt`。
- 危なかった点: verb を呼ぶ既存のテストをこのセッションの中で回すと、セッションの `CLAUDE_PID` と `CLAUDE_CODE_SESSION_ID` が環境に入っているので、`oe-register root` が本物の `~/.claude/state/oe-lease/` に lease を作るところだった。書く前に気づき、verb を呼ぶ既存のテスト9本で lease の置き場を一時ディレクトリに向け、これらの変数を外した。本物の置き場は作られていない（全体のテストのあとにも確かめる）。negative knowledge `01M5T897YCWY13GFTADD3136EC`（偽物に差し替えるときは、本物に届く経路が残っていないかを最後までたどる）の当てはめである。経路は「テストの外のセッションの環境変数」で、テストの中の差し替えだけを見ていると見落とす。
- `oe-delegate` の既存のテストは、子のコマンドの文字列を丸ごと比べていたので、lease の環境変数（起こすたびに違う ID）を外して比べる形にし、付いていることは別に確かめた。承認の digest は環境変数を含まないので、照合は変わらない。

### I2: 実装SO（Codex の1レーン・2026-11-07）

- `so-compare --codex-only`（`gpt-6.1-sol`・131秒・初回で返った）。プロンプトと出力は統括のワークスペースの根の `tmp/577-record-identity/impl-pr2-prompt.md` と `tmp/577-record-identity/so-impl-pr2/`。
- 採ったもの（2件・どちらも直した）:
  - 中: adopt で取り込んだ統括が `oe-register root` を打つと、取り込んだ lease に session_id が無いので名乗れず、同じプロセスに2つ目の lease を作っていた。`oe-lease create --root` は、自分のプロセスを binding に持つ lease がもうあれば、それを使って自分の session_id を登録する形にした。
  - 低: `oe-lease bind` と `oe-lease create --root` を直接打ったときに `lease_bound` が残らなかった。`oe-lease` の側で残す形にし、`oe-register` の側の重複を外した。
- 指摘が無かった点: lease の部分が失敗しても委譲・登記・送信が今までどおり進むこと・producer が遅くならないこと・別のセッションの lease を焼き込まないこと・adopt の重複と server の絞り込み・テストの隔離。
- 残る確かめ: R2（statusLine が環境を受け継ぐか）と R4（起動から4秒後のフォアグラウンドのプロセスが claude か）は、偽物の道具のテストでは確かめられない。実機の確かめが要る（報告で統括に聞く）。

### I2: Copilot の1ラウンドと、全体のテスト（2026-11-07）

- Copilot の指摘2件をどちらも直して返信した（`06f6cf6`）。1件目は、producer のテストが lease の環境を受け継ぐと従来の出力の確かめが崩れること。I2 で verb を呼ぶテスト9本を隔離したときに、producer のテストを見落としていた。producer は verb ではなく環境変数だけを読むので、「verb を呼ぶテスト」という探し方では引っかからなかった。2件目は、本物の置き場を比べる相手が呼ぶたびに更新されるファイルだったこと。PR-1 の `tests/test_lease.sh` にも同じ形があったので一緒に直した。
- 全体のテスト（57本・両方の bash・`TMUX` を外した環境）で落ちたのは `test_home_unset`（2件）と `test_oe_confirm`（2件）だけで、master の `d2b5a99` でも同じ4件が落ちることを、同じ環境で回して確かめた。テストのあとも本物の `~/.claude/state/oe-lease/` は作られていない。

## I3: PR-4（統括の lease・交代を lease の記録で行う）（2026-11-07）

- PR-2（#581）は master の `62381f1` にマージされた。origin/master を feature ブランチに merge してから始めた（`798f124`）。
- R2 と R4 の実機の確かめは、統括が使い捨ての子で済ませ、どちらも合格だった（sidecar に lease_id と generation が載る・binding の pid はフォアグラウンドの claude と一致）。DJ-18 の書く時点の直しは要らない。統括の観測が1件あった。統括は PR-2 より前に席を取ったので自分の lease が無く、子の `parent_lease_id` が空だった。
- この観測に対して、子の lease の親が空なら埋める関数 `oe_lease_fill_children` を足し、`oe-register root` と `oe-handoff take` の両方から呼ぶ形にした。`oe-register root` は PR-2 の時点で、もう root のペインで打ち直しても lease を作る（または使う）形になっていたが、それより前に起こした子の親は空のまま残っていた。
- take: 統括の lease の generation を進める1回の書き込みを commit point にし、registry・board・event はそのあとに書く派生の記録にした（DJ-5）。前任は、前任のペインのフォアグラウンドのプロセスが lease のいまの generation の binding であることで確かめる。前任に lease が無いとき（#577 の前に席を取った統括）は、前任のプロセスを binding にして作る。作る lease の番号は board の代目に合わせた（後継の代目 - 1 から始める）。adopt が 1 から始めるのと揃っていないが、統括の lease は board の代目と同じ番号の方が人が読みやすいので、take の側だけ合わせた。
- take を2回目に走らせたとき、board がもう自分を指していれば、lease の段より前の「席は既に自分」で終わる（#390 からある分岐）。lease を進めてから board を書く前に止まった場面では、2回目は lease を飛ばして board を直す。この2つをテストで分けて確かめた。
- retire: 閉じてよいかを lease の記録だけで判定し、引き継ぎ文書の機械の節は読まない（owner の答え Q84）。以前の4つの確かめ（session_id・ペインの pid・コマンド名・tmux server の pid）は、前任のペインのフォアグラウンドのプロセスが前の generation の binding（pid と開始時刻）である、の1つにした。シェルで始まるペインの前任も閉じられるようになった（M3）。機械の節の PR と申告の照合はやめ、いまの open PR との照合だけにした。照合の規則（部分一致にしない・種別をまたがない）を見ていた既存のテストは、いまの open PR の側で同じ規則を見る形に書き直した。
- retire の既存のテストは、機械の節に頼っていた17件を書き直した。数は 206 から 197 に減った。減ったのは、機械の節の目印・古い形式・server の pid を見ていた確かめで、いまは存在しない分岐である。
- handoff-state の heartbeat の引き方は、N6 の関数に任せても既存のテスト（prepare 81件・take 125件・retire 206件）がそのまま通った。`oe_hs_beat_age_for_pane` は「いちばん新しい拍動の古さ」を出す別の問いなので、N6 の関数へは寄せていない（理由の文を作るために使っている）。
- oe-vitals: 統括の lease を、`OE_VITALS_LEASE_ID` か board の置き場の workspace で探す。death は binding のプロセスが無いと確かめられたときだけにした（ペインが残っていても、プロセスが終わっていれば death になる）。lease が決まらなければ、いままでどおり board のペインで判定する。cron で走るので、tmux server の pid は `$TMUX` か `tmux display-message` で取る。
- テストの道具: `lib/tmux-pane-identity.sh` の偽の ps・tmux・kill を `tests/fixtures/fake-proc.sh` にまとめた。PR-2 の `tests/test_lease_writers.sh` には同じ形の偽物が直に書いてあるが、そちらは触っていない。
- `tests/test_oe_vitals.sh` は lease の置き場を一時ディレクトリに向けていなかったので、向けた。向けないと、本物の置き場の統括の lease を読み、テストの結果が手元の状態で変わる。

### I3: 実装SO（Codex の1レーン・2026-11-07）

- `so-compare --codex-only`（`gpt-6.1-sol`・195秒・初回で返った）。プロンプトと出力は統括のワークスペースの根の `tmp/577-record-identity/impl-pr4-prompt.md` と `tmp/577-record-identity/so-impl-pr4/`。
- 採ったもの（4件・`7bdc972`）:
  - 高: take が前任を確かめてから epoch を読み直していたので、そのあいだに別の後継が進めた lease を、確かめていない相手のまま進められた。確かめと epoch を同じ1回の読み取りから取る形にした。
  - 高: 別の後継が lease を進めて board を書く前に止まった場面で、もう1つの後継が take を打つと、前任はいまの generation の binding でないので「lease が無い」と取り違え、2つ目の統括の lease を作っていた。前任のプロセスが退任した generation の binding なら止まる形にした。
  - 高: 後継が take の前に自分の lease を作っていると「既に自分」で通り、前任の lease が在任のまま残っていた。また、board の前任のペイン番号が別のリポジトリの統括に使い回されていると、その lease を進められた。自分の lease の前の generation が前任のプロセスであることと、前任の lease の workspace がこの交代の workspace であることを確かめる形にした。
  - 中: oe-vitals は拍動が1件も無いと、lease の binding のプロセスが無くても death を出さなかった。lease が決まっていれば拍動の数で止まらない形にした。
- 採らなかったもの（1件）: board を書いたあとに止まったときの打ち直しで、交代イベントだけが直らない件（中・被害は低い）。#390 からの「席は既に自分」の分岐が `--predecessor` と `--generation` を案内するので、take の保証の書き方を「lease を進めたあと board を書く前に止まった場合」に限るコメントに直した。
- 指摘が無かった点: retire の判定（機械の節を読まない・4つの確かめを1つにしたこと）・oe-vitals の workspace の一致での取り違え・テストの隔離。
- 振り返り: 指摘の3件は、どれも「確かめた相手」と「書き換える相手」が離れる形だった。#390 の take が board の compare-and-swap で塞いだのと同じ型を、lease の側で1回作り直していた。確かめに使った値と書き換えの条件を同じ読み取りから取る、を lease の書き込みでも守る。

### I3: Copilot の1ラウンド（2026-11-07）

- Copilot は行のコメントを付けず（「No open issues」）、概要の見出しだけで「退任の確かめが、対象の workspace を確かめずに通る」と書いた。具体の箇所は無かったが、読み直すと retire は lease の workspace と `-w` の workspace の一致を見ていなかった（take は実装SO の指摘で見るようにした）。申告と突き合わせる open PR・worktree・未 push は `-w` の workspace で見るので、違えば別のリポジトリの記録で閉じる判断をすることになる。take と同じ確かめを retire に足した。
- 既存のテストのうち、未 push と worktree の確かめのために `-w` を別の workspace にしていた4件は、lease もその workspace で作る形にした（retire 200件）。

## I4: PR-3（送る側）（2026-11-07）

- PR-4（#583）は master の `fd3a8c7` にマージされた。統括は22代目から23代目に交代した。origin/master（#584 を含む）を feature ブランチに merge してから始めた（`932f572`）。#584 は、他動詞を1語だけ名詞にして「の」で受ける形（〜の確かめ など）を出力の規則で避ける変更なので、この節から文書の書き方を合わせた。
- 送る・飛ぶ・選ぶの宛先を引く関数を `lib/target-resolve.sh` の1つにまとめ、oe-send・oe-jump・oe-select が同じ関数を使う形にした。oe-jump は宛先を `$( )` の中で引いていたので、関数は結果を変数に入れる形にした（`$( )` の中の代入は外に残らない）。
- ラベルの引き方は、lease の記録を先に引き、候補を3つに分けた。binding があり、プロセスが無いと確かめられていない lease だけを候補にする。binding の無い lease（起動を確かめられなかった子）しか無いときと、候補が無いときは、registry に落とす（owner の答え Q77）。binding の無い lease を「確かめられないので送らない」にすると、起動から4秒で binding を書けなかった子へラベルで送れなくなるので、Q77 の「可能な限りフォールバック」に寄せた。lease_id で指したときは落とさず、確かめられなければ 5 で止まる。
- `--to-parent` は、`OE_LEASE_ID` が無い子と、自分の lease に親が書かれていない子を `PARENT_TMUX_PANE` に落とす。後者は、統括の lease ができる前に起こした子（PR-4 の統括の観測と同じ形）である。PR-4 の `oe-register root` と take が親を埋めるので、時間がたてば減る。
- 危なかった点: oe-send がラベルを lease の記録から引くようになったので、テストの中で本物の `~/.claude/state/oe-lease/`（いまは統括の lease など本物のペインを指す lease がある）を読むと、テストのラベルが本物の lease に一致したとき、本物のペインを宛先にしうる。書く前に気づき、oe-send・oe-jump・oe-select を呼ぶ既存のテスト5本で lease の置き場を一時ディレクトリに向けた。直す前に回したテストは、どれも lease の置き場を一時ディレクトリに向けていたか、送る関数を直に呼んで tmux を関数で差し替えていたので、本物のペインには送っていない。PR-2 の「verb を呼ぶテストは本物の置き場を作る」と同じ型で、今回は「読む」側だった。
- 配っているスキルの文は、明示の宛先が先という順を変えず、2番目を `$PARENT_TMUX_PANE` から `oe-send --to-parent` に替えた。`OE_LEASE_ID` の無い子では、いままでと同じ `$PARENT_TMUX_PANE` に落ちることを書いた。

### I4: 実装SO（Codex の1レーン・2026-11-07）

- `so-compare --codex-only`（`gpt-6.1-sol`・157秒・初回で返った）。プロンプトと出力は統括のワークスペースの根の `tmp/577-record-identity/impl-pr3-prompt.md` と `tmp/577-record-identity/so-impl-pr3/`。
- 採ったもの（3件）:
  - 高: ラベルを lease の記録から引くとき、共有の置き場の全体から拾っていたので、別の統括の子に同じラベルがあればそちらへ送れた。registry は「いまの親の子」に限っていたので、それより広がっていた。自分の lease を親に持つ lease だけを候補にした。自分の lease が分からないときは、lease からは引かず registry に落とす。
  - 中: oe-select は文を打ったあとに lease を引いていたので、打っているあいだにペインの中身が替わると、替わったあとの相手の lease を採れた。選んだ時点で lease を引く形にした。ペインのプロセスを確かめられないときはペイン番号で送る（以前と同じ送り方）が、そのことを知らせる。
  - 中: `tests/test_oe_tree.sh` は一時ディレクトリに `delegate-registry.sh` だけを置いて oe-jump を動かすので、oe-jump が新しい lib を読めず、jump に失敗して picker へ戻り続ける場面があった。全部の lib を置く形にした（88件）。I3 と I4 で oe-jump を変えたときに、oe-jump を間接に動かすテストを探しきれていなかった。
- 指摘が無かった点: oe-send と oe-jump の本人を確かめる手順・`--to-parent`・exit 5 の呼び手・配っているスキルの文・テストの隔離。
- 振り返り: ラベルの範囲の件は、registry の引き方が暗に持っていた「いまの親の子だけ」という範囲を、新しい引き方に写し忘れた形である。置き換える前の引き方が何を絞っていたかを、置き換える側の候補の条件と並べて確かめる。

### I4: Copilot の1ラウンドと、全体のテスト（2026-11-07）

- Copilot の行のコメント3件をどれも直して返信した（`6fbfb52`）。
  - `--to-parent` は、`OE_LEASE_ID` があるのに自分の lease の記録を読めないときも `PARENT_TMUX_PANE` に落としていた。交代のあとなら、本人を確かめないまま前任へ送ることになる。読めない・読み解けないときは 2 で止まる形にした。落とすのは、読めた記録に親が無いときだけにした。
  - 記録に残す generation と、確かめて送ったペインが別々の読み取りから決まっていた。ペインを引く前後で epoch を比べ、変わっていれば引き直す形にした。この窓は時間の重なりでしか起きないので、テストでは再現していない。
  - ラベルを `@tsv` で取り出して bash で比べていたので、バックスラッシュやタブを含むラベルを見落としていた。jq の中で JSON の値のまま比べる形にした。
- 1件目は、PR-4 の実装SO の指摘（take が「前任の lease が無い」と「既に退任した」を区別していなかった）と同じ型である。「読めない」と「無い」を同じ分岐に畳むと、安全側に倒したつもりの逃げ道が、確かめを飛ばす経路になる。
- 全体のテスト（59本・両方の bash）は、実装SO の指摘を直す前に回し始めた。落ちたのは前からある `test_home_unset`（2件）と `test_oe_confirm`（2件）だけで、本物の lease の置き場は書き換わっていない。指摘を直したあとに、変えた lib を使うテスト10本を両方の bash で回し直して通った。

## I5: PR-5（観測する側）（2026-11-07）

- PR-3（#588）は master の `0639919` にマージされ、統括が3つの統括へ知らせて sync も済ませた。origin/master（#586・#587 を含む）を feature ブランチに merge してから始めた（`a351bec`）。
- B-11（commit する文書に lease_id を書いてよいか）は、discussion が「実装の段階で決める」と残した判断なので、owner への問いにした（`.oe/question-577-6.json`・止まらずに続けた）。推奨は「commit する文書には書かず、作業層にだけ書く」。答えが出るまでは推奨のとおりにふるまい、README の例も仮の値にした。
- N7 は、ゲート3 で承認された plan の項目なので問いにせず実装した。`oe-confirm` の子ペインの消滅の通知済みのキーに、子の lease を足した。`oe-undelivered` のキーは、もとから送った時刻とログの中の位置を持つので、tmux を起こし直してペイン番号が使い回されても、別のメッセージとぶつからない。変えていない（棚卸しの表は両方に「キーに足す」と書いていたが、読み直すと `oe-undelivered` は当たらなかった）。
- `oe-threads` は、ペインの session を N6 の関数で引く形にした。以前の「fresh な候補が2件なら曖昧」「server_pid の無い sidecar も pane だけで突合」は、oe-threads の設計の決まり（DJ-C・DJ-D）として理由つきで書かれていたので、すぐには替えずに理由を読み直した。1つのペインで動く claude は1つなので、候補が2件なら新しい方が今の session である。新しい session がまだ拍動を書いていない窓は、以前の決まりでも候補が1件で同じ答えになる。よって、そろえても誤帰属は増えないと判断した。そろえる途中で、N6 の関数が未来の時刻の拍動を候補にしていたことに気づいた（oe-threads は外していた）。時計が戻ると「いちばん新しい」として勝ち続けるので、1分を超えて未来のものを N6 の側で外した。
- `oe-selfcheck` は pane を持つ sidecar の数を数えるだけで、ペインから session を引いていないので、替えるものが無かった。
- `oe-tree --lease` を足し、lease の記録から木を描けるようにした。既定の表示（registry から描く）の切り替えは、owner の答え Q66 のとおり復帰のテストのときに一度に行う。registry を「誰か」のキーとして読むのをやめる最後の切り替えも同じである。
- PR-3 で engine の `bin/README.md` を直し忘れていた（oe-send の lease の宛先・`--to-parent`・exit 5）。PR-5 で oe-tree の `--lease` を書くときに気づき、一緒に書いた。
- 共有の成果物にペイン番号を書かない決まりに反して、I4 の節に統括のペイン番号を書いていた（PR-3 でマージ済み）。PR-5 で代目に直した。README の `--lease` の出力例にも、手元の本物の lease_id とペイン番号を一度書いてしまい、commit の前に仮の値に直した。

### I5: 実装SO（Codex の1レーン・2026-11-08）

- `so-compare --codex-only`（`gpt-6.1-sol`・228秒・初回で返った）。プロンプトと出力は統括のワークスペースの根の `tmp/577-record-identity/impl-pr5-prompt.md` と `tmp/577-record-identity/so-impl-pr5/`。
- 採ったもの（3件と、説明の誤り1件）:
  - 中: `oe-tree --lease` は、親の連鎖が循環している lease（A の親が B、B の親が A）を、どちらも根と判定せず黙って出さなかった。根からたどれなかったものも根として出し、循環していると書く形にした。親を書き換える側（`oe_lease_set_parent`）は、自分自身を親にすることしか止めていないので、循環はありうる。
  - 低: N6 の関数は1分までの未来の拍動を候補にしていたので、時計が戻ると、終わった session の拍動が今の session より勝った。以前の oe-threads は未来を外していたので、私の「規則をそろえても誤帰属は増えない」は、この場面で成り立たなかった。未来の拍動をすべて外す形にした。
  - 低: oe-threads は sidecar を集めたあとに N6 の関数で読み直すので、そのあいだに現れた sidecar を選ぶと、表示の値が - になった。選んだ sidecar を直に読む形にした。
  - 説明の誤り: 「server_pid が空の sidecar はいまは書かれない」と書いたが、いまの producer も `$TMUX` が無いか壊れた環境では空を書く。コメントと README を直した（扱いは変えない。どの server のペインか決められないので候補にしない）。
- 採らなかったもの（2件）:
  - テストが本物を読む経路（oe-threads のテストの「tmux 不在」の場面が本物の tmux を呼ぶ・oe-confirm のテストから呼ぶ oe-selfcheck が本物の heartbeat を読む）。どちらも以前からの箇所で、読むだけで書き換えない。この PR の範囲の外として残した。
  - oe-confirm のキーを変えたので、変える前に lease 付きの子を通知済みでも、変えたあとに一度だけ同じ子をもう一度知らせる。移行のときの1回だけで被害は低い。古いキーも見る形にすると、前の server の子の通知済みのキーが新しい子を抑える元の問題が戻るので、変えない。
- 指摘が無かった点: oe-undelivered を変えない判断・oe-selfcheck に替えるものが無い判断・oe-confirm のキーの混在・bash 3.2。

### I5: Copilot の1ラウンドと、全体のテスト（2026-11-08）

- Copilot は行のコメントを付けず、概要の見出しで4つを挙げた（heartbeat を何度も読む・表示の値が古い・深い木を循環と取り違える・置き場が読めないのに成功で終わる）。具体の箇所は無かったので、それぞれをコードに当てて確かめた。
  - heartbeat を何度も読む: 本当だった。oe-threads は生存ペインごとに N6 の関数を呼び、そのたびに置き場の sidecar を全部読み直していた。sidecar は200件近くたまるので、ペインが10あれば jq を2000回近く呼ぶ。N6 の規則を、すでに読んだ行に当てる口（`oe_hb_pick_panes`）を lib に足し、oe-threads は先に読んだ sidecar に1回だけ当てる形にした。`oe_hb_session_for_pane` も同じ口を使うので、規則は1か所のままである。
  - 表示の値が古い: 上と同じ根で、帰属は読み直した置き場から、表示の値は先に読んだ記録から決めていた。同じ読み取りから決める形になったので、実装SO の指摘で足した「直に読む」逃げ道は要らなくなり、外した。
  - 深い木を循環と取り違える: 本当だった。`oe-tree --lease` は深さ20で描くのをやめていたので、21段目より下が「根からたどれない」として循環と書かれた。循環は描いたノードの記録で止まるので、深さの上限を外した。
  - 置き場が読めないのに成功で終わる: 本当だった。置き場が在るのに読めない（権限が無い）と、「開いた lease はありません」で 0 を返していた。在るのに読めないとき・ディレクトリでないときは 2 で止まる形にした。
- 全体のテスト（60本・両方の bash）は、Copilot の指摘を直す前に回した。落ちたのは前からある `test_home_unset`（2件）だけで、`test_oe_confirm` は #586 で直っていた。本物の lease の置き場は書き換わっていない。直したあとに、変えた lib と verb を使うテスト8本を両方の bash で回し直して通った。
- 振り返り: 1つ目は、PR-4 で「規則を1つの関数にまとめる」を、関数を呼ぶ側の読み方まで考えずに当てた形である。規則をそろえることと、読み取りの回数をそろえることは別で、すでに読んだものに当てる口が要る。

## I6: PR-6（移行の片付け）（2026-11-09）

- PR-5（#590）は master の `ed64889` にマージされた。#355 の復帰の drill は 2026-11-08 に成功し、decision の D11 の条件（両方書く期間は drill まで）を満たした。PR-6 は新しい子で、`origin/master`（`4efde91`）から同じ名前のブランチを作り直して始めた（前の worktree は統括が消していた。origin には squash で入った前のブランチが残っている）。
- brief は承認済みの plan の I6 で、plan を新しく書かない。外す前に、plan の「移行の終わり方」の表の各行の条件を本物の記録で確かめる。

### I6: 外す条件を本物の記録で確かめた（2026-11-09 00:3x JST・読み取りだけ）

見たものは、`oe-tree --lease`（lease の記録から描く木）・`oe-tree`（既定の表示。registry から描く）・lease の置き場の記録10件・registry の記録12件・生きたペインの端末のフォアグラウンドのプロセスの環境（`OE_LEASE_ID`・`OE_GENERATION`・`PARENT_TMUX_PANE` の3つだけを抜き出した）である。どれも読むだけで、本物の `~/.claude/state/` には書いていない。

- lease を持つ生きたもの: hub の統括（23代目）と、その子（この PR-6 の子）、別のリポジトリの統括の子1つ。lease の記録の残り7件は閉じているか、プロセスが消えている。
- lease を持たない生きたもの: **ほかのリポジトリの統括3つ**（3つとも PR-2 より前に席を取り、交代していない）と、**子6つ**。
  - 子のうち5つは、環境に `PARENT_TMUX_PANE` だけを持ち、`OE_LEASE_ID` を持たない（起動は 2026-10-21 から 11-06。PR-2 の 11-07 より前）。そのうち2つは、`PARENT_TMUX_PANE` が registry の親と違う古いペインを指している。親の交代のあとも環境が書き換わらないことの実例である（decision の帰結の「残る穴」の2つ目）。
  - 残りの1つは `oe-register` で手で登録した子で、`OE_LEASE_ID` も `PARENT_TMUX_PANE` も持たない。
- `/tmp/oe-parent-<N>` のファイルは0件。書く側は engine のどこにも無く（`oe-report` が読むだけ）、`oe-delegate` も書かない。
- registry を「誰か」のキーとして読むところ: PR-5 のあとも、`oe-list`・`oe-select`・`oe-status`・`oe-ack`・`oe-tree` の既定の表示・宛先の `#N` を lease で引けないときのフォールバック（`lib/target-resolve.sh`・owner の答え Q77）が registry を読む。`oe-recover` と `oe-register` は registry に書く。

表の行ごとの判定:

| 残すもの | 外す条件 | 確かめた結果 | 判定 |
|---|---|---|---|
| registry への両方書き | 読む側がすべて lease を読み、drill を通したとき | drill は通した。読む側は上の6か所が registry を読む。lease を持たない生きた統括が3つあるので、読む側を lease に切り替えると、その統括と子が一覧から消え、`#N` で送れなくなる | 満たさない |
| `oe-lease adopt` | lease を持たない生きた統括と子が0 | 統括3つ・子6つ | 満たさない |
| `PARENT_TMUX_PANE` の注入 | スキルの文が `--to-parent` だけで、`PARENT_TMUX_PANE` だけを持つ生きた子が0 | 子5つ | 満たさない |
| スキルの古い規則 | 上と同じ | 上と同じ | 満たさない |
| `oe-report` と `/tmp/oe-parent-<N>` | `oe-report` を呼びうる生きた古い子が0 | 子5つは PR-3 の sync（11-07）より前に起動し、古いスキルの文を読んでいる | 満たさない（`/tmp/oe-parent-<N>` だけは、あとで統括の判断で外した。plan の表では行を分けた） |

- 見立て: plan の表の外す条件は、どれも「古い統括と子が残っていないか」に掛かっている。hub の中の記録だけを見れば揃うが、engine は全リポジトリに配っているので、ほかのリポジトリで PR-2 より前から動いている統括と子が、条件を止めている。plan を書いたときは、ほかのリポジトリの統括が何日も交代しないことを見積もっていなかった。
- 外せないことは brief が想定していた（「条件を満たさないものは外さず、理由と次に見る時期を表に残す」）。ただし外すものが実質1つも無い PR になるので、記録だけにしてよいかと、あとで外す作業の置き場を、統括へ問いにした（統括のワークスペースの根の `.oe/question-577-7.json`・「続ける」）。推奨は、表に結果と次に見る時期を書き、`/tmp/oe-parent-<N>` のフォールバックだけを外す、である。書く側が無くファイルも0件で、`PARENT_TMUX_PANE` だけを持つ5つの子はどれもその変数を持つので、外しても誰の経路も変わらない。
- 統括の答え（2026-11-09・owner の原則の範囲内で統括が決めた）: Q1 は推奨どおり、5行とも外さず、`/tmp/oe-parent-<N>` のフォールバックだけ外す。plan の「条件を満たしたものを外す」の文のとおりなので、変更の級ではない。Q2 は、統括が #603 を起こし、plan の表の置き場を PR-6 から #603 に替える。plan には補正 H2 として書いた。

### I6: 外したものと、一緒に入れたもの（2026-11-09）

- `oe-report` から `/tmp/oe-parent-<自 pane>` のフォールバックを外した。テストに、ファイルを置いても読まないことの場面（[5b]）を足した。worktree の `bin/oe-report` を一時的に master の版へ差し替えて回すと、この場面は rc=0 で偽の親へ送ってしまい FAIL になるので、変更を検出できる。テストは `/tmp` に使い捨ての番号のファイルを1つ置き、すぐ消す（`oe-report` が読む場所が `/tmp` に固定されているため、一時ディレクトリに向けられない）。
- B-11 の答え（Q88）: `doc-flow-guardrail` の委譲固定節の ephemeral-ID hygiene の例に `lease_id` を足した。brief の固定節の文と一致した。
- decision の帰結に、フォアグラウンドのプロセスで本人を確かめるのは claude がフォアグラウンドのプロセスグループの長であることが前提、の1行を足した（#355 の knowledge `01M6XN85N408CMMERA12QR1C3F` の由来）。D11 に、PR-6 で外したものと残したものの追記を足した。
- plan の status を `stable` にし、I5・I6 の済み印を書いた（I1〜I4 の PR 番号とマージの commit は、`gh pr view` で確かめて合っていた）。
- 全体のテスト（63本）を bash 5.2 と 3.2 で回した。落ちたのは `test_home_unset` の1件（`_oe_home_usable` の定義は1種類・#602）だけで、master でも同じく落ちる。1回目は state の置き場の環境変数を全部一時ディレクトリへ向けて回したので、既定の置き場を確かめる `test_home_unset` の場面が余計に落ち、`test_envelope` も1回落ちた。置き場を lease だけ一時ディレクトリに向けて回し直すと、どちらも master と同じ結果になった。本物の lease と registry の記録は、前後で shasum が一致した。

### I6: 実装SO（2026-11-09）

- `so-compare --codex-only` は、Codex の利用上限で3秒で失敗した（events に「usage limit」）。brief の決まりで `--cursor-only`（`composer-2.5`）に1回だけ回し、初回で返った。プロンプトと出力は統括のワークスペースの根の `tmp/so-20261109-002042/`。
- 採ったもの（7件・どれも低か中で、振る舞いは変えない）:
  - 中: decision の D19 が「`oe-report` と `/tmp/oe-parent-<N>` は PR-6 で廃止」のままで、D11 の追記と食い違っていた。D19 に、外したのはフォールバックだけで verb は #603、と追記した。
  - 低: plan の表の `/tmp/oe-parent-<N>` の行の条件が「同上」で、満たしていないのに外したように読めた。条件と別の理由（統括の判断）で外したと書いた。episode の表にも、あとで分けたことを足した。
  - 低: テスト [5b] は、途中で止まると `/tmp` のファイルが残りえた。EXIT の trap に足した。番号を数字でない接頭辞にして、本物のペインの番号と重ならないようにした。テスト [5] の見出しの「file」を外した。
  - 低: engine の `bin/README.md` の `oe-report` の節に、親を環境変数だけから引くことと、戻しの方針が `oe-send --to-parent` であることを書いた（以前は `oe-send "$PARENT_TMUX_PANE"` と書いていた）。
  - 低: episode の「master に当てると FAIL」を、worktree の verb を差し替えて回した、と正確に書き直した。
- 採らなかったもの: 凍結した過去の plan・discussion の「env → `/tmp/oe-parent`」の記述。当時の記録なので直さない。
- 指摘が無かった点: 呼び出し元と配布スキルへの影響・exit code の帯・[5b] の検出力・外した/外さなかった判定とコードの事実・`lease_id` の1語の追加。

### I6: Copilot の1ラウンド（PR #604・2026-11-09）

- Copilot は行のコメントを付けず、概要で1つを挙げた。engine の `bin/README.md` の交代の節が「README が推す戻しの書き方 `oe-send "$PARENT_TMUX_PANE"`」と書いたままで、PR-3 で一本化した `oe-send --to-parent` と食い違う、という指摘である。本当だった。この段落は PR-6 で `oe-report` の文を直すときに触ったのに、同じ段落の古い推奨に気づかなかった。以前の推奨であることと、`OE_LEASE_ID` を持つ子は交代のあとも後継へ届くこと、穴が残るのは古い子と `oe-report` だけであることを書いた。PR に返信のコメントを書いた。

## closure（2026-11-09・PR #604 の Copilot の1ラウンドのあと・マージ前）

tier は heavy である（失敗と撤回があり、意図して起動した SO を各段で回し、選択肢を比べて棄却した設計判断がある）。

### 次の消費者

- #603（外せなかった5つの負債を外す作業）の担当。外す条件と、2026-11-09 に確かめた結果は `本文: I6: 外す条件を本物の記録で確かめた（2026-11-09 00:3x JST・読み取りだけ）` と plan の「移行の終わり方」の表にある。
- #355 の続き（`delivery_held` と送れないときの保留・N4）を決める担当。decision #577 の D15 が「この decision では決めない」と置いた。

### 事実・失敗

- 公式の文書の行を開いて `[verified]` を付けたが、文の主語（MCP server の子プロセス）を取り違えていた。`` `本文: 訂正: `--continue` の文は MCP server の子プロセスについての文だった（2026-11-06）` ``
- 語を置き換える小さなスクリプトが行頭の字下げを詰め、frontmatter を壊した。退避した写しへ戻した。`本文: P2: 新しい概念の名前を識別子にそろえた（2026-11-06）`
- 名前の候補を、識別子の衝突だけで絞った（分野で通じるかを見ていなかった）。`本文: DJ-17 の2回目の候補を一次情報で調べた`
- 設計SO の Codex のレーンが利用上限で返らず、Cursor の1レーンで進めた。`本文: P2: ゲート2（設計SO・2026-11-06）`
- その Codex のやり直しで、手で立てた統括が lease を持たず session_id が登録されない穴などが見つかった。`本文: P5: Codex でゲート2 をやり直した（2026-11-06）`
- 前の ADR（#238/#239）の本文だけを読み、owner が #390 の plan のゲート3 で確かめ直した裁定まで追っていなかった。`本文: P2: 持ち場の名前が lease に決まり、plan-390 の裁定との関係を owner に確かめている（2026-11-06）`
- ゲート2 の採用で D14 だけを直し、D11 を見直さずに食い違いを残した（P5 で解消）。`本文: P4: 分身レビューの指摘のうち、owner の判断を待たずに直す10件（2026-11-06）`
- 既存のテストをセッションの中で回すと、セッションの `CLAUDE_PID` から本物の lease の置き場に書くところだった。書く前に気づいた。`本文: I2: PR-2（書く側を lease と registry の両方書きにする）（2026-11-07）`。PR-3 でも同じ型を書く前に見つけた。`本文: I4: PR-3（送る側）（2026-11-07）`
- 各 PR の実装SO と Copilot は、ほかにも見落としを見つけた（producer のテストの漏れ・retire が workspace を見ていなかった・oe-tree のテストの lib 不足など）。どれもその PR で直した。`本文: I2: Copilot の1ラウンドと、全体のテスト（2026-11-07）`・`本文: I3: Copilot の1ラウンド（2026-11-07）`・`本文: I4: 実装SO（Codex の1レーン・2026-11-07）`
- 実装SO の指摘への小さな直しが、Copilot に別の窓を指摘された。`本文: I1: Copilot の1ラウンド（PR #580・2026-11-06）`
- PR-5 で、規則を1つの関数にまとめたときに読み取りの回数を考えず、heartbeat を何度も読む形になった。`本文: I5: Copilot の1ラウンドと、全体のテスト（2026-11-08）`
- 共有の成果物に統括のペイン番号と本物の lease_id を書いてしまい、直した。`本文: I5: PR-5（観測する側）（2026-11-07）`
- PR-6 では、plan の外す条件がほかのリポジトリの古いセッションで止まり、5行を外せなかった。plan を書いたときに、ほかのリポジトリの統括が何日も交代しないことを見積もっていなかった。`本文: I6: 外す条件を本物の記録で確かめた（2026-11-09 00:3x JST・読み取りだけ）`
- PR-6 の push で、squash で入った前の同名のリモートブランチ（PR #590 の head）が残っていて、force は安全確認で止められた。2026-11-09 に統括が古いリモートブランチを消し（ls-remote で0件を確かめた）、ふつうの push で出せた。`本文なし: 進行の障害で設計に関わらないため本文に節を立てなかった。事実はこの行に書いた`
- PR-5 の子の Bash が、入力の無い `cat`（`bat` の alias）で約3時間止まり、2026-11-08 の 03:10 JST に統括が `bat` を終わらせて復帰させた。`本文なし: 子の側では起きた時点で書けなかった。事実は統括の記録から写してこの行に書いた`
- PR-6 の全体のテストの1回目で、state の置き場の環境変数を必要以上に一時ディレクトリへ向け、テストが余計に落ちた。PR-6 の実装SO でも Codex が利用上限で返らず、Cursor の1レーンで回した。`本文: I6: 外したものと、一緒に入れたもの（2026-11-09）`・`本文: I6: 実装SO（2026-11-09）`
- PR-6 の README の直しで、同じ段落にあった古い推奨（`oe-send "$PARENT_TMUX_PANE"`）を見落とし、Copilot に指摘された。`本文: I6: Copilot の1ラウンド（PR #604・2026-11-09）`

### 決定と根拠

- 設計の決定は decision #577（D1〜D19）が正本で、選択肢と棄却した案は discussion の §5・§7 にある。`本文: P2: ゲート1（ゼロベースの代替探索・2026-11-06）`
- PR-6 で、外す条件を満たさない負債を外さず #603 へ移し、書く側の無い `/tmp/oe-parent-<N>` だけを外した（統括の判断）。`本文: I6: 外す条件を本物の記録で確かめた（2026-11-09 00:3x JST・読み取りだけ）`

### わかったこと

- セッションは `CLAUDE_CODE_SESSION_ID` と `CLAUDE_PID` で自分を知っていて、id を付けた `--resume` と `--continue` で会話の id と一致した。`本文: I0: resume の値の計測（2026-11-06・ゲート3 承認のあと）`
- 全リポジトリに配る仕組みの移行は、hub の中の記録だけでは終わりを決められない。ほかのリポジトリで交代しない統括と、環境が書き換わらない古い子が、外す条件を止める。`本文: I6: 外す条件を本物の記録で確かめた（2026-11-09 00:3x JST・読み取りだけ）`

### 昇格の判定

frontmatter の `promotion` に1件ずつ書いた。理由と材料は次のとおり。

- **「誰か」のキーを lease_id と generation の記録にする（D1〜D19）** — `required`。decision #577 として PR #580 で accepted にし、実行済み。材料は discussion の §5 と decision。`本文: I1: decision を accepted に上げ、置き換えた側に印を足した（2026-11-07）`
- **外す条件を満たさない移行の負債を #603 へ移す** — `required`。決まったことは decision #577 の D11・D19 への追記と plan の補正 H2 として、この PR に入れた。`本文: I6: 外したものと、一緒に入れたもの（2026-11-09）`
- **セッションの環境の CLAUDE_CODE_SESSION_ID と CLAUDE_PID が「名乗る経路が無い」の前提を崩す** — `not-required`。decision #577 の「前提の変化」の2と D7 に入っている。`本文: 発見: セッションは自分の session_id を環境変数で知っている（2026-11-06）`
- **パターンの外の対照で36本の外から7本が出た** — `not-required`。昇格ではなく、注入された item `01M07QDKE73BTK0Q3K90FE4G9T` への観測として書き戻した（下の「注入された knowledge への観測」）。`本文: 網羅の確かめ（パターンの外からの対照）`
- **[verified] は文がある所までで、文の主語が主張の対象であるかを確かめていなかった** — `not-required`。`evidence-verification-rule` の §1・§2 が「出典が主張を直接支える（entailment）」を `verified` の条件にしていて、同旨が着地している。`` `本文: 訂正: `--continue` の文は MCP server の子プロセスについての文だった（2026-11-06）` ``
- **名前は分野で一般的か・デファクトかで選び、公式の文書での出現で確かめる** — `not-required`。output-format §8（PR #573）に「その分野の人がふだん何と呼ぶか」として着地している。`本文: DJ-17 の2回目の候補を一次情報で調べた`
- **前の ADR を読むときは、owner があとで確かめ直した裁定まで追う** — `not-required`。decision #577 の「plan-390 のゲート3 の回答1 との関係」の節にこの件の関係が書かれている。一般の教訓としては knowledge `01M5PKRS6WECYZTYFC4WXANW50`（decision を要約の名前で引いて前提にするとき）が近い場面を受けている。`本文: P2: 持ち場の名前が lease に決まり、plan-390 の裁定との関係を owner に確かめている（2026-11-06）`
- **並行の仕組みへの小さな直しは、新しい窓を作っていないかを数えてから採る** — `not-required`。一度の出来事で、行動の変え方が「直したあとの差分を読み直す」という一般のレビューの手順を越えない。収穫基準の「非自明」を満たさないと判断した。`本文: I1: Copilot の1ラウンド（PR #580・2026-11-06）`

### 注入された knowledge への観測

#577 の brief（統括のワークスペースの根の `.oe/brief-577-record-identity.md`・`brief-577-impl.md`・`brief-577-pr6.md`）に注入された item は4件である: `01M07QDKE73BTK0Q3K90FE4G9T`・`01KZKWJM1KTAFN22XK0WP0F96J`・`01M5T897YCWY13GFTADD3136EC`・`01M6XN85N408CMMERA12QR1C3F`。4件すべての `observations` に、ref `#577` で1レコードずつ足した。

### 残課題

- 移行の負債5つ（registry の両方書き・`oe-lease adopt`・`PARENT_TMUX_PANE` の注入・スキルの古い規則・`oe-report`）を外す → #603。
- `delivery_held` と送れないときの保留（N4・D15） → #355。
- `test_home_unset` の1件の失敗（`_oe_home_usable` の定義が2種類） → #602。
- heartbeat の一時ファイル（`.hb.*`）が残る漏れ（plan の N5・decision の D4 が「別 issue」とした件） → #350（以前からある issue）。
- 分身レビューが挙げた原則の足りない観点 → #404（統括が送る。`本文: 分身が挙げた、原則の足りない観点（記録だけ・#404 へは統括が送る）`）。
- oe-threads と oe-confirm のテストが本物の tmux と heartbeat を読む経路 → 追わない。読むだけで書き換えず、#577 の前からある経路である（`本文: I5: 実装SO（Codex の1レーン・2026-11-08）`）。
- 凍結した過去の plan と discussion に「env → `/tmp/oe-parent`」の記述が残る → 追わない（当時の記録で、凍結の規約で書き換えない）。
- 対話の一覧から選ぶ resume で `CLAUDE_CODE_SESSION_ID` が一致するかは計測していない（D7） → 追わない。成り立たなくても方法3 に落ちるので、起きたときに直す。

### 形式メモ

- 出力型の骨格で、6日間・6つの PR にまたがる失敗を本文の節への pointer で拾えた。本文に節が無い出来事（push の障害・子の停止）は補完マーカーで書いた。
- 皮（KPT・YWT）は使っていない。
- 摩擦は、印6件の判定で、既存の着地先（rule・knowledge）を探す手間だった。
- Step 4 の外部チェックは `so-compare --cursor-only` で回した（Codex は利用上限）。出力は統括のワークスペースの根の `tmp/so-20261109-003937/`。指摘のうち、pointer の誤り1件・事実・失敗の抜け6件・残課題の行き先3件・作業層だけの根拠2件を直した。knowledge の木が `docs/` と `projects/.../docs/` の2つにある点は、置き場の規約（source.ref と同じ木）のとおりで、直していない。
