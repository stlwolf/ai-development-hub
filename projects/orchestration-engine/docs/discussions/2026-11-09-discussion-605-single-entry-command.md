---
id: "01M70B8NBEHCFVN1XC9HYHWBCR"
title: "#605 engine の入口と verb の配り方を、ほかの CLI がどうしているか"
date: 2026-11-09
type: discussion
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/605"
    reason: "入口の形を決める材料"
  - type: plan
    ref: "projects/orchestration-engine/docs/plans/2026-11-09-plan-605-single-entry-command.md"
    reason: "この調べものを使って書いた計画"
tags: [entry-command, cli-design, research]
---

# #605 engine の入口と verb の配り方を、ほかの CLI がどうしているか

## 何を知りたかったか

engine の `bin/` にある `oe-*` を、`~/bin` に配る1本の入口から `<入口> <verb>` で呼べるようにする（#605）。入口の名前と形を決める前に、次の2つを一次情報で確かめた。

1. 代表的な CLI（git・kubectl・docker・gh・cargo）と、bash で書かれた振り分け役（rbenv・pyenv・basecamp/sub）が、サブコマンドをどう振り分け、どう配っているか。とくに、git のように隣の実行ファイル（`git-<名前>`）へ振り分ける形が今も使われているか。
2. 最近（2026-05〜11 を目安）のオーケストレーション系・コーディングエージェントの CLI が、入口とサブコマンドをどう作り、何を PATH に置いているか。

調べたのは 2026-11-09 で、ソースは各リポジトリのその日の HEAD を読んだ。状態の札は `evidence-verification-rule` の3値で、`[verified]` はこの文書の書き手がソースか公式の文書を開いて確かめたもの、`[unverified-summary]` は調査の下請け（サブエージェント）が読んだと報告し、書き手は開き直していないものである。

## 1. 代表的な CLI と bash の振り分け役

| ツール | 探す名前 | 探す場所 | 呼び方 | 出典 |
|---|---|---|---|---|
| git | `git-<名前>` | exec-path を PATH の先頭に足してから PATH | 子のプロセス（fork と wait）。見つからなければ alias を試してから「not a git command」 | git.c `execv_dashed_external`（v2.56 系 `fb255012ac` の L793-L833）・exec-cmd.c `setup_path` L333-L340 [unverified-summary] |
| kubectl | `kubectl-<名前>` | PATH | Unix では `syscall.Exec`（プロセスを置き換える）。長い名前から先に合わせる（`kubectl foo bar` は `kubectl-foo-bar` を先に試す） | https://github.com/kubernetes/kubectl/blob/64cedd4e35/pkg/cmd/plugin.go （L60 `exec.LookPath`・L87 `syscall.Exec`）[verified] ・ https://kubernetes.io/docs/tasks/extend-kubectl/kubectl-plugins/ [unverified-summary] |
| docker | `docker-<名前>` | `~/.docker/cli-plugins` ほか決まったディレクトリ。PATH は見ない | 子のプロセス。`docker-cli-plugin-metadata` に答えることが条件 | docker/cli `7c0f1b261a` の cli-plugins/manager/manager.go [unverified-summary] |
| gh | `gh-<名前>` | gh のデータディレクトリの `extensions`。PATH ではない | 子のプロセス | https://cli.github.com/manual/gh_extension ・ cli/cli `736c68f674` の pkg/cmd/extension/manager.go [unverified-summary] |
| cargo | `cargo-<名前>` | PATH（`$CARGO_HOME/bin` が先） | 未確認 | https://doc.rust-lang.org/cargo/reference/external-tools.html#custom-subcommands [unverified-summary] |
| rbenv | `rbenv-<名前>` | 自分の実体のディレクトリ（`libexec`）を PATH の先頭に足してから `type -P` | `exec "$command_path" "$@"`。無ければ ``no such command `X'`` で exit 1。`X --help` は `rbenv-help X` へ | https://github.com/rbenv/rbenv/blob/07e9b1e297/libexec/rbenv （`readlink -f` を先に試し、だめなら `readlink` を1段ずつたどるループ・L95-L128 の振り分け）[verified] |
| pyenv | `pyenv-<名前>` | rbenv と同じ | `exec`。自分の場所は、サブシェルの中で `cd` と `readlink` を繰り返して解く | https://github.com/pyenv/pyenv/blob/9e40c078c0/libexec/pyenv L23-L55・L104-L152 [unverified-summary] |
| basecamp/sub | `sub-<名前>` | 同上 | `exec`。一覧は PATH の `sub-*` を glob、help は各ファイルの `# Summary:`・`# Usage:` のコメントから取る | https://github.com/basecamp/sub/blob/4bcb94f0c1/libexec/sub （最後のコミットは 2021-08-24）[unverified-summary] |

