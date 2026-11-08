---
id: "01M6XCDSHJJWHCDRBTKDSM4FC3"
title: "#576 統括のセッションに resume の一覧で見分けられる名前を付ける"
date: 2026-11-08
type: episode
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/576"
    reason: "本 episode の作業対象"
  - type: reference
    ref: "projects/orchestration-engine/docs/episodes/2026-11-06-episode-577-record-identity-key.md"
    reason: "統括の lease（session_id を持つ記録）を入れた直前の作業"
tags: [orchestration, hooks, session-name, lease]
---

# #576 統括のセッションに resume の一覧で見分けられる名前を付ける

## なぜこの作業が始まったか

2026-11-06 に owner が「resume の一覧で統括が上にいない時がある」「セッション名がほぼリポジトリ名だけ」と指摘した。統括が hub の直近15本の会話の題を見たところ、統括の会話6本はすべて `ai-development-hub` だった。セッション名の hook（`canonical/hooks/scripts/session-name.sh`）は master ではリポジトリ名に落ち、統括は master で動くためである。

**この episode は着手時に枠を作り、作業しながら追記している。** 後追いで再構成した節があれば、その節の冒頭にその旨を書く。

## この単位の入力

- brief: 統括（cockpit 23代目）が 2026-11-08 に発行した #576 の brief（作業層・消える）。終端は P2（plan を書き、ゲート3 の問いを送って止まる）。マージ・worktree の掃除・issue の close・sync はしない。
- 認識合わせ: 子が `issue-intake` を通し、統括へ渡して確定版を待つ（P0）。
- SO: 設計 weak（Codex 1レーン）・実装 weak（Codex 1レーン）+ Copilot 1ラウンド。
- 注入された negative knowledge: なし（brief の列挙で該当0件）。

## 作業の記録

### P0: 認識合わせ（2026-11-08）

- worktree を `feature/#576_supervisor_session_name` で master `df16c60` から作った。
- 着手時に読んだ事実（いまのリポジトリに当て直したもの）:
  - 統括の lease は1本で、`current_generation` は 1、`session_ids` は1件である。lease は #577 で作ったばかりなので、generation は board の「統括23代目」の代と一致しない。代を名前に入れるなら、lease の generation は材料にならない。
  - `session-name.sh` の hook のテストは、リポジトリに1本も無い。
  - `claude --help` の `-r, --resume [value]` は「session ID か名前で resume、または語で絞った picker を開く」と書いている。語が名前と完全に一致したときに picker を出さずに入るかどうかは、実物で確かめる必要がある。
- 別のモデル（Codex・gpt-6.1-sol・設定から解決）に漏れを問い合わせ、「漏れは無い」と返った。
- 3つの出力を `.oe/question-576-1.json` に書き、統括へ送って確定版を待つ。
- 統括から確定版（https://github.com/stlwolf/ai-development-hub/issues/576#issuecomment-6721086870 ・owner は「この内容で確定する」・深掘りなし）が届いた。issue-intake の 1-2 の照合で、最後の確定版の URL と一致した。

### P1: 名前の決まりと記録の鍵の案・設計SO（2026-11-08）

#### 出した案

- 名前の決まり: R1 `cockpit <リポジトリ名> <N>代目`（代が分からなければ `cockpit <リポジトリ名>`）と、R2 `cockpit <リポジトリ名>`（代を入れない）。
- 記録の鍵: K1 は hook が lease を直接読む案、K2 は席を取る verb が session_id ごとの「名前の要求」を書き hook はそれを読むだけにする案、K3 は lease に名前のフィールドを足す案である。

#### 公式のドキュメントで分かったこと（受け入れ基準に効く）

`claude -r` の挙動を https://code.claude.com/docs/en/sessions.md で確かめた。

- 名前での resume は、今のリポジトリとその worktree の中だけで探す。名前が1件に完全一致すれば一覧を出さずに入り、そうでなければ語を入れた一覧（picker）を開く。
- 一覧の既定の範囲は今の worktree のセッションである。`Ctrl+W` で同じリポジトリの worktree 全部、`Ctrl+A` でこの機械の全プロジェクトに広がる。

したがって、`claude -r cockpit` を打っただけでは**今のリポジトリの統括しか並ばない**。確定版の受け入れ基準「`claude -r cockpit` で各リポジトリの統括が並ぶ」は、`Ctrl+A` を押す手順を足さないと満たせない。これは名前の決め方では解けないので、受け入れ基準の書き換えとしてゲート3 で owner に聞く。

