---
id: "01M61XWE4PE5N8GFVKT57615XC"
title: "#529 oe-hookfire の tool-attribution が累計で判定し、unknown の記録が1件でも残ると永久に broken になる"
date: 2026-10-29
type: episode
status: draft
related:
  - type: parent_issue
    ref: "https://github.com/stlwolf/ai-development-hub/issues/529"
    reason: "本 episode の作業対象"
  - type: reference
    ref: "projects/orchestration-engine/docs/episodes/2026-10-29-episode-530-hookfire-unreadable-logs.md"
    reason: "同じスクリプトの直前の単位（#530）。読めないときを indeterminate にする決まりをこの単位も守る"
tags: [orchestration, hook, health-check]
knowledge_observations:
  - "01KZ21M0N0FZ4YMR2R6DPHTWQ4"
---

# #529 oe-hookfire の tool-attribution が累計で判定し、unknown の記録が1件でも残ると永久に broken になる

## なぜこの作業が始まったか

2026-10-23 の orchestration-engine の実装の監査（#484）で、`oe-hookfire` の tool-attribution が `tally/unknown/` に記録が1件でも在れば時刻を見ずに broken を出すことが見つかった。手でのプローブ1回で unknown に落ちると、ディレクトリを手で消すまで exit 1 が続く。定期実行に配線すると常に broken になり、ほかの broken が埋もれる。

**この episode は着手時に枠を作り、作業しながら追記している。** 後追いで再構成した節があれば、その節の冒頭にその旨を書く。

## この単位の入力

- brief: 統括（cockpit 21代目）が 2026-10-29 に発行した小さなコードの直し4件の brief（作業層・消える）の単位 U2。着手条件（U1 の PR #552 のマージ）は統括から届いた（master `8afda76`）。plan と認識合わせは owner の方針で省く。終端は U2-S3（報告を送る）。マージ・worktree の掃除・issue の close・sync はしない。
- scope: `projects/orchestration-engine/bin/oe-hookfire` の3節（tool-attribution）に既存の `fresh()` の窓を当てる。窓の外の古い unknown だけなら、累計の件数を表に出したうえで ok にする。2節の道具ごとのループと6節の突き合わせでは `unknown` を飛ばす。
- SO: 実装 weak（Codex 1レーン）+ Copilot 1ラウンド。
- 注入された negative knowledge: 1件（frontmatter の `knowledge_observations`）。closure で観測を書き戻す。

## 作業の記録

### S1: 再現（2026-10-29）

master `8afda76` で再現した。3つの道具の tally をすべて直近にし、`tally/unknown/block-destructive.allow` を1バイト・mtime 2026-01-01 で置くと、`broken tool-attribution ツール不明の記録が 1 ファイル・計 1 件ある` と exit 1 が出た。あわせて `fire/unknown/*` の indeterminate の行が3つと `cross-check/unknown` の info の行が出た。

### S1: 直し方と確かめた結果（2026-10-29）

- **直し方**: 3節は unknown の tally を1つずつ見て、`fresh()` の窓の中で1バイト以上あるものを数える。1つでもあれば broken、無ければ累計（ファイル数・件数）を表に出して ok にする。internal-error（窓の外の古い1件は ok・累計は表に出す）と同じ形である。2節の道具ごとのループと6節の突き合わせでは `unknown` を飛ばす。
- **brief に無い判断が2つある。** どちらも #530 で決めた「読めないときを 0 件に潰さない」と、2節の「サイズ 0 を発火と読まない」を unknown にも当てたもので、新しい決まりを足してはいない。
  - **unknown を読めないとき**: 変更前は、unknown のディレクトリが在るだけで broken だったので、読めなくても broken になっていた。窓で切る形にすると、`find` が失敗したときに 0 ファイルとして ok に落ちる。そこで `find` の終了コードを拾い、失敗したら indeterminate にした。窓で切ることが持ち込む退行を塞ぐためのもので、直さなければこの単位が #530 と同じ不具合を新しく作っていた。
  - **窓の中でサイズ 0 の unknown の tally**: ok にも broken にもせず indeterminate にした。最初は「サイズ 0 は記録ではない」として ok にする形で書き、テストもそう書いた。書いたあとで、2節は同じ状態を「truncate か書き込みの失敗」として indeterminate にしていることに気づき、合わせた。unknown に落ちた記録を truncate で消すと緑になる形を、自分で作りかけていた。
  - unknown のディレクトリが在るが空のときは ok にした（記録が無い）。変更前は broken だった。
- **確かめた結果**: `tests/test_hook_firing.sh` に [20] を足した（7項目）。`/bin/bash` 3.2.57 で pass=69 fail=0、bash 5.2.37 で pass=73 fail=0。oe-hookfire だけを変更前に戻すと [20] の6項目が落ちる（落ちないのは「窓の中の unknown があれば broken」で、今までどおりを確かめる項目）。`shellcheck` は2つのファイルで通る。