分かったこと:

- 隣の `<ツール>-<名前>` を名前で探して呼ぶ形は、git・kubectl・docker・gh・cargo のどれもが今も使っている [unverified-summary]（上の各出典）。ただし、これらは本体を1つのバイナリ（git の builtin、kubectl・docker・gh の cobra）で持ち、外部の実行ファイルは拡張（プラグイン）の口として使っている。全部の verb を隣のスクリプトに置く形が丸ごと残っているのは、bash で書かれた rbenv・pyenv・sub である。
- `exec` で呼ぶか子のプロセスで呼ぶかは、振り分けたあとに入口が何かをするかで分かれる。git・docker・gh は子の後でページャ・シグナルの転送・フックを扱うので子のプロセスにしている。kubectl（Unix）と bash の振り分け役は、振り分けたら何もしないので `exec` にしている。engine の入口は振り分けたら何もしないので、`exec` の側に当たる。
- symlink 越しに自分の実体のディレクトリを解く方法は、rbenv が「`readlink -f` を試し、使えなければ `readlink` を1段ずつたどるループ」を持つ [verified]。macOS の `readlink -f` は 12.3 からなので（rbenv のコメント）、ループの側があれば bash 3.2 と古い macOS でも動く。
- verb の一覧は、ファイルを glob して前置きを外すだけで作る（rbenv の `rbenv-commands`・sub の `sub-commands`）。一覧を固定で持たない。help の短い説明は、各ファイルの冒頭のコメントから取る。

## 2. 最近のオーケストレーション系・コーディングエージェントの CLI

| ツール | PATH に置く名前 | サブコマンドの作り | 束ね方 | 出典 |
|---|---|---|---|---|
| Claude Code | `claude` | 1つのバイナリ | 平らな verb（`update`・`doctor`・`agents` など）と束ねたもの（`auth …`・`mcp …`・`plugin …`）が混ざる | https://code.claude.com/docs/en/cli-reference [unverified-summary] |
| Codex CLI（rust-v0.167.0・2026-11-06） | `codex`（npm の bin は1本） | clap | 平らな `exec`・`review`・`resume` などと、`mcp`・`plugin`・`sandbox` などの束 | https://github.com/openai/codex/blob/main/codex-cli/package.json （`"bin": {"codex": "bin/codex.js"}`）[verified] ・ codex-rs/cli/src/main.rs [unverified-summary] |
| Gemini CLI（v0.67.0） | `gemini` | yargs | `extensions`・`mcp`・`hooks` などの束 | google-gemini/gemini-cli の packages/cli [unverified-summary] |
| Cursor CLI | `agent` | 1つのバイナリ | 平らな `login`・`ls`・`resume` と束ねた `mcp …`・`worker …` | https://cursor.com/docs/cli/reference/parameters [unverified-summary] |
| Goose（v1.57.0） | `goose` | clap | 平らな `run`・`doctor` と、`session`・`recipe`・`plugin` などの束 | crates/goose-cli/src/cli.rs [unverified-summary] |
| agent-of-empires（v1.22.3・tmux とworktree で複数のエージェントを並べる） | `aoe` | clap 4.6 | 平らな `add`・`list`・`send`・`status`・`stop` と、`session …`・`worktree …`・`tmux …` など約18の束 | https://github.com/agent-of-empires/agent-of-empires/blob/main/Cargo.toml （`[[bin]] name = "aoe"`・`clap = "4.6"`）[verified] ・ src/cli/definition.rs [unverified-summary] |
| claude-squad（v1.0.20） | `cs`（brew では `claude-squad`） | cobra | 引数なしで TUI。verb は `reset`・`debug`・`version` だけ | smtg-ai/claude-squad の README・main.go [unverified-summary] |
| ccmanager・vibe-kanban・OpenHands CLI・Amp | それぞれ1本（OpenHands は `openhands-acp` も） | meow・cac・Python の entry point など | フラグ中心か、数個の verb | 各リポジトリの README と manifest [unverified-summary] |

