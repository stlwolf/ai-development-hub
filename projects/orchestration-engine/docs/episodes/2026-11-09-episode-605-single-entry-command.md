---
id: "01M70B8NAAEJDS5VAX6ND2JZE6"
title: "#605 engine の入口を1本のコマンドにして、verb をサブコマンドで振り分ける"
date: 2026-11-09
type: episode
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/605"
    reason: "作業対象"
  - type: discussion
    ref: "projects/orchestration-engine/docs/discussions/2026-11-09-discussion-605-single-entry-command.md"
    reason: "入口と配り方の調べもの"
  - type: plan
    ref: "projects/orchestration-engine/docs/plans/2026-11-09-plan-605-single-entry-command.md"
    reason: "実装の計画"
tags: [entry-command, distribution, verb-resolution]
---

# #605 engine の入口を1本のコマンドにして、verb をサブコマンドで振り分ける

## なぜこの作業が始まったか

統括の復帰の試験（2026-11-09）で、owner が普通のシェルから `oe-recover` を打つ必要があり、PATH に無いので dotfiles に一時的な関数（`oex`）を置いた。人が打つ verb が増えるたびに `~/bin` へ1本ずつ配る形は続かないので、判断ボードの Q102（`oe-recover` を `~/bin` に配るか）を取り下げて #605 にした。統括（cockpit）から plan-first で委譲された。認識合わせは issue の確定版コメント（2026-11-09）がある。

## 着手時の状態（P1）

- 起点は `origin/master` の `b7e4902`（#610 のマージ後）。worktree はブランチ `feature/#605_single_entry_command`。
- `~/bin` に配っている engine のコマンドは `oe-tree` と `oe-hookfire` の2本（`scripts/sync/sync-bin.sh` の `CMD_NAMES`）。`command -v oe` は何も返さない（`~/bin` にも Homebrew にも `oe` は無い）。
- bash は `/bin/bash` が 3.2.57、PATH の先頭の `bash` が 5.2.37。

## negative knowledge の採用

brief は2件を採用している。2件目の ID が中身と合っていなかった。

- `01M6XN85N408CMMERA12QR1C3F`（tmux に渡す1行で claude を起こすときは `exec claude …`）: そのまま採用する。ただし読んでみると、`oe-recover` と `oe-handoff` の本人確認は、ペインの前面のプロセスを「自分の claude の pid（環境変数 `CLAUDE_PID`）」と突き合わせる形で、verb 自身のプロセスの位置は見ていない（`bin/oe-handoff:684`・`bin/oe-recover:192`）。入口が verb を `exec` しても子として起こしても、`CLAUDE_PID` とペインの前面のプロセスは変わらない。それでも、入口は `exec` で呼ぶ形にする（プロセスが1段増えないので、シグナルと終了コードの受け渡しを考えずに済む）。
- brief の2件目 `01KYCQV7SD6BVBWVCRFYJH9TYG` は、中身が「自由文の欄を deny-list で検証すると迂回路が残る」で、brief の要約（偽物に差し替えて確かめるとき本物に届く経路が残る）と合わない。要約に当たる item は `01M5T897YCWY13GFTADD3136EC`（trigger: 外へ出る操作をする道具を偽物に差し替えて動かすとき、とくに間接の引き方を使うとき）である。brief の意図は後者と読み、後者を採用する。これは brief の ID の書き違いを直す補正で、統括への P3 の報告に書く。

## 作業の記録

### P1: 調べものと設計判断の洗い出し

