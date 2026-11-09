---
id: "01M70B8NCM1XZ1HH1M3JYXN17P"
title: "#605 engine の入口を1本のコマンドにして、verb をサブコマンドで振り分ける"
date: 2026-11-09
type: plan
status: in-development   # ゲート3 承認は 2e0cca7 の版（2026-11-10・owner が Q103〜Q105 をすべて推奨どおり）。承認のあとの直し H1・H2（どちらも補正）は「ゲート3 のあとの変更」節
so:
  design: weak
  impl: weak
  reason: "入口は隣の oe-<verb> を exec するだけの小さなスクリプトで、各 verb の中身は変えない。戻すのもリンクとファイル名を戻すだけで済む。設計SO は Codex の1レーン（返らなければ Cursor に1回だけ）、実装SO は1レーンと Copilot の1ラウンド（brief の指定）"
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/605"
    reason: "本 plan の issue"
  - type: reference
    ref: "https://github.com/stlwolf/ai-development-hub/issues/605#issuecomment-6742431883"
    reason: "着手時の認識合わせの確定版（2026-11-09）。この plan はその各項目を網羅する（「確定版の項目との対応」の表）"
  - type: design_context
    ref: "projects/orchestration-engine/docs/discussions/2026-11-09-discussion-605-single-entry-command.md"
    reason: "入口と配り方をほかの CLI がどうしているかの調べもの（出典付き）"
  - type: reference
    ref: "https://github.com/stlwolf/ai-development-hub/issues/609"
    reason: "復帰のコマンドを、この入口のサブコマンドに置く前提の issue"
  - type: reference
    ref: "https://github.com/stlwolf/ai-development-hub/issues/537"
    reason: "engine を独立したパッケージにしていく大目標。入口は外に見せる口になる"
  - type: reference
    ref: "projects/orchestration-engine/docs/episodes/2026-11-09-episode-605-single-entry-command.md"
    reason: "実行記録"
tags: [entry-command, distribution, verb-resolution]
---

# #605 engine の入口を1本のコマンドにして、verb をサブコマンドで振り分ける

## 背景

engine の `bin/` には `oe-*` が27本あり、`~/bin` に配っているのは `oe-tree` と `oe-hookfire` の2本だけである [verified]（`scripts/sync/sync-bin.sh:64`）。ほかの verb は、AI が `doc-flow-guardrail` の「verb 解決規約」節の手順（PATH にある `oe-tree` の実体のディレクトリから隣を探す）で呼ぶ。人が普通のシェルから打つ `oe-recover` は PATH に無く、統括の復帰の試験（2026-11-09）では dotfiles に一時的な関数 `oex` を置いて打った（dotfiles のブランチ `feat/oe-test-aliases` の `.oe-aliases.bash`）。

この plan は、`~/bin` に配る1本の入口から `<入口> <verb>` で全 verb を呼べるようにし、「verb 解決規約」と dotfiles の一時的な関数を要らなくする。

## この plan の範囲

- やる: 入口のスクリプトを engine の `bin/` に足す。1サイクル本体の扱い（DJ-1）に応じて `bin/oe` を動かす。`~/bin` への配布の一覧に入口を足す。「verb 解決規約」と、呼び方を書いたスキルの文を新しい形にそろえる。検査を足す。
- やらない: 各 verb の中身（引数の解釈・出力・終了コード）は変えない。verb が自分の案内の文で出すコマンドの形（例: `oe-handoff` が `oe-register` の絶対パスを出す箇所）も変えない（follow-up に残す）。`oe-tree` と `oe-hookfire` の `~/bin` への配布は外さない（dotfiles の `.tmux.conf` が `~/bin/oe-tree` の絶対パスで呼ぶため・互換で残す）。dotfiles には書かない。

## 前提（読んで確かめた事実）

- `bin/oe` は1サイクルの自律オーケストレーションの本体で、引数をタスクの文として受ける [verified]（`bin/oe` の `oe_main`）。呼び出し元は検査3本（`tests/test_oe_task_file.sh:16`・`tests/test_e2e_smoke.sh:130`・`tests/e2e_real_agent/smoke_cursor_composer_claude_sonnet.sh:66`）と README・過去の文書だけで、hook・設定・launchd からは呼ばれていない [verified]（`grep -rn 'bin/oe\b'`）。
- `command -v oe` は何も返さない。`~/bin` にも Homebrew にも `oe` は無い [verified]（2026-11-09 の手元）。
- 27本の verb のうち24本は、lib を `dirname "$0"` で解く [verified]（`grep -l 'dirname "\$0"'`）。symlink のまま呼ぶと lib を見つけられないので、入口は verb を実体のパスで呼ぶ必要がある。
- `oe-recover` と `oe-handoff` の本人確認は、環境変数 `CLAUDE_PID`・`TMUX_PANE`・`CLAUDE_CODE_SESSION_ID` と、ペインの前面のプロセスで行う [verified]（`bin/oe-recover:192`・`bin/oe-handoff:684-695`・`lib/tmux-pane-identity.sh:96-98`）。verb 自身のプロセスの位置は見ない。
- verb の多くは2行目に `# oe-<verb> — <説明>` の1行を持つ（`oe-capture` などに無いものがある）[verified]。
- tmux のグローバルの PATH に `~/bin` が入っている [verified]（`tmux show-environment -g PATH`）。`oe-delegate` と `lib/spawn.sh` は PATH を書き換えない [verified]（`grep -n PATH`）。子のセッションは `~/bin` の入口を引ける見込みである。
- `/bin/bash` は 3.2.57、PATH の先頭の `bash` は 5.2.37 [verified]。verb の shebang は `#!/usr/bin/env bash`。
- ほかの CLI の形は discussion にまとめた。要点: PATH に置くのは1本、verb は平らに並べて資源の種類ごとの操作だけを束ねる、bash の振り分け役（rbenv・pyenv・sub）は自分の実体のディレクトリを解いて隣の `<ツール>-<verb>` を `exec` する。

