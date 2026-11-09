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