分かったこと:

- どのツールも、PATH に置く名前は1本である [unverified-summary]（上表。codex と aoe は [verified]）。引数なしで打つと、対話の画面や TUI が始まるものが多い。
- verb は日常の操作（`run`・`exec`・`list`・`send`・`stop`・`resume`）を平らに並べ、資源の種類ごとの操作（`mcp`・`plugin`・`auth`・`session`・`worktree`）だけを束ねる形が多い。tmux で複数のエージェントを並べる aoe は、engine に一番近い。aoe も `aoe send`・`aoe list` を平らに置きつつ `aoe session …` を束ねている。
- エージェント系の CLI で、PATH の `<ツール>-<verb>` を探して呼ぶものは見つからなかった。拡張は、エージェントに読み込ませるもの（スキル・MCP サーバ・フック）として `<ツール> plugin …` の束で扱っている。外部の実行ファイルへ振り分ける形が残っているのは、gh・kubectl・git などの汎用の開発ツールである。

## 3. engine の入口への当てはめ

- **形**: PATH に置くのは入口1本、`<入口> <verb>` で振り分ける、という形は、調べたどの系統とも合う。engine は bash のスクリプトの集まりなので、作りは rbenv・sub の型（自分の実体のディレクトリを解く → 隣の `oe-<verb>` を確かめる → `exec`）が一番近い。
- **振り分け先の探し方**: rbenv と sub は自分のディレクトリを PATH の先頭に足してから `type -P` で探す。engine では PATH を触らず、解いたディレクトリの `oe-<verb>` を直に確かめる形がよい。PATH に足すと、verb の中から呼ばれる別のコマンドの解決が変わりうる。issue の「入口は隣の `oe-<verb>` を exec するだけ」とも合う。
- **一覧と help**: 一覧は `oe-*` の glob で作り、固定で持たない（rbenv・sub と同じ）。engine の verb は2行目に `# oe-<verb> — <説明>` の形の1行を持つものが多いので、これを一覧の説明に使える。
- **束ね方**: 平らな verb（ファイル名 `oe-<verb>` がそのまま `<入口> <verb>`）を基本にし、束ねるのは各 verb の中のサブコマンド（すでに `oe-recover hint`・`oe-handoff take`・`oe-lease show` がある）に任せる。aoe の形とも合う。#609 の復帰のコマンドの名前は、この決まりの上で決められる。
- **名前の注意**: Yocto（openembedded-core）の `scripts/` には `oe-build-perf-report`・`oe-check-sstate`・`oe-git-proxy` などの `oe-*` が多数ある（https://github.com/openembedded/openembedded-core/tree/master/scripts ・HEAD `5247d0d886`）[verified]。素の `oe` は見当たらなかった。Yocto のビルド環境の中でだけ PATH に載るものなので、この hub の手元では当たらない。#537 で engine を外に出すときに、名前の衝突の候補として見直す。

## 調べていないこと

- Conductor・Antigravity CLI・Nimbalyst は確かめていない。
- cargo が `exec` で呼ぶか子のプロセスで呼ぶかは確かめていない。
- `[unverified-summary]` の行は、下請けの報告を書き手が開き直していない。結論（入口は1本・平らな verb が基本・bash では `exec` で振り分ける）は、`[verified]` の4件（rbenv・kubectl・codex・aoe）だけでも支えられる。