## 設計判断

owner に聞くものは「GATE 3 の問い」に出し、ここには推奨を書く。印の無いものは自分で決めた。

### DJ-1 既存の `bin/oe`（1サイクル本体）との名前の衝突（owner に聞く・Q1）

- 推奨: **入口の名前を `oe` にし、1サイクル本体を `bin/oe-run` に移す。** 本体は `oe run "<タスク>"`・`oe run --task-file <path>` で呼ぶ。
- 理由: 入口の名前と verb のファイルの前置きが同じ `oe` になり、`oe <verb>` と `bin/oe-<verb>` が1対1で対応する。`oe-*` のファイルを足せばそのまま呼べる、という受け入れ基準が名前の規則だけで成り立つ。本体の呼び出し元は検査3本と README だけなので、移す費用はこの PR の中に収まる。
- 移すときに直すもの: 本体の使い方の文（`bin/oe:37` の `usage: oe …`）と誤りの文の前置き（`oe:`）を `oe run` の形にする。本体は入口と同じ `bin/` に置くので、`PROJECT_DIR`（`dirname "$0"/..`）・lib・state と audit の置き場の解き方は変わらない（設計SO の指摘 10 の後段）。
- ほかの案:
  - 入口を別の名前にする（例: `oectl`）。本体の `oe` は動かさなくてよいが、入口の名前と verb の前置きが食い違い（`oectl recover` が `oe-recover` を呼ぶ）、PATH に `oe` 系の名前が2つ並ぶ。
  - `oe` のまま、最初の引数が verb の名前なら振り分け、そうでなければタスクの文として本体へ渡す。`oe recover` が「recover という文のタスク」と区別できないので採らない（issue の本文と同じ理由）。
- 名前の注意（#537 に申し送る）: Yocto（openembedded-core）の `scripts/` に `oe-*` が多数ある [verified]（discussion の「名前の注意」）。素の `oe` は無く、Yocto のビルド環境の中でだけ PATH に載るので、この hub では当たらない。engine を外に出すときに見直す。

### DJ-2 #609 の復帰のコマンドを置くサブコマンドの名前の付け方（owner に聞く・Q2）

- 推奨: **この issue では決まりだけを決め、具体的な名前は #609 に回す。** 決まりは「入口の直下の verb はファイル名 `oe-<verb>` のとおり平らに並べる。束ねたいときは、verb の中のサブコマンドにする（すでに `oe recover hint`・`oe handoff take`・`oe lease show` がこの形）」である。#609 は、この決まりの上で `oe-<名前>` を1本足すか、既存の verb のサブコマンドにするかを選ぶ。
- 理由: 調べた CLI は、日常の操作を平らに並べ、資源の種類ごとの操作だけを束ねる形が多い（discussion の2節）。入口の側で束ねる層（`oe cockpit restore` を入口が `oe-cockpit` の `restore` に振り分けるなど）を作ると、入口が verb の一覧を知る必要が出て、「`oe-*` を足すだけで呼べる」が崩れる。具体名は #609 の設計（何を1本にまとめるか）が決まってから付けるほうが、名前と中身が合う。
- ほかの案: ここで具体名まで決める（例: `oe-cockpit` を足して `oe cockpit restore`）。#609 の設計は「設計を寄せておく段階」で中身が未確定なので、名前だけ先に決めると後で合わなくなりうる。

### DJ-3 入口の作り（自分で決めた）