昇格の印: `claude -r <名前>` は今のリポジトリだけを探し、全リポジトリの一覧には picker の `Ctrl+A` が要る（統括の復帰の手順 #355 にも効く事実）

もう1つ分かったのは、R1 にすると名前がリポジトリの中で1つに決まるので、`claude -r "cockpit ai-development-hub 23代目"` で一覧を通さずに直接入れることである。R2 だと退任した統括と同じ名前になり、必ず一覧が開く。

#### 設計SO（弱・Codex gpt-6.1-sol・設定から解決・1レーン）

推奨は R1+K2 の修正版で、こちらの推奨と一致した。指摘は23件で、採否は次のとおりである。

- 採る: 要求の同一性を名前でなく要求の ID で見る（同じ名前で席を取り直したときに、手動の改名のあとでも改名できるようにするため）。ID は lease の `<lease_id>:<generation>` にし、同じ take の再試行では同じ ID、新しい席では新しい ID になるようにする。
- 採る: 要求があるセッションでは、統括の道で処理を終え、Path1 と Path2 に落とさない。Path1 はペインを鍵にするので、前の住人の記録が残っていると、次のプロンプトで `#<issue>` の名前に戻されるためである。
- 採る: plan mode と `/` で始まるプロンプトの除外は、要求を「適用済み」にする前に行う。
- 採る: 要求は、席を取る処理（lease を進め、session_id を登録する）が成功したあとに書き、書けなかったら take の報告に「していないこと」として出す。
- 採る: 要求の記録と適用済みの記録の GC を対で考える。どちらも 30 日触れられなければ消し、hook は no-op のときに両方に触れる。
- 採る: 要求が無い・壊れている・名前が空のときは、今の動きのまま何もしない。
- 採らない: SessionStart で要求を適用する案。名前は会話の記録に残るので、resume のときに付け直す必要が無い。
- 採らない: 同じ名前のリポジトリを `owner/repo` で見分ける案。一覧の既定の範囲がリポジトリの中なので、ぶつかるのは `Ctrl+A` で広げたときだけで、そのときは一覧にパスが出る。必要になったら足す。
- 範囲の外として残す: `--fork-session` で session_id が変わった統括の名前の引き継ぎ。新しい id には要求が無いので、席を取り直したときに付く。#355（復帰）で席を取り直す手順に乗る。
- 範囲の外として残す: 2つのプロセスが同じ session_id を持つ場合。lease 側で同じ session_id を2つの lease に登録できない（`oe_lease_register_session` の rc=8）ので、新しい対策は足さない。
- 残りの指摘（原子的な置き換え・壊れた JSON・id の検証など）は、今の hook がすでに使っている書き方（tmp に書いて mv・jq で読み失敗したら何もしない）で満たすので、plan の実装の決まりに書く。

### GATE 3（2026-11-08）

- 統括から承認が届いた（plan は `dac722c` の版）。owner は判断ボードの Q98〜Q101 をすべて推奨どおりに選んだ。
- Q98（名前の形）に owner の補足「代目の日本語はいらない。入れても gen？」があった。名前を `cockpit <リポジトリ名> gen<N>`（例 `cockpit ai-development-hub gen23`）にし、plan の「ゲート3 のあとの変更」の H1（補正）に書いて統括へ申告した。`gen` と数字を続けて書くのは、`gen23` を1語として検索でき、`claude -r "<名前>"` に渡す語の区切りが1つ減るためである。
- Q100 で owner は受け入れ基準の書き換えを承認した。plan の A2 をその文に置き換えた（H1 に含む）。
- 統括から、H1 を補正として受け付けた（承認の記録の entry 0）と届いた。

### I1-1: 今の hook の動きをテストで固める（2026-11-08）

- `projects/orchestration-engine/tests/test_session_name.sh` を新しく置き、群 A（T1〜T5・15件）を書いた。今の hook で bash 5.2.37 と /bin/bash 3.2 の両方で 15件すべて通った。shellcheck も通る。
- テストの効き目を、壊した写しで確かめた。Path1 の冪等の判定を外すと T2 の1件、Path2 の「同じブランチで手で付けた名前を残す」判定を外すと T5 の1件が落ちた。
- 書いている途中で分かったこと: Path1 は plan mode と `/` で始まるプロンプトでも名前を取り戻す（除外は Path2 にしかない）。統括の道（I1-2）の除外は plan の DJ-4 のとおり統括の道の中で行う。

### I1-2: 書く側の部品と hook の統括の道（2026-11-08）

