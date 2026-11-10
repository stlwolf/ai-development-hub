---
id: "01M736X8PPTX687HY1PW1N7N5E"
title: "#481 knowledge item 01M579XZ の確かめのコマンドを macOS の grep でも動く形にする"
date: 2026-11-11
type: episode
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/481"
    reason: "本 episode の作業対象"
  - type: reference
    ref: "docs/harness/knowledge/items/01M579XZNAT7EXY4VPGRM9J8JW.md"
    reason: "本文を直す knowledge item"
tags: [knowledge, bash, macos, harness]
---

# #481 knowledge item 01M579XZ の確かめのコマンドを macOS の grep でも動く形にする

## なぜこの作業が始まったか

knowledge item `01M579XZNAT7EXY4VPGRM9J8JW`（bash で変数の直後に ASCII 以外の文字が来ると変数名に食われる）の本文は、確かめのコマンドに `grep -nP` を書いている。#467 でこれを試したところ、macOS 付属の grep は `-P` を受け付けず終了コード 2 になった。教訓は正しいが、確かめの手段が持ち出す先で動かない。統括の小さな直しの委譲（3件のうち1件目）として受けた。

## この単位の入力

- brief: 統括の委譲の書面（gitignored の作業層）。認識合わせと plan は owner の指示で省いた。
- 注入された knowledge item: 統括の採用は0件。着手時に `knowledge-list --strict` を見て、直す対象そのものの `01M579XZNAT7EXY4VPGRM9J8JW` が当たる（bash の文に変数を書く場面ではないが、確かめのコマンドの形を決める判断に使う）。
- SO モード: 実装SO は弱・Codex 1レーンと Copilot 1ラウンド。

## 作業の記録

### S1-0: 着手（2026-11-11 02:05）

- baseline: `origin/master` `74237b2`。
- ブランチ: `fix/#481_knowledge_grep_macos`。brief は worktree を子が作ると書くが、受け手のセッションはデスクトップアプリが用意した worktree の中で動き、そこから出ない決まりなので、その worktree の中で `origin/master` からブランチを切った。3件は順に進めるので、同じ worktree で1件ずつブランチを替える。

### S1-1: 代わりの形を macOS の grep で確かめた結果（2026-11-11 02:08）

確かめのための見本のファイル（作業者の scratchpad・8行）に、囲み忘れの行3つ（`$eq_sync_want）`・`$v、`・`$_x」`）と、当たってはいけない行5つ（`${eq_sync_want}）`・`$v は`・`$v)`・`${v}。`・`\$5、`）を置いた。

```text
$ /usr/bin/grep --version
grep (BSD grep, GNU compatible) 2.6.0-FreeBSD
$ /usr/bin/grep -nP '\$[A-Za-z_][A-Za-z0-9_]*[^\x00-\x7F]' sample.sh
grep: invalid option -- P
exit=2
$ LC_ALL=C /usr/bin/grep -nE '\$[A-Za-z_][A-Za-z0-9_]*[^[:space:] -~]' sample.sh
1:echo "主版 $eq_sync_want）で動く"
3:echo "$v、と"
7:echo "$_x」"
exit=0
$ LC_ALL=C /usr/bin/grep -nE '…同じ…' clean.sh   # ${v}） の1行だけ
exit=1
```

囲み忘れの3行だけを拾い、当たってはいけない5行は拾わなかった。当たりが無いときは終了コード 1 である。`LC_ALL=ja_JP.UTF-8` で `LC_ALL=C` を外した場合も同じ3行だったが、`[^[:space:] -~]` を文字ごとでなくバイトごとに読ませる意図をはっきりさせるため、`LC_ALL=C` は残した。GNU grep はこの環境に無いので確かめていない。そのため item には「macOS で確かめた・POSIX の `-E` と文字クラスだけを使う」と書き、GNU grep で動くとは書かなかった。

### S1-2: item の本文の直し方（2026-11-11 02:10）