- 自分の実体のディレクトリを、`BASH_SOURCE[0]`（無ければ `$0`）から symlink を1段ずつたどって解く。各段で `readlink`（`-f` を付けない）を読み、相対のリンク先はリンクのあるディレクトリから解く。最後に `cd -P … && pwd -P` で実体のディレクトリを得る。rbenv・pyenv の型と同じで、bash 3.2 と `readlink -f` の無い macOS で動く。
- **解く処理はまるごとサブシェル（`$( … )`）の中で行い、その中で `CDPATH` を空にする。** 呼び出し元のシェルの作業ディレクトリと環境は変えない。`oe run --task-file <相対パス>` や、作業ディレクトリを既定の workspace にする verb（`bin/oe-kick:59` など）の意味を変えないためである。`CDPATH` があると `cd` が行き先を標準出力に出し、取ったディレクトリに混ざるので空にする。入口は環境変数を足さず、書き換えたものを verb へ export しない（設計SO の指摘 4）。
- たどる段の数に上限（既定 40）を置き、長すぎるリンクの鎖で止まらなくならないようにする。上限は検査のための差し替えの口 `OE_ENTRY_LINK_LIMIT` で下げられる（engine の他の verb の「差し替えの口」と同じ扱い）。入口のファイルそのものが輪になったリンクなら、OS が開く前に失敗するので、入口の処理の対象ではない（設計SO の指摘 5）。
- 振り分け先は、解いたディレクトリの `oe-<verb>` だけを見る。PATH は探さず、PATH も書き換えない（verb の中で呼ばれるほかのコマンドの解決を変えないため）。
- 振り分けは `exec "$dir/oe-$verb" "$@"`。プロセスが置き換わるので、引数・標準入出力・終了コード・シグナルは verb と呼び出し元の間で直に受け渡しされる。negative knowledge `01M6XN85N408CMMERA12QR1C3F` の教訓（プロセスを1段挟まない）にも合う。
- **verb の名前の検査は、端を固定した正規表現 `^[a-z0-9][a-z0-9-]*$` で行う**（`[[ "$verb" =~ $re ]]`・正規表現は変数に入れて渡す。bash 3.2 と 5 で同じに動く形）。glob の `[a-z0-9][a-z0-9-]*` で書くと、1文字の名前を拒み `abc/def` を通すので使わない（設計SO の指摘 1。Codex が `/bin/bash` 3.2.57 で実測）。
- **振り分けの候補の条件と一覧の候補の条件を、1つの関数にまとめる。** 条件は「名前の検査を通る」「`oe-<verb>` が symlink でない通常のファイルで、実行できる」の3つである。verb の symlink は受けない（いまの `bin/` に無く、外を指すリンクを候補にしないため）。入口自身（`oe`）は前置き `oe-` を持たないので候補に入らない（設計SO の指摘 6）。

### DJ-4 一覧・help・誤りの扱い（自分で決めた）

| 呼び方 | 出すもの | 終了コード |
|---|---|---|
| `oe`（引数なし） | 使い方と verb の一覧を標準エラーへ | 2 |
| `oe -h`・`oe --help`・`oe help` | 使い方と verb の一覧を標準出力へ。1行目に engine の `bin/` の実体のパスを出す | 0 |
| `oe help <何か>`・`oe --help <何か>` | 「verb の使い方は `oe <verb> --help`」の誤りを標準エラーへ | 2 |
| `oe <verb> …` | verb の出力のまま（`--help` も verb へそのまま渡す） | verb のまま |
| `oe <知らない verb>` | `oe: no such verb: <名前>（oe --help で一覧）` を標準エラーへ | 127 |
| `oe oe-send` のように前置きを付けた名前 | 上の誤りに「`oe send` と打つ」の案内を足す | 127 |
| `oe -x`（知らないオプション） | 誤りと使い方を標準エラーへ | 2 |

- 一覧は、DJ-3 の候補の条件を通る `oe-*` を名前順に並べ、前置きを外して出す。固定の一覧は持たない。候補が0件なら、その旨を1行出す（誤りにはしない）。
- 説明は、各ファイルの2行目が `# oe-<verb> — <説明>` の形ならその説明を出し、無ければ名前だけを出す。説明は飾りなので、ファイルが読めない・形が合わないときも一覧全体を失敗させない。表示は書式を固定した `printf '%s …' ` で行い、説明を書式の文字列にしない（設計SO の指摘 6）。
- `oe help <verb>` は持たない。verb の使い方は `oe <verb> --help` の1つの形にする。入口の役目を「振り分けと一覧」に絞るためで、設計SO が一番筋のよい代替として挙げた形である。verb ごとの `--help` の中身はこの issue で保証しない（例: `oe-ident` は不正な引数として何も出さず exit 0 で終わる。`bin/oe-ident:34`）（設計SO の指摘 7）。
- engine の `bin/` の実体のパスを help の1行目に出すのは、規約の書き換え（DJ-6）で、`$oe_bin/README.md` のように在り処を変数で指していた文の行き先にするためである（設計SO の指摘 3）。
- 知らない verb を 127 にするのは、シェルの「コマンドが無い」と同じ意味にそろえ、verb 自身の呼び方の誤り（多くの verb が 2 を返す）と区別するためである。

### DJ-5 `~/bin` への配布（自分で決めた）