- 調べものは2つの下請け（サブエージェント）に分けて並べた。1つは代表的な CLI（git・kubectl・docker・gh・cargo）と bash の振り分け役（rbenv・pyenv・sub）、もう1つは最近のエージェント系の CLI である。返った報告のうち、結論を支える4件（rbenv の `exec "$command_path" "$@"`・kubectl の `syscall.Exec`・codex の npm の bin が1本・aoe の `[[bin]] name = "aoe"`）は、書き手がソースを開き直して確かめた。残りは discussion で `[unverified-summary]` の札にした。
- 調べて分かったことで、設計に効いたのは3つである。PATH に置く名前は1本が普通であること。verb は平らに並べ、束ねるのは資源の種類ごとの操作だけが多いこと。bash の振り分け役は `exec` で振り分け、自分の場所は `readlink` を1段ずつたどって解くこと。エージェント系の CLI で PATH の `<ツール>-<verb>` へ振り分けるものは無く、この形は bash の道具と汎用の開発ツールに残っている。
- Yocto の `oe-*` スクリプト群と前置きが重なることを見つけた。素の `oe` は無く、この hub では当たらないので、#537 への申し送りにした。
- 設計判断は8つに分けた。owner に聞くのは DJ-1（入口の名前と本体の移し先）と DJ-2（#609 の名前の付け方）の2つで、どちらも brief が owner の判断と指定したものである。DJ-3〜DJ-8 は自分で決めた。

昇格の印: 入口の直下の verb はファイル名 `oe-<verb>` のとおり平らに並べ、束ねるのは verb の中のサブコマンドにする、という決まりは、#609 以降の verb の名前の付け方を縛るので decision の候補である

### P2: 設計SO（Codex の1レーン）と採否

- `so-compare --codex-only` を1回通し、1回目で返った（gpt-6.1-sol・codex-cli 0.166.0）。出力は worktree の `tmp/so-20261109-233240/`（gitignored）。判定は Issues Found で、指摘は10件（must 3・should 7）。
- 採否は全件採用である。採る前に、根拠に挙がった行のうち4件を書き手が開き直して確かめた。指摘ごとの入れた先は plan の「設計SO」節の表にあり、ここでは再掲しない。
- 自分の案で見落としていたもののうち、型として残す価値があるのは2つである。
  - 名前の検査を「`[a-z0-9][a-z0-9-]*`」と書いたが、glob と正規表現のどちらで実装するかを書いていなかった。glob で実装すると1文字の名前を拒み `abc/def` を通す（Codex が bash 3.2.57 で実測）。plan に書いた文字の並びが、実装の言語によって違う意味になる例である。
  - 偽物で確かめる隔離（negative knowledge `01M5T897…`）を、入口の探し方（T-8）にだけ当て、入口越しに既存の検査を回す T-9 には当てていなかった。T-9 で回す `tests/test_handoff_take.sh` は、もともと実物の `oe-selfcheck` を直に呼び、`HOME` を隔離していない。item の教訓の「手順の引き方を最後までたどる」は、新しく書く検査だけでなく、流用する既存の検査にも当たる。
- Codex が代替に挙げた「`oe help <verb>` を持たず、入口の役目を振り分けと一覧に絞る」を採った。持てば verb ごとの `--help` の質のばらつき（`oe-ident` は `--help` を不正な引数として黙って exit 0）を入口が引き受けることになるためである。

昇格の印: 偽物で確かめる隔離は、新しく書く検査だけでなく、入口越しなど別の呼び方で流用する既存の検査にも当て直す（流用した検査が、もともと本物に届く経路を持っていることがある）。item `01M5T897YCWY13GFTADD3136EC` への観測の追記の候補である

### P3: draft PR とゲート3 の問い

- plan・discussion・episode を1コミットにして push し、draft の PR #617 に載せた。実装はまだ無い。
- ゲート3 の問いは3件（入口の名前と本体の移し先・#609 の名前の付け方・この plan で進むか）を、統括のワークスペースの作業層に問いのファイルとして書き、`build.py check` を通した。報告の宛先は brief の明示（cockpit の統括）で、`oe-tree` に root `cockpit` として生きて出ることを確かめてから、報告のファイルのパスを1行送った（exit 0）。ゲート3 の承認の記録が届くまで止まる。

### GATE 3: 承認

- 2026-11-10 に承認の記録 `.oe/decision-605-gate3.md` が届いた。owner は Q103〜Q105（入口の名前・#609 の名前の付け方・この plan で進む）をすべて推奨どおりに選んだ。baseline は plan @ `2e0cca7`。brief の negative knowledge の ID の補正も受け付けられた。
- 承認の時点で master は `cd0723d`（#615）に進んでいた。重なるのは `scripts/README.md` だけである。承認の基準の commit をブランチに残すため、rebase はしないことにした。

