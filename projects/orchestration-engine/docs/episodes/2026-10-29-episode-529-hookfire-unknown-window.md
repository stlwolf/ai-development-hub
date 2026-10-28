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

### S2: 実装SO（弱・Codex 1レーン）の結果と採否（2026-10-29）

Codex の1レーンが返った（`timeout_status=success`・125秒）。出力は作業層の `tmp/so-529-impl/` にある。指摘は中4件・低1件で、**どれも「最近 unknown に落ちた記録を ok と見逃す経路」だった。** 2節・6節で unknown を飛ばしたこと、窓の中のサイズ 0 を indeterminate にしたこと、空の unknown ディレクトリを ok にしたことには反対が無かった。

- **見立て**: 変更前は unknown が在るだけで broken だったので、数え方の取りこぼし（ファイル名の改行・symlink・途中の失敗）は判定に出なかった。窓で切ると、取りこぼしたものがそのまま「窓の中に無い」になり、ok に化ける。**窓で切る直しは、それまで隠れていた数え方の甘さを ok の側へ露出させる。** S1 では「読めないとき」だけを塞ぎ、ほかの取りこぼしを見ていなかった。
- **採用（中）: 各ファイルの `fresh()` の中の find の失敗が「窓の外」になる。** 採用（中）: **ファイル名やディレクトリ名に改行があると、改行区切りで読み直したときに割れ、最近の記録が ok になる。** 採用（中）: **`-type f` は symlink を拾わないので、symlink の先へ追記された記録が数えられない。** 採用（中）: **入口の `-d` が、祖先を辿れない・壊れた symlink を「無い」として ok にする**（これは変更前からある筋）。
- **直し方**: 3節を書き直した。件数は find 自身の述語（`-size +0 -mtime -N` など）で数え、`-print0` の NUL を数える。`-L` で symlink を辿る。find と cat が1つでも失敗したら indeterminate にする。入口は #530 で足した `log_state` で分ける。ファイルを1つずつ読み直すループをやめたので、各ファイルの `fresh()` の失敗という筋自体が無くなった。
- **採用（低）: `size_of` の失敗を累計 0 に潰していた。** 累計を `find -L … -exec cat {} + | wc -c` で数え、失敗したら indeterminate にする形に含めた。
- テストに6項目足した（空のディレクトリ・改行を含むファイル名・ファイルの symlink・ディレクトリの symlink・壊れた symlink・祖先を辿れない）。前のコミットに対しては5項目が落ちる（空のディレクトリはもともと ok）。master に対しては [20] の13項目のうち9項目が落ちる。落ちない4項目は、master が「在るだけで broken」なので通るもの（窓の中の記録・改行・2つの symlink）で、窓で切った後の非回帰を確かめる項目である。テストは `/bin/bash` 3.2.57 で pass=75 fail=0、bash 5.2.37 で pass=79 fail=0。

### S2: Copilot の1ラウンド（2026-10-29）

Copilot のレビューは行への指摘が0件で、概要に「unknown の下の tally が壊れた symlink だと黙って飛ばされ、ok になる」と1件あった。**採用した。** S2 の実装SO で symlink を `-L` で辿る形にしたが、辿れない symlink は `-L` の下でも型が `l` のまま残り、`-type f` で数えられない。窓の中の記録が1つも無く辿れない symlink があるときは indeterminate にする。テストに1項目足し、前のコミットに対して落ちることを確かめた。テストは `/bin/bash` 3.2.57 で pass=76 fail=0、bash 5.2.37 で pass=80 fail=0。#530 で入口の壊れた symlink を扱ったのに、中身の壊れた symlink を同じ単位で見なかった。