- `scripts/sync/sync-bin.sh` の `CMD_NAMES` に `oe`（実体は engine の `bin/oe`＝入口）を足す。`oe-tree` と `oe-hookfire` は互換で残す。`validate-knowledge` と `knowledge-list` は触らない。
- 入口が engine の外の hub の置き場所（`~/work/repos/...`）を持たないようにする。入口が知っているのは「自分の実体のディレクトリ」だけで、どこに checkout してもリンクを張れば動く（#537 の前提）。

### DJ-6 「verb 解決規約」と呼び方を書いた文の書き換え（自分で決めた）

- 規約は「`oe <verb>` で呼ぶ。`command -v oe` が空なら、engine の checkout の `bin/oe <verb>` を直接指す（入口は直接のパスで呼んでも同じに動く）。呼んだあとに終了コードを確かめる（127 は verb が無いか入口が無い）」に置き換える。足がかり（`oe-tree`）から `readlink` で隣を探す手順は消す。
- 呼び方を書いた文をそろえる対象: `doc-flow-guardrail`（規約の節と、委譲固定節の「報告2段構え」の行・③④⑤の工程の文）・`delegate-task`（`BIN="$REPO/projects/orchestration-engine/bin"` と `"$BIN/oe-*"` の23か所）・`orchestration-toolkit`（PATH 未登録の説明と verb の数）・`judgment-board-flow`・`issue-intake`（規約の節を指す文）・`predecision-exploration`・`code-path-exhaustion`（`oe-refute` の場所の書き方）。engine の `bin/README.md` と `README.md`（`oe` の節を `oe-run` へ、入口の節を足す）・hub の `README.md`・`scripts/README.md`・`CLAUDE.md`（配布の件数と一覧）。
- **旧い手順が作っていた変数の消費先も移す。** `doc-flow-guardrail` の③⑤は、規約が作る `$oe_bin` を使って `$oe_bin/README.md` を指している（`canonical/skills/doc-flow-guardrail/SKILL.md:187`・`:202` 付近）。新しい規約は `$oe_bin` を作らないので、これらは「engine の `bin/README.md`（`oe --help` の1行目に出るディレクトリ）」に書き換える。README の在り処を引くためだけに旧い手順を残さない（設計SO の指摘 3）。
- `delegate-task` の `-w "$REPO"` は呼び方でなく委譲先の指定なので変えない。
- 規約の節は消さずに中身を短くする。ほかのスキルが節の名前で指しているので、節を消すと指す先が無くなる。

### DJ-7 PR の単位（自分で決めた）

- **1 PR にする。** 入口・本体の移動・配布の一覧・スキルの文は、1つの論理的な変更（呼び方を入口1本にする）である。分けると、スキルが `oe <verb>` と書いているのに入口がまだ無い、またはその逆の状態が master にできる。

### DJ-8 dotfiles の一時的な関数を消すこと（自分で決めた・実行は gate 6 の側）

- 完了の条件に入れる。dotfiles は別のリポジトリで、brief は子に dotfiles へ書くことを許していないので、条件を2つに分ける（設計SO の指摘 10 の後段）。
  - 子の完了の条件: 消す手順（`.bashrc` の読み込みの3行と `.oe-aliases.bash` を消す、ブランチ `feat/oe-test-aliases` を閉じる）と、消す前の確かめ（新しい入口が `~/bin/oe` として張られ、`oe recover hint -w .` が普通のシェルから動く）を、最後の報告に書いて渡す。
  - issue の完了の条件: owner か統括が、この PR のマージと `sync.sh` のあとに、上の確かめをしてから実際に消す。子は、この条件が済んでいないあいだ、issue を完了と書かない。

## 確定版の項目との対応

| 確定版の項目 | この plan での扱い |
|---|---|
| `oe-*` 27本を1本の入口から `<入口> <verb>` で呼ぶ・配るのは入口1本で新しい verb を足しても一覧を触らない | DJ-3・DJ-4・DJ-5。T-5・T-7 |
| 最初に一次情報で調べ、その結果で入口の名前と形を決める | discussion。DJ-1〜DJ-4 が引く |
| 人も AI も1つの形で全 verb を呼べ、規約と dotfiles の関数が要らなくなる | DJ-6・DJ-8 |
| 修正範囲（engine の `bin/`・`sync-bin.sh`・規約とスキルと brief の文・本体を動かすなら検査） | DJ-1・DJ-5・DJ-6。I1〜I3 |
| 本体の呼び出し元は検査3本と README だけ | 前提で確かめた。DJ-1 |
| `oe-tree` と `oe-hookfire` の配布はすぐに外せない | DJ-5（互換で残す） |
| 子のセッションが入口を PATH で引けるか未確認 | 前提で tmux の PATH を確かめた。I4 で実際に子のペインから引けることを確かめる |
| dotfiles の一時的な関数を消すことを完了の条件に入れる | DJ-8 |
| #609 のサブコマンドの名前の付け方をここで決めるか #609 に回すか | DJ-2（Q2） |
| ［別モデル］`~/bin` のリンクから実体のディレクトリを解く | DJ-3。T-1 |
| ［別モデル］引数・標準入出力・終了コード・シグナルがそのまま渡る | DJ-3（`exec`）。T-2・T-3 |
| ［別モデル］引数なしと `--help` で一覧、未知の verb は明示のエラー、一覧は固定で持たない | DJ-4。T-5・T-6・T-7 |