### I1: 入口と本体の移動

- 入口 `bin/oe` を plan の DJ-3・DJ-4 のとおりに書いた。本体は `git mv` で `bin/oe-run` に移し、使い方の文と誤りの文の前置きを `oe run` に直した。本体の説明のコメントは4行目にあったので、一覧の説明に出るよう2行目に動かした（plan の H2・補正）。
- 検査 `tests/test_oe_entry.sh`（T-1〜T-8）を書いた。最初の実行は結果の行を出さずに止まった。`set -o pipefail` の下で `oe --help | head -1` を使ったため、`head` が先に閉じて入口が SIGPIPE で終わり、パイプ全体が非0になって `set -e` で検査が止まっていた。`sed -n 1p`（入力を最後まで読む）に替えて直した。
- 陽性対照として、入口を2通りにわざと壊して回した。`exec` をやめて子のプロセスで呼ぶ形にすると、T-3 の pid の一致が FAIL になった。名前の検査を glob（`[a-z0-9][a-z0-9-]*`）にすると、1文字の名前と T-1 のリンクの場面が FAIL になった（glob では `[a-z0-9-]` が1文字を表し、そのあとの `*` が任意の文字列になるので、2文字以上を要求する。T-1 は1文字の偽の verb `a` で呼んでいたので、リンクの場面もそろって落ちた）。どちらも元に戻し、`cmp` で一致を確かめた。
- 1つ目の壊し方では、子のプロセスとして残った偽の verb（無限に回る `oe-loop`）が検査の出力のパイプを握ったまま残り、検査を包んだコマンドが終わらなかった。偽の verb の出力を `/dev/null` へ向け、入口が `exec` しない壊れ方でも検査が止まらないようにした。
- 本体の検査3本（`test_oe_task_file.sh`・`test_e2e_smoke.sh`・e2e の smoke 1本）を `bin/oe-run` に向け直し、`test_e2e_smoke.sh` には入口の `oe run` 越しに正常系へ着く回を1回足した（設計SO の指摘 9）。

### I2: T-9 と配布

- T-9 の対象を読み直すと、`oe-handoff take` の本人確認の場面（一致しない・`CLAUDE_PID` が無い）を持っているのは `test_lease_handoff.sh` で、plan に挙げた `test_handoff_take.sh` は席の張替を見る検査だった。3本目として足し、3本を入口越しに回す `tests/test_oe_entry_identity.sh` を書いた（plan の H1・補正）。
- 差し替えの口 `tests/fixtures/via-entry.sh` は、`OE_TEST_VIA_ENTRY=1` のときだけ verb を「入口を exec で呼ぶだけの小さなスクリプト」に替え、呼ばれた回数を記録する。各検査は最後に回数が0でないことを確かめる。既定の回は何も変えない。
- 陽性対照として、入口が `exec` の前に `CLAUDE_PID` を消すように壊して回すと、T-9 は本人と一致する場面・止まる場面の行がそろって FAIL になった。入口は元に戻した。
- `sync-bin.sh` の `CMD_NAMES` に `oe` を足した。T-10 は一時的な `HOME` で配置し、`~/bin/oe` が engine の `bin/oe` を指す symlink で、そこから `oe --help` と `oe run --help` が動くことを見る。

### I3: 呼び方の文