- `projects/orchestration-engine/lib/session-title.sh` に、名前を出す関数（`oe_session_title_supervisor_name`）と要求を書く関数（`oe_session_title_request`）を置いた。名前のリポジトリ名は、git の共通ディレクトリの親から取る。worktree の中から呼ばれても本体のリポジトリ名になるようにするためである（plan の DJ-1 の「git のトップのディレクトリ名」を、worktree でも同じ名前になる形で実装した。統括は本体で動くので結果は同じ）。
- `canonical/hooks/scripts/session-name.sh` の先頭に統括の道（Path0）を入れた。plan の DJ-3・DJ-4・DJ-6 のとおりである。要求を適用したとき、state に `last_branch` が無ければ今のブランチで埋める。要求が GC で消えたあとに、Path2 が空の `last_branch` をブランチの変化と取り違えて、手で付けた名前を上書きしないためである。
- テストの群 B（18件）を足した。変更のあとは bash 5.2 と /bin/bash 3.2 の両方で 33件すべて通る。master の hook に当てると群 B のうち6件が落ちる（T6・T7・T8 の2件・T9 の最後・T11）。落ちない12件は、名前の関数と書き手（hook を通らない）と、「改名しない」「今の動きのまま」を確かめる件（T9 の前の2件・T10）で、変更の前でも同じ結果になるのが正しい。
- shellcheck は変えた3本で通る。

### I1-3: take と root から名前の要求を書く（2026-11-08）

- `oe-handoff take` は、lease を進めて自分の session_id を登録したあとに、`cockpit <リポジトリ名> gen<代>` の要求を書く（ID は `<lease_id>:<generation>`）。`oe-register root` は label が `cockpit` のときだけ、代なしの `cockpit <リポジトリ名>` を書く。
- 書いている途中で見つけた食い違い: take は中で `oe-register root --label cockpit --force` を呼ぶので、そのままだと take が書いた代つきの名前を root が代なしで上書きする。同じ ID の要求がすでにあれば root は書かないようにした（`oe_session_title_has_request`）。plan の DJ-5 の範囲の中の直しである。
- 既存の `test_handoff_take.sh` と `test_handoff_retire.sh` は本物の HOME のまま `CLAUDE_CODE_SESSION_ID` を偽の値にして take を走らせるので、そのままでは本物の `~/.claude/state/session-title` に書く。どちらにも `OE_SESSION_TITLE_DIR` を一時ディレクトリに向ける1行を足した。全体を回したあと、本物の置き場が作られていないことを確かめた。
- root のテストは、plan では `test_oe_register.sh` に足すと書いたが、lease の偽のプロセスがそろっている `test_lease_writers.sh` の (4) に足した（root が要求を書く・ID・同じ ID なら上書きしない、の3件）。take のテストは `test_handoff_take.sh` の [1] に3件足した。
- GATE I1-3: `tests/` の全テストを、セッションの環境変数を外して bash 5.2 と /bin/bash 3.2 の両方で回した。落ちたのは `test_home_unset.sh` の2件だけで、master でも同じ2件が落ちる（`oe-register --help` の rc と `_oe_home_usable` の定義の種類の数）。新しい lib の `_oe_home_usable` の行は lease.sh と byte 一致させたので、種類の数は増えていない。

### I1-4: README（2026-11-08）

- `canonical/hooks/README.md` の「session-name.sh + wt-pane-issue.sh」節に、(0) の要約と Path0 の項（要求の形・一度だけ改名する決まり・Path1 と Path2 に落ちないこと・`claude -r` の範囲）を足した。

### I1-5: 実物の確かめ（2026-11-08・Claude Code v2.1.319）

#### やり方

- 動いている `~/.claude/hooks/session-name.sh` は main のチェックアウト（master）の hook への symlink なので、そのままでは新しい hook が動かない。検証用の claude だけ、`--setting-sources project,local`（ユーザー設定を読まない）と `--settings`（UserPromptSubmit にブランチの hook だけを置いた JSON）で起こした。sync はしていない（hook は配布物なので sync は統括の仕事）。
- scratchpad に git のリポジトリを2つ（`trial-a`・`trial-b`）作り、tmux の検証用のウィンドウにそれぞれ claude を起こした。今の統括の lease と登記には触っていない。
- それぞれのセッションで、bash モード（`!`）でブランチの `oe-register root --label cockpit` を打ち、次に普通のプロンプトを1つ送った。

#### 結果