## ゼロベースの代替（ゲート1）

入口を作る前提を外して、ほかの解き方を1回考えた。

- 全 verb を `~/bin` に配る（`CMD_NAMES` を glob で作る）。新しい verb で一覧を触らずに済むが、PATH に27本の名前が並び、#537 の「外に見せる口を1本にする」に合わない。`dirname "$0"` で lib を解く verb は symlink 越しに動かないので、verb の側も直す必要が出る。
- engine の `bin/` を PATH に足す（シェルの設定で）。配布の仕組みが要らないが、dotfiles か各人のシェルの設定に依存し、hub の sync で配れない。#537 で外に出したときの入れ方としても弱い。
- シェルの関数（dotfiles の `oex` の形）を正式にする。AI の Bash は対話のシェルの関数を読まないことがあり、子のセッションで引けない。

どれも入口1本より条件が悪いので、入口1本の形で進める。

## 設計SO（ゲート2・弱・Codex の1レーン）

`so-compare --codex-only` を 2026-11-09 に1回通した（Codex は gpt-6.1-sol・codex-cli 0.166.0・設定から解決・1回目で返った）。依頼文には `.oe/` の中身を入れていない。判定は Issues Found で、指摘は10件（must 3・should 7）。根拠の行のうち4件（`tests/test_handoff_take.sh:254`・`scripts/README.md:51`・`bin/oe-ident:34`・`doc-flow-guardrail` の `$oe_bin`）は書き手が開き直して確かめ、どれも当たっていた。**10件をすべて採り、plan に入れた**。

| # | 重さ | 指摘 | 入れた先 |
|---|---|---|---|
| 1 | must | 名前の検査を glob で書くと1文字の名前を拒み `abc/def` を通す。端を固定した正規表現と明記し、検査の場面を足す | DJ-3・T-6 |
| 2 | must | T-8 は T-9 の検査の隔離を保証しない。`test_handoff_take.sh` は実物の `oe-selfcheck` を直に呼び、`HOME` を隔離していない | T-9 の隔離（別の受入の条件にした） |
| 3 | must | 旧い規約の手順を消すと、`$oe_bin/README.md` を指す文に未定義の変数が残る | DJ-4（help の1行目に在り処）・DJ-6・達成を見る数の grep |
| 4 | should | 解く処理で作業ディレクトリと `CDPATH` の扱いを決めていない | DJ-3（サブシェル・`CDPATH` を空に）・T-2・T-4 |
| 5 | should | 輪のリンクの検査は、OS が先に拒むので入口の上限を通らずに緑になりうる | DJ-3（`OE_ENTRY_LINK_LIMIT`）・T-1 |
| 6 | should | 一覧と振り分けの候補の条件を1つにする。symlink の扱い・説明の表示の書式 | DJ-3・DJ-4・T-5 |
| 7 | should | `oe help <verb>` の受入の検査と余分な引数の扱いが無い。verb の help の質は一様でない | DJ-4（`oe help <verb>` を持たない形に絞った）・T-5 |
| 8 | should | T-9 は本人と一致・不一致・問い合わせの失敗を分け、口を通ったことも確かめる | T-9 |
| 9 | should | 本体の正常系に入口越しで着く検査が無い。入口と verb の bash を分けて書く | T-4・受入 |
| 10 | should | 配布の受入は `--check` の緑だけでは足りない（写しでも緑）。`scripts/README.md` が漏れている。本体の usage の更新。dotfiles の条件を分ける | T-10・DJ-6・DJ-1・DJ-8 |

Codex は、DJ-2・DJ-5・DJ-7 に妨げになる点は見つからず、固定の一覧や PATH の探索を入れる理由も見つからなかった、と書いている。代替として挙げたのは「隣のファイルの形を保ち、`help <verb>` を省いて入口の役目を縮める」で、指摘 7 として採った。

## 実装の分け方（PR の単位）

1 PR（DJ-7）。

## 達成を見る数の測り方

- `~/bin` に配る engine のコマンドの数: `scripts/sync/sync-bin.sh --list` のうち engine の実体を指すもの。2本（`oe-tree`・`oe-hookfire`）から3本（入口 `oe` と互換の2本）になる。新しい verb を足しても増えない。
- 「verb 解決規約」の手順（足がかりから `readlink` で隣を探す手順）と、その手順や旧い書き方が作る変数を使う文を書いたファイルの数: いまは `doc-flow-guardrail`・`orchestration-toolkit`・`delegate-task` の3つ。0 にし、規約は `doc-flow-guardrail` の1か所で「`oe <verb>`」を指すだけにする。`grep -rnE '\$oe_bin|\$anchor|\$BIN/oe-|BIN="\$REPO/projects/orchestration-engine/bin"' canonical` が空になることで見る（変数の消費先の残りも拾う。設計SO の指摘 3）。