- `doc-flow-guardrail` の「verb 解決規約」を、入口 `oe <verb>` で呼ぶ3つの手順に置き換えた。旧い手順が作る `$oe_bin` を指していた3か所（③の止まる条件・④の後継・⑤の復帰）は、`oe --help` の1行目に出るディレクトリの `bin/README.md` を指すように直した（設計SO の指摘 3）。
- インラインのコードで `oe-<verb> <引数>` と書かれた呼び方は `oe <verb> <引数>` に、`delegate-task` の `"$BIN/oe-<verb>"` は `oe <verb>` に、それぞれ機械的に置き換えた。引数の無い `oe-send` のような verb の名前としての言及は残した（ファイルの名前であり、呼び方の指示ではないため）。
- 達成を見る数: `grep -rnE '\$oe_bin|\$anchor|\$BIN/oe-|BIN="\$REPO/projects/orchestration-engine/bin"' canonical` は 0 件になった（変える前は `doc-flow-guardrail`・`delegate-task` などで該当があった）。`~/bin` に配る engine の `bin/` のコマンドは、`sync-bin.sh --list` で `oe`・`oe-tree`・`oe-hookfire` の3本になった（前は2本）。
- 呼び方の形で残したのは `canonical/hooks/README.md` の2か所で、「どの verb のどの操作のときに名前が付くか」を説明する文である。呼び方の指示ではないので変えていない。

昇格の印: `set -o pipefail` の下で、出力の多いコマンドを `| head -1` で受けると SIGPIPE で非0になり、`set -e` の検査が黙って止まる。検査で先頭の行を取るときは `sed -n 1p` を使う。engine の検査で同じ形を書く人が踏みうるので knowledge の候補である

### I4: 子のペインから入口を引けるか

- この作業のセッション自身が `oe-delegate` で起こされた子のペインなので、その Bash で確かめた。PATH に `~/bin` が入っており（`tmux show-environment -g PATH` にも入っている）、sync したあとは `~/bin/oe` を引ける状態である。いまは配っていないので `command -v oe` は空だった。
- worktree から sync はかけず（`~/.claude` のリンクが worktree に張り替わるため）、scratchpad の一時ディレクトリに worktree の `bin/oe` へのリンクを置いて PATH の先頭に足した。`command -v oe` がそのリンクを指し、`oe --help` の1行目が worktree の engine の `bin/`、`oe tree` が統括と自分のノードを出した（exit 0）。
- 実装SO に `oe review --lanes 1` を入口越しに呼ぶと、`oe-review` が「`--lanes` は 2 か 3」と exit 2 で返した。入口越しでも verb の呼び方の誤りの文と終了コードがそのまま届いた例である。brief の「実装1レーン」に合わせ、実装SO は `so-compare --codex-only` で通すことにした。

### CHECK-1: 全検査を master と比べる

- engine の `tests/test_*.sh` を1本ずつ、branch（実装を入れた worktree）と master（`b7e4902`・作業の起点）で回し、名前と終了コードを並べた。どちらも全件が exit 0 で、違いは branch に足した `test_oe_entry.sh` だけだった。branch の回は差し替えの口を入れる前の版だったので、口を入れた3本と本体の検査2本は既定のモードで回し直し、どれも exit 0 だった。

### GATE 4: 実装SO（Codex の1レーン）と採否

- `so-compare --codex-only` を1回通した（gpt-6.1-sol・1回目で返った）。出力は worktree の `tmp/so-20261110-010758/`（gitignored）。指摘は5件（must 1・should 4）で、全件を採って直した。指摘ごとの直し方は plan の H3 にあり、ここでは再掲しない。
- must（呼び出し元が export した同名の変数を入口が書き換えて verb に渡す）は、書き手も bash 5 と 3.2 で再現した。設計SO の指摘 4 で「入口は環境変数を足さない・書き換えたものを export しない」と決め、T-3 で「入口越しと直の呼び出しで env が同じ」を確かめていたのに、見落としていた。T-3 の比較は、呼び出し元が入口の中と同じ名前の変数を持たない場合しか見ていなかったからである。bash の `local` が export の属性を引き継ぐことは、「足さない」を確かめる検査では見えない。
- 直したあとの検査を、直す前の入口（`7c3ba7f` の版）に当てて、足した4件がそろって落ちることを確かめた（陽性対照）。

昇格の印: bash で、関数の `local` は同名の export 済みの変数の export の属性を引き継ぐので、`exec` で別のプログラムに置き換わる前に代入した名前は、呼び出し元が export していればその値が書き換わって渡る。透過であるべき振り分け役は、本体のシェルで代入せずに `exec` する。knowledge の候補である
