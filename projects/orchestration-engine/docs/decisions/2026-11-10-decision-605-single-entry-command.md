---
id: "01M70HVB01QSRATF8HMXYYKZJB"
title: "engine の入口を oe の1本にし、verb はファイル名 oe-<verb> のとおり平らに並べ、束ねるのは verb の中のサブコマンドにする"
date: 2026-11-10
type: decision
status: stable
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/605"
    reason: "本 decision が記録する owner の判定（ゲート3 の Q103・Q104・2026-11-10）の issue"
  - type: derived_from
    ref: "projects/orchestration-engine/docs/plans/2026-11-09-plan-605-single-entry-command.md"
    reason: "判定の材料。設計判断 DJ-1〜DJ-8・ゲート3 のあとの補正 H1〜H3"
  - type: design_context
    ref: "projects/orchestration-engine/docs/discussions/2026-11-09-discussion-605-single-entry-command.md"
    reason: "ほかの CLI が入口と verb をどう配っているかの調べもの（出典付き）"
  - type: reference
    ref: "projects/orchestration-engine/docs/episodes/2026-11-09-episode-605-single-entry-command.md"
    reason: "作業の記録。設計SO・実装SO の採否と陽性対照"
  - type: future_hook
    ref: "https://github.com/stlwolf/ai-development-hub/issues/609"
    reason: "統括の復帰を1本のコマンドにする issue。その名前は決定2 の決まりの上で付ける"
  - type: future_hook
    ref: "https://github.com/stlwolf/ai-development-hub/issues/537"
    reason: "engine を独立したパッケージにしていく大目標。入口 oe は外に見せる口になる"
tags: [orchestration, entry-command, distribution, cli-design, decision]
---

# engine の入口を oe の1本にし、verb はファイル名 oe-<verb> のとおり平らに並べ、束ねるのは verb の中のサブコマンドにする

## 背景

engine の `bin/` の `oe-*` は、`~/bin` に `oe-tree` と `oe-hookfire` の2本しか配っておらず、ほかの verb は AI が「verb 解決規約」（PATH にある `oe-tree` の実体のディレクトリから隣を探す手順）で呼び、人は PATH に無いので打てなかった（統括の復帰の試験で `oe-recover` を打つために dotfiles に一時的な関数を置いた）。verb を足すたびに配布の一覧に1本ずつ足す形は続かず、engine を外に出す大目標（#537）でも外に見せる口は1本のコマンドにしたい、という owner の方針で #605 が立った。

## 決定

### 決定1 入口の名前は oe にし、1サイクルの本体は oe run に移す（Q103）

- `~/bin` に配る入口を `oe` にする。入口は `oe <verb> [引数...]` で、自分の実体のディレクトリの隣の `oe-<verb>` を `exec` するだけにする。
- これまで `bin/oe` だった1サイクルの自律オーケストレーションの本体は `bin/oe-run` に移し、`oe run` で呼ぶ。
- 棄却した案:
  - 入口を別の名前（例: `oectl`）にし、本体の `oe` を残す。入口の名前と verb の前置きが食い違い（`oectl recover` が `oe-recover` を呼ぶ）、PATH に `oe` 系の名前が2つ並ぶ。
  - `oe` のまま、最初の引数が verb の名前なら振り分け、そうでなければタスクの文として本体へ渡す。`oe recover` が「recover という文のタスク」か「verb」かを区別できない。
- 選んだ理由: 入口の名前と verb のファイルの前置きがそろうので、`oe <verb>` と `bin/oe-<verb>` が名前の規則だけで1対1に対応し、「`oe-<verb>` を足すだけで呼べる」が入口の側の一覧なしで成り立つ。本体の呼び出し元は検査3本と README だけで、移す費用が小さかった。

### 決定2 verb は平らに並べ、束ねるのは verb の中のサブコマンドにする（Q104）

- 入口の直下の verb は、ファイル名 `oe-<verb>` のとおり平らに並べる。入口の側で verb を束ねる層（`oe cockpit restore` を入口が `oe-cockpit` の `restore` へ振り分けるなど）は作らない。
- 束ねたいときは、verb の中のサブコマンドにする。いまの `oe recover hint`・`oe handoff take`・`oe lease show` がこの形である。
- 名前 `help` は入口の help に使うので、verb の名前にしない。
- 具体的な名前（#609 の復帰のコマンドなど）は、その verb の設計が決まってから、この決まりの上で付ける。
- 棄却した案:
  - #605 で #609 の具体名まで決める（例: `oe-cockpit` を足して `oe cockpit restore`）。#609 は設計を寄せておく段階で中身が未確定なので、名前だけ先に決めると後で合わなくなりうる。
  - 決まりも決めず、すべて #609 に回す。入口の作り（入口の側で束ねるかどうか）が #609 の結論で変わりうる状態が残る。
- 選んだ理由: 入口の側で束ねると、入口が verb の一覧と束ね方を知る必要が出て、決定1 の「足すだけで呼べる」が崩れる。調べた CLI（Claude Code・Codex CLI・Goose・agent-of-empires など）も、日常の操作を平らに並べ、資源の種類ごとの操作だけを束ねる形が多かった（discussion の2節）。

### 決定3 入口は振り分け役に徹し、呼び出し元の状態を何も変えない

- 入口は PATH を探さず書き換えず、解いたディレクトリの `oe-<verb>` だけを見る。
- 入口の判断はすべてサブシェルの中で行い、本体のシェルでは変数に代入せずに `exec` する。引数・標準入出力・終了コード・シグナル・環境変数・作業ディレクトリは verb のまま届く。
- 理由（環境）: lease の本人確認は `CLAUDE_PID` などの環境変数とペインの前面のプロセスで行い、verb 自身のプロセスの位置は見ない。したがって入口越しに本人確認を変えうるのは、入口が環境変数を変えることである。実装SO で、bash の `local` が export の属性を引き継ぐために、呼び出し元が export した同名の変数を入口が書き換えて渡していたことが分かり、本体のシェルで代入しない形にした（episode の「GATE 4」節）。
- 理由（`exec`）: 入口は振り分けたあとに何もしないので、`exec` でプロセスを置き換え、プロセスの段を増やさない。シグナルと終了コードの受け渡しを入口が仲介せずに済む。

## 当時の前提（偽になったら見直す）

- engine の verb が bash のスクリプトで、`bin/` の中に `oe-<verb>` のファイルとして並んでいること。verb を1つのバイナリにまとめる（cobra・clap などのフレームワークに移る）なら、入口の作りと決定2 の「ファイル名どおり」は見直す。
- `oe` という名前が、使う環境の PATH でほかのコマンドとぶつからないこと。Yocto（openembedded-core）の `scripts/` に `oe-*` が多数あるが、素の `oe` は無く、Yocto のビルド環境の中でだけ PATH に載る（2026-11-09 に確認）。#537 で engine を外に出すときに見直す。
- `oe-tree` と `oe-hookfire` を、dotfiles の `.tmux.conf` などが `~/bin` の絶対パスで呼んでいること。呼び出し元を `oe tree` に移せば、互換で残している2本の配布を外せる。