## テスト

新しい検査は `tests/test_oe_entry.sh` に置く。bash 5（`bash tests/test_oe_entry.sh`）と bash 3.2（`/bin/bash tests/test_oe_entry.sh`）の両方で回す。入口は検査と同じ bash（`"$BASH"`）で起こす。

偽物で確かめる検査は、negative knowledge `01M5T897YCWY13GFTADD3136EC` に従い、一時ディレクトリに入口の写しと偽物の verb だけを置いた「偽の engine の bin」を作って、そこへのリンクから呼ぶ。入口は自分の実体のディレクトリしか見ないので、本物の `oe-send` などには届かない。届かないことを T-8 で確かめる。

- T-1 リンクの解決: 絶対パスのリンク・相対パスのリンク・2段のリンク・空白を含むディレクトリのリンク・親のディレクトリが symlink の場合から呼んで、実体の隣の verb が動く。段の上限は、`OE_ENTRY_LINK_LIMIT=2` にして3段のリンク（輪でない鎖）から呼び、入口が出す固有の誤りの文と終了コードが返ることで確かめる（OS が輪を拒む場合と分け、入口の処理に着いた証拠を取る。設計SO の指摘 5）。
- T-2 引数と入出力と作業ディレクトリ: 空白を含む引数・空文字列・`--opt`・`-h`・改行を含む引数が、そのままの数と中身で verb に届く。標準入力が届き、標準出力と標準エラーが分かれたまま返る。verb の終了コード 0・1・2・3・42 がそのまま返る。偽の verb が出す `pwd` が呼び出し元の作業ディレクトリと同じで、`CDPATH` を設定して呼んでも同じである（設計SO の指摘 4）。
- T-3 プロセスの受け渡し: `sh -c 'echo $$; exec <入口> pid'` で、偽の verb が出す `$$` が呼び出し元のシェルの pid と同じ（プロセスが1段も増えない）。`CLAUDE_PID`・`TMUX_PANE`・`CLAUDE_CODE_SESSION_ID`・`OE_LEASE_ID` が verb に届き、入口が足した環境変数が無い（呼ぶ前と後の `env` の差が無い）。verb に送った TERM が verb に届き、終了コードが 143 になる。
- T-4 本体の移動: `oe run --task-file <空のファイル>` が、移す前の `bin/oe` と同じ誤り（exit 2・`file is empty`）を返す。`oe run --task-file <相対パス>` が、呼び出し元の作業ディレクトリから解かれる。`tests/test_oe_task_file.sh` は `bin/oe-run` を指すように直して通す。`tests/test_e2e_smoke.sh` は `bin/oe-run` を直に呼ぶ場面に加え、入口の `oe run` を通す場面を1回足し、正常系に入口越しで着くことを確かめる（設計SO の指摘 9）。
- T-5 一覧と help: 引数なしは標準エラーに一覧と exit 2。`-h`・`--help`・`help` は標準出力に一覧と exit 0 で、1行目が実体の `bin/` のパスである。一覧に出るのは DJ-3 の候補の条件を通るものだけで、README・実行できないファイル・ディレクトリ・入口自身・名前の検査を通らない実行できるファイル（`oe-foo.bak`・`oe-Upper`）・壊れたリンク・外を指すリンクを含まない。候補が0件でも誤りにならない。2行目の説明がある verb は説明付きで出て、説明に `%` を含んでも崩れない。`oe help send` と `oe --help send` は exit 2（設計SO の指摘 6・7）。
- T-6 誤り: 1文字の正しい名前（`oe-a`）は呼べる。知らない verb・`../x`・`a/b`・`abc/def`・`ab/../../x`・改行を含む名前・大文字を含む名前・空文字列は exit 127 と `no such verb`。`oe oe-send` は「`oe send` と打つ」の案内付き。知らないオプションは exit 2（設計SO の指摘 1）。
- T-7 足すだけで呼べる: 偽の engine の bin に `oe-newverb` を足すと、入口を触らずに `oe newverb` で呼べ、一覧に出る。
- T-8 本物に届かない（入口の探し方）: 偽の engine の bin を指すリンクから `oe send` を呼ぶと exit 127（本物の engine の `oe-send` を呼ばない）。PATH の先頭に本物の engine の `bin/` を置いても同じである。
- T-9 本人確認が入口越しに通る: `tests/test_oe_recover.sh` と `tests/test_handoff_take.sh` に、環境変数（例: `OE_TEST_VIA_ENTRY=1`）で verb を「入口を `exec` で呼ぶだけの小さなスクリプト」に差し替える口を足す。この入口の口は、呼ばれるたびに一時ファイルへ1行を書き、検査の終わりにその行数が0でないことを確かめる（口を有効にしたのに直の呼び出しが残って緑になるのを防ぐ）。入口越しに次の3つを、それぞれ期待値付きで通す（設計SO の指摘 8）。
  - 本人と一致する（`CLAUDE_PID` がペインの前面のプロセスと合う）: 復帰・席の取得が済む。
  - 本人と一致しない: 止まり、lease と board が変わらない。
  - 問い合わせに失敗する（偽の `ps` か `tmux` が失敗する）: 既存の検査が決めている扱いのとおりになる。
  - 偽の `ps`・`tmux` が呼ばれた記録も確かめ、本人確認の経路を実際に通ったことを見る。