- 太字の行動の文の grep を新しい形に替え、当たりが無ければ終了コード 1 になることを添えた。
- そのすぐ下に段落を1つ足し、macOS の grep で確かめたこと、`LC_ALL=C` と `[^[:space:] -~]` の意味、`-P` を使わない理由（終了コード 2 で何も確かめない）、当たらない形（`${var}`・名前で始まらない `$`）を書いた。
- 「行動をどう変えるか」の節の「上の grep」を「上の `LC_ALL=C grep -nE`」に替え、どちらの grep を指すかを一通りにした。
- 観測の台帳（`observations`）には足していない。issue のとおり、直したことは本文の更新として残し、#467 と #571 の観測は書いたときのまま残す。

### S1-3: check_runbook.py の R9 を指す1行は足さない（2026-11-11 02:12）

足さないと決めた。理由は、R9 が見る範囲が item の当たる場面と重ならないからである。`check_runbook.py` の引数は手順書の `.md` か手順書の置き場で（同ファイルの先頭の使い方と `collect`）、R9 が見るのは手順書のコマンドのブロックと、手順書が呼ぶ bash のスクリプトだけである（`runbook-authoring` の `SKILL.md` の検査の表の R9）。item の trigger は bash のスクリプト・テスト・heredoc 一般で、手順書から呼ばれないスクリプトや test の文言（#401 の出来事）には R9 を当てられない。item から「検査のスクリプトがあればそれを使う」と指すと、当てられない場面でも検査があると読める。手順書を書く担当は `runbook-authoring` 自身が R9 を案内しているので、item の側から指さなくても届く。

### S2-1: 実装SO の結果と採否（2026-11-11 02:10〜02:15）

Codex 1レーン（`gpt-6.1-sol`・45秒・exit 0・`tool_status` は `not_observed`）は指摘を3つ返した。結果は `tmp/so-481/codex-stdout.txt`（gitignored）にある。

1. 採る。新しい grep は行の文字だけを見るので、単一引用の中・`\$v）`・注釈・引用した heredoc の中の `$v）` にも当たる（展開されないので誤検出）。逆に `"$v\` の行継続で次の行の先頭に `）` が来る形は拾わない。手元の macOS の grep で、前の3つ（単一引用・注釈・`\$v）`）が当たり、行継続が当たらないことを再現した。元の `grep -nP` の形にも同じ限界があったが、item は「囲み忘れが無いことを確かめる」と書いており、当たれば誤りと読める。item に「当たった行は候補で、展開される位置かを目で見る」段落を足した。ASCII の制御文字（`0x01`・`0x7f`）にも当たるという指摘は、本文の説明が既に「空白でも印字できる ASCII でもないバイト」と書いて正確なので、足さない。
2. 採否なし。`LC_ALL=C`・`-P` を使わない理由・終了コードの説明は正しいという答えだった。
3. 採る。S1-3 の判断を撤回する（下の S2-2）。

### S2-2: R9 を指す1行を足すに替えた（2026-11-11 02:15）

S1-3 で「R9 の範囲は item の場面と重ならない」と書いたのは誤りだった。手順書のコマンドのブロックと手順書が呼ぶスクリプトは、item の trigger（bash のスクリプト・heredoc）の一部である。正しくは「R9 は item の場面の一部だけを見る」である。そのうえで、R9 は grep にできないこと（引用・注釈・ヒアドキュメントを追って、展開されない位置を除く）をするので、手順書の場面では grep より誤検出が少ない。範囲を「手順書のコマンドのブロックと、手順書が呼ぶ bash のスクリプト」に限って書けば、ほかの場面でも検査があると読まれる心配は無い。そこで S1-1 の段落の末尾に、範囲を限った1文を足した。item の側からだけ指し、スキルの側は変えていない。

### S1-4: 検査の結果（2026-11-11 02:11・S2-2 のあとに 02:16 に打ち直した）

```text
$ validate-knowledge docs/harness/knowledge/items/01M579XZNAT7EXY4VPGRM9J8JW.md
OK: docs/harness/knowledge/items/01M579XZNAT7EXY4VPGRM9J8JW.md
$ validate-knowledge docs/harness/knowledge/items
OK: docs/harness/knowledge/items
```