- `oe-register` の出力: 「registered %N as root (label: cockpit)」「lease … を自分の lease にしました（root）」「セッション名の要求を書きました（cockpit trial-a。次のプロンプトで付きます）」。
- 次のプロンプトで、ペインの題・プロンプト欄の右の名前・会話の記録の `customTitle` が、すべて `cockpit trial-a` になった。記録は `{"format":1,"request_id":"<lease_id>:1","name":"cockpit trial-a",…}`、state は `{"seat_request_id":"<lease_id>:1","last_branch":"master"}` だった。trial-b も同じく `cockpit trial-b` になった。
- `/rename manual-x` のあとにもう1つプロンプトを送っても、名前は `manual-x` のままだった（同じ要求の ID のあいだは手で付けた名前を残す）。
- `trial-a` で `claude -r cockpit` を打つと、一覧は語「cockpit」で絞られ、出たのは `cockpit trial-a` の1件だけだった（今のリポジトリだけ）。
- その一覧で `Ctrl+A` を押しても、検索欄にいるあいだは広がらなかった。`↓` で一覧に移ってから `Ctrl+A` を押すと、語で絞ったまま `cockpit trial-b`（パス `…/t576/trial-b`）と `cockpit trial-a` が並んだ。案内の行も「Ctrl+A to only show current repo」に変わった。広げた一覧の写しは、ほかのリポジトリの会話も出るので、ここには検証用の2件だけを写す。
- 2つのセッションを閉じてから `claude -r "cockpit trial-a"` を打つと、一覧を通さずにそのセッションに入り、名前も会話もそのままだった。

昇格の印: `claude -r <語>` の一覧の `Ctrl+A` は、検索欄にいるあいだは効かず、`↓` で一覧に移ってから押す（#355 の復帰の手順に書く事実）

#### 片付け

- 検証用の lease 2本（workspace が `trial-a` と `trial-b`）を `oe-lease close` で閉じ、検証用のウィンドウを閉じた。
- registry の検証用の root 2件は、ペインが無くなったので `oe-tree` に `gone` として出ている。registry の GC は次に registry を書いたときに走るので、そのときに消える。GC を手で走らせると統括の下のほかの `gone` の記録も消すので、走らせていない。
- 名前の要求の記録 2件（`~/.claude/state/session-title/`）は残した。30日で GC される。

#### 受入（GATE I1）

- A1: root の道は実物で確かめた（上）。take の道（代つきの `gen<N>`）は `test_handoff_take.sh` で確かめた。take を実物で走らせるには統括の交代が要るので、実物では確かめていない。
- A2: 上のとおり満たす。`Ctrl+A` の押し方を README に書いた。
- A3: `test_session_name.sh` の T1〜T5 が変更の前後で同じ結果。
- A4: engine の全テストが、master でも落ちる `test_home_unset.sh` の2件を除いて通る（I1-3）。shellcheck は変えたファイルで通る。

### I2-1: 実装SO（弱・Codex gpt-6.1-sol・設定から解決・1レーン・2026-11-08）

依頼文には、hook・lib・take・root の diff（master からの差分 256 行）と目的だけを入れた。`.oe/` の中身と業務のリポジトリの情報は入れていない。指摘は4件（どれも中）で、3件を直した。

- 採った・直した: 要求のファイルを2回読んでいたので、あいだで書き換わると、ある要求の ID と別の要求の名前を組み合わせて適用しうる。ファイルを1回だけ読む形にした（この競合はテストで再現しにくいので、読み方の構造で防いだ）。
- 採った・直した: `{…}{` のように途中で切れたファイルや、JSON が2つ並んだファイルでも、jq は最初の値を出してから失敗し、`|| true` でそれを使っていた。`jq -s` で読み、オブジェクトがちょうど1つのときだけ要求とする形にした（T10 に2件足した。直す前の hook では `cockpit repo` と `ab` に改名した）。state の読み取りも同じ形にした。
- 採った・直した: state の置き場に書けないと適用済みの ID が残らず、毎回のプロンプトで手で付けた名前を上書きしていた。保存できたときだけ改名する形にした（T12 を足した。名前が付かないままになるが、手で付けた名前を毎回上書きするよりは害が小さいと判断した）。
- 採らない: `oe-register root` が「要求は無い」と確かめた直後に、並行する take が同じ ID の代つきの要求を書くと、root が代なしで上書きする。take は自分の要求を書いたあとに root を順に呼ぶので、同じセッションで take と root が並んで走るのは、take の外で root を別に同時に打つときだけである。統括がそうする手順は無いので、ロックは足さない。

テストは `test_session_name.sh` が 37件（bash 5.2 と /bin/bash 3.2）。直す前の hook に当てると新しい3件が落ちる。shellcheck は通る。