- T-9 の隔離（T-8 とは別の境界）: 入口の口を有効にした回は、`HOME` と engine の state・lease・event・registry・heartbeat の置き場をすべて一時ディレクトリへ向け、検査の中で直に呼ばれる依存（`tests/test_handoff_take.sh:254` が呼ぶ実物の `oe-selfcheck` と、それが PATH から呼ぶ `tmux`）にも偽物が当たることを確かめる。「入口は隣しか探さない」（T-8）と「verb の依存が本物に届かない」（T-9 の隔離）を、別の受入の条件として扱う（設計SO の指摘 2）。
- T-10 配布: `sync-bin.sh --list` に `oe` が出る。検査用の一時的な `HOME` で配置を走らせ、`${HOME}/bin/oe` が engine の `bin/oe` を指す symlink であること（通常のファイルの写しでないこと）と、そのリンクから `oe --help` と1つの verb が動くことを確かめる。`--check` は内容が同じ通常のファイルも一致と見なすので、`--check` の緑だけでは受けない（設計SO の指摘 10）。

ほかに、変えたスクリプトと新しいスクリプトに `shellcheck` をかける。engine の既存の検査（`tests/` の全部）を回し、変える前の master と同じ結果であることを確かめる。

## 受入

- 確定版の各項目が「確定版の項目との対応」の表のとおりに満たされている。
- T-1〜T-8 と T-10 が bash 5 と bash 3.2 の両方で通る。ここで bash を切り替えるのは入口の側である（入口を `"$BASH"` で起こす）。入口が `exec` したあとの verb は shebang（`#!/usr/bin/env bash`）で PATH の先頭の bash で動くので、verb をどの bash で動かしたかは、検査の結果に別に書く（設計SO の指摘 9）。T-9 は既存の検査の流儀に合わせ、PATH の先頭の bash で通す。
- 子のペイン（`oe-delegate` で起こしたもの）の Bash から `command -v oe` が入口を指し、`oe tree` が動く（I4）。
- 「達成を見る数」が 2本→3本 と 3→0 になっている。
- 子の完了の条件として、dotfiles の一時的な関数を消す手順と消す前の確かめが最後の報告にある。issue の完了の条件として、owner か統括がマージと sync のあとに確かめてから消す（DJ-8）。

## ステップ

### P1: worktree・参照の読み・調べもの（discussion）・設計判断の洗い出し（完了）

### P2: 設計SO（弱・Codex の1レーン）を plan の案に当て、採否を episode に書く（完了・10件をすべて採った）

### P3: plan を draft PR に載せ、ゲート3 の問いを `.oe/question-605-1.json` に書いて `build.py check` を通し、`.oe/report-605-p3.md` を書いて報告の宛先へ1行送り、止まる（完了）

### GATE 3: owner の plan 承認（承認の記録 `.oe/decision-605-gate3.md` が届いてから I に進む）（完了・2026-11-10・3件とも推奨どおり）

### I1: 入口 `bin/oe` を書き、1サイクル本体を `bin/oe-run` に移す。T-1〜T-8 と、本体の検査3本の書き換え（完了）

### CHECK-1: T-1〜T-8 を bash 5 と bash 3.2 で通し、shellcheck と engine の既存の検査を回す（完了・master `b7e4902` と branch の全検査がどちらも全件 exit 0）

### I2: T-9（本人確認を入口越しに通す口）と、`sync-bin.sh` の配布の一覧（DJ-5）と T-10（完了・H1）

### I3: 「verb 解決規約」と呼び方を書いた文の書き換え（DJ-6）・README と CLAUDE.md（完了）

### CHECK-2: 「達成を見る数」を測る。スキルの文に残った古い呼び方を grep で探す（完了・episode の I3）

### GATE 4: 実装SO（弱・1レーン）（完了・指摘5件をすべて直した・H3）

### I4: 子のペインから入口を引けることを確かめる（完了・episode の I4。sync は worktree からかけず、一時ディレクトリのリンクを PATH に置いて確かめる。worktree からの sync は `~/.claude` のリンクを worktree に張り替える）

### I5: PR を ready にし、Copilot の1ラウンドを終え、episode を closure して報告し、止まる（マージ・worktree の掃除・issue の close・dotfiles の変更はしない）

## GATE 3 の問い

- Q1（DJ-1）: 入口の名前を `oe` にし、1サイクル本体を `oe run` に移してよいか。
- Q2（DJ-2）: #609 のサブコマンドは、この issue で決まり（平らな verb・束ねるのは verb の中）だけを決め、具体名は #609 に回してよいか。
- Q3: この plan で実装に進んでよいか。

## ゲート3 のあとの変更

### H1（補正・2026-11-10・I2）: T-9 の対象に `tests/test_lease_handoff.sh` を足し、まとめて回す検査を1本足した

- 何を変えたか: T-9 で入口越しに回す既存の検査を、plan の2本（`test_oe_recover.sh`・`test_handoff_take.sh`）に `test_lease_handoff.sh` を足した3本にした。3本を `OE_TEST_VIA_ENTRY=1` で回し、本人確認の場面の行が PASS で出たことを確かめる検査 `tests/test_oe_entry_identity.sh` を足した。差し替えの口は `tests/fixtures/via-entry.sh` に置いた。T-10 は `tests/test_oe_entry.sh` の中に置いた。
- 理由: 実装の前に読み直すと、`oe-handoff take` の本人確認の場面（前任のペインのプロセスが claude でない・`CLAUDE_PID` が無い、のときに lease も board も動かさない）を持っているのは `test_lease_handoff.sh` の (B) で、`test_handoff_take.sh` は席の張替を見る検査で本人確認の場面を持っていなかった。plan の2本のままだと、T-9 の「本人と一致しない」を `oe-handoff` について確かめられない。
- 級: 補正。承認した結果（入口越しに本人確認が通る）を確かめる検査を強める直しで、step・要件・ゲート・終端は変えていない。plan の2本はそのまま回し、`test_handoff_take.sh` の入口越しの回の `HOME` の隔離（設計SO の指摘 2）も入れてある。

### H2（補正・2026-11-10・I1）: `bin/oe-run` の説明の行を2行目に置いた

- 何を変えたか: 本体を移すとき、`bin/oe-run` の冒頭のコメント（`# oe-run — …`）を、`set -euo pipefail` の前の2行目に動かした。
- 理由: DJ-4 は一覧の説明を各ファイルの2行目の `# oe-<verb> — <説明>` から取る。移す前の `bin/oe` は4行目に `# oe — …` を持っていたので、そのままでは `oe --help` の一覧で `run` だけ説明が空になる。
- 級: 補正。文言と構成の整理で、本体の挙動は変えていない（`tests/test_oe_task_file.sh` と `tests/test_e2e_smoke.sh` が通る）。

### H3（補正・2026-11-10・ゲート4）: 実装SO の指摘5件を直した

- 出どころ: 実装SO（`so-compare --codex-only`・gpt-6.1-sol・1回目で返った・判定は must 1・should 4）。`oe review` は2レーンか3レーンしか受けないので、brief の「実装1レーン」に合わせて `so-compare` で通した。must は書き手も bash 5 と 3.2 で再現した。
- 直したこと:
  1. （must）呼び出し元が export した変数と同じ名前（`dir`・`verb` など）を入口が中で使うと、bash の `local` は export の属性を引き継ぐので、書き換えた値が verb に届いていた。入口の判断をすべてサブシェルの関数 `oe_entry_check` に移し、本体のシェルでは変数に何も代入せずに `exec "$(oe_entry_dir)/oe-$1" "${@:2}"` とした。T-3 に同じ名前の変数を export して呼ぶ場面を足した。
  2. （should）`oe-help` は一覧に出るのに `oe help` が入口の help に取られて呼べなかった。名前 `help` を候補の条件で外した（一覧にも出さない）。T-5 に `oe-help` を置く場面を足した。
  3. （should）`test_handoff_take.sh` の [11b] は、実物の `oe-selfcheck` が PATH の偽の tmux を通ったことを確かめていなかった。偽の tmux が呼ばれた引数を別のログに残し、[11b] の前後で `list-panes` が増えたことを確かめる行を足した。T-9 のまとめの検査でもその行を見る。
  4. （should）`doc-flow-guardrail` の⑤に「子も `oe-recover` を打つ」が残っていた。`oe recover` に直した。
  5. （should）「verb 解決規約」の「127 なら何も実行されていない」は、入口が verb の終了コードをそのまま返すので言い切れない。標準エラーの `oe: no such verb` と `command not found` で入口の側の 127 を見分け、それ以外は verb の出力を読んでから打ち直すかを決める、と直した。
- 級: 補正。承認した要件（環境変数をそのまま渡す・一覧と振り分けを同じ条件にする・入口越しの検査の隔離・呼び方をそろえる）を満たすための直しで、step・ゲート・終端は変えていない。`help` を候補から外すのは、DJ-4 がすでに `help` を入口の help に使うと決めていたことの帰結である。
